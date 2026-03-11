import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../data/datasources/local/objectbox_database.dart';
import '../../../data/models/entry.dart';
import 'sync_backend.dart';
import 'sync_crypto_service.dart';
import 'sync_metadata.dart';
import 'sync_models.dart';

/// Core sync engine: coordinates push/pull between ObjectBox and cloud backend.
///
/// Strategy:
/// - Push: debounced 2s after each local mutation
/// - Pull: on app launch + resume, fetch changes since last CKServerChangeToken
/// - Conflicts: last-write-wins for text fields; delete wins
class SyncEngine {
  final ObjectBoxDatabase _db;
  final SyncBackend _backend;
  final SyncMetadata _metadata;
  final SyncCryptoService _crypto;
  final String _mediaBasePath;
  static const _uuid = Uuid();
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static final _uuidV4Pattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final _stateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get stateStream => _stateController.stream;

  SyncState _currentState = SyncState.disabled;
  SyncState get currentState => _currentState;

  Timer? _pushDebounce;

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
    // Initial pull on startup
    await pull();
  }

  /// Enable or disable sync
  Future<void> setEnabled(bool enabled) async {
    await _metadata.setEnabled(enabled);
    if (enabled) {
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
      entry.syncUUID = _uuid.v4();
    }
    if (!_isValidUuidV4(entry.deviceId)) {
      entry.deviceId = _metadata.deviceId;
    }
  }

  /// Queue a local change for push to iCloud (debounced 2s).
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

  /// Push pending local changes to iCloud.
  Future<SyncResult> push() async {
    if (!_metadata.isEnabled) return SyncResult.error('Sync disabled');

    final pending = _metadata.pendingChanges;
    if (pending.isEmpty) return SyncResult.success();

    _setState(SyncState.pushing);

    try {
      final pushedUUIDs = <String>[];
      final invalidUUIDs = <String>[];
      SyncEncryptionSession? encryptionSession;

      for (final change in pending) {
        if (!_isValidUuid(change.syncUUID)) {
          invalidUUIDs.add(change.syncUUID);
          continue;
        }

        if (change.changeType == SyncChangeType.delete) {
          await _backend.deleteRecord(change.syncUUID);
          pushedUUIDs.add(change.syncUUID);
          continue;
        }

        final entry = _db.getEntryBySyncUUID(change.syncUUID);
        if (entry == null) continue;
        ensureSyncUUID(entry);
        if (!_isValidUuid(entry.syncUUID)) {
          invalidUUIDs.add(change.syncUUID);
          continue;
        }

        encryptionSession ??= await _crypto.createEncryptionSession();
        final record = await _entryToRecord(
          entry,
          encryptionSession: encryptionSession,
        );
        await _backend.saveRecord(record);
        pushedUUIDs.add(change.syncUUID);
      }

      await _metadata.removePendingChanges([...pushedUUIDs, ...invalidUUIDs]);
      await _metadata.setLastError(null);
      _setState(SyncState.idle);

      return SyncResult.success(pushed: pushedUUIDs.length);
    } on SocketException catch (e) {
      await _metadata.setLastError('Network error during push: $e');
      _setState(SyncState.error);
      return SyncResult.error(e.toString());
    } on SyncDocumentCorruptedException catch (e) {
      await _metadata.setLastError(e.toString());
      _setState(SyncState.error);
      return SyncResult.error(e.toString());
    } on SyncCryptoException catch (e) {
      await _metadata.setLastError(e.message);
      _setState(SyncState.error);
      return SyncResult.error(e.message);
    } catch (e) {
      await _metadata.setLastError('Push failed: $e');
      _setState(SyncState.error);
      return SyncResult.error(e.toString());
    }
  }

  /// Pull remote changes from iCloud since last change token.
  Future<SyncResult> pull() async {
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

      for (final record in fetchResult.records) {
        final mergeResult = await _mergeRecord(record);
        if (mergeResult == _MergeResult.pulled) pulled++;
        if (mergeResult == _MergeResult.conflict) conflicts++;
      }

      // Handle deletions
      for (final deletedUUID in fetchResult.deletedUUIDs) {
        if (!_isValidUuid(deletedUUID)) {
          continue;
        }
        final local = _db.getEntryBySyncUUID(deletedUUID);
        if (local != null) {
          await _db.softDeleteEntry(local.id);
          pulled++;
        }
      }

      // Save new change token
      if (fetchResult.newChangeToken != null) {
        await _metadata.setChangeToken(fetchResult.newChangeToken);
      }
      await _metadata.setLastSyncTime(DateTime.now());
      await _metadata.setLastError(null);

      _setState(SyncState.idle);
      return SyncResult.success(pulled: pulled, conflicts: conflicts);
    } on SocketException catch (e) {
      await _metadata.setLastError('Network error during pull: $e');
      _setState(SyncState.error);
      return SyncResult.error(e.toString());
    } on SyncDocumentCorruptedException catch (e) {
      await _metadata.setLastError(e.toString());
      _setState(SyncState.error);
      return SyncResult.error(e.toString());
    } on SyncCryptoException catch (e) {
      await _metadata.setLastError(e.message);
      _setState(SyncState.error);
      return SyncResult.error(e.message);
    } catch (e) {
      await _metadata.setLastError('Pull failed: $e');
      _setState(SyncState.error);
      return SyncResult.error(e.toString());
    }
  }

  /// Merge a remote record into the local database.
  Future<_MergeResult> _mergeRecord(Map<String, dynamic> record) async {
    final syncUUID = record['syncUUID'] as String?;
    if (!_isValidUuid(syncUUID)) return _MergeResult.skipped;

    final localEntry = _db.getEntryBySyncUUID(syncUUID!);
    final remoteModifiedAt = record['modifiedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(record['modifiedAt'] as int)
        : DateTime.now();

    if (localEntry == null) {
      // New entry from remote — create locally
      final entry = await _recordToEntry(record);
      await _db.saveEntry(entry);
      return _MergeResult.pulled;
    }

    // Conflict resolution: last-write-wins
    final localModifiedAt = localEntry.modifiedAt ?? localEntry.createdAt;
    if (remoteModifiedAt.isAfter(localModifiedAt)) {
      // Remote is newer — update local
      await _applyRecordToEntry(localEntry, record);
      _db.updateEntry(localEntry);
      return _MergeResult.conflict;
    }

    // Local is newer or same — skip (local wins)
    return _MergeResult.skipped;
  }

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
      'mediaPath': _toRelativeMediaPath(entry.mediaPath),
      'deviceId': entry.deviceId ?? _metadata.deviceId,
    };
    return _crypto.encryptRecordFields(record, session: encryptionSession);
  }

  Future<Entry> _recordToEntry(Map<String, dynamic> record) async {
    final decrypted = await _crypto.decryptRecordFields(record);
    final syncUUID = decrypted['syncUUID'] as String?;
    final deviceId = decrypted['deviceId'] as String?;
    return Entry(
      typeIndex: decrypted['typeIndex'] as int? ?? 0,
      createdAt: decrypted['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(decrypted['createdAt'] as int)
          : DateTime.now(),
      text: decrypted['text'] as String?,
      title: decrypted['title'] as String?,
      context: decrypted['context'] as String?,
      mood: decrypted['mood'] as String?,
      tags: decrypted['tags'] as String?,
      isDeleted: decrypted['isDeleted'] as bool? ?? false,
      deletedAt: decrypted['deletedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(decrypted['deletedAt'] as int)
          : null,
      detectedTheme: decrypted['detectedTheme'] as String?,
      sentimentScore: (decrypted['sentimentScore'] as num?)?.toDouble(),
      capsuleUnlockDate: decrypted['capsuleUnlockDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              decrypted['capsuleUnlockDate'] as int,
            )
          : null,
      transcription: decrypted['transcription'] as String?,
      mediaPath: _toAbsoluteMediaPath(decrypted['mediaPath'] as String?),
      syncUUID: _isValidUuid(syncUUID) ? syncUUID : _uuid.v4(),
      modifiedAt: decrypted['modifiedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(decrypted['modifiedAt'] as int)
          : null,
      deviceId: _isValidUuidV4(deviceId) ? deviceId : _metadata.deviceId,
    );
  }

  Future<void> _applyRecordToEntry(
    Entry entry,
    Map<String, dynamic> record,
  ) async {
    final decrypted = await _crypto.decryptRecordFields(record);
    entry.text = decrypted['text'] as String?;
    entry.title = decrypted['title'] as String?;
    entry.context = decrypted['context'] as String?;
    entry.mood = decrypted['mood'] as String?;
    entry.tags = decrypted['tags'] as String?;
    entry.detectedTheme = decrypted['detectedTheme'] as String?;
    entry.sentimentScore = (decrypted['sentimentScore'] as num?)?.toDouble();
    entry.transcription = decrypted['transcription'] as String?;
    entry.mediaPath = _toAbsoluteMediaPath(decrypted['mediaPath'] as String?);
    entry.isDeleted = decrypted['isDeleted'] as bool? ?? false;
    entry.deletedAt = decrypted['deletedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(decrypted['deletedAt'] as int)
        : null;
    entry.modifiedAt = decrypted['modifiedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(decrypted['modifiedAt'] as int)
        : DateTime.now();
    final deviceId = decrypted['deviceId'] as String?;
    entry.deviceId = _isValidUuidV4(deviceId) ? deviceId : _metadata.deviceId;
  }

  bool _isValidUuid(String? value) {
    if (value == null || value.isEmpty) return false;
    return _uuidPattern.hasMatch(value);
  }

  bool _isValidUuidV4(String? value) {
    if (value == null || value.isEmpty) return false;
    return _uuidV4Pattern.hasMatch(value);
  }

  String? _toRelativeMediaPath(String? path) {
    if (path == null || path.isEmpty) return null;
    if (_mediaBasePath.isEmpty) return path;
    final normalizedBase = _normalizePath(_mediaBasePath);
    final normalizedPath = _normalizePath(path);
    final prefix = '$normalizedBase/';
    if (normalizedPath.startsWith(prefix)) {
      return normalizedPath.substring(prefix.length);
    }
    return path;
  }

  String? _toAbsoluteMediaPath(String? path) {
    if (path == null || path.isEmpty) return null;
    if (_mediaBasePath.isEmpty) return path;
    if (path.startsWith('/') || path.startsWith(r'\\')) {
      return path;
    }
    return '${_normalizePath(_mediaBasePath)}/${_normalizePath(path)}';
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

enum _MergeResult { pulled, conflict, skipped }
