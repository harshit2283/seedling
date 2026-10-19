import 'dart:io';

import 'package:flutter/services.dart';
import 'sync_backend.dart';
import '../error_reporter.dart';

/// Dart wrapper around the native CloudKit plugin.
///
/// Communicates with CloudKitSyncPlugin.swift via MethodChannel.
/// All CloudKit operations happen on the iOS side; this class
/// marshals data between Dart and native.
class CloudKitSyncService implements SyncBackend {
  static const _channel = MethodChannel('com.seedling.cloudkit_sync');

  /// Check if iCloud is available (user signed in, container accessible)
  @override
  Future<bool> isAvailable() async {
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
  Future<void> saveRecords(List<Map<String, dynamic>> records) async {
    for (final record in records) {
      await saveRecord(record);
    }
  }

  @override
  Future<void> deleteRecords(List<String> syncUUIDs) async {
    for (final syncUUID in syncUUIDs) {
      await deleteRecord(syncUUID);
    }
  }

  /// Per-user key salt, stored in a single `SeedlingKeyring` record.
  @override
  Future<String?> readKdfSalt() async {
    return _channel.invokeMethod<String>('readKeyring');
  }

  /// CloudKit refuses to create a record that already exists, so the first
  /// device to publish wins atomically; the native side returns the winner.
  @override
  Future<String> publishKdfSalt(String salt) async {
    final winner = await _channel.invokeMethod<String>('publishKeyring', {
      'kdfSalt': salt,
    });
    if (winner == null || winner.isEmpty) {
      throw PlatformException(
        code: 'KEYRING_FAILED',
        message: 'Could not read the sync keyring',
      );
    }
    return winner;
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
      const ErrorReporter().report(
        e,
        context: 'CloudKitSyncService.fetchChanges',
      );
      return null;
    }
  }

  /// Encrypted media lives in its own `SeedlingMedia` record as a CKAsset
  /// (the file is already ciphertext; see SyncMediaCrypto).
  @override
  Future<void> uploadMediaBlob(String assetId, File ciphertext) async {
    await _channel.invokeMethod<void>('uploadMediaBlob', {
      'assetId': assetId,
      'sourcePath': ciphertext.path,
    });
  }

  @override
  Future<bool> downloadMediaBlob(String assetId, File target) async {
    final found = await _channel.invokeMethod<bool>('downloadMediaBlob', {
      'assetId': assetId,
      'destinationPath': target.path,
    });
    return found ?? false;
  }

  @override
  Future<void> deleteMediaBlob(String assetId) async {
    await _channel.invokeMethod<void>('deleteMediaBlob', {'assetId': assetId});
  }

  @override
  Future<bool> connect() async => true;

  @override
  Future<void> disconnect() async {}
}
