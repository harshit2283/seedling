/// Result of fetching remote changes from a sync backend.
class SyncFetchResult {
  final List<Map<String, dynamic>> records;
  final List<String> deletedUUIDs;
  final String? newChangeToken;

  const SyncFetchResult({
    required this.records,
    required this.deletedUUIDs,
    this.newChangeToken,
  });
}

/// Backend contract used by [SyncEngine].
abstract class SyncBackend {
  /// Returns whether the backend is ready for sync calls.
  Future<bool> isAvailable();

  /// Human-readable account status for settings UI.
  Future<String> getAccountStatus();

  /// Persist a full entry record remotely.
  Future<void> saveRecord(Map<String, dynamic> record);

  /// Delete a record remotely by sync UUID.
  Future<void> deleteRecord(String syncUUID);

  /// Fetch remote changes since [changeToken].
  Future<SyncFetchResult?> fetchChanges({String? changeToken});

  /// Upload a media asset referenced by [syncUUID].
  Future<String?> uploadAsset(String localPath, String syncUUID);

  /// Download a media asset referenced by [syncUUID].
  Future<String?> downloadAsset(String syncUUID, String targetPath);

  /// Connect to provider account interactively when supported.
  Future<bool> connect() async => false;

  /// Disconnect provider account when supported.
  Future<void> disconnect() async {}
}

enum SyncProviderType { cloudKit, googleDrive }

extension SyncProviderTypeLabel on SyncProviderType {
  String get label {
    switch (this) {
      case SyncProviderType.cloudKit:
        return 'iCloud (CloudKit)';
      case SyncProviderType.googleDrive:
        return 'Google Drive';
    }
  }
}
