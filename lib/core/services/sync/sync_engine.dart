import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../../../data/datasources/local/objectbox_database.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/sync_id.dart';
import 'sync_backend.dart';
import 'sync_crypto_service.dart';
import 'sync_media_crypto.dart';
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
  /// version) and Drive uses per-device change logs. v3: media files sync
  /// (encrypted), so existing photo/voice entries must upload their files.
  /// v4: CloudKit moved to per-device change logs (media ids/keys and
  /// deletions now round-trip), and records carry AAD + a MAC.
  static const currentFormatVersion = 4;

  final ObjectBoxDatabase _db;
  final SyncBackend _backend;
  final SyncMetadata _metadata;
  final SyncCryptoService _crypto;
  final String _mediaBasePath;
  final bool Function() _networkAllowed;
  final SyncMediaCrypto _mediaCrypto;
  final Directory _tempDirectory;
  final int _maxConcurrentTransfers;

  /// The running background media download pass, if any.
  Future<void>? _mediaDownloads;

  /// Whether this session confirmed the local key is the account's key.
  /// Nothing is pushed until it is.
  bool _keyVerified = false;
  String? _verifiedFingerprint;

  /// Set when the last pull failed (so local state may be behind, or the key
  /// is unusable); pushes wait for a successful pull.
  bool _lastPullFailed = false;

  /// Upper bound for one backend call, so a hung request can't stall the
  /// serialized push/pull queue forever (media transfers get longer).
  final Duration callTimeout;
  final Duration transferTimeout;
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
    bool Function()? networkAllowed,
    SyncMediaCrypto? mediaCrypto,
    Directory? tempDirectory,
    int maxConcurrentTransfers = 2,
    this.callTimeout = const Duration(minutes: 2),
    this.transferTimeout = const Duration(minutes: 10),
  }) : _db = database,
       _backend = backend,
       _metadata = metadata,
       _crypto = cryptoService,
       _mediaBasePath = mediaBasePath,
       _networkAllowed = networkAllowed ?? _always,
       _mediaCrypto = mediaCrypto ?? SyncMediaCrypto(),
       _tempDirectory = tempDirectory ?? Directory.systemTemp,
       _maxConcurrentTransfers = maxConcurrentTransfers;

  static bool _always() => true;

  /// Network is only touched when this backend's sync is on *and* the
  /// app-wide cloud-sync opt-in is on.
  bool get _allowed => _metadata.isEnabled && _networkAllowed();

  /// Initialize sync engine. Call once at app startup (callers don't await
  /// it, so it never throws: failures end up in state + lastError).
  Future<void> init() async {
    if (!_allowed) {
      _setState(SyncState.disabled);
      return;
    }

    try {
      final available = await _backend.isAvailable().timeout(callTimeout);
      if (!available) {
        _setState(SyncState.error);
        return;
      }
      _keyVerified = false;
      if (!await _verifyKey()) return;

      _setState(SyncState.idle);
      await _queueMaintenanceChanges();
      // Pull first; only push once local state is known to be current and
      // readable (a failed pull must not be followed by a push).
      final pulled = await pull();
      if (pulled.success && _metadata.pendingChanges.isNotEmpty) {
        await push();
      }
    } catch (e) {
      await _fail('sync', e);
    }
  }

  /// Confirms the local key is the account's key (same keyring salt and a
  /// passing key check). On a mismatch nothing may be pushed: records under
  /// the wrong key are unreadable everywhere else. When the key changed
  /// since the last full upload (re-keyed after a keyring race or a new
  /// passphrase), everything is queued for re-upload under the new key.
  Future<bool> _verifyKey() async {
    final current = await _crypto.keyFingerprint();
    if (_keyVerified && current == _verifiedFingerprint) return true;
    _keyVerified = false;
    final keyring = await _backend.readKeyring().timeout(callTimeout);
    if (keyring != null && await _crypto.hasPassphrase()) {
      if (!await _crypto.matchesKeyring(keyring)) {
        const mismatch = SyncKeySaltMismatchException();
        await _metadata.setLastError(mismatch.message);
        _setState(SyncState.error);
        return false;
      }
    }
    if (current != null) {
      final previous = _metadata.pushedKeyFingerprint;
      if (previous != null && previous != current) {
        // Anything pushed under the old key is unreadable to the others.
        await _metadata.setFormatVersion(0);
        await _queueFullUploadIfNeeded(DateTime.now());
      }
      await _metadata.setPushedKeyFingerprint(current);
    }
    _verifiedFingerprint = current;
    _keyVerified = true;
    return true;
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
      _keyVerified = false;
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
        mediaAssetId: changeType == SyncChangeType.delete
            ? entry.mediaAssetId
            : null,
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
    final purged = _db.takePurgedEntries();
    await _metadata.addPendingChanges([
      for (final p in purged)
        SyncChange(
          syncUUID: p.syncUUID,
          changeType: SyncChangeType.delete,
          timestamp: now,
          mediaAssetId: p.mediaAssetId,
        ),
    ]);

    await _queueFullUploadIfNeeded(now);
  }

  Future<void> _queueFullUploadIfNeeded(DateTime now) async {
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
    if (!_allowed) return SyncResult.error('Sync disabled');

    // Snapshot: only these exact changes are removed afterwards. Anything
    // queued while we are on the network stays queued for the next push.
    final pending = _metadata.pendingChanges;
    if (pending.isEmpty) return SyncResult.success();

    final handled = <SyncChange>[];
    try {
      if (_lastPullFailed) {
        return SyncResult.error('Waiting for a successful pull before pushing');
      }
      if (!await _verifyKey()) {
        return SyncResult.error(const SyncKeySaltMismatchException().message);
      }
      _setState(SyncState.pushing);

      final saves = <SyncChange>[];
      final toSave = <Entry>[];
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

        toSave.add(entry);
        saves.add(change);
      }

      // Media first, so a record never points at a blob that isn't there.
      // An interrupted upload leaves the change queued and resumes next push.
      var skippedLarge = 0;
      await _forEachBounded(toSave.where(_needsUpload).toList(), (entry) async {
        if (!await _uploadMedia(entry)) skippedLarge++;
      });

      for (final entry in toSave) {
        encryptionSession ??= await _crypto.createEncryptionSession();
        records.add(
          await _entryToRecord(entry, encryptionSession: encryptionSession),
        );
      }

      if (records.isNotEmpty) {
        await _backend.saveRecords(records).timeout(callTimeout);
        handled.addAll(saves);
      }
      if (deletes.isNotEmpty) {
        await _backend
            .deleteRecords([for (final d in deletes) d.syncUUID])
            .timeout(callTimeout);
        await _forEachBounded(
          [
            for (final d in deletes)
              if (_isValidUuid(d.mediaAssetId)) d.mediaAssetId!,
          ],
          (assetId) async {
            try {
              await _backend.deleteMediaBlob(assetId).timeout(callTimeout);
            } on UnsupportedError {
              // Backend without media sync: nothing to remove.
            }
          },
        );
        handled.addAll(deletes);
      }

      await _metadata.removePendingChanges(handled);
      await _metadata.setLastError(
        skippedLarge > 0
            ? 'Skipped syncing $skippedLarge media file(s) over 50 MB.'
            : null,
      );
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
    if (!_allowed) return SyncResult.error('Sync disabled');

    _setState(SyncState.pulling);

    try {
      if (!await _verifyKey()) {
        _lastPullFailed = true;
        return SyncResult.error(const SyncKeySaltMismatchException().message);
      }
      final fetchResult = await _backend
          .fetchChanges(changeToken: _metadata.changeToken)
          .timeout(callTimeout);

      if (fetchResult == null) {
        _lastPullFailed = false;
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
      // Previously quarantined records are retried first (the key may have
      // been fixed since); fresher fetched versions replace them.
      for (final record in [
        ..._metadata.quarantinedRecords,
        ...fetchResult.records,
      ]) {
        final syncUUID = record['syncUUID'] as String?;
        if (!_isValidUuid(syncUUID)) continue;
        final existing = newest[syncUUID!];
        if (existing == null ||
            _modifiedAt(record).isAfter(_modifiedAt(existing))) {
          newest[syncUUID] = record;
        }
      }

      final toSave = <Entry>[];
      final quarantined = <Map<String, dynamic>>[];
      for (final record in newest.values) {
        final Map<String, dynamic> decrypted;
        try {
          decrypted = await _crypto.decryptRecordFields(record);
        } on SyncUnversionedRecordException {
          ignored++;
          continue;
        } on SyncPassphraseMissingException catch (e) {
          // No usable key at all (as opposed to one bad record): stop, keep
          // the token, and don't let a push follow.
          if (e is SyncPassphraseReentryRequiredException ||
              e is SyncKeySaltMismatchException) {
            quarantined.add(record);
            continue;
          }
          rethrow;
        } on SyncCryptoException {
          // Undecryptable or forged: set aside, keep going, keep the token
          // moving so one record can't wedge sync.
          quarantined.add(record);
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
      await _metadata.setQuarantinedRecords(quarantined);
      await _metadata.setLastSyncTime(DateTime.now());
      // Set-aside records are not an error: Settings shows their count
      // (syncQuarantineCountProvider) with a calm explanation.
      await _metadata.setLastError(null);
      _lastPullFailed = false;

      _setState(SyncState.idle);
      // Files arrive in the background; records show a placeholder until then.
      unawaited(downloadPendingMedia());
      return SyncResult.success(
        pulled: pulled,
        conflicts: conflicts,
        quarantined: quarantined.length,
      );
    } catch (e) {
      _lastPullFailed = true;
      return _fail('pull', e);
    }
  }

  Future<SyncResult> _fail(String operation, Object e) async {
    final message = switch (e) {
      SocketException() => 'Network error during $operation: $e',
      TimeoutException() => 'Sync timed out during $operation; will retry.',
      SyncDocumentCorruptedException() => e.toString(),
      SyncCryptoException(:final message) => message,
      _ => '${operation[0].toUpperCase()}${operation.substring(1)} failed: $e',
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
      'mediaAssetId': entry.mediaAssetId,
      'mediaKey': entry.mediaKey,
      'deviceId': entry.deviceId ?? _metadata.deviceId,
    };
    return _crypto.encryptRecordFields(record, session: encryptionSession);
  }

  Entry _decryptedToEntry(Map<String, dynamic> decrypted) {
    final syncUUID = decrypted['syncUUID'] as String?;
    final deviceId = decrypted['deviceId'] as String?;
    final typeIndex = decrypted['typeIndex'] as int? ?? 0;
    final assetId = decrypted['mediaAssetId'] as String?;
    final hasBlob = _isValidUuid(assetId);
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
      // With a blob, the file is downloaded later (mediaPath set then).
      mediaPath: hasBlob
          ? null
          : _localMediaPath(decrypted['mediaPath'] as String?, typeIndex),
      mediaAssetId: hasBlob ? assetId : null,
      mediaKey: hasBlob ? decrypted['mediaKey'] as String? : null,
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
    final assetId = decrypted['mediaAssetId'] as String?;
    if (_isValidUuid(assetId)) {
      if (entry.mediaAssetId != assetId) {
        // New or replaced media: fetch it in the background.
        entry.mediaAssetId = assetId;
        entry.mediaKey = decrypted['mediaKey'] as String?;
        entry.mediaPath = null;
      }
    } else if (entry.mediaAssetId == null) {
      // Older builds sync only a path (and no file).
      entry.mediaPath = _localMediaPath(
        decrypted['mediaPath'] as String?,
        entry.typeIndex,
      );
    }
    entry.isDeleted = decrypted['isDeleted'] as bool? ?? false;
    entry.deletedAt = _date(decrypted['deletedAt']);
    entry.modifiedAt = _date(decrypted['modifiedAt']) ?? DateTime.now();
    final deviceId = decrypted['deviceId'] as String?;
    entry.deviceId = _isValidUuidV4(deviceId) ? deviceId : _metadata.deviceId;
  }

  bool _isValidUuid(String? value) => SyncId.isValid(value);

  // ---------------------------------------------------------------------------
  // Media
  // ---------------------------------------------------------------------------

  /// Runs [work] over [items] with at most [_maxConcurrentTransfers] at once.
  Future<void> _forEachBounded<T>(
    List<T> items,
    Future<void> Function(T item) work,
  ) async {
    if (items.isEmpty) return;
    var next = 0;
    Future<void> worker() async {
      while (next < items.length) {
        await work(items[next++]);
      }
    }

    final workers = items.length < _maxConcurrentTransfers
        ? items.length
        : _maxConcurrentTransfers;
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
  }

  bool _needsUpload(Entry entry) =>
      entry.mediaAssetId == null && _localMediaFile(entry) != null;

  /// The entry's media file on this device, if it exists.
  File? _localMediaFile(Entry entry) {
    final path = entry.mediaPath;
    if (path == null || path.isEmpty) return null;
    final direct = File(path);
    if (direct.existsSync()) return direct;
    // Stored absolute paths go stale when iOS moves the app container.
    final relative = _relativeMediaPath(path, entry.typeIndex);
    if (relative == null || _mediaBasePath.isEmpty) return null;
    final moved = File('${_normalizePath(_mediaBasePath)}/$relative');
    return moved.existsSync() ? moved : null;
  }

  /// Encrypts and uploads the entry's media, then records the blob id and
  /// key on the entry. Returns false when the file was skipped (too large or
  /// the backend has no media support).
  Future<bool> _uploadMedia(Entry entry) async {
    final file = _localMediaFile(entry);
    if (file == null) return true;
    if (await file.length() > SyncMediaCrypto.maxPlaintextBytes) {
      developer.log('Skipping media over 50 MB', name: 'SyncEngine');
      return false;
    }
    final assetId = SyncId.generate();
    final key = _mediaCrypto.newFileKey();
    final sealed = File('${_tempDirectory.path}/seedling_up_$assetId.enc');
    try {
      await _mediaCrypto.encryptFile(file, sealed, key);
      await _backend.uploadMediaBlob(assetId, sealed).timeout(transferTimeout);
    } on UnsupportedError {
      return false;
    } finally {
      if (await sealed.exists()) await sealed.delete();
    }
    entry.mediaAssetId = assetId;
    entry.mediaKey = base64Encode(key);
    _updateMediaFields(entry.syncUUID!, (fresh) {
      fresh
        ..mediaAssetId = assetId
        ..mediaKey = entry.mediaKey;
      return true;
    });
    return true;
  }

  /// Applies [change] to the *current* stored entry in one synchronous step,
  /// so an edit made while a transfer was running is never overwritten.
  bool _updateMediaFields(String syncUUID, bool Function(Entry) change) {
    final fresh = _db.getEntryBySyncUUID(syncUUID);
    if (fresh == null || !change(fresh)) return false;
    _db.saveEntries([fresh], preserveModifiedAt: true);
    return true;
  }

  /// Downloads, verifies and stores media for entries that have a remote
  /// blob but no local file. Safe to call repeatedly; one pass at a time.
  /// Anything that fails stays pending and is retried after the next pull.
  Future<void> downloadPendingMedia() {
    return _mediaDownloads ??= _downloadPendingMedia().whenComplete(() {
      _mediaDownloads = null;
    });
  }

  Future<void> _downloadPendingMedia() async {
    if (!_allowed || _mediaBasePath.isEmpty) return;
    final List<Entry> pending;
    try {
      pending = _db.getEntriesNeedingMediaDownload();
    } catch (e) {
      // Background work: never surface as an unhandled error.
      developer.log('Media download pass failed', name: 'SyncEngine', error: e);
      return;
    }
    await _forEachBounded(pending, (entry) async {
      try {
        await _downloadMedia(entry);
      } catch (e) {
        developer.log(
          'Media download failed; will retry',
          name: 'SyncEngine',
          error: e,
        );
      }
    });
  }

  Future<void> _downloadMedia(Entry entry) async {
    final assetId = entry.mediaAssetId!;
    final encodedKey = entry.mediaKey;
    if (!_isValidUuid(assetId) || encodedKey == null) return;
    final key = base64Decode(encodedKey);
    final sealed = File('${_tempDirectory.path}/seedling_down_$assetId.enc');
    final folder = _folderForType(entry.typeIndex);
    final dir = Directory('${_normalizePath(_mediaBasePath)}/$folder');
    final target = File(
      '${dir.path}/${SyncId.generate()}.${entry.typeIndex == EntryType.voice.index ? 'm4a' : 'jpg'}',
    );
    try {
      if (!await _backend
          .downloadMediaBlob(assetId, sealed)
          .timeout(transferTimeout)) {
        return;
      }
      if (await sealed.length() >
          SyncMediaCrypto.maxPlaintextBytes + 1024 * 1024) {
        developer.log('Skipping media over 50 MB', name: 'SyncEngine');
        return;
      }
      await dir.create(recursive: true);
      // Throws (and removes target) on a bad tag or wrong key.
      await _mediaCrypto.decryptFile(sealed, target, key);
    } finally {
      if (await sealed.exists()) await sealed.delete();
    }
    final stored = _updateMediaFields(entry.syncUUID!, (fresh) {
      if (fresh.mediaAssetId != assetId || fresh.mediaPath != null) {
        return false; // Changed meanwhile; this file is no longer wanted.
      }
      fresh.mediaPath = target.path;
      return true;
    });
    if (!stored && await target.exists()) await target.delete();
  }

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
