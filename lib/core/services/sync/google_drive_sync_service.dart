import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_backend.dart';
import 'sync_models.dart';

class _DriveSyncDocument {
  final int metadataVersion;
  final int updatedAt;
  final Map<String, Map<String, dynamic>> records;
  final Map<String, int> deletions;
  final Map<String, Map<String, dynamic>> quarantine;

  const _DriveSyncDocument({
    this.metadataVersion = 1,
    required this.updatedAt,
    required this.records,
    required this.deletions,
    this.quarantine = const {},
  });

  factory _DriveSyncDocument.empty() => const _DriveSyncDocument(
    metadataVersion: 1,
    updatedAt: 0,
    records: {},
    deletions: {},
    quarantine: {},
  );

  Map<String, dynamic> toJson() => {
    'metadataVersion': metadataVersion,
    'updatedAt': updatedAt,
    'records': records,
    'deletions': deletions,
    'quarantine': quarantine,
  };

  factory _DriveSyncDocument.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'] as Map<String, dynamic>? ?? {};
    final rawDeletions = json['deletions'] as Map<String, dynamic>? ?? {};
    final rawQuarantine = json['quarantine'] as Map<String, dynamic>? ?? {};
    return _DriveSyncDocument(
      metadataVersion: json['metadataVersion'] as int? ?? 0,
      updatedAt: json['updatedAt'] as int? ?? 0,
      records: rawRecords.map(
        (key, value) => MapEntry(
          key,
          Map<String, dynamic>.from((value as Map).cast<String, dynamic>()),
        ),
      ),
      deletions: rawDeletions.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      quarantine: rawQuarantine.map(
        (key, value) => MapEntry(
          key,
          Map<String, dynamic>.from((value as Map).cast<String, dynamic>()),
        ),
      ),
    );
  }

  _DriveSyncDocument copyWith({
    int? metadataVersion,
    int? updatedAt,
    Map<String, Map<String, dynamic>>? records,
    Map<String, int>? deletions,
    Map<String, Map<String, dynamic>>? quarantine,
  }) {
    return _DriveSyncDocument(
      metadataVersion: metadataVersion ?? this.metadataVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      records: records ?? this.records,
      deletions: deletions ?? this.deletions,
      quarantine: quarantine ?? this.quarantine,
    );
  }
}

/// Google Drive appData-based sync backend used on iOS/Android.
class GoogleDriveSyncService implements SyncBackend {
  static const _syncFileName = 'seedling_sync_db_v1.json';
  static const _recoveryDirName = 'sync_recovery';
  static const _scopes = <String>[drive.DriveApi.driveAppdataScope];
  static const _lockedAccountKey = 'sync_gdrive_locked_account';

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  drive.DriveApi? _driveApi;
  String? _syncFileId;
  bool _initialized = false;
  SharedPreferences? _prefs;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _googleSignIn.initialize();
    _initialized = true;
  }

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> _ensureReady({bool interactive = false}) async {
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

  // ---------------------------------------------------------------------------
  // Account lock
  // ---------------------------------------------------------------------------

  Future<String?> get lockedAccount async {
    await _ensurePrefs();
    return _prefs!.getString(_lockedAccountKey);
  }

  Future<bool> canUseAccount(String email) async {
    final locked = await lockedAccount;
    return locked == null || locked == email;
  }

  Future<void> _pinAccount(String email) async {
    await _ensurePrefs();
    await _prefs!.setString(_lockedAccountKey, email);
  }

  Future<void> resetAccountLock() async {
    await _ensurePrefs();
    await _prefs!.remove(_lockedAccountKey);
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

    await _findOrCreateSyncFileId();
    await _pinAccount(email);
    return true;
  }

  @override
  Future<void> disconnect() async {
    _driveApi = null;
    _syncFileId = null;
    await _googleSignIn.disconnect();
  }

  @override
  Future<bool> isAvailable() async {
    return _ensureReady();
  }

  @override
  Future<String> getAccountStatus() async {
    await _ensureInitialized();
    final account = await _googleSignIn.attemptLightweightAuthentication();
    if (account == null) return 'Not connected';
    return account.email;
  }

  @override
  Future<void> saveRecord(Map<String, dynamic> record) async {
    if (!await _ensureReady()) {
      throw StateError('Google Drive not connected');
    }
    final syncUUID = record['syncUUID'] as String?;
    if (syncUUID == null || syncUUID.isEmpty) {
      throw ArgumentError('syncUUID is required');
    }

    final doc = await _loadDocument();
    doc.records[syncUUID] = Map<String, dynamic>.from(record);
    doc.deletions.remove(syncUUID);

    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = doc.copyWith(
      updatedAt: now,
      records: doc.records,
      deletions: doc.deletions,
    );
    await _withRetry(() => _saveDocument(updated));
  }

  @override
  Future<void> deleteRecord(String syncUUID) async {
    if (!await _ensureReady()) {
      throw StateError('Google Drive not connected');
    }

    final doc = await _loadDocument();
    doc.records.remove(syncUUID);
    doc.deletions[syncUUID] = DateTime.now().millisecondsSinceEpoch;

    final updated = doc.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      records: doc.records,
      deletions: doc.deletions,
    );
    await _withRetry(() => _saveDocument(updated));
  }

  @override
  Future<SyncFetchResult?> fetchChanges({String? changeToken}) async {
    if (!await _ensureReady()) return null;

    final doc = await _loadDocument();
    final since = int.tryParse(changeToken ?? '') ?? 0;

    final changedRecords = <Map<String, dynamic>>[];
    for (final entry in doc.records.entries) {
      final record = entry.value;
      final modifiedAtRaw = record['modifiedAt'];
      if (modifiedAtRaw != null && modifiedAtRaw is! num) {
        final backupPath = await _backupRawData(
          operation: 'fetch_record_corrupt',
          data: utf8.encode(jsonEncode(record)),
        );
        throw SyncDocumentCorruptedException(
          operation: 'fetch',
          message:
              'Record ${entry.key} has invalid modifiedAt type: ${modifiedAtRaw.runtimeType}',
          backupPath: backupPath,
        );
      }
      final modifiedAt = (modifiedAtRaw as num?)?.toInt() ?? 0;
      if (modifiedAt > since) {
        changedRecords.add(record);
      }
    }

    final deletedUUIDs = <String>[];
    for (final entry in doc.deletions.entries) {
      if (entry.value > since) {
        deletedUUIDs.add(entry.key);
      }
    }

    return SyncFetchResult(
      records: changedRecords,
      deletedUUIDs: deletedUUIDs,
      newChangeToken: doc.updatedAt.toString(),
    );
  }

  @override
  Future<String?> uploadAsset(String localPath, String syncUUID) async {
    if (!await _ensureReady()) return null;
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
    if (!await _ensureReady()) return null;

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
  // Quarantine helpers
  // ---------------------------------------------------------------------------

  Future<void> clearQuarantine() async {
    if (!await _ensureReady()) return;
    final doc = await _loadDocument();
    final updated = doc.copyWith(quarantine: {});
    await _saveDocument(updated);
  }

  Future<int> get quarantineCount async {
    if (!await _ensureReady()) return 0;
    final doc = await _loadDocument();
    return doc.quarantine.length;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<_DriveSyncDocument> _loadDocument() async {
    final api = _driveApi!;
    await _findOrCreateSyncFileId();
    if (_syncFileId == null) return _DriveSyncDocument.empty();

    final media = await api.files.get(
      _syncFileId!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );
    if (media is! drive.Media) return _DriveSyncDocument.empty();

    final bytes = await media.stream.expand((chunk) => chunk).toList();
    if (bytes.isEmpty) return _DriveSyncDocument.empty();

    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final doc = _DriveSyncDocument.fromJson(json);
      return _migrateMetadata(doc);
    } catch (error, stackTrace) {
      final backupPath = await _backupRawData(
        operation: 'load_document_corrupt',
        data: bytes,
      );
      developer.log(
        'Corrupted sync document encountered while loading',
        name: 'GoogleDriveSyncService',
        error: error,
        stackTrace: stackTrace,
      );
      throw SyncDocumentCorruptedException(
        operation: 'load',
        message: 'Unable to decode sync document',
        backupPath: backupPath,
      );
    }
  }

  _DriveSyncDocument _migrateMetadata(_DriveSyncDocument doc) {
    // v0 → v1: no changes needed yet, just stamp version
    if (doc.metadataVersion >= 1) return doc;
    return _DriveSyncDocument(
      metadataVersion: 1,
      updatedAt: doc.updatedAt,
      records: doc.records,
      deletions: doc.deletions,
      quarantine: doc.quarantine,
    );
  }

  Future<void> _saveDocument(_DriveSyncDocument doc) async {
    final api = _driveApi!;
    await _findOrCreateSyncFileId();
    late final List<int> bytes;
    try {
      bytes = utf8.encode(jsonEncode(doc.toJson()));
    } catch (error, stackTrace) {
      final raw = utf8.encode(doc.toJson().toString());
      final backupPath = await _backupRawData(
        operation: 'save_document_corrupt',
        data: raw,
      );
      developer.log(
        'Unable to encode sync document for save',
        name: 'GoogleDriveSyncService',
        error: error,
        stackTrace: stackTrace,
      );
      throw SyncDocumentCorruptedException(
        operation: 'save',
        message: 'Unable to encode sync document',
        backupPath: backupPath,
      );
    }
    final stream = Stream<List<int>>.value(bytes);
    final media = drive.Media(stream, bytes.length);

    if (_syncFileId == null) {
      final metadata = drive.File()
        ..name = _syncFileName
        ..parents = ['appDataFolder'];
      final created = await api.files.create(metadata, uploadMedia: media);
      _syncFileId = created.id;
      return;
    }

    await api.files.update(drive.File(), _syncFileId!, uploadMedia: media);
  }

  Future<String?> _backupRawData({
    required String operation,
    required List<int> data,
  }) async {
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

  Future<void> _findOrCreateSyncFileId() async {
    if (_syncFileId != null) return;
    final api = _driveApi!;
    final files = await api.files.list(
      q: "name='$_syncFileName' and trashed=false and 'appDataFolder' in parents",
      spaces: 'appDataFolder',
      $fields: 'files(id,name)',
      pageSize: 1,
    );
    final found = files.files;
    if (found != null && found.isNotEmpty) {
      _syncFileId = found.first.id;
      return;
    }

    final created = await api.files.create(
      drive.File()
        ..name = _syncFileName
        ..parents = ['appDataFolder'],
    );
    _syncFileId = created.id;
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
