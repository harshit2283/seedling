import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'sync_backend.dart';

/// Dart wrapper around the native CloudKit plugin.
///
/// Communicates with CloudKitSyncPlugin.swift via MethodChannel.
/// All CloudKit operations happen on the iOS side; this class
/// marshals data between Dart and native.
class CloudKitSyncService implements SyncBackend {
  static const _channel = MethodChannel('com.seedling.cloudkit_sync');
  static const _assetFieldName = 'mediaAsset';

  /// Check if iCloud is available (user signed in, container accessible)
  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('CloudKitSyncService.isAvailable failed: ${e.code}');
      return false;
    }
  }

  /// Get the iCloud account status message for display
  @override
  Future<String> getAccountStatus() async {
    try {
      final result = await _channel.invokeMethod<String>('getAccountStatus');
      return result ?? 'Unknown';
    } on PlatformException catch (e) {
      return e.message ?? 'Error checking account';
    }
  }

  /// Save a record to CloudKit private database
  @override
  Future<void> saveRecord(Map<String, dynamic> record) async {
    await _channel.invokeMethod<void>('saveRecord', record);
  }

  /// Delete a record from CloudKit by syncUUID
  @override
  Future<void> deleteRecord(String syncUUID) async {
    await _channel.invokeMethod<void>('deleteRecord', {'syncUUID': syncUUID});
  }

  @override
  /// Fetch changes since the given change token.
  ///
  /// If [changeToken] is null, fetches all records (full sync).
  /// Returns null if no changes are available.
  Future<SyncFetchResult?> fetchChanges({String? changeToken}) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'fetchChanges',
        {'changeToken': changeToken},
      );

      if (result == null) return null;

      final records =
          (result['records'] as List<dynamic>?)
              ?.map((r) => Map<String, dynamic>.from(r as Map))
              .toList() ??
          [];

      final deletedUUIDs =
          (result['deletedUUIDs'] as List<dynamic>?)
              ?.map((u) => u as String)
              .toList() ??
          [];

      return SyncFetchResult(
        records: records,
        deletedUUIDs: deletedUUIDs,
        newChangeToken: result['changeToken'] as String?,
      );
    } on PlatformException catch (e) {
      debugPrint('CloudKitSyncService.fetchChanges failed: ${e.code}');
      return null;
    }
  }

  /// Upload a media asset to CloudKit
  @override
  Future<String?> uploadAsset(String localPath, String syncUUID) async {
    try {
      final result = await _channel.invokeMethod<String>('uploadAsset', {
        'filePath': localPath,
        'syncUUID': syncUUID,
        'fieldName': _assetFieldName,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('CloudKitSyncService.uploadAsset failed: ${e.code}');
      return null;
    }
  }

  /// Download a media asset from CloudKit
  @override
  Future<String?> downloadAsset(String syncUUID, String targetPath) async {
    try {
      final result = await _channel.invokeMethod<String>('downloadAsset', {
        'syncUUID': syncUUID,
        'destinationPath': targetPath,
        'fieldName': _assetFieldName,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('CloudKitSyncService.downloadAsset failed: ${e.code}');
      return null;
    }
  }

  @override
  Future<bool> connect() async => true;

  @override
  Future<void> disconnect() async {}
}
