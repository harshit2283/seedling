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

  /// The account keyring kept in the user's own sync space:
  /// `{kdfSalt: base64, check: key-check value}`, or null if none exists yet.
  Future<Map<String, dynamic>?> readKeyring() async => null;

  /// Stores [keyring] unless one already exists, and returns the keyring in
  /// effect afterwards (an existing one wins). Every device must end up with
  /// the same answer.
  Future<Map<String, dynamic>> publishKeyring(
    Map<String, dynamic> keyring,
  ) async => throw UnsupportedError('This sync backend has no keyring');

  /// Fetch remote changes since [changeToken]. Null means the backend was
  /// not reachable (not a successful empty pull).
  Future<SyncFetchResult?> fetchChanges({String? changeToken});

  /// Upload an already-encrypted media blob under [assetId]. Backends only
  /// ever see ciphertext (see SyncMediaCrypto); there is deliberately no
  /// way to upload a plaintext file.
  ///
  /// [replace] is set when retrying an interrupted upload under the same
  /// asset id: the new content must replace any existing copy.
  Future<void> uploadMediaBlob(
    String assetId,
    File ciphertext, {
    bool replace = false,
  }) async => throw UnsupportedError('This sync backend does not sync media');

  /// Download the encrypted blob [assetId] into [target]. Returns false when
  /// the blob doesn't exist (yet).
  Future<bool> downloadMediaBlob(String assetId, File target) async =>
      throw UnsupportedError('This sync backend does not sync media');

  /// Delete the blob [assetId]; deleting a missing blob is not an error.
  Future<void> deleteMediaBlob(String assetId) async =>
      throw UnsupportedError('This sync backend does not sync media');

  /// Deletes media blobs that no record in [referenced] points at and that
  /// are old enough not to belong to another device's in-flight push.
  Future<int> deleteOrphanMediaBlobs(Set<String> referenced) async => 0;

  /// Other devices whose change logs have been idle for [idle].
  Future<List<String>> idleDeviceIds(Duration idle) async => const [];

  /// Removes the change logs of [deviceIds] (their data must already be in
  /// this device's log).
  Future<void> deleteDeviceLogs(List<String> deviceIds) async {}

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
