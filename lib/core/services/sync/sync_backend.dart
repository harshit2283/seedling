import 'dart:io';

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

  /// Persist several records. Backends that rewrite a whole document per
  /// write should do it once for the batch.
  Future<void> saveRecords(List<Map<String, dynamic>> records) async {
    for (final record in records) {
      await saveRecord(record);
    }
  }

  /// Delete several records by sync UUID.
  Future<void> deleteRecords(List<String> syncUUIDs) async {
    for (final syncUUID in syncUUIDs) {
      await deleteRecord(syncUUID);
    }
  }

  /// The per-user key-derivation salt (base64) kept in the user's remote
  /// sync space, or null if none has been created yet.
  Future<String?> readKdfSalt() async => null;

  /// Stores [salt] as the per-user key salt unless one already exists, and
  /// returns the salt in effect afterwards (the existing one wins). Every
  /// device must end up with the same answer.
  Future<String> publishKdfSalt(String salt) async =>
      throw UnsupportedError('This sync backend has no keyring');

  /// Fetch remote changes since [changeToken].
  Future<SyncFetchResult?> fetchChanges({String? changeToken});

  /// Upload an already-encrypted media blob under [assetId]. Backends only
  /// ever see ciphertext (see SyncMediaCrypto); there is deliberately no
  /// way to upload a plaintext file.
  Future<void> uploadMediaBlob(String assetId, File ciphertext) async =>
      throw UnsupportedError('This sync backend does not sync media');

  /// Download the encrypted blob [assetId] into [target]. Returns false when
  /// the blob doesn't exist (yet).
  Future<bool> downloadMediaBlob(String assetId, File target) async =>
      throw UnsupportedError('This sync backend does not sync media');

  /// Delete the blob [assetId]; deleting a missing blob is not an error.
  Future<void> deleteMediaBlob(String assetId) async =>
      throw UnsupportedError('This sync backend does not sync media');

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
