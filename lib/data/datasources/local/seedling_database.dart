import 'dart:async';
import 'dart:io' show Directory, File;
import 'dart:typed_data';

import 'package:drift/drift.dart'
    show
        ResultSetImplementation,
        TableUpdate,
        TableUpdateQuery,
        driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../../../core/services/error_reporter.dart';
import '../../../core/services/media/file_storage_service.dart';
import '../../../core/services/security/clock_guard_service.dart';
import '../../../core/services/security/database_key_store.dart';
import '../../models/entry.dart';
import '../../models/ritual.dart';
import '../../models/sync_id.dart';
import '../../models/tree.dart';
import 'schema.dart';

/// An entry removed by [SeedlingDatabase.purgeExpiredEntries], as sync
/// needs to know it (to delete the remote record and media blob).
typedef PurgedEntry = ({String syncUUID, String? mediaAssetId});

/// The database could not be opened safely: SQLCipher is missing, or the
/// key does not decrypt the file. Nothing is ever opened unencrypted.
class DatabaseOpenException implements Exception {
  final String message;
  final Object? cause;
  const DatabaseOpenException(this.message, [this.cause]);

  @override
  String toString() => 'DatabaseOpenException: $message';
}

/// Seedling's local store: one SQLite file, encrypted as a whole with
/// SQLCipher (a random 256-bit key from the device-only keychain).
///
/// Schema, migrations and change notifications are drift's
/// ([SeedlingSchema]). Reads are synchronous on the same connection, which
/// is what the UI providers expect; every write is one transaction followed
/// by one change notification. Each read builds fresh [Entry] objects, so a
/// caller mutating what it got back never affects anyone else.
class SeedlingDatabase {
  SeedlingDatabase._(
    this._raw,
    this._schema, {
    required this.storeDirectory,
    required this.isFreshStore,
  });

  final sql.Database _raw;
  final SeedlingSchema _schema;
  FileStorageService? _fileStorage;
  ClockGuardService? _clockGuard;
  ErrorReporter _errorReporter = const ErrorReporter();
  bool _closed = false;

  static SeedlingDatabase? _instance;

  /// File name of the database inside [storeDirectory].
  static const fileName = 'seedling.db';

  /// Directory holding the database file (and its `-wal` / `-shm`
  /// companions). Empty for an in-memory test database.
  final String storeDirectory;

  /// True when the database file did not exist before this open, i.e. a
  /// fresh install or a device restored from a backup (the database is
  /// excluded from iOS backups, but SharedPreferences are not).
  final bool isFreshStore;

  /// Default on-device location of the app's database directory.
  static Future<String> defaultStoreDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/database';
  }

  /// Opens the app's database (once; later calls return the same instance).
  ///
  /// The key is read from the keychain and created only when there is none.
  /// A database file whose key is gone can never be read again; it is set
  /// aside (renamed, not deleted) and an empty database is started.
  static Future<SeedlingDatabase> create({
    DatabaseKeyStore? keyStore,
    String? directory,
    ErrorReporter errorReporter = const ErrorReporter(),
  }) async {
    final existing = _instance;
    if (existing != null) return existing;

    final dir = directory ?? await defaultStoreDirectory();
    final keys = keyStore ?? DatabaseKeyStore();
    var key = await keys.read();
    if (key == null) {
      final file = File('$dir/$fileName');
      if (await file.exists()) {
        errorReporter.report(
          StateError('Database key missing; setting the old file aside'),
          context: 'SeedlingDatabase.create',
        );
        await _setAside(dir);
      }
      key = await keys.create();
    }
    final db = await _open(directory: dir, key: key);
    db._errorReporter = errorReporter;
    _instance = db;
    return db;
  }

  /// Opens a standalone database (not the app singleton) for tests: in
  /// [directory] when given, otherwise in memory.
  @visibleForTesting
  static Future<SeedlingDatabase> openForTesting({
    String? directory,
    Uint8List? key,
  }) {
    // Tests open several databases at once (e.g. two sync devices); each has
    // its own connection, so drift's single-instance warning doesn't apply.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return _open(directory: directory, key: key ?? _testKey);
  }

  static final Uint8List _testKey = Uint8List.fromList(
    List<int>.generate(DatabaseKeyStore.keyLength, (i) => i * 7 + 1),
  );

  static Future<void> _setAside(String directory) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (final suffix in const ['', '-wal', '-shm']) {
      final file = File('$directory/$fileName$suffix');
      if (await file.exists()) {
        await file.rename('$directory/$fileName.unreadable-$stamp$suffix');
      }
    }
  }

  static Future<SeedlingDatabase> _open({
    required String? directory,
    required Uint8List key,
  }) async {
    final sql.Database raw;
    final bool fresh;
    if (directory == null) {
      raw = sql.sqlite3.openInMemory();
      fresh = true;
    } else {
      await Directory(directory).create(recursive: true);
      final path = '$directory/$fileName';
      fresh = !await File(path).exists();
      raw = sql.sqlite3.open(path);
    }

    try {
      _unlock(raw, key);
      raw.execute('PRAGMA journal_mode = WAL');
      // Safe with WAL (a power cut can lose the last commit, never corrupt).
      raw.execute('PRAGMA synchronous = NORMAL');
      raw.execute('PRAGMA foreign_keys = ON');
    } catch (_) {
      raw.close();
      rethrow;
    }

    final schema = SeedlingSchema(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    // Runs creation (and, in later versions, migrations) before first use.
    await schema.customSelect('SELECT 1').get();

    final db = SeedlingDatabase._(
      raw,
      schema,
      storeDirectory: directory ?? '',
      isFreshStore: fresh,
    );
    assert(db._columnsMatchSchema(), 'Entry columns drifted from schema.dart');
    db._ensureTreeForYear(DateTime.now().year);
    return db;
  }

  /// Applies the SQLCipher key, refusing to continue without SQLCipher or
  /// with a key that does not decrypt the file.
  static void _unlock(sql.Database raw, Uint8List key) {
    final version = raw.select('PRAGMA cipher_version');
    final cipher = version.isEmpty ? null : version.first.values.first;
    if (cipher is! String || cipher.isEmpty) {
      throw const DatabaseOpenException(
        'SQLCipher is not linked; refusing to open an unencrypted database',
      );
    }
    if (key.length != DatabaseKeyStore.keyLength) {
      throw const DatabaseOpenException('Database key has the wrong length');
    }
    final hex = [
      for (final b in key) b.toRadixString(16).padLeft(2, '0'),
    ].join();
    // A raw key: no passphrase derivation, so opening stays fast.
    raw.execute("PRAGMA key = \"x'$hex'\"");
    try {
      // SQLCipher only checks the key when the first page is read.
      raw.select('SELECT count(*) FROM sqlite_master');
    } on sql.SqliteException catch (e) {
      throw DatabaseOpenException('The database key does not match', e);
    }
  }

  /// Attach the media file storage service so hard deletes can clean up files.
  void attachFileStorage(FileStorageService fileStorage) {
    _fileStorage = fileStorage;
  }

  /// Attach a clock guard so capsule visibility queries can defend against
  /// device-clock rollback.
  void attachClockGuard(ClockGuardService clockGuard) {
    _clockGuard = clockGuard;
  }

  /// Attach an error reporter so silently-handled failures (e.g. media file
  /// cleanup) can be funneled to a single sink. Defaults to a no-op reporter.
  void attachErrorReporter(ErrorReporter errorReporter) {
    _errorReporter = errorReporter;
  }

  /// Returns the trusted "now" (UTC) for capsule unlock comparisons,
  /// falling back to system clock when no guard is attached.
  ///
  /// The guard's value is captured at launch, so it only acts as a floor
  /// (defending against the clock being rolled back); time still moves
  /// forward while the app stays open, so capsules that come due mid-session
  /// unlock.
  DateTime _trustedNowUtc() {
    final systemNow = DateTime.now().toUtc();
    final cached = _clockGuard?.cachedTrustedNow();
    if (cached != null && cached.isAfter(systemNow)) return cached;
    return systemNow;
  }

  /// Close the database.
  void close() {
    if (_closed) return;
    _closed = true;
    for (final statement in _statements.values) {
      statement.close();
    }
    _statements.clear();
    unawaited(_schema.close());
    _raw.close();
    if (identical(_instance, this)) _instance = null;
  }

  // ============== Plumbing ==============

  final Map<String, sql.PreparedStatement> _statements = {};

  /// A prepared statement for [sqlText], kept for the connection's lifetime
  /// (the write path runs the same few statements over and over).
  sql.PreparedStatement _statement(String sqlText) => _statements.putIfAbsent(
    sqlText,
    () => _raw.prepare(sqlText, persistent: true),
  );

  /// Runs [body] in one write transaction (all or nothing).
  T _transaction<T>(T Function() body) {
    _raw.execute('BEGIN IMMEDIATE');
    try {
      final result = body();
      _raw.execute('COMMIT');
      return result;
    } catch (_) {
      _raw.execute('ROLLBACK');
      rethrow;
    }
  }

  void _notify({
    bool entries = false,
    bool trees = false,
    bool rituals = false,
  }) {
    if (_closed) return;
    _schema.notifyUpdates({
      if (entries) TableUpdate.onTable(_schema.entries),
      if (trees) TableUpdate.onTable(_schema.trees),
      if (rituals) TableUpdate.onTable(_schema.rituals),
    });
  }

  /// A stream that emits [read] now and again after changes to [tables].
  ///
  /// Changes are coalesced per event-loop turn: a burst of writes (a sync
  /// merge applying deletes one by one, an import) costs one re-read, not
  /// one per write.
  Stream<T> _watch<T>(
    List<ResultSetImplementation<dynamic, dynamic>> tables,
    T Function() read,
  ) {
    final query = TableUpdateQuery.onAllTables(tables);
    return Stream<T>.multi((controller) {
      controller.add(read());
      Timer? pending;
      final subscription = _schema
          .tableUpdates(query)
          .listen(
            (_) => pending ??= Timer(Duration.zero, () {
              pending = null;
              if (_closed || controller.isClosed) return;
              controller.add(read());
            }),
            onError: controller.addError,
            onDone: () {
              pending?.cancel();
              controller.close();
            },
          );
      controller.onCancel = () {
        pending?.cancel();
        return subscription.cancel();
      };
    });
  }

  static int _ms(DateTime value) => value.millisecondsSinceEpoch;
  static int? _msOrNull(DateTime? value) => value?.millisecondsSinceEpoch;
  static DateTime _date(Object? ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms! as int);
  static DateTime? _dateOrNull(Object? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);

  /// The instant [value] names, in local time and at the millisecond
  /// precision the database keeps, so a caller's object matches a later
  /// read (importers and sync hand in UTC DateTimes).
  static DateTime _localMs(DateTime value) =>
      DateTime.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch);

  static void _normaliseDates(Entry entry) {
    entry.createdAt = _localMs(entry.createdAt);
    final deletedAt = entry.deletedAt;
    entry.deletedAt = deletedAt == null ? null : _localMs(deletedAt);
    final unlock = entry.capsuleUnlockDate;
    entry.capsuleUnlockDate = unlock == null ? null : _localMs(unlock);
    final modifiedAt = entry.modifiedAt;
    entry.modifiedAt = modifiedAt == null ? null : _localMs(modifiedAt);
  }

  // ============== Entry rows ==============

  static const _entryColumns = <String>[
    'created_at',
    'type_index',
    'text',
    'media_path',
    'title',
    'context',
    'mood',
    'tags',
    'is_released',
    'is_deleted',
    'deleted_at',
    'detected_theme',
    'manual_link_ids',
    'capsule_unlock_date',
    'transcription',
    'sync_uuid',
    'modified_at',
    'device_id',
    'media_asset_id',
    'media_key',
  ];

  static List<Object?> _entryValues(Entry e) => [
    _ms(e.createdAt),
    e.typeIndex,
    e.text,
    e.mediaPath,
    e.title,
    e.context,
    e.mood,
    e.tags,
    e.isReleased ? 1 : 0,
    e.isDeleted ? 1 : 0,
    _msOrNull(e.deletedAt),
    e.detectedTheme,
    e.manualLinkIds,
    _msOrNull(e.capsuleUnlockDate),
    e.transcription,
    e.syncUUID,
    _msOrNull(e.modifiedAt),
    e.deviceId,
    e.mediaAssetId,
    e.mediaKey,
  ];

  /// Reads the columns of [_selectEntryColumns], by position.
  static Entry _entryFromRow(sql.Row r) => Entry(
    id: r.columnAt(0) as int,
    createdAt: _date(r.columnAt(1)),
    typeIndex: r.columnAt(2) as int,
    text: r.columnAt(3) as String?,
    mediaPath: r.columnAt(4) as String?,
    title: r.columnAt(5) as String?,
    context: r.columnAt(6) as String?,
    mood: r.columnAt(7) as String?,
    tags: r.columnAt(8) as String?,
    isReleased: r.columnAt(9) != 0,
    isDeleted: r.columnAt(10) != 0,
    deletedAt: _dateOrNull(r.columnAt(11)),
    detectedTheme: r.columnAt(12) as String?,
    manualLinkIds: r.columnAt(13) as String?,
    capsuleUnlockDate: _dateOrNull(r.columnAt(14)),
    transcription: r.columnAt(15) as String?,
    syncUUID: r.columnAt(16) as String?,
    modifiedAt: _dateOrNull(r.columnAt(17)),
    deviceId: r.columnAt(18) as String?,
    mediaAssetId: r.columnAt(19) as String?,
    mediaKey: r.columnAt(20) as String?,
  );

  static final String _selectEntryColumns = ['id', ..._entryColumns].join(', ');

  bool _columnsMatchSchema() {
    final declared = {for (final c in _schema.entries.$columns) c.name};
    return declared.length == _entryColumns.length + 1 &&
        declared.containsAll(_entryColumns) &&
        declared.contains('id');
  }

  static final String _insertEntrySql =
      'INSERT INTO entries (${_entryColumns.join(', ')}) '
      'VALUES (${List.filled(_entryColumns.length, '?').join(', ')})';
  static final String _insertEntryWithIdSql =
      'INSERT INTO entries (id, ${_entryColumns.join(', ')}) '
      'VALUES (?, ${List.filled(_entryColumns.length, '?').join(', ')})';
  static final String _updateEntrySql =
      'UPDATE entries SET ${_entryColumns.map((c) => '$c = ?').join(', ')} '
      'WHERE id = ?';

  /// Entries matching [where] (a WHERE/ORDER BY tail with `?` for [args]).
  /// The statement is kept prepared unless [oneOff] (variable-length SQL).
  List<Entry> _entries(
    String where, [
    List<Object?> args = const [],
    bool oneOff = false,
  ]) {
    final sqlText = 'SELECT $_selectEntryColumns FROM entries $where';
    if (oneOff) {
      return [for (final row in _raw.select(sqlText, args)) _entryFromRow(row)];
    }
    final cursor = _statement(sqlText).selectCursor(args);
    final result = <Entry>[];
    while (cursor.moveNext()) {
      result.add(_entryFromRow(cursor.current));
    }
    return result;
  }

  static const _newestFirst = 'ORDER BY created_at DESC, id DESC';

  // ============== Tree Operations ==============

  Tree _ensureTreeForYear(int year) {
    final existing = getTreeForYear(year);
    if (existing != null) return existing;
    final tree = Tree(year: year);
    _raw.execute(
      'INSERT OR IGNORE INTO trees (year, entry_count, created_at, '
      'state_index) VALUES (?, ?, ?, ?)',
      [year, 0, _ms(tree.createdAt), tree.stateIndex],
    );
    return getTreeForYear(year)!;
  }

  static Tree _treeFromRow(sql.Row r) => Tree(
    id: r['id'] as int,
    year: r['year'] as int,
    entryCount: r['entry_count'] as int,
    createdAt: _date(r['created_at']),
    stateIndex: r['state_index'] as int,
  );

  void _putTree(Tree tree) {
    _raw.execute(
      'INSERT INTO trees (year, entry_count, created_at, state_index) '
      'VALUES (?, ?, ?, ?) ON CONFLICT(year) DO UPDATE SET '
      'entry_count = excluded.entry_count, '
      'state_index = excluded.state_index',
      [tree.year, tree.entryCount, _ms(tree.createdAt), tree.stateIndex],
    );
  }

  /// Get tree for a specific year
  Tree? getTreeForYear(int year) {
    final rows = _raw.select('SELECT * FROM trees WHERE year = ?', [year]);
    return rows.isEmpty ? null : _treeFromRow(rows.first);
  }

  /// Get the current year's tree
  Tree? get currentTree => getTreeForYear(DateTime.now().year);

  /// Get all trees
  List<Tree> getAllTrees() => [
    for (final row in _raw.select('SELECT * FROM trees ORDER BY year'))
      _treeFromRow(row),
  ];

  /// Watch current tree for changes
  Stream<Tree?> watchCurrentTree() =>
      _watch([_schema.trees], () => currentTree);

  // ============== Entry Operations ==============

  /// Save an entry (new or existing) and keep tree counts in step.
  Future<Entry> saveEntry(Entry entry) async {
    _writeEntries([entry]);
    return entry;
  }

  /// Save many entries in a single transaction with a single change
  /// notification. Tree counts are adjusted from each entry's previous stored
  /// state, so inserting soft-deleted entries or flipping isDeleted keeps
  /// counts correct.
  ///
  /// With [preserveModifiedAt] the entries keep their own modifiedAt (sync
  /// merges must not make a remote change look like a newer local edit).
  Future<List<Entry>> saveEntries(
    List<Entry> entries, {
    bool preserveModifiedAt = false,
  }) async {
    _writeEntries(entries, preserveModifiedAt: preserveModifiedAt);
    return entries;
  }

  /// Update an entry. Tree counts follow any isDeleted change.
  void updateEntry(Entry entry) {
    _writeEntries([entry]);
  }

  /// The single write path for entries: one transaction, tree-count deltas,
  /// one change notification. The caller's objects get their id, syncUUID
  /// and modifiedAt, and dates normalised to what a read returns.
  void _writeEntries(List<Entry> entries, {bool preserveModifiedAt = false}) {
    if (entries.isEmpty) return;
    final now = DateTime.now();
    final ids = _transaction(() {
      final yearDeltas = <int, int>{};
      final ids = <int>[];
      final previousQuery = _statement(
        'SELECT created_at, is_deleted FROM entries WHERE id = ?',
      );
      final insert = _statement(_insertEntrySql);
      final insertWithId = _statement(_insertEntryWithIdSql);
      final update = _statement(_updateEntrySql);
      for (final entry in entries) {
        _normaliseDates(entry);
        _assignSyncUUIDIfMissing(entry);
        if (!preserveModifiedAt || entry.modifiedAt == null) {
          entry.modifiedAt = _localMs(now);
        }
        final previous = entry.id != 0
            ? previousQuery.select([entry.id])
            : null;
        final values = _entryValues(entry);
        if (previous != null && previous.isNotEmpty) {
          final row = previous.first;
          if (row['is_deleted'] == 0) {
            final year = _date(row['created_at']).year;
            yearDeltas.update(year, (d) => d - 1, ifAbsent: () => -1);
          }
          update.execute([...values, entry.id]);
          ids.add(entry.id);
        } else if (entry.id != 0) {
          insertWithId.execute([entry.id, ...values]);
          ids.add(entry.id);
        } else {
          insert.execute(values);
          ids.add(_raw.lastInsertRowId);
        }
        if (!entry.isDeleted) {
          yearDeltas.update(
            entry.createdAt.year,
            (d) => d + 1,
            ifAbsent: () => 1,
          );
        }
      }
      _applyTreeDeltas(yearDeltas);
      return ids;
    });
    for (var i = 0; i < entries.length; i++) {
      entries[i]
        ..id = ids[i]
        ..invalidateSearchCache();
    }
    _notify(entries: true, trees: true);
  }

  void _applyTreeDeltas(Map<int, int> yearDeltas) {
    for (final MapEntry(key: year, value: delta) in yearDeltas.entries) {
      if (delta == 0) continue;
      final tree = getTreeForYear(year) ?? Tree(year: year);
      for (var i = 0; i < delta.abs(); i++) {
        delta > 0 ? tree.addEntry() : tree.removeEntry();
      }
      _putTree(tree);
    }
  }

  /// Get an entry by ID (any state, including trash and sealed capsules).
  Entry? getEntry(int id) {
    final found = _entries('WHERE id = ?', [id]);
    return found.isEmpty ? null : found.first;
  }

  /// Current-year entries, newest first, without the trash or capsules that
  /// are still sealed. Read-only list.
  List<Entry> getCurrentYearEntries() {
    final now = DateTime.now();
    return List.unmodifiable(
      _entries(
        'WHERE is_deleted = 0 AND created_at >= ? AND '
        '(capsule_unlock_date IS NULL OR capsule_unlock_date <= ?) '
        '$_newestFirst',
        [_ms(DateTime(now.year)), _ms(now)],
      ),
    );
  }

  /// Every entry outside the trash (all years, sealed capsules included),
  /// newest first. Read-only list.
  List<Entry> getAllEntries() =>
      List.unmodifiable(_entries('WHERE is_deleted = 0 $_newestFirst'));

  /// Get entries in pages to avoid loading full history in memory.
  List<Entry> getEntriesPage({
    required int limit,
    required int offset,
    int? year,
    bool includeDeleted = false,
    bool descending = true,
    bool includeLockedCapsules = false,
  }) {
    final (where, args) = _entriesFilter(
      year: year,
      includeDeleted: includeDeleted,
      excludeLockedCapsules: !includeLockedCapsules,
    );
    final order = descending
        ? 'ORDER BY created_at DESC, id DESC'
        : 'ORDER BY created_at ASC, id ASC';
    return _entries('$where $order LIMIT ? OFFSET ?', [...args, limit, offset]);
  }

  /// Count entries with optional year and deletion filters.
  int getEntriesCount({
    int? year,
    bool includeDeleted = false,
    bool includeLockedCapsules = false,
  }) {
    final (where, args) = _entriesFilter(
      year: year,
      includeDeleted: includeDeleted,
      excludeLockedCapsules: !includeLockedCapsules,
    );
    return _raw
            .select('SELECT count(*) AS n FROM entries $where', args)
            .first['n']
        as int;
  }

  (String, List<Object?>) _entriesFilter({
    int? year,
    bool includeDeleted = false,
    bool excludeLockedCapsules = false,
  }) {
    final conditions = <String>[];
    final args = <Object?>[];
    if (year != null) {
      conditions.add('created_at >= ? AND created_at < ?');
      args
        ..add(_ms(DateTime(year)))
        ..add(_ms(DateTime(year + 1)));
    }
    if (!includeDeleted) conditions.add('is_deleted = 0');
    if (excludeLockedCapsules) {
      conditions.add(
        '(capsule_unlock_date IS NULL OR capsule_unlock_date < ?)',
      );
      args.add(_ms(_trustedNowUtc()));
    }
    return (
      conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}',
      args,
    );
  }

  /// Soft delete an entry (recoverable for 30 days) and update tree count
  Future<bool> softDeleteEntry(int id) async {
    final entry = getEntry(id);
    if (entry == null || entry.isDeleted) return false;

    entry.isDeleted = true;
    entry.deletedAt = DateTime.now().toUtc();
    // _writeEntries bumps modifiedAt, so sync treats the deletion as a newer
    // change and propagates it; it also decrements the tree count.
    _writeEntries([entry]);
    return true;
  }

  /// Hard delete an entry permanently
  Future<bool> deleteEntry(int id) async {
    final entry = getEntry(id);
    if (entry == null) return false;
    await _deleteEntryMedia(entry);

    final removed = _transaction(() {
      _raw.execute('DELETE FROM entries WHERE id = ?', [id]);
      final removed = _raw.updatedRows > 0;
      if (removed && !entry.isDeleted) {
        _applyTreeDeltas({entry.createdAt.year: -1});
      }
      return removed;
    });
    _notify(entries: true, trees: true);
    return removed;
  }

  Future<void> _deleteEntryMedia(Entry entry) async {
    final fileStorage = _fileStorage;
    final mediaPath = entry.mediaPath;
    if (fileStorage == null || mediaPath == null || mediaPath.isEmpty) {
      return;
    }
    try {
      await fileStorage.deleteFile(mediaPath);
    } catch (e, st) {
      _errorReporter.report(
        e,
        stack: st,
        context: 'SeedlingDatabase._deleteEntryMedia',
      );
    }
  }

  /// Restore a soft-deleted entry
  Future<bool> restoreEntry(int id) async {
    final entry = getEntry(id);
    if (entry == null || !entry.isDeleted) return false;

    entry.isDeleted = false;
    entry.deletedAt = null;
    _writeEntries([entry]);
    return true;
  }

  /// Get all soft-deleted entries (for recovery screen), latest first.
  List<Entry> getDeletedEntries() =>
      _entries('WHERE is_deleted = 1 ORDER BY deleted_at DESC, id DESC');

  /// syncUUIDs of entries purged this session that sync has not yet been
  /// told about. Drained by [takePurgedEntries].
  final List<PurgedEntry> _purged = [];

  /// Returns (and forgets) the entries [purgeExpiredEntries] removed, so the
  /// sync engine can queue remote deletes (the remote tombstone would
  /// otherwise linger and could be pulled back onto devices).
  List<PurgedEntry> takePurgedEntries() {
    final taken = List<PurgedEntry>.of(_purged);
    _purged.clear();
    return taken;
  }

  /// Live entries whose media blob is known remotely but not on this device
  /// yet (pulled from another device, or an interrupted download).
  List<Entry> getEntriesNeedingMediaDownload() => _entries(
    'WHERE media_asset_id IS NOT NULL AND media_path IS NULL '
    'AND is_deleted = 0',
  );

  /// Every media blob id referenced by a stored entry (trash included).
  List<String> getAllMediaAssetIds() => [
    for (final row in _raw.select(
      'SELECT media_asset_id FROM entries WHERE media_asset_id IS NOT NULL',
    ))
      row['media_asset_id'] as String,
  ];

  /// Every stored entry's syncUUID, including soft-deleted ones.
  List<String> getAllSyncUUIDs() => [
    for (final row in _raw.select(
      'SELECT sync_uuid FROM entries WHERE sync_uuid IS NOT NULL',
    ))
      if (SyncId.isValid(row['sync_uuid'] as String))
        row['sync_uuid'] as String,
  ];

  /// Purge entries deleted more than 30 days ago
  Future<int> purgeExpiredEntries() async {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));
    final expired = _entries('WHERE is_deleted = 1 AND deleted_at < ?', [
      _ms(cutoff),
    ]);
    if (expired.isEmpty) return 0;

    for (final entry in expired) {
      await _deleteEntryMedia(entry);
    }

    final removed = _transaction(() {
      var removed = 0;
      final delete = _statement('DELETE FROM entries WHERE id = ?');
      for (final entry in expired) {
        delete.execute([entry.id]);
        removed += _raw.updatedRows;
      }
      return removed;
    });
    _purged.addAll([
      for (final e in expired)
        if (SyncId.isValid(e.syncUUID))
          (syncUUID: e.syncUUID!, mediaAssetId: e.mediaAssetId),
    ]);
    if (removed > 0) _notify(entries: true);
    return removed;
  }

  /// Watch the current year's visible entries (see [getCurrentYearEntries]).
  Stream<List<Entry>> watchEntries() =>
      _watch([_schema.entries], getCurrentYearEntries);

  /// Watch all entries (see [getAllEntries]).
  Stream<List<Entry>> watchAllEntries() =>
      _watch([_schema.entries], getAllEntries);

  // ============== Search ==============

  /// Ids of entries (any year, trash included) whose text, title, context,
  /// mood or transcription contain [query], ignoring case and accents, from
  /// the full-text index (substring match, like the in-memory filter). Null
  /// when the index can't answer: queries shorter than three characters (the
  /// trigram index needs three); callers then match in memory.
  Set<int>? searchEntryIds(String query) {
    final trimmed = query.trim();
    if (trimmed.runes.length < 3) return null;
    final phrase = '"${trimmed.replaceAll('"', '""')}"';
    return {
      for (final row in _raw.select(
        'SELECT rowid FROM entries_fts WHERE entries_fts MATCH ?',
        [phrase],
      ))
        row['rowid'] as int,
    };
  }

  // ============== Capsule Operations ==============

  /// Get all capsules (locked and unlocked), soonest unlock first.
  List<Entry> getAllCapsules() => _entries(
    'WHERE capsule_unlock_date IS NOT NULL AND is_deleted = 0 '
    'ORDER BY capsule_unlock_date, id',
  );

  /// Get capsules that unlock today
  List<Entry> getCapsulesToUnlockToday() {
    final today = _trustedNowUtc().toLocal();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _entries(
      'WHERE capsule_unlock_date >= ? AND capsule_unlock_date < ? '
      'AND is_deleted = 0 ORDER BY capsule_unlock_date, id',
      [_ms(startOfDay), _ms(endOfDay)],
    );
  }

  /// Get entries from previous years that match today's month and day.
  ///
  /// Narrows by date and lock state on the indexed columns first, then loads
  /// only the matches.
  List<Entry> getEntriesOnThisDay() {
    final today = DateTime.now();
    final nowMs = _ms(today);
    final ids = <int>[
      for (final row in _raw.select(
        'SELECT id, created_at FROM entries WHERE is_deleted = 0 '
        'AND created_at < ? AND (capsule_unlock_date IS NULL OR '
        'capsule_unlock_date <= ?) $_newestFirst',
        [_ms(DateTime(today.year)), nowMs],
      ))
        if (_date(row['created_at']) case final created
            when created.month == today.month && created.day == today.day)
          row['id'] as int,
    ];
    if (ids.isEmpty) return [];
    return _entries(
      'WHERE id IN (${List.filled(ids.length, '?').join(', ')}) '
      '$_newestFirst',
      ids,
      true,
    );
  }

  /// Watch capsules for changes
  Stream<List<Entry>> watchCapsules() =>
      _watch([_schema.entries], getAllCapsules);

  /// Rebuild tree counts and growth stages from entries.
  Future<void> recountTrees({int? year}) async {
    final countsByYear = <int, int>{};
    final years = <int>{DateTime.now().year, ?year};
    for (final row in _raw.select(
      'SELECT created_at, is_deleted FROM entries',
    )) {
      final entryYear = _date(row['created_at']).year;
      if (row['is_deleted'] == 0) {
        countsByYear.update(entryYear, (c) => c + 1, ifAbsent: () => 1);
      }
      if (year == null) years.add(entryYear);
    }

    _transaction(() {
      for (final targetYear in years) {
        final tree = _ensureTreeForYear(targetYear)
          ..entryCount = countsByYear[targetYear] ?? 0
          ..updateVisualState();
        _putTree(tree);
      }
    });
    _notify(entries: true, trees: true);
  }

  /// Permanently clears all entries and tree growth data.
  Future<void> clearAllData() async {
    _transaction(() {
      _raw.execute('DELETE FROM entries');
      _raw.execute('DELETE FROM trees');
      _ensureTreeForYear(DateTime.now().year);
    });
    _notify(entries: true, trees: true);
  }

  // ============== Sync Operations ==============

  void _assignSyncUUIDIfMissing(Entry entry) {
    final current = entry.syncUUID;
    if (current == null || current.isEmpty) {
      entry.syncUUID = SyncId.generate();
    }
  }

  /// Find an entry by its sync UUID (for cloud sync merge)
  Entry? getEntryBySyncUUID(String syncUUID) {
    final found = _entries('WHERE sync_uuid = ?', [syncUUID]);
    return found.isEmpty ? null : found.first;
  }

  // ============ Ritual Operations ============

  static Ritual _ritualFromRow(sql.Row r) => Ritual(
    id: r['id'] as int,
    uuid: r['uuid'] as String,
    name: r['name'] as String,
    signature: r['signature'] as String,
    statusIndex: r['status_index'] as int,
    cadenceDays: r['cadence_days'] as int,
    preferredHour: r['preferred_hour'] as int?,
    createdAt: _date(r['created_at']),
    lastObservedAt: _dateOrNull(r['last_observed_at']),
    nextDueAt: _dateOrNull(r['next_due_at']),
    occurrenceCount: r['occurrence_count'] as int,
  );

  Future<void> saveRitual(Ritual ritual) async {
    final values = [
      ritual.uuid,
      ritual.name,
      ritual.signature,
      ritual.statusIndex,
      ritual.cadenceDays,
      ritual.preferredHour,
      _ms(ritual.createdAt),
      _msOrNull(ritual.lastObservedAt),
      _msOrNull(ritual.nextDueAt),
      ritual.occurrenceCount,
    ];
    const columns =
        'uuid, name, signature, status_index, cadence_days, preferred_hour, '
        'created_at, last_observed_at, next_due_at, occurrence_count';
    _transaction(() {
      if (ritual.id != 0) {
        _raw.execute(
          'INSERT INTO rituals (id, $columns) VALUES '
          '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET '
          'uuid = excluded.uuid, name = excluded.name, '
          'signature = excluded.signature, '
          'status_index = excluded.status_index, '
          'cadence_days = excluded.cadence_days, '
          'preferred_hour = excluded.preferred_hour, '
          'created_at = excluded.created_at, '
          'last_observed_at = excluded.last_observed_at, '
          'next_due_at = excluded.next_due_at, '
          'occurrence_count = excluded.occurrence_count',
          [ritual.id, ...values],
        );
      } else {
        _raw.execute(
          'INSERT INTO rituals ($columns) VALUES '
          '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          values,
        );
        ritual.id = _raw.lastInsertRowId;
      }
    });
    _notify(rituals: true);
  }

  Ritual? getRitual(int id) {
    final rows = _raw.select('SELECT * FROM rituals WHERE id = ?', [id]);
    return rows.isEmpty ? null : _ritualFromRow(rows.first);
  }

  /// All rituals, by name.
  List<Ritual> getAllRituals() => [
    for (final row in _raw.select('SELECT * FROM rituals ORDER BY name, id'))
      _ritualFromRow(row),
  ];

  Future<void> deleteRitual(int id) async {
    _raw.execute('DELETE FROM rituals WHERE id = ?', [id]);
    _notify(rituals: true);
  }

  Stream<List<Ritual>> watchRituals() =>
      _watch([_schema.rituals], getAllRituals);

  // ============ Object Collection Operations ============

  /// Object entries (outside the trash, not sealed), newest first.
  List<Entry> getObjectEntries() => _entries(
    'WHERE type_index = ? AND is_deleted = 0 AND '
    '(capsule_unlock_date IS NULL OR capsule_unlock_date <= ?) '
    '$_newestFirst',
    [EntryType.object.index, _ms(_trustedNowUtc())],
  );

  // ============ Manual Link Operations ============

  /// Load entries by their syncUUIDs (for manual linking).
  ///
  /// Links can point at memories from any year, so this searches every year
  /// via the syncUUID index (soft-deleted entries and locked capsules are
  /// left out, as they are everywhere else in the UI).
  List<Entry> getEntriesBySyncUUIDs(List<String> uuids) {
    if (uuids.isEmpty) return [];
    final unique = uuids.toSet().toList();
    final nowMs = _ms(_trustedNowUtc());
    final found = <Entry>[];
    // SQLite caps bound parameters per statement; chunk to stay well below.
    for (var start = 0; start < unique.length; start += 500) {
      final chunk = unique.sublist(
        start,
        start + 500 > unique.length ? unique.length : start + 500,
      );
      found.addAll(
        _entries(
          'WHERE sync_uuid IN (${List.filled(chunk.length, '?').join(', ')}) '
          'AND is_deleted = 0 AND '
          '(capsule_unlock_date IS NULL OR capsule_unlock_date <= ?)',
          [...chunk, nowMs],
          true,
        ),
      );
    }
    found.sort((a, b) {
      final byDate = b.createdAt.compareTo(a.createdAt);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
    return found;
  }
}
