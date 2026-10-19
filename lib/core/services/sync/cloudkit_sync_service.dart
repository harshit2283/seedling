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
/// record in a private custom zone. Ids are the file names.
class CloudKitFileStore implements DriveFileStore {
  final Directory _temp;

  CloudKitFileStore({Directory? tempDirectory})
    : _temp = tempDirectory ?? Directory.systemTemp;

  @override
  Future<List<DriveFileInfo>> listByPrefix(String prefix) async {
    final raw = await _channel.invokeListMethod<Object?>('fsList', {
      'prefix': prefix,
    });
    return [
      for (final item in raw ?? const <Object?>[])
        if (item is Map && item['id'] is String && item['name'] is String)
          DriveFileInfo(id: item['id'] as String, name: item['name'] as String),
    ];
  }

  File _tempFile(String tag) => File(
    '${_temp.path}/seedling_ck_${tag}_${DateTime.now().microsecondsSinceEpoch}',
  );

  @override
  Future<List<int>?> read(String fileId) async {
    final tmp = _tempFile('read');
    try {
      final found = await _channel.invokeMethod<bool>('fsRead', {
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
    // Ids are names, so overwriting is creating under the same name.
    await create(fileId, bytes);
  }

  @override
  Future<String> createFromFile(String name, File source) async {
    await _channel.invokeMethod<bool>('fsWrite', {
      'id': name,
      'name': name,
      'sourcePath': source.path,
    });
    return name;
  }

  @override
  Future<void> downloadTo(String fileId, File target) async {
    final found = await _channel.invokeMethod<bool>('fsRead', {
      'id': fileId,
      'destinationPath': target.path,
    });
    if (found != true) {
      throw FileSystemException('CloudKit file missing', fileId);
    }
  }

  @override
  Future<void> delete(String fileId) async {
    await _channel.invokeMethod<bool>('fsDelete', {'id': fileId});
  }
}

/// iCloud backend. Uses the same per-device change-log protocol as Google
/// Drive (see [DriveSyncLogStore]), stored in the private CloudKit database,
/// so deletes propagate as log tombstones and every record field (media ids
/// and keys included) round-trips unchanged. Records written by older builds
/// as `SeedlingEntry` records are read once to migrate them.
class CloudKitSyncService implements SyncBackend {
  final DriveFileStore? _injectedStore;
  final String? _injectedDeviceId;
  final Future<List<Map<String, dynamic>>> Function()? _injectedLegacy;
  Future<DriveSyncLogStore>? _logStore;

  CloudKitSyncService()
    : _injectedStore = null,
      _injectedDeviceId = null,
      _injectedLegacy = null;

  @visibleForTesting
  CloudKitSyncService.withStore(
    DriveFileStore store, {
    required String deviceId,
    Future<List<Map<String, dynamic>>> Function()? legacyRecords,
  }) : _injectedStore = store,
       _injectedDeviceId = deviceId,
       _injectedLegacy = legacyRecords;

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
      legacy: _readLegacyOnce,
    );
  }();

  /// Delivers the legacy `SeedlingEntry` records once (marker 1). A failure
  /// (e.g. the record type was never created) is not fatal: it is retried on
  /// the next pull and never blocks log changes.
  Future<int?> _readLegacyOnce(
    int? seenMarker,
    List<Map<String, dynamic>> records,
    Set<String> deletedUUIDs,
  ) async {
    if (seenMarker != null) return seenMarker;
    try {
      final legacy = _injectedLegacy != null
          ? await _injectedLegacy()
          : await _fetchLegacyRecords();
      records.addAll(legacy);
      return 1;
    } on PlatformException catch (e) {
      const ErrorReporter().report(e, context: 'CloudKitSyncService.legacy');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLegacyRecords() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'fetchLegacyRecords',
    );
    return [
      for (final r in (result?['records'] as List<dynamic>? ?? const []))
        Map<String, dynamic>.from(r as Map),
    ];
  }

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
  Future<void> uploadMediaBlob(String assetId, File ciphertext) async =>
      (await _logs()).uploadBlob(assetId, ciphertext);

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
