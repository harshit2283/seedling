import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import '../../../core/services/error_reporter.dart';
import '../../../core/services/media/file_storage_service.dart';
import '../../../core/services/security/at_rest_encryption_service.dart';
import '../../../core/services/security/clock_guard_service.dart';
import '../../../objectbox.g.dart';
import '../../models/entry.dart';
import '../../models/ritual.dart';
import '../../models/sync_id.dart';
import '../../models/tree.dart';

/// ObjectBox database singleton for local storage
/// Handles all CRUD operations for entries and trees
class ObjectBoxDatabase {
  late final Store _store;
  late final Box<Entry> _entryBox;
  late final Box<Tree> _treeBox;
  late final Box<Ritual> _ritualBox;
  late final AtRestEncryptionService _encryptionService;
  FileStorageService? _fileStorage;
  ClockGuardService? _clockGuard;
  ErrorReporter _errorReporter = const ErrorReporter();

  // Stream controllers for reactive updates
  final _treeController = StreamController<Tree?>.broadcast();
  final _entriesController = StreamController<List<Entry>>.broadcast();
  final _capsulesController = StreamController<List<Entry>>.broadcast();

  // Plaintext copies of stored entries, keyed by id. Every write in this
  // class keeps it current (we already hold the plaintext when writing), so
  // reads after a write never re-decrypt the store. Entries are decrypted at
  // most once per session, the first time they are read.
  final Map<int, Entry> _plainById = {};
  bool _plainComplete = false;

  // Sorted views derived from [_plainById]; rebuilt (sort only, no
  // decryption) after a write.
  List<Entry>? _allEntriesCache;
  List<Entry>? _visibleEntriesCache;

  static ObjectBoxDatabase? _instance;

  ObjectBoxDatabase._();

  /// Get the singleton instance
  static ObjectBoxDatabase get instance {
    if (_instance == null) {
      throw StateError(
        'ObjectBoxDatabase not initialized. Call ObjectBoxDatabase.create() first.',
      );
    }
    return _instance!;
  }

  /// Initialize the database (call once at app startup)
  static Future<ObjectBoxDatabase> create() async {
    if (_instance != null) {
      return _instance!;
    }

    final dir = await getApplicationDocumentsDirectory();
    final db = await _open(
      directory: '${dir.path}/objectbox',
      encryptionService: AtRestEncryptionService(),
    );
    _instance = db;
    return db;
  }

  /// Opens a standalone database in [directory] (not the app singleton).
  /// For tests that need a real store instead of a mock.
  @visibleForTesting
  static Future<ObjectBoxDatabase> openForTesting({
    required String directory,
    required AtRestEncryptionService encryptionService,
  }) => _open(directory: directory, encryptionService: encryptionService);

  static Future<ObjectBoxDatabase> _open({
    required String directory,
    required AtRestEncryptionService encryptionService,
  }) async {
    final db = ObjectBoxDatabase._();
    db._store = await openStore(directory: directory);
    db._entryBox = db._store.box<Entry>();
    db._treeBox = db._store.box<Tree>();
    db._ritualBox = db._store.box<Ritual>();
    db._encryptionService = encryptionService;
    await db._encryptionService.init();

    db._migrateLegacySyncUUIDs();

    // Ensure current year's tree exists
    await db._ensureCurrentYearTree();

    // Emit initial values
    db._emitCurrentTree();
    db._emitEntries();
    return db;
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

  /// Close the database
  void close() {
    _treeController.close();
    _entriesController.close();
    _capsulesController.close();
    _store.close();
    _instance = null;
  }

  void _emitCurrentTree() {
    _treeController.add(currentTree);
  }

  void _emitEntries() {
    _entriesController.add(getCurrentYearEntries());
  }

  /// Drop the sorted views. The plaintext map stays valid: writers update it.
  void _invalidateEntryCaches() {
    _allEntriesCache = null;
    _visibleEntriesCache = null;
  }

  /// Make sure every stored entry has a plaintext copy in [_plainById].
  void _ensureAllPlainLoaded() {
    if (_plainComplete) return;
    for (final raw in _entryBox.getAll()) {
      _plainById.putIfAbsent(raw.id, () => _decrypted(raw));
    }
    _plainComplete = true;
  }

  static int _newestFirst(Entry a, Entry b) {
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }

  List<Entry> _refreshAllEntriesCache() {
    _ensureAllPlainLoaded();
    final entries = _plainById.values.where((e) => !e.isDeleted).toList()
      ..sort(_newestFirst);
    _allEntriesCache = entries;
    return entries;
  }

  List<Entry> _refreshVisibleEntriesCache() {
    _ensureAllPlainLoaded();
    final startOfYear = DateTime(DateTime.now().year);
    final entries =
        _plainById.values
            .where(
              (e) =>
                  !e.isDeleted &&
                  !e.createdAt.isBefore(startOfYear) &&
                  !e.isLocked,
            )
            .toList()
          ..sort(_newestFirst);
    _visibleEntriesCache = entries;
    return entries;
  }

  /// Plaintext versions of raw query results, decrypting only entries this
  /// session has not seen yet. Order is preserved.
  List<Entry> _plain(List<Entry> raw) => [
    for (final entry in raw)
      _plainById.putIfAbsent(entry.id, () => _decrypted(entry)),
  ];

  /// Decrypts [raw] in place (it is a fresh object from the box) and returns it.
  Entry _decrypted(Entry raw) {
    _decryptEntryFields(raw);
    return raw;
  }

  // ============== Tree Operations ==============

  /// Get or create tree for current year
  Future<Tree> _ensureCurrentYearTree() async {
    return _ensureTreeForYear(DateTime.now().year);
  }

  /// Get or create tree for a specific year.
  Future<Tree> _ensureTreeForYear(int year) async {
    var tree = getTreeForYear(year);
    if (tree == null) {
      tree = Tree(year: year);
      _treeBox.put(tree);
    }
    return tree;
  }

  /// Get tree for a specific year
  Tree? getTreeForYear(int year) {
    final query = _treeBox.query(Tree_.year.equals(year)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  /// Get the current year's tree
  Tree? get currentTree => getTreeForYear(DateTime.now().year);

  /// Get all trees
  List<Tree> getAllTrees() {
    return _treeBox.getAll();
  }

  /// Update a tree
  void updateTree(Tree tree) {
    _treeBox.put(tree);
    _emitCurrentTree();
  }

  /// Watch current tree for changes
  Stream<Tree?> watchCurrentTree() {
    return Stream<Tree?>.multi((controller) {
      controller.add(currentTree);
      final subscription = _treeController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

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

  /// The single write path for entries. Encrypts copies (the caller's
  /// objects stay plaintext), applies tree-count deltas, refreshes the
  /// plaintext cache and notifies listeners once.
  void _writeEntries(List<Entry> entries, {bool preserveModifiedAt = false}) {
    if (entries.isEmpty) return;
    final now = DateTime.now();
    var touchesCapsules = false;
    _store.runInTransaction(TxMode.write, () {
      final yearDeltas = <int, int>{};
      final stored = <Entry>[];
      for (final entry in entries) {
        _assignSyncUUIDIfMissing(entry);
        if (!preserveModifiedAt || entry.modifiedAt == null) {
          entry.modifiedAt = now;
        }
        final previous = entry.id != 0 ? _entryBox.get(entry.id) : null;
        if (previous != null && !previous.isDeleted) {
          yearDeltas.update(
            previous.createdAt.year,
            (d) => d - 1,
            ifAbsent: () => -1,
          );
        }
        if (!entry.isDeleted) {
          yearDeltas.update(
            entry.createdAt.year,
            (d) => d + 1,
            ifAbsent: () => 1,
          );
        }
        if (entry.isCapsule || (previous?.isCapsule ?? false)) {
          touchesCapsules = true;
        }
        stored.add(_encryptedCopy(entry));
      }
      final ids = _entryBox.putMany(stored);
      for (var i = 0; i < entries.length; i++) {
        entries[i].id = ids[i];
      }
      _applyTreeDeltas(yearDeltas);
    });
    for (final entry in entries) {
      entry.invalidateSearchCache();
      _plainById[entry.id] = entry.copy();
    }

    _invalidateEntryCaches();
    _emitCurrentTree();
    _emitEntries();
    if (touchesCapsules) _emitCapsules();
  }

  void _applyTreeDeltas(Map<int, int> yearDeltas) {
    for (final MapEntry(key: year, value: delta) in yearDeltas.entries) {
      if (delta == 0) continue;
      final tree = getTreeForYear(year) ?? Tree(year: year);
      for (var i = 0; i < delta.abs(); i++) {
        delta > 0 ? tree.addEntry() : tree.removeEntry();
      }
      _treeBox.put(tree);
    }
  }

  Entry _encryptedCopy(Entry entry) {
    final copy = entry.copy();
    _encryptEntryFields(copy);
    return copy;
  }

  /// Plaintext copy of the stored entry [id], or null.
  Entry? _plainForId(int id) {
    final cached = _plainById[id];
    if (cached != null) return cached;
    final raw = _entryBox.get(id);
    if (raw == null) return null;
    return _plainById[id] = _decrypted(raw);
  }

  /// Get an entry by ID. Returns a private copy the caller may mutate.
  Entry? getEntry(int id) => _plainForId(id)?.copy();

  /// Get all entries for current year, newest first (excludes soft-deleted)
  List<Entry> getCurrentYearEntries() {
    return _visibleEntriesCache ?? _refreshVisibleEntriesCache();
  }

  /// Get recent entries (limit, excludes soft-deleted)
  List<Entry> getRecentEntries({int limit = 10}) {
    final query = _entryBox
        .query(Entry_.isDeleted.equals(false))
        .order(Entry_.createdAt, flags: Order.descending)
        .build();
    query.limit = limit;
    final results = query.find();
    query.close();
    return _plain(
      results,
    ).where((entry) => !entry.isLocked).take(limit).toList();
  }

  /// Get all entries (excludes soft-deleted)
  List<Entry> getAllEntries() {
    return _allEntriesCache ?? _refreshAllEntriesCache();
  }

  /// Get entries in pages to avoid loading full history in memory.
  List<Entry> getEntriesPage({
    required int limit,
    required int offset,
    int? year,
    bool includeDeleted = false,
    bool descending = true,
    bool includeLockedCapsules = false,
  }) {
    final query = _buildEntriesQuery(
      year: year,
      includeDeleted: includeDeleted,
      descending: descending,
      excludeLockedCapsules: !includeLockedCapsules,
    );
    query.offset = offset;
    query.limit = limit;
    final results = query.find();
    query.close();
    return _plain(results);
  }

  /// Count entries with optional year and deletion filters.
  int getEntriesCount({
    int? year,
    bool includeDeleted = false,
    bool includeLockedCapsules = false,
  }) {
    final query = _buildEntriesQuery(
      year: year,
      includeDeleted: includeDeleted,
      excludeLockedCapsules: !includeLockedCapsules,
    );
    final count = query.count();
    query.close();
    return count;
  }

  /// Soft delete an entry (recoverable for 30 days) and update tree count
  Future<bool> softDeleteEntry(int id) async {
    final entry = _plainForId(id)?.copy();
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
    final entry = _entryBox.get(id);
    if (entry != null && !entry.isDeleted) {
      _applyTreeDeltas({entry.createdAt.year: -1});
    }

    if (entry != null) {
      await _deleteEntryMedia(entry);
    }

    final removed = _entryBox.remove(id);
    _plainById.remove(id);

    // Notify listeners
    _invalidateEntryCaches();
    _emitCurrentTree();
    _emitEntries();
    _emitCapsules();

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
        context: 'ObjectBoxDatabase._deleteEntryMedia',
      );
    }
  }

  /// Restore a soft-deleted entry
  Future<bool> restoreEntry(int id) async {
    final entry = _plainForId(id)?.copy();
    if (entry == null || !entry.isDeleted) return false;

    entry.isDeleted = false;
    entry.deletedAt = null;
    _writeEntries([entry]);
    return true;
  }

  /// Get all soft-deleted entries (for recovery screen)
  List<Entry> getDeletedEntries() {
    final query = _entryBox
        .query(Entry_.isDeleted.equals(true))
        .order(Entry_.deletedAt, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return _plain(results);
  }

  /// Purge entries deleted more than 30 days ago
  Future<int> purgeExpiredEntries() async {
    final thirtyDaysAgo = DateTime.now().toUtc().subtract(
      const Duration(days: 30),
    );
    final query = _entryBox
        .query(
          Entry_.isDeleted
              .equals(true)
              .and(
                Entry_.deletedAt.lessThan(thirtyDaysAgo.millisecondsSinceEpoch),
              ),
        )
        .build();
    final expiredEntries = query.find();
    query.close();

    if (expiredEntries.isEmpty) return 0;

    for (final entry in expiredEntries) {
      await _deleteEntryMedia(entry);
    }

    final ids = expiredEntries.map((e) => e.id).toList();
    final removed = _entryBox.removeMany(ids);
    ids.forEach(_plainById.remove);

    if (removed > 0) {
      _invalidateEntryCaches();
      _emitEntries();
      _emitCapsules();
    }

    return removed;
  }

  /// Update an entry. The caller's object stays plaintext (callers such as
  /// the detail screen keep using it), and tree counts follow any isDeleted
  /// change.
  void updateEntry(Entry entry) {
    _writeEntries([entry]);
  }

  /// Watch entries for changes (current year, newest first)
  Stream<List<Entry>> watchEntries() {
    return Stream<List<Entry>>.multi((controller) {
      controller.add(getCurrentYearEntries());
      final subscription = _entriesController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  /// Watch all entries
  Stream<List<Entry>> watchAllEntries() {
    return Stream<List<Entry>>.multi((controller) {
      controller.add(_allEntriesCache ?? _refreshAllEntriesCache());
      final subscription = _entriesController.stream.listen(
        (_) => controller.add(_allEntriesCache ?? _refreshAllEntriesCache()),
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  /// Get entry count for current year
  int get currentYearEntryCount {
    final tree = currentTree;
    return tree?.entryCount ?? 0;
  }

  // ============== Capsule Operations (Phase 4.5) ==============

  /// Get all visible entries (excludes locked capsules and deleted)
  /// This is the main query for displaying memories
  List<Entry> getVisibleEntries() {
    return getCurrentYearEntries();
  }

  /// Get all capsules (locked and unlocked)
  List<Entry> getAllCapsules() {
    // Get entries that have a capsule unlock date set
    final query = _entryBox
        .query(
          Entry_.capsuleUnlockDate.notNull().and(
            Entry_.isDeleted.equals(false),
          ),
        )
        .order(Entry_.capsuleUnlockDate)
        .build();
    final results = query.find();
    query.close();
    return _plain(results);
  }

  /// Get only locked capsules
  List<Entry> getLockedCapsules() {
    return getAllCapsules().where((e) => e.isLocked).toList();
  }

  /// Get only unlocked capsules
  List<Entry> getUnlockedCapsules() {
    return getAllCapsules().where((e) => e.isUnlocked).toList();
  }

  /// Get capsules that unlock today
  List<Entry> getCapsulesToUnlockToday() {
    final today = _trustedNowUtc().toLocal();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final query = _entryBox
        .query(
          Entry_.capsuleUnlockDate
              .between(
                startOfDay.millisecondsSinceEpoch,
                endOfDay.millisecondsSinceEpoch - 1,
              )
              .and(Entry_.isDeleted.equals(false)),
        )
        .order(Entry_.capsuleUnlockDate)
        .build();
    final results = query.find();
    query.close();
    return _plain(results);
  }

  /// Get entries from previous years that match today's month and day.
  ///
  /// Excludes the current year at the query level, and filters by date and
  /// lock state (plaintext columns) before anything is decrypted, so only
  /// the handful of matches are ever decrypted.
  List<Entry> getEntriesOnThisDay() {
    final today = DateTime.now();
    final startOfYear = DateTime(today.year).millisecondsSinceEpoch;

    // Only fetch entries before the current year to minimise decryption work.
    final query = _entryBox
        .query(
          Entry_.isDeleted
              .equals(false)
              .and(Entry_.createdAt.lessThan(startOfYear)),
        )
        .order(Entry_.createdAt, flags: Order.descending)
        .build();
    final pastEntries = query.find();
    query.close();

    return _plain(
      pastEntries.where((entry) {
        if (entry.isLocked) return false;
        return entry.createdAt.month == today.month &&
            entry.createdAt.day == today.day;
      }).toList(),
    );
  }

  /// Save a capsule entry (same as saveEntry but with semantic naming)
  Future<Entry> saveCapsule(Entry entry) async {
    return saveEntry(entry);
  }

  /// Emit capsule updates
  void _emitCapsules() {
    _capsulesController.add(getAllCapsules());
  }

  /// Watch capsules for changes
  Stream<List<Entry>> watchCapsules() {
    return Stream<List<Entry>>.multi((controller) {
      controller.add(getAllCapsules());
      final subscription = _capsulesController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  /// Rebuild tree counts and growth stages from entries.
  Future<void> recountTrees({int? year}) async {
    final entries = _entryBox.getAll();
    final yearsToRecount = <int>{};
    final entryCountsByYear = <int, int>{};

    for (final entry in entries) {
      final entryYear = entry.createdAt.year;
      if (!entry.isDeleted) {
        entryCountsByYear.update(
          entryYear,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      if (year == null || year == entryYear) {
        yearsToRecount.add(entryYear);
      }
    }

    if (year != null) {
      yearsToRecount.add(year);
    }

    // Ensure at least current year exists, even if empty.
    yearsToRecount.add(DateTime.now().year);

    for (final targetYear in yearsToRecount) {
      final tree = await _ensureTreeForYear(targetYear);
      final count = entryCountsByYear[targetYear] ?? 0;
      tree.entryCount = count;
      tree.updateVisualState();
      _treeBox.put(tree);
    }

    _invalidateEntryCaches();
    _emitCurrentTree();
    _emitEntries();
    _emitCapsules();
  }

  /// Permanently clears all entries and tree growth data.
  Future<void> clearAllData() async {
    _entryBox.removeAll();
    _plainById.clear();
    _plainComplete = false;
    _treeBox.removeAll();
    await _ensureCurrentYearTree();
    _invalidateEntryCaches();
    _emitCurrentTree();
    _emitEntries();
    _emitCapsules();
  }

  // ============== Sync Operations (Phase 5) ==============

  void _assignSyncUUIDIfMissing(Entry entry) {
    final current = entry.syncUUID;
    if (current == null || current.isEmpty) {
      entry.syncUUID = SyncId.generate();
    }
  }

  /// One-time repair for stores written by older builds:
  /// - entries without a syncUUID get one, so links and sync can find them;
  /// - legacy non-UUID ids (base36 timestamps minted by the old link editor)
  ///   are replaced by v4 UUIDs, and every manualLinkIds list that referenced
  ///   them is rewritten, so the links survive. Previously sync replaced those
  ///   ids on push and the links silently broke.
  ///
  /// Cheap when there is nothing to do: only the syncUUID column is read.
  void _migrateLegacySyncUUIDs() {
    final probe = _entryBox.query().build();
    final ids = probe.property(Entry_.syncUUID).find();
    final total = probe.count();
    probe.close();
    final needsWork =
        ids.length < total || ids.any((id) => !SyncId.isValid(id));
    if (!needsWork) return;

    _store.runInTransaction(TxMode.write, () {
      final renamed = <String, String>{};
      final changed = <Entry>[];
      for (final entry in _entryBox.getAll()) {
        final current = entry.syncUUID;
        if (SyncId.isValid(current)) continue;
        final replacement = SyncId.generate();
        if (current != null && current.isNotEmpty) {
          renamed[current] = replacement;
        }
        entry.syncUUID = replacement;
        changed.add(entry);
      }
      if (changed.isNotEmpty) _entryBox.putMany(changed);
      if (renamed.isEmpty) return;

      final linkQuery = _entryBox.query(Entry_.manualLinkIds.notNull()).build();
      final linking = linkQuery.find();
      linkQuery.close();
      final relinked = <Entry>[];
      for (final entry in linking) {
        final raw = _encryptionService.decryptField(entry.manualLinkIds);
        if (raw == null || raw.isEmpty) continue;
        final parts = raw.split(',');
        if (!parts.any((part) => renamed.containsKey(part.trim()))) continue;
        final rewritten = [
          for (final part in parts) renamed[part.trim()] ?? part,
        ];
        entry.manualLinkIds = _encryptionService.encryptField(
          rewritten.join(','),
        );
        relinked.add(entry);
      }
      if (relinked.isNotEmpty) _entryBox.putMany(relinked);
    });
  }

  /// Find an entry by its sync UUID (for cloud sync merge)
  Entry? getEntryBySyncUUID(String syncUUID) {
    final query = _entryBox.query(Entry_.syncUUID.equals(syncUUID)).build();
    final result = query.findFirst();
    query.close();
    if (result == null) return null;
    return _plain([result]).single.copy();
  }

  /// Get all entries modified since a given timestamp (for sync push)
  List<Entry> getEntriesModifiedSince(DateTime since) {
    final query = _entryBox
        .query(Entry_.modifiedAt.greaterThan(since.millisecondsSinceEpoch))
        .order(Entry_.modifiedAt)
        .build();
    final results = query.find();
    query.close();
    return _plain(results);
  }

  Query<Entry> _buildEntriesQuery({
    int? year,
    bool includeDeleted = false,
    bool descending = true,
    bool excludeLockedCapsules = false,
  }) {
    Condition<Entry>? condition;

    if (year != null) {
      final startOfYear = DateTime(year);
      final endOfYear = DateTime(year + 1);
      condition = Entry_.createdAt.between(
        startOfYear.millisecondsSinceEpoch,
        endOfYear.millisecondsSinceEpoch - 1,
      );
    }

    if (!includeDeleted) {
      final notDeleted = Entry_.isDeleted.equals(false);
      condition = condition != null ? condition.and(notDeleted) : notDeleted;
    }

    if (excludeLockedCapsules) {
      // Exclude entries with capsuleUnlockDate in the future (locked capsules).
      // capsuleUnlockDate is stored unencrypted, so this is query-level filtering.
      final now = _trustedNowUtc().millisecondsSinceEpoch;
      final notLocked = Entry_.capsuleUnlockDate.isNull().or(
        Entry_.capsuleUnlockDate.lessThan(now),
      );
      condition = condition != null ? condition.and(notLocked) : notLocked;
    }

    final queryBuilder = condition != null
        ? _entryBox.query(condition)
        : _entryBox.query();

    return queryBuilder
        .order(Entry_.createdAt, flags: descending ? Order.descending : 0)
        .build();
  }

  void _encryptEntryFields(Entry entry) {
    entry.text = _encryptionService.encryptField(entry.text);
    entry.title = _encryptionService.encryptField(entry.title);
    entry.context = _encryptionService.encryptField(entry.context);
    entry.mood = _encryptionService.encryptField(entry.mood);
    entry.tags = _encryptionService.encryptField(entry.tags);
    entry.detectedTheme = _encryptionService.encryptField(entry.detectedTheme);
    entry.connectionIds = _encryptionService.encryptField(entry.connectionIds);
    entry.manualLinkIds = _encryptionService.encryptField(entry.manualLinkIds);
    entry.transcription = _encryptionService.encryptField(entry.transcription);
  }

  void _decryptEntryFields(Entry entry) {
    entry.decryptionFailed = false;
    entry.invalidateSearchCache();

    String? decryptOrPreserve(String? value) {
      final decrypted = _encryptionService.decryptField(value);
      if (decrypted == null && _encryptionService.isEncryptedValue(value)) {
        entry.decryptionFailed = true;
        return value;
      }
      return decrypted;
    }

    entry.text = decryptOrPreserve(entry.text);
    entry.title = decryptOrPreserve(entry.title);
    entry.context = decryptOrPreserve(entry.context);
    entry.mood = decryptOrPreserve(entry.mood);
    entry.tags = decryptOrPreserve(entry.tags);
    entry.detectedTheme = decryptOrPreserve(entry.detectedTheme);
    entry.connectionIds = decryptOrPreserve(entry.connectionIds);
    entry.manualLinkIds = decryptOrPreserve(entry.manualLinkIds);
    entry.transcription = decryptOrPreserve(entry.transcription);
  }

  // ============ Ritual Operations ============

  Future<void> saveRitual(Ritual ritual) async {
    _ritualBox.put(ritual);
  }

  Ritual? getRitual(int id) => _ritualBox.get(id);

  List<Ritual> getAllRituals() {
    return _ritualBox.getAll()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> deleteRitual(int id) async {
    _ritualBox.remove(id);
  }

  Stream<List<Ritual>> watchRituals() {
    return _ritualBox
        .query()
        .watch(triggerImmediately: true)
        .map((q) => q.find());
  }

  // ============ Object Collection Operations ============

  /// Get all object-type entries (non-deleted, unlocked), sorted by createdAt descending
  List<Entry> getObjectEntries() {
    final now = _trustedNowUtc().millisecondsSinceEpoch;
    final notLocked = Entry_.capsuleUnlockDate.isNull().or(
      Entry_.capsuleUnlockDate.lessOrEqual(now),
    );
    final query = _entryBox
        .query(
          Entry_.typeIndex
              .equals(EntryType.object.index)
              .and(Entry_.isDeleted.equals(false))
              .and(notLocked),
        )
        .order(Entry_.createdAt, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return _plain(results);
  }

  // ============ Manual Link Operations ============

  /// Load entries by their syncUUIDs (for manual linking).
  ///
  /// Links can point at memories from any year, so this searches every year
  /// via the syncUUID index (soft-deleted entries and locked capsules are
  /// left out, as they are everywhere else in the UI).
  List<Entry> getEntriesBySyncUUIDs(List<String> uuids) {
    if (uuids.isEmpty) return [];
    final now = _trustedNowUtc().millisecondsSinceEpoch;
    final notLocked = Entry_.capsuleUnlockDate.isNull().or(
      Entry_.capsuleUnlockDate.lessOrEqual(now),
    );
    final query = _entryBox
        .query(
          Entry_.syncUUID
              .oneOf(uuids.toSet().toList())
              .and(Entry_.isDeleted.equals(false))
              .and(notLocked),
        )
        .order(Entry_.createdAt, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return _plain(results);
  }
}
