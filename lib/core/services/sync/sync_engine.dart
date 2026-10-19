import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import '../../../data/datasources/local/objectbox_database.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/sync_id.dart';
import 'sync_backend.dart';
import 'sync_crypto_service.dart';
import 'sync_metadata.dart';
import 'sync_models.dart';

/// Core sync engine: coordinates push/pull between ObjectBox and cloud backend.
///
/// Strategy:
/// - Push: debounced 2s after each local mutation
/// - Pull: on app launch + resume, fetch changes since last change token
/// - Conflicts: last-write-wins for text fields; delete wins
/// - Push and pull never overlap (they run one at a time, in call order).
class SyncEngine {
  /// Bump when the remote layout changes so that every local entry must be
  /// uploaded again. v2: CloudKit keeps the encryption envelope (salt and
  /// version) and Drive uses per-device change logs.
  static const currentFormatVersion = 2;

  final ObjectBoxDatabase _db;
  final SyncBackend _backend;
  final SyncMetadata _metadata;
  final SyncCryptoService _crypto;
  final String _mediaBasePath;
  static final _uuidV4Pattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static const _mediaFolders = {'photos', 'voices', 'objects'};
  // A single path segment: no leading dot, no control characters or ':'.
  static final _safeFileName = RegExp(r'^[^.\x00-\x1f:][^\x00-\x1f:]{0,254}$');

  final _stateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get stateStream => _stateController.stream;

  SyncState _currentState = SyncState.disabled;
  SyncState get currentState => _currentState;

  Timer? _pushDebounce;

  /// Tail of the push/pull queue; see [_serialized].
  Future<void> _lockTail = Future<void>.value();

  SyncEngine({
    required ObjectBoxDatabase database,
    required SyncBackend backend,
    required SyncMetadata metadata,
    required SyncCryptoService cryptoService,
    String mediaBasePath = '',
  }) : _db = database,
       _backend = backend,
       _metadata = metadata,
       _crypto = cryptoService,
       _mediaBasePath = mediaBasePath;

  /// Initialize sync engine. Call once at app startup.
  Future<void> init() async {
    if (!_metadata.isEnabled) {
      _setState(SyncState.disabled);
      return;
    }

    final available = await _backend.isAvailable();
    if (!available) {
      _setState(SyncState.error);
      return;
    }

    _setState(SyncState.idle);
    await _queueMaintenanceChanges();
    // Initial pull on startup, then flush anything queued (including changes
    // left over from a previous session).
    await pull();
    if (_metadata.pendingChanges.isNotEmpty) {
      await push();
    }
  }

  /// Enable or disable sync
  Future<void> setEnabled(bool enabled) async {
    final wasEnabled = _metadata.isEnabled;
    await _metadata.setEnabled(enabled);
    if (enabled) {
      if (!wasEnabled) {
        // Upload everything that exists locally, not just future edits.
        await _metadata.setFormatVersion(0);
      }
      await init();
    } else {
      _pushDebounce?.cancel();
      _setState(SyncState.disabled);
    }
  }

  /// Assign a syncUUID to an entry if it doesn't have one.
  /// Call this before saving entries.
  void ensureSyncUUID(Entry entry) {
    if (!_isValidUuid(entry.syncUUID)) {
      entry.syncUUID = SyncId.generate();
    }
    if (!_isValidUuidV4(entry.deviceId)) {
      entry.deviceId = _metadata.deviceId;
    }
  }

  /// Queue a local change for push (debounced 2s).
  void queuePush(Entry entry, SyncChangeType changeType) {
    if (!_metadata.isEnabled) return;

    ensureSyncUUID(entry);
    if (!_isValidUuid(entry.syncUUID)) {
      unawaited(
        _metadata.setLastError('Unable to queue sync change: invalid syncUUID'),
      );
      return;
    }
    _metadata.addPendingChange(
      SyncChange(
        syncUUID: entry.syncUUID!,
        changeType: changeType,
        timestamp: DateTime.now(),
      ),
    );

    // Debounce push
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(seconds: 2), () => push());
  }

  /// Queue work that is not triggered by a user edit:
  /// - remote deletes for entries purged from the local trash;
  /// - a full upload when this device hasn't uploaded for the current remote
  ///   layout yet (first enable, or after a format change).
  Future<void> _queueMaintenanceChanges() async {
    final now = DateTime.now();
    final purged = _db.takePurgedSyncUUIDs();
    await _metadata.addPendingChanges([
      for (final uuid in purged)
        SyncChange(
          syncUUID: uuid,
          changeType: SyncChangeType.delete,
          timestamp: now,
        ),
    ]);

    if (_metadata.formatVersion < currentFormatVersion) {
      final queued = _metadata.pendingChanges.map((c) => c.syncUUID).toSet();
      await _metadata.addPendingChanges([
        for (final uuid in _db.getAllSyncUUIDs())
          if (!queued.contains(uuid))
            SyncChange(
              syncUUID: uuid,
              changeType: SyncChangeType.update,
              timestamp: now,
            ),
      ]);
      await _metadata.setFormatVersion(currentFormatVersion);
    }
  }

  /// Runs [body] after every previously requested push/pull has finished, so
  /// a pull never merges while a push is reading entries (and vice versa).
  Future<T> _serialized<T>(Future<T> Function() body) {
    final result = _lockTail.then((_) => body());
    _lockTail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Push pending local changes.
  Future<SyncResult> push() => _serialized(_push);

  Future<SyncResult> _push() async {
    if (!_metadata.isEnabled) return SyncResult.error('Sync disabled');

    // Snapshot: only these exact changes are removed afterwards. Anything
    // queued while we are on the network stays queued for the next push.
    final pending = _metadata.pendingChanges;
    if (pending.isEmpty) return SyncResult.success();

    _setState(SyncState.pushing);

    final handled = <SyncChange>[];
    try {
      final saves = <SyncChange>[];
      final records = <Map<String, dynamic>>[];
      final deletes = <SyncChange>[];
      SyncEncryptionSession? encryptionSession;

      for (final change in pending) {
        if (!_isValidUuid(change.syncUUID)) {
          handled.add(change);
          continue;
        }

        if (change.changeType == SyncChangeType.delete) {
          deletes.add(change);
          continue;
        }

        final entry = _db.getEntryBySyncUUID(change.syncUUID);
        if (entry == null) {
          // Gone locally; a hard delete queues its own delete change.
          handled.add(change);
          continue;
        }

        encryptionSession ??= await _crypto.createEncryptionSession();
        records.add(
          await _entryToRecord(entry, encryptionSession: encryptionSession),
        );
        saves.add(change);
      }

      if (records.isNotEmpty) {
        await _backend.saveRecords(records);
        handled.addAll(saves);
      }
      if (deletes.isNotEmpty) {
        await _backend.deleteRecords([for (final d in deletes) d.syncUUID]);
        handled.addAll(deletes);
      }

      await _metadata.removePendingChanges(handled);
      await _metadata.setLastError(null);
      _setState(SyncState.idle);

      return SyncResult.success(pushed: records.length + deletes.length);
    } catch (e) {
      // Keep whatever did reach the backend from being pushed again.
      await _metadata.removePendingChanges(handled);
      return _fail('push', e);
    }
  }

  /// Pull remote changes since the last change token.
  Future<SyncResult> pull() => _serialized(_pull);

  Future<SyncResult> _pull() async {
    if (!_metadata.isEnabled) return SyncResult.error('Sync disabled');

    _setState(SyncState.pulling);

    try {
      final fetchResult = await _backend.fetchChanges(
        changeToken: _metadata.changeToken,
      );

      if (fetchResult == null) {
        _setState(SyncState.idle);
        return SyncResult.success();
      }

      _setState(SyncState.merging);

      var pulled = 0;
      var conflicts = 0;
      var ignored = 0;

      // A fetch can carry several versions of one record (e.g. from several
      // devices); only the newest matters.
      final newest = <String, Map<String, dynamic>>{};
      for (final record in fetchResult.records) {
        final syncUUID = record['syncUUID'] as String?;
        if (!_isValidUuid(syncUUID)) continue;
        final existing = newest[syncUUID!];
        if (existing == null ||
            _modifiedAt(record).isAfter(_modifiedAt(existing))) {
          newest[syncUUID] = record;
        }
      }

      final toSave = <Entry>[];
      for (final record in newest.values) {
        final Map<String, dynamic> decrypted;
        try {
          decrypted = await _crypto.decryptRecordFields(record);
        } on SyncUnversionedRecordException {
          ignored++;
          continue;
        }

        final local = _db.getEntryBySyncUUID(record['syncUUID'] as String);
        if (local == null) {
          toSave.add(_decryptedToEntry(decrypted));
          pulled++;
          continue;
        }

        // Conflict resolution: last-write-wins; local wins ties.
        final localModifiedAt = local.modifiedAt ?? local.createdAt;
        if (_modifiedAt(decrypted).isAfter(localModifiedAt)) {
          _applyDecryptedToEntry(local, decrypted);
          toSave.add(local);
          conflicts++;
        }
      }

      // One transaction, one UI refresh; tree counts follow isDeleted, and
      // modifiedAt stays the remote value (it is not a new local edit).
      if (toSave.isNotEmpty) {
        await _db.saveEntries(toSave, preserveModifiedAt: true);
      }

      // Handle deletions (after records: delete wins)
      for (final deletedUUID in fetchResult.deletedUUIDs) {
        if (!_isValidUuid(deletedUUID)) continue;
        final local = _db.getEntryBySyncUUID(deletedUUID);
        if (local != null && !local.isDeleted) {
          await _db.softDeleteEntry(local.id);
          pulled++;
        }
      }

      if (ignored > 0) {
        developer.log(
          'Ignored $ignored unversioned sync record(s)',
          name: 'SyncEngine',
        );
      }

      // Save new change token
      if (fetchResult.newChangeToken != null) {
        await _metadata.setChangeToken(fetchResult.newChangeToken);
      }
      await _metadata.setLastSyncTime(DateTime.now());
      await _metadata.setLastError(null);

      _setState(SyncState.idle);
      return SyncResult.success(pulled: pulled, conflicts: conflicts);
    } catch (e) {
      return _fail('pull', e);
    }
  }

  Future<SyncResult> _fail(String operation, Object e) async {
    final message = switch (e) {
      SocketException() => 'Network error during $operation: $e',
      SyncDocumentCorruptedException() => e.toString(),
      SyncCryptoException(:final message) => message,
      _ => '${operation == 'push' ? 'Push' : 'Pull'} failed: $e',
    };
    await _metadata.setLastError(message);
    _setState(SyncState.error);
    return SyncResult.error(e is SyncCryptoException ? e.message : '$e');
  }

  static DateTime _modifiedAt(Map<String, dynamic> record) {
    final raw = record['modifiedAt'];
    return raw is num
        ? DateTime.fromMillisecondsSinceEpoch(raw.toInt())
        : DateTime.now();
  }

  static DateTime? _date(Object? raw) =>
      raw is num ? DateTime.fromMillisecondsSinceEpoch(raw.toInt()) : null;

  Future<Map<String, dynamic>> _entryToRecord(
    Entry entry, {
    required SyncEncryptionSession encryptionSession,
  }) async {
    ensureSyncUUID(entry);
    final record = <String, dynamic>{
      'syncUUID': entry.syncUUID,
      'typeIndex': entry.typeIndex,
      'createdAt': entry.createdAt.millisecondsSinceEpoch,
      'modifiedAt':
          entry.modifiedAt?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      'text': entry.text,
      'title': entry.title,
      'context': entry.context,
      'mood': entry.mood,
      'tags': entry.tags,
      'isDeleted': entry.isDeleted,
      'deletedAt': entry.deletedAt?.millisecondsSinceEpoch,
      'detectedTheme': entry.detectedTheme,
      'sentimentScore': entry.sentimentScore,
      'capsuleUnlockDate': entry.capsuleUnlockDate?.millisecondsSinceEpoch,
      'transcription': entry.transcription,
      'manualLinkIds': entry.manualLinkIds,
      'mediaPath': _relativeMediaPath(entry.mediaPath, entry.typeIndex),
      'deviceId': entry.deviceId ?? _metadata.deviceId,
    };
    return _crypto.encryptRecordFields(record, session: encryptionSession);
  }

  Entry _decryptedToEntry(Map<String, dynamic> decrypted) {
    final syncUUID = decrypted['syncUUID'] as String?;
    final deviceId = decrypted['deviceId'] as String?;
    final typeIndex = decrypted['typeIndex'] as int? ?? 0;
    return Entry(
      typeIndex: typeIndex,
      createdAt: _date(decrypted['createdAt']) ?? DateTime.now(),
      text: decrypted['text'] as String?,
      title: decrypted['title'] as String?,
      context: decrypted['context'] as String?,
      mood: decrypted['mood'] as String?,
      tags: decrypted['tags'] as String?,
      isDeleted: decrypted['isDeleted'] as bool? ?? false,
      deletedAt: _date(decrypted['deletedAt']),
      detectedTheme: decrypted['detectedTheme'] as String?,
      sentimentScore: (decrypted['sentimentScore'] as num?)?.toDouble(),
      capsuleUnlockDate: _date(decrypted['capsuleUnlockDate']),
      transcription: decrypted['transcription'] as String?,
      manualLinkIds: decrypted['manualLinkIds'] as String?,
      mediaPath: _localMediaPath(decrypted['mediaPath'] as String?, typeIndex),
      syncUUID: _isValidUuid(syncUUID) ? syncUUID : SyncId.generate(),
      modifiedAt: _date(decrypted['modifiedAt']),
      deviceId: _isValidUuidV4(deviceId) ? deviceId : _metadata.deviceId,
    );
  }

  void _applyDecryptedToEntry(Entry entry, Map<String, dynamic> decrypted) {
    entry.text = decrypted['text'] as String?;
    entry.title = decrypted['title'] as String?;
    entry.context = decrypted['context'] as String?;
    entry.mood = decrypted['mood'] as String?;
    entry.tags = decrypted['tags'] as String?;
    entry.detectedTheme = decrypted['detectedTheme'] as String?;
    entry.sentimentScore = (decrypted['sentimentScore'] as num?)?.toDouble();
    entry.transcription = decrypted['transcription'] as String?;
    // Records from older builds don't carry links; don't wipe local ones.
    if (decrypted.containsKey('manualLinkIds')) {
      entry.manualLinkIds = decrypted['manualLinkIds'] as String?;
    }
    entry.mediaPath = _localMediaPath(
      decrypted['mediaPath'] as String?,
      entry.typeIndex,
    );
    entry.isDeleted = decrypted['isDeleted'] as bool? ?? false;
    entry.deletedAt = _date(decrypted['deletedAt']);
    entry.modifiedAt = _date(decrypted['modifiedAt']) ?? DateTime.now();
    final deviceId = decrypted['deviceId'] as String?;
    entry.deviceId = _isValidUuidV4(deviceId) ? deviceId : _metadata.deviceId;
  }

  bool _isValidUuid(String? value) => SyncId.isValid(value);

  bool _isValidUuidV4(String? value) {
    if (value == null || value.isEmpty) return false;
    return _uuidV4Pattern.hasMatch(value);
  }

  /// The portable form of a media path: `<folder>/<file>` inside the media
  /// directory. Never an absolute path (that would leak this device's
  /// layout, and is meaningless elsewhere).
  String? _relativeMediaPath(String? path, int typeIndex) {
    if (path == null || path.isEmpty) return null;
    final segments = path
        .replaceAll('\\', '/')
        .split('/')
        .where((s) => s.isNotEmpty && s != '.' && s != '..')
        .toList();
    if (segments.isEmpty) return null;
    final fileName = segments.last;
    if (!_safeFileName.hasMatch(fileName)) return null;
    final parent = segments.length >= 2 ? segments[segments.length - 2] : null;
    final folder = _mediaFolders.contains(parent)
        ? parent!
        : _folderForType(typeIndex);
    return '$folder/$fileName';
  }

  /// Where a remote media path may live on this device: always a plain file
  /// name inside one of our media folders. Remote values are untrusted, so
  /// absolute paths and `..` segments are reduced to that form.
  String? _localMediaPath(String? remote, int typeIndex) {
    final relative = _relativeMediaPath(remote, typeIndex);
    if (relative == null) return null;
    if (_mediaBasePath.isEmpty) return relative;
    return '${_normalizePath(_mediaBasePath)}/$relative';
  }

  static String _folderForType(int typeIndex) {
    if (typeIndex == EntryType.voice.index) return 'voices';
    if (typeIndex == EntryType.object.index) return 'objects';
    return 'photos';
  }

  String _normalizePath(String path) {
    var normalized = path.replaceAll('\\', '/');
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  void _setState(SyncState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void dispose() {
    _pushDebounce?.cancel();
    _stateController.close();
  }
}
