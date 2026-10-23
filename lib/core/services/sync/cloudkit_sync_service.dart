import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../error_reporter.dart';
import 'drive_sync_log.dart';
import 'sync_backend.dart';
import 'sync_metadata.dart';

const _channel = MethodChannel('com.seedling.cloudkit_sync');

/// [DriveFileStore] over the CloudKit plugin: each file is a `SeedlingFile`
/// record in a private custom zone. Ids are the file names, so exact-name
/// lookups are single-record fetches (no zone scans). Throttling errors are
/// retried with backoff, honouring CloudKit's retry-after hint.
class CloudKitFileStore implements DriveFileStore {
  static const _retryable = {
    'RATE_LIMITED',
    'ZONE_BUSY',
    'NETWORK_UNAVAILABLE',
    'SERVICE_UNAVAILABLE',
  };

  final Directory _temp;
  final int _maxAttempts;
  final Future<void> Function(Duration) _sleep;

  CloudKitFileStore({
    Directory? tempDirectory,
    int maxAttempts = 4,
    Future<void> Function(Duration)? sleep,
  }) : _temp = tempDirectory ?? Directory.systemTemp,
       _maxAttempts = maxAttempts,
       _sleep = sleep ?? Future<void>.delayed;

  Future<T?> _call<T>(String method, Map<String, Object?> args) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _channel.invokeMethod<T>(method, args);
      } on PlatformException catch (e) {
        if (!_retryable.contains(e.code) || attempt >= _maxAttempts) rethrow;
        final details = e.details;
        final hinted = details is Map ? details['retryAfterSeconds'] : null;
        final seconds = hinted is num
            ? hinted.toDouble().clamp(1, 120)
            : (1 << attempt).toDouble();
        await _sleep(Duration(milliseconds: (seconds * 1000).round()));
      }
    }
  }

  static DriveFileInfo? _info(Object? item) {
    if (item is! Map || item['id'] is! String || item['name'] is! String) {
      return null;
    }
    final created = item['createdAt'];
    return DriveFileInfo(
      id: item['id'] as String,
      name: item['name'] as String,
      createdAt: created is num
          ? DateTime.fromMillisecondsSinceEpoch(created.toInt())
          : null,
    );
  }

  @override
  Future<List<DriveFileInfo>> listByPrefix(String prefix) async {
    final raw = await _call<List<Object?>>('fsList', {'prefix': prefix});
    return [for (final item in raw ?? const <Object?>[]) ?_info(item)];
  }

  @override
  Future<DriveFileInfo?> findByName(String name) async =>
      _info(await _call<Object?>('fsExists', {'id': name}));

  File _tempFile(String tag) => File(
    '${_temp.path}/seedling_ck_${tag}_${DateTime.now().microsecondsSinceEpoch}',
  );

  @override
  Future<List<int>?> read(String fileId) async {
    final tmp = _tempFile('read');
    try {
      final found = await _call<bool>('fsRead', {
        'id': fileId,
        'destinationPath': tmp.path,
      });
      if (found != true) return null;
      return await tmp.readAsBytes();
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  @override
  Future<String> create(String name, List<int> bytes) async {
    final tmp = _tempFile('write');
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      return await createFromFile(name, tmp);
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  @override
  Future<void> overwrite(String fileId, List<int> bytes) async {
    // Ids are names, so overwriting is writing under the same name.
    await create(fileId, bytes);
  }

  @override
  Future<String> createFromFile(String name, File source) async {
    await _call<bool>('fsWrite', {
      'id': name,
      'name': name,
      'sourcePath': source.path,
    });
    return name;
  }

  @override
  Future<void> overwriteFromFile(String fileId, File source) async {
    await createFromFile(fileId, source);
  }

  @override
  Future<void> downloadTo(String fileId, File target) async {
    final found = await _call<bool>('fsRead', {
      'id': fileId,
      'destinationPath': target.path,
    });
    if (found != true) {
      throw FileSystemException('CloudKit file missing', fileId);
    }
  }

  @override
  Future<void> delete(String fileId) async {
    await _call<bool>('fsDelete', {'id': fileId});
  }
}

/// iCloud backend. Uses the same per-device change-log protocol as Google
/// Drive (see [DriveSyncLogStore]), stored in the private CloudKit database,
/// so deletes propagate as log tombstones and every record field (media ids
/// and keys included) round-trips unchanged.
class CloudKitSyncService implements SyncBackend {
  final DriveFileStore? _injectedStore;
  final String? _injectedDeviceId;
  Future<DriveSyncLogStore>? _logStore;

  CloudKitSyncService() : _injectedStore = null, _injectedDeviceId = null;

  @visibleForTesting
  CloudKitSyncService.withStore(
    DriveFileStore store, {
    required String deviceId,
  }) : _injectedStore = store,
       _injectedDeviceId = deviceId;

  Future<DriveSyncLogStore> _logs() => _logStore ??= () async {
    var deviceId = _injectedDeviceId;
    if (deviceId == null) {
      final prefs = await SharedPreferences.getInstance();
      deviceId = SyncMetadata(
        prefs,
        namespace: SyncProviderType.cloudKit.name,
      ).deviceId;
    }
    return DriveSyncLogStore(
      _injectedStore ?? CloudKitFileStore(),
      deviceId: deviceId,
    );
  }();

  @override
  Future<bool> isAvailable() async {
    if (_injectedStore != null) return true;
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException catch (e) {
      const ErrorReporter().report(
        e,
        context: 'CloudKitSyncService.isAvailable',
      );
      return false;
    }
  }

  @override
  Future<String> getAccountStatus() async {
    if (_injectedStore != null) return 'test';
    try {
      final result = await _channel.invokeMethod<String>('getAccountStatus');
      return result ?? 'Unknown';
    } on PlatformException catch (e) {
      return e.message ?? 'Error checking account';
    }
  }

  @override
  Future<void> saveRecord(Map<String, dynamic> record) => saveRecords([record]);

  @override
  Future<void> deleteRecord(String syncUUID) => deleteRecords([syncUUID]);

  // Errors propagate (no "no changes" on failure): the engine reports them
  // and keeps the queue / change token as they were.
  @override
  Future<void> saveRecords(List<Map<String, dynamic>> records) async =>
      (await _logs()).append(records: records);

  @override
  Future<void> deleteRecords(List<String> syncUUIDs) async =>
      (await _logs()).append(deletions: syncUUIDs);

  @override
  Future<SyncFetchResult?> fetchChanges({String? changeToken}) async =>
      (await _logs()).fetch(changeToken);

  @override
  Future<Map<String, dynamic>?> readKeyring() async =>
      (await _logs()).readKeyring();

  @override
  Future<Map<String, dynamic>> publishKeyring(
    Map<String, dynamic> keyring,
  ) async => (await _logs()).publishKeyring(keyring);

  @override
  Future<void> uploadMediaBlob(
    String assetId,
    File ciphertext, {
    bool replace = false,
  }) async => (await _logs()).uploadBlob(assetId, ciphertext, replace: replace);

  @override
  Future<int> deleteOrphanMediaBlobs(Set<String> referenced) async =>
      (await _logs()).deleteOrphanBlobs(referenced);

  @override
  Future<List<String>> idleDeviceIds(Duration idle) async =>
      (await _logs()).idleDevices(idle);

  @override
  Future<void> deleteDeviceLogs(List<String> deviceIds) async =>
      (await _logs()).deleteDeviceLogs(deviceIds);

  @override
  Future<bool> downloadMediaBlob(String assetId, File target) async =>
      (await _logs()).downloadBlob(assetId, target);

  @override
  Future<void> deleteMediaBlob(String assetId) async =>
      (await _logs()).deleteBlob(assetId);

  @override
  Future<bool> connect() async => true;

  @override
  Future<void> disconnect() async {}
}
