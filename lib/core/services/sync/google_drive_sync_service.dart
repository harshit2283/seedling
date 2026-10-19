import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/prefs_keys.dart';
import 'drive_sync_log.dart';
import 'sync_backend.dart';
import 'sync_metadata.dart';
import 'sync_models.dart';

/// [DriveFileStore] over the Drive v3 API, scoped to the appData folder.
class _DriveApiFileStore implements DriveFileStore {
  final drive.DriveApi _api;

  _DriveApiFileStore(this._api);

  @override
  Future<List<DriveFileInfo>> listByPrefix(String prefix) async {
    final found = <DriveFileInfo>[];
    String? pageToken;
    do {
      // Drive's `contains` is a prefix match on names; filter exactly below.
      final page = await _api.files.list(
        q: "name contains '$prefix' and trashed=false and 'appDataFolder' in parents",
        spaces: 'appDataFolder',
        $fields: 'nextPageToken, files(id,name)',
        pageSize: 100,
        pageToken: pageToken,
      );
      for (final file in page.files ?? const <drive.File>[]) {
        final id = file.id;
        final name = file.name;
        if (id != null && name != null && name.startsWith(prefix)) {
          found.add(DriveFileInfo(id: id, name: name));
        }
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null);
    return found;
  }

  @override
  Future<List<int>?> read(String fileId) async {
    final media = await _api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );
    if (media is! drive.Media) return null;
    return media.stream.expand((chunk) => chunk).toList();
  }

  @override
  Future<String> create(String name, List<int> bytes) async {
    final created = await _api.files.create(
      drive.File()
        ..name = name
        ..parents = ['appDataFolder'],
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
    );
    return created.id!;
  }

  @override
  Future<void> overwrite(String fileId, List<int> bytes) async {
    await _api.files.update(
      drive.File(),
      fileId,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
    );
  }
}

/// Google Drive appData-based sync backend used on iOS/Android.
///
/// Each device appends to its own change log (see [DriveSyncLog]); pulls
/// read every device's log by sequence number. The v1 shared document is
/// still read so data pushed by older app versions keeps arriving.
class GoogleDriveSyncService implements SyncBackend {
  static const _recoveryDirName = 'sync_recovery';
  static const _scopes = <String>[drive.DriveApi.driveAppdataScope];

  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  final DriveFileStore? _injectedStore;
  final String? _injectedDeviceId;

  drive.DriveApi? _driveApi;
  Future<DriveSyncLogStore>? _logStoreFuture;
  bool _initialized = false;
  SharedPreferences? _prefs;

  GoogleDriveSyncService() : _injectedStore = null, _injectedDeviceId = null;

  /// A service over [store] that needs no Google sign-in.
  @visibleForTesting
  GoogleDriveSyncService.withStore(
    DriveFileStore store, {
    required String deviceId,
  }) : _injectedStore = store,
       _injectedDeviceId = deviceId;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _googleSignIn.initialize();
    _initialized = true;
  }

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> _ensureReady({bool interactive = false}) async {
    if (_injectedStore != null) return true;
    await _ensureInitialized();
    if (_driveApi != null) return true;

    var account = await _googleSignIn.attemptLightweightAuthentication();
    if (account == null && interactive) {
      account = await _googleSignIn.authenticate(scopeHint: _scopes);
    }
    if (account == null) return false;

    final authz =
        await account.authorizationClient.authorizationForScopes(_scopes) ??
        (interactive
            ? await account.authorizationClient.authorizeScopes(_scopes)
            : null);
    if (authz == null) return false;

    final client = authz.authClient(scopes: _scopes);
    _driveApi = drive.DriveApi(client);
    return true;
  }

  /// One log store per connection: it owns the write lock for this device's
  /// log, so concurrent callers must share it.
  Future<DriveSyncLogStore> _logs() =>
      _logStoreFuture ??= _createLogStore().catchError((Object e) {
        _logStoreFuture = null;
        throw e;
      });

  Future<DriveSyncLogStore> _createLogStore() async {
    final String deviceId;
    if (_injectedDeviceId != null) {
      deviceId = _injectedDeviceId;
    } else {
      await _ensurePrefs();
      // Same (un-namespaced) id SyncMetadata stamps on records.
      deviceId = SyncMetadata(
        _prefs!,
        namespace: SyncProviderType.googleDrive.name,
      ).deviceId;
    }
    return DriveSyncLogStore(
      _injectedStore ?? _DriveApiFileStore(_driveApi!),
      deviceId: deviceId,
      backup: (operation, bytes) =>
          _backupRawData(operation: operation, data: bytes),
    );
  }

  // ---------------------------------------------------------------------------
  // Account lock
  // ---------------------------------------------------------------------------

  Future<String?> get lockedAccount async {
    await _ensurePrefs();
    return _prefs!.getString(PrefsKeys.syncGDriveLockedAccount);
  }

  Future<bool> canUseAccount(String email) async {
    final locked = await lockedAccount;
    return locked == null || locked == email;
  }

  Future<void> _pinAccount(String email) async {
    await _ensurePrefs();
    await _prefs!.setString(PrefsKeys.syncGDriveLockedAccount, email);
  }

  Future<void> resetAccountLock() async {
    await _ensurePrefs();
    await _prefs!.remove(PrefsKeys.syncGDriveLockedAccount);
    await disconnect();
  }

  // ---------------------------------------------------------------------------
  // Retry helper
  // ---------------------------------------------------------------------------

  Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 3,
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (e) {
        final isRateLimitOrServiceError =
            (e.toString().contains('429') || e.toString().contains('503'));
        final isSocketError = e is SocketException;

        if ((isRateLimitOrServiceError || isSocketError) &&
            attempt < maxAttempts - 1) {
          await Future.delayed(Duration(seconds: 1 << attempt));
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Max retry attempts exceeded');
  }

  // ---------------------------------------------------------------------------
  // SyncBackend implementation
  // ---------------------------------------------------------------------------

  @override
  Future<bool> connect() async {
    await _ensureInitialized();

    final GoogleSignInAccount? lightAccount = await _googleSignIn
        .attemptLightweightAuthentication();
    final GoogleSignInAccount account =
        lightAccount ?? await _googleSignIn.authenticate(scopeHint: _scopes);

    final email = account.email;
    if (!await canUseAccount(email)) {
      final locked = await lockedAccount;
      await _googleSignIn.disconnect();
      throw AccountMismatchException(
        lockedAccount: locked!,
        attemptedAccount: email,
      );
    }

    final authz =
        await account.authorizationClient.authorizationForScopes(_scopes) ??
        await account.authorizationClient.authorizeScopes(_scopes);

    final client = authz.authClient(scopes: _scopes);
    _driveApi = drive.DriveApi(client);
    _logStoreFuture = null;

    await _pinAccount(email);
    return true;
  }

  @override
  Future<void> disconnect() async {
    _driveApi = null;
    _logStoreFuture = null;
    if (_injectedStore != null) return;
    await _googleSignIn.disconnect();
  }

  @override
  Future<bool> isAvailable() async {
    return _ensureReady();
  }

  @override
  Future<String> getAccountStatus() async {
    if (_injectedStore != null) return 'test';
    await _ensureInitialized();
    final account = await _googleSignIn.attemptLightweightAuthentication();
    if (account == null) return 'Not connected';
    return account.email;
  }

  @override
  Future<void> saveRecord(Map<String, dynamic> record) => saveRecords([record]);

  @override
  Future<void> deleteRecord(String syncUUID) => deleteRecords([syncUUID]);

  @override
  Future<void> saveRecords(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    for (final record in records) {
      final syncUUID = record['syncUUID'] as String?;
      if (syncUUID == null || syncUUID.isEmpty) {
        throw ArgumentError('syncUUID is required');
      }
    }
    if (!await _ensureReady()) {
      throw StateError('Google Drive not connected');
    }
    final logs = await _logs();
    await _withRetry(() => logs.append(records: records));
  }

  @override
  Future<void> deleteRecords(List<String> syncUUIDs) async {
    if (syncUUIDs.isEmpty) return;
    if (!await _ensureReady()) {
      throw StateError('Google Drive not connected');
    }
    final logs = await _logs();
    await _withRetry(() => logs.append(deletions: syncUUIDs));
  }

  @override
  Future<SyncFetchResult?> fetchChanges({String? changeToken}) async {
    if (!await _ensureReady()) return null;
    final logs = await _logs();
    return _withRetry(() => logs.fetch(changeToken));
  }

  @override
  Future<String?> uploadAsset(String localPath, String syncUUID) async {
    if (!await _ensureReady() || _driveApi == null) return null;
    final file = File(localPath);
    if (!await file.exists()) return null;

    return _withRetry(() async {
      final api = _driveApi!;
      final folderName = 'seedling_media';
      final folderId = await _findOrCreateFolder(folderName);
      final fileName = '${syncUUID}_${file.uri.pathSegments.last}';
      final media = drive.Media(file.openRead(), await file.length());
      final metadata = drive.File()
        ..name = fileName
        ..parents = [folderId];
      final created = await api.files.create(metadata, uploadMedia: media);
      return created.id;
    });
  }

  @override
  Future<String?> downloadAsset(String syncUUID, String targetPath) async {
    if (!await _ensureReady() || _driveApi == null) return null;

    return _withRetry(() async {
      final api = _driveApi!;
      final query =
          "name contains '${syncUUID}_' and trashed=false and 'appDataFolder' in parents";
      final files = await api.files.list(
        q: query,
        spaces: 'appDataFolder',
        $fields: 'files(id,name)',
        pageSize: 1,
      );
      final found = files.files;
      if (found == null || found.isEmpty || found.first.id == null) return null;

      final media = await api.files.get(
        found.first.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (media is! drive.Media) return null;

      final output = File(targetPath);
      final sink = output.openWrite();
      await media.stream.pipe(sink);
      await sink.close();
      return output.path;
    });
  }

  // ---------------------------------------------------------------------------
  // Quarantine helpers (records an older version set aside in the v1 doc)
  // ---------------------------------------------------------------------------

  Future<void> clearQuarantine() async {
    if (!await _ensureReady()) return;
    await (await _logs()).clearLegacyQuarantine();
  }

  Future<int> get quarantineCount async {
    if (!await _ensureReady()) return 0;
    final doc = await (await _logs()).readLegacyDocument();
    final quarantine = doc?['quarantine'];
    return quarantine is Map ? quarantine.length : 0;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<String?> _backupRawData({
    required String operation,
    required List<int> data,
  }) async {
    if (_injectedStore != null) return null;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final recoveryDir = Directory('${docsDir.path}/$_recoveryDirName');
      if (!await recoveryDir.exists()) {
        await recoveryDir.create(recursive: true);
      }

      final file = File(
        '${recoveryDir.path}/${operation}_${DateTime.now().millisecondsSinceEpoch}.bin',
      );
      await file.writeAsBytes(data, flush: true);
      return file.path;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to write sync recovery backup',
        name: 'GoogleDriveSyncService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<String> _findOrCreateFolder(String folderName) async {
    final api = _driveApi!;
    final files = await api.files.list(
      q: "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false and 'appDataFolder' in parents",
      spaces: 'appDataFolder',
      $fields: 'files(id,name)',
      pageSize: 1,
    );
    final found = files.files;
    if (found != null && found.isNotEmpty && found.first.id != null) {
      return found.first.id!;
    }

    final created = await api.files.create(
      drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = ['appDataFolder'],
    );
    return created.id!;
  }
}
