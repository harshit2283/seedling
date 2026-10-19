import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../constants/prefs_keys.dart';
import 'sync_models.dart';

/// Metadata namespaces in use (one per sync provider; see SyncProviderType).
const syncNamespaces = <String>['cloudKit', 'googleDrive'];

/// Persists sync state: change tokens, pending queue, last sync time.
class SyncMetadata {
  static const _uuid = Uuid();
  static final _uuidV4Pattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  final SharedPreferences _prefs;
  final String _namespace;

  SyncMetadata(this._prefs, {required String namespace})
    : _namespace = namespace;

  String _key(String base) => '${base}_$_namespace';

  /// Whether iCloud sync is enabled by the user
  bool get isEnabled => _prefs.getBool(_key(PrefsKeys.syncEnabled)) ?? false;

  Future<void> setEnabled(bool enabled) async {
    await _prefs.setBool(_key(PrefsKeys.syncEnabled), enabled);
  }

  /// CloudKit server change token (opaque string from CKServerChangeToken)
  String? get changeToken => _prefs.getString(_key(PrefsKeys.syncChangeToken));

  Future<void> setChangeToken(String? token) async {
    if (token == null) {
      await _prefs.remove(_key(PrefsKeys.syncChangeToken));
    } else {
      await _prefs.setString(_key(PrefsKeys.syncChangeToken), token);
    }
  }

  /// When last successful sync completed
  DateTime? get lastSyncTime {
    final ms = _prefs.getInt(_key(PrefsKeys.syncLastSync));
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> setLastSyncTime(DateTime time) async {
    await _prefs.setInt(
      _key(PrefsKeys.syncLastSync),
      time.millisecondsSinceEpoch,
    );
  }

  /// Unique device identifier for this installation
  String get deviceId {
    var id = _prefs.getString(PrefsKeys.syncDeviceId);
    if (!_isValidUuidV4(id)) {
      id = _uuid.v4();
      _prefs.setString(PrefsKeys.syncDeviceId, id);
    }
    return id!;
  }

  /// Pending changes that haven't been pushed to iCloud yet
  List<SyncChange> get pendingChanges {
    final raw = _prefs.getString(_key(PrefsKeys.syncPendingQueue));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SyncChange.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error, stackTrace) {
      unawaited(_handlePendingQueueCorruption(raw, error, stackTrace));
      return [];
    }
  }

  Future<void> addPendingChange(SyncChange change) =>
      addPendingChanges([change]);

  /// Queue changes; a newer change for the same syncUUID replaces the older
  /// one (latest wins). A replacement always gets a strictly later timestamp
  /// than the change it replaces, so a push that snapshotted the old change
  /// can tell it apart (see [removePendingChanges]).
  Future<void> addPendingChanges(List<SyncChange> changes) async {
    if (changes.isEmpty) return;
    final byUUID = {for (final c in pendingChanges) c.syncUUID: c};
    for (var change in changes) {
      final replaced = byUUID[change.syncUUID];
      if (replaced != null && !change.timestamp.isAfter(replaced.timestamp)) {
        change = SyncChange(
          syncUUID: change.syncUUID,
          changeType: change.changeType,
          timestamp: replaced.timestamp.add(const Duration(milliseconds: 1)),
          mediaAssetId: change.mediaAssetId ?? replaced.mediaAssetId,
        );
      }
      byUUID.remove(change.syncUUID);
      byUUID[change.syncUUID] = change;
    }
    await _savePendingChanges(byUUID.values.toList());
  }

  /// Remove exactly the [handled] changes (same syncUUID, type and
  /// timestamp). A change queued for the same entry after the push took its
  /// snapshot is kept, so edits made while a push is in flight are not lost.
  Future<void> removePendingChanges(List<SyncChange> handled) async {
    if (handled.isEmpty) return;
    String key(SyncChange c) =>
        '${c.syncUUID}|${c.changeType.name}|${c.timestamp.millisecondsSinceEpoch}';
    final handledKeys = handled.map(key).toSet();
    final current = pendingChanges;
    final before = current.length;
    current.removeWhere((c) => handledKeys.contains(key(c)));
    if (current.length == before) return;
    await _savePendingChanges(current);
  }

  /// Quarantine as stored by earlier builds (SharedPreferences). Returned
  /// once and removed; SyncQuarantine keeps it in a file now.
  Future<List<Map<String, dynamic>>> takeLegacyQuarantine() async {
    final raw = _prefs.getString(_key(PrefsKeys.syncQuarantine));
    if (raw == null) return const [];
    await _prefs.remove(_key(PrefsKeys.syncQuarantine));
    try {
      return [
        for (final r in jsonDecode(raw) as List<dynamic>)
          Map<String, dynamic>.from(r as Map),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Asset ids reserved for media uploads that haven't completed, by entry
  /// syncUUID. A retry reuses the id (replacing any partial blob) instead of
  /// leaving an orphan behind under a new id.
  Map<String, String> get pendingMediaUploads {
    final raw = _prefs.getString(_key(PrefsKeys.syncPendingMedia));
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> setPendingMediaUpload(String syncUUID, String? assetId) async {
    final current = pendingMediaUploads;
    if (assetId == null) {
      if (current.remove(syncUUID) == null) return;
    } else {
      current[syncUUID] = assetId;
    }
    await _prefs.setString(
      _key(PrefsKeys.syncPendingMedia),
      jsonEncode(current),
    );
  }

  /// When remote housekeeping (orphan blobs, idle logs) last ran.
  DateTime? get lastMaintenanceAt {
    final ms = _prefs.getInt(_key(PrefsKeys.syncLastMaintenance));
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastMaintenanceAt(DateTime at) async {
    await _prefs.setInt(
      _key(PrefsKeys.syncLastMaintenance),
      at.millisecondsSinceEpoch,
    );
  }

  /// Fingerprint of the sync key last used to push (see
  /// SyncCryptoService.keyFingerprint). A change means re-push everything.
  String? get pushedKeyFingerprint =>
      _prefs.getString(_key(PrefsKeys.syncKeyFingerprint));

  Future<void> setPushedKeyFingerprint(String? value) async {
    if (value == null) {
      await _prefs.remove(_key(PrefsKeys.syncKeyFingerprint));
    } else {
      await _prefs.setString(_key(PrefsKeys.syncKeyFingerprint), value);
    }
  }

  /// After an iOS backup restore, preferences come back but the database does
  /// not. The restored device must not reuse the original device's id (both
  /// would write the same change log) or replay its queue, so give it a new
  /// identity and a clean sync state for every provider.
  static Future<void> resetForRestoredInstall(SharedPreferences prefs) async {
    await prefs.remove(PrefsKeys.syncDeviceId);
    for (final namespace in syncNamespaces) {
      await SyncMetadata(prefs, namespace: namespace).reset();
    }
  }

  /// Persists remote deletes for purged entries right away, for every
  /// provider whose sync is on, so they survive an app kill before sync runs.
  static Future<void> queuePurgedDeletes(
    SharedPreferences prefs,
    List<({String syncUUID, String? mediaAssetId})> purged,
  ) async {
    if (purged.isEmpty) return;
    final now = DateTime.now();
    for (final namespace in syncNamespaces) {
      final meta = SyncMetadata(prefs, namespace: namespace);
      if (!meta.isEnabled) continue;
      await meta.addPendingChanges([
        for (final p in purged)
          SyncChange(
            syncUUID: p.syncUUID,
            changeType: SyncChangeType.delete,
            timestamp: now,
            mediaAssetId: p.mediaAssetId,
          ),
      ]);
    }
  }

  /// Remote layout version this device has completed a full upload for.
  int get formatVersion =>
      _prefs.getInt(_key(PrefsKeys.syncFormatVersion)) ?? 0;

  Future<void> setFormatVersion(int version) async {
    await _prefs.setInt(_key(PrefsKeys.syncFormatVersion), version);
  }

  Future<void> clearPendingChanges() async {
    await _prefs.remove(_key(PrefsKeys.syncPendingQueue));
  }

  Future<void> _savePendingChanges(List<SyncChange> changes) async {
    final json = jsonEncode(changes.map((c) => c.toJson()).toList());
    await _prefs.setString(_key(PrefsKeys.syncPendingQueue), json);
  }

  bool _isValidUuidV4(String? value) {
    if (value == null || value.isEmpty) return false;
    return _uuidV4Pattern.hasMatch(value);
  }

  Future<void> _handlePendingQueueCorruption(
    String raw,
    Object error,
    StackTrace stackTrace,
  ) async {
    final backupPath = await _backupCorruptedPendingQueue(raw);
    await _prefs.remove(_key(PrefsKeys.syncPendingQueue));
    developer.log(
      'Corrupted pending sync queue cleared. Backup: $backupPath',
      name: 'SyncMetadata',
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<String?> _backupCorruptedPendingQueue(String raw) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final recoveryDir = Directory('${docsDir.path}/sync_recovery');
      if (!await recoveryDir.exists()) {
        await recoveryDir.create(recursive: true);
      }
      final file = File(
        '${recoveryDir.path}/pending_queue_corrupt_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(raw, flush: true);
      return file.path;
    } catch (error, stackTrace) {
      developer.log(
        'Failed backing up corrupted pending queue',
        name: 'SyncMetadata',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Last sync error message (null if no error)
  String? get lastError => _prefs.getString(_key(PrefsKeys.syncLastError));

  /// When the last sync error occurred
  DateTime? get lastErrorAt {
    final ms = _prefs.getInt(_key(PrefsKeys.syncLastErrorAt));
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> setLastError(String? message) async {
    if (message == null) {
      await _prefs.remove(_key(PrefsKeys.syncLastError));
      await _prefs.remove(_key(PrefsKeys.syncLastErrorAt));
    } else {
      await _prefs.setString(_key(PrefsKeys.syncLastError), message);
      await _prefs.setInt(
        _key(PrefsKeys.syncLastErrorAt),
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  /// Reset all sync metadata (for re-initialization)
  Future<void> reset() async {
    await _prefs.remove(_key(PrefsKeys.syncChangeToken));
    await _prefs.remove(_key(PrefsKeys.syncLastSync));
    await _prefs.remove(_key(PrefsKeys.syncPendingQueue));
    await _prefs.remove(_key(PrefsKeys.syncFormatVersion));
    await _prefs.remove(_key(PrefsKeys.syncQuarantine));
    await _prefs.remove(_key(PrefsKeys.syncKeyFingerprint));
    await _prefs.remove(_key(PrefsKeys.syncPendingMedia));
    await _prefs.remove(_key(PrefsKeys.syncLastMaintenance));
    await setLastError(null);
  }
}
