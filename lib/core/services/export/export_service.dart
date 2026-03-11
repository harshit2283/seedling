import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/entry.dart';

/// Result of an export operation
class ExportResult {
  final bool success;
  final String? filePath;
  final String? error;

  const ExportResult.success(this.filePath) : success = true, error = null;
  const ExportResult.failure(this.error) : success = false, filePath = null;
}

/// Result of an encrypted import operation
class ImportResult {
  final bool success;
  final String? error;
  final int importedEntries;
  final int importedMediaFiles;
  final int skippedDuplicates;
  final List<String> warnings;

  const ImportResult.success({
    required this.importedEntries,
    required this.importedMediaFiles,
    this.skippedDuplicates = 0,
    this.warnings = const [],
  }) : success = true,
       error = null;

  const ImportResult.failure(this.error)
    : success = false,
      importedEntries = 0,
      importedMediaFiles = 0,
      skippedDuplicates = 0,
      warnings = const [];
}

/// Preview metadata for an encrypted backup.
class EncryptedBackupPreview {
  final int entryCount;
  final int mediaCount;
  final int version;
  final DateTime? exportedAt;
  final bool integrityVerified;
  final String? kdf;
  final int? iterations;

  const EncryptedBackupPreview({
    required this.entryCount,
    required this.mediaCount,
    required this.version,
    this.exportedAt,
    this.integrityVerified = false,
    this.kdf,
    this.iterations,
  });
}

/// Fully loaded encrypted backup payload.
class LoadedEncryptedBackup {
  final EncryptedBackupPreview preview;
  final List<Map<String, dynamic>> entries;
  final Map<String, List<int>> mediaFiles;
  final List<String> warnings;

  const LoadedEncryptedBackup({
    required this.preview,
    required this.entries,
    required this.mediaFiles,
    this.warnings = const [],
  });
}

/// Service for exporting user data
class ExportService {
  static const _encryptedBackupVersion = 1;
  static const _pbkdf2Iterations = 120000;
  static const _payloadSignatureAlgorithm = 'hmac-sha256';
  static const int _maxEncryptedBackupBytes = 300 * 1024 * 1024;
  static const int _maxArchiveEntries = 12000;
  static const int _maxArchiveBytes = 800 * 1024 * 1024;

  /// Export entries as JSON file
  Future<ExportResult> exportToJson(List<Entry> entries) async {
    try {
      final jsonData = _entriesToJson(entries);
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filePath = '${tempDir.path}/seedling_export_$timestamp.json';

      final file = File(filePath);
      await file.writeAsString(jsonString);

      return ExportResult.success(filePath);
    } catch (e) {
      debugPrint('ExportService.exportToJson failed: $e');
      return const ExportResult.failure('Could not export memories to JSON');
    }
  }

  /// Export entries with media as ZIP file
  Future<ExportResult> exportToZip(
    List<Entry> entries,
    String mediaBasePath,
  ) async {
    try {
      final zipData = await _buildZipBytes(entries, mediaBasePath);

      if (zipData == null) {
        return const ExportResult.failure('Failed to encode ZIP file');
      }

      // Write to temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filePath = '${tempDir.path}/seedling_backup_$timestamp.zip';

      final file = File(filePath);
      await file.writeAsBytes(zipData);

      return ExportResult.success(filePath);
    } catch (e) {
      debugPrint('ExportService.exportToZip failed: $e');
      return const ExportResult.failure('Could not create backup archive');
    }
  }

  /// Export entries and media as encrypted backup payload.
  Future<ExportResult> exportEncryptedBackup(
    List<Entry> entries,
    String mediaBasePath, {
    required String passphrase,
  }) async {
    if (passphrase.trim().length < 8) {
      return const ExportResult.failure(
        'Passphrase must be at least 8 characters',
      );
    }

    try {
      final zipBytes = await _buildZipBytes(entries, mediaBasePath);
      if (zipBytes == null) {
        return const ExportResult.failure('Failed to encode ZIP file');
      }
      final salt = _randomBytes(16);
      final nonce = _randomBytes(12);
      final key = await _deriveKey(passphrase, salt);
      final algorithm = AesGcm.with256bits();
      final secretBox = await algorithm.encrypt(
        zipBytes,
        secretKey: key,
        nonce: nonce,
      );

      final payload = <String, dynamic>{
        'version': _encryptedBackupVersion,
        'kdf': 'pbkdf2-sha256',
        'iterations': _pbkdf2Iterations,
        'salt': base64Encode(salt),
        'nonce': base64Encode(secretBox.nonce),
        'mac': base64Encode(secretBox.mac.bytes),
        'ciphertext': base64Encode(secretBox.cipherText),
        'sigAlg': _payloadSignatureAlgorithm,
      };
      payload['signature'] = await _computePayloadSignature(payload, key);

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filePath = '${tempDir.path}/seedling_backup_$timestamp.seedling';
      await File(filePath).writeAsString(jsonEncode(payload));
      return ExportResult.success(filePath);
    } catch (e) {
      debugPrint('ExportService.exportEncryptedBackup failed: $e');
      return const ExportResult.failure('Could not create encrypted backup');
    }
  }

  Future<List<int>?> _buildZipBytes(
    List<Entry> entries,
    String mediaBasePath,
  ) async {
    final archive = Archive();
    final normalizedMediaBasePath = mediaBasePath.trim();
    String? resolvedMediaBasePath;
    if (normalizedMediaBasePath.isNotEmpty) {
      final baseDir = Directory(normalizedMediaBasePath);
      if (await baseDir.exists()) {
        resolvedMediaBasePath = await baseDir.resolveSymbolicLinks();
      }
    }

    final jsonData = _entriesToJson(entries);
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
    final jsonBytes = utf8.encode(jsonString);
    archive.add(ArchiveFile('entries.json', jsonBytes.length, jsonBytes));

    final manifest = <String, dynamic>{
      'format': 'seedling-archive',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'entryCount': entries.length,
    };
    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    archive.add(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );
    final indexHtml = _buildArchiveIndexHtml(entries);
    final indexBytes = utf8.encode(indexHtml);
    archive.add(ArchiveFile('index.html', indexBytes.length, indexBytes));

    for (final entry in entries) {
      final pagePath = 'entries/entry-${entry.syncUUID ?? entry.id}.html';
      final page = _buildEntryHtml(entry);
      final pageBytes = utf8.encode(page);
      archive.add(ArchiveFile(pagePath, pageBytes.length, pageBytes));
    }

    for (final entry in entries) {
      if (entry.mediaPath != null && entry.mediaPath!.isNotEmpty) {
        final hasValidMediaBasePath =
            resolvedMediaBasePath?.trim().isNotEmpty ?? false;
        if (!hasValidMediaBasePath) {
          continue;
        }
        final mediaFile = File(entry.mediaPath!);
        if (await mediaFile.exists()) {
          final resolvedFilePath = await mediaFile.resolveSymbolicLinks();
          if (!resolvedFilePath.startsWith(
            '$resolvedMediaBasePath${Platform.pathSeparator}',
          )) {
            continue;
          }
          final bytes = await mediaFile.readAsBytes();
          final fileName = _fileNameFromPath(entry.mediaPath!);
          final mediaType = _getMediaFolder(entry.type);
          archive.add(
            ArchiveFile('media/$mediaType/$fileName', bytes.length, bytes),
          );
        }
      }
    }

    return compute(_encodeZip, archive);
  }

  /// Decrypt encrypted backup and return summary info.
  Future<ImportResult> importEncryptedBackup(
    String filePath, {
    required String passphrase,
  }) async {
    try {
      final loaded = await loadEncryptedBackup(
        filePath,
        passphrase: passphrase,
      );
      return ImportResult.success(
        importedEntries: loaded.entries.length,
        importedMediaFiles: loaded.mediaFiles.length,
      );
    } on SecretBoxAuthenticationError {
      return const ImportResult.failure('Invalid passphrase');
    } catch (e) {
      debugPrint('ExportService.importEncryptedBackup failed: $e');
      return const ImportResult.failure('Import failed');
    }
  }

  /// Load and decrypt an encrypted backup, returning full payload data.
  Future<LoadedEncryptedBackup> loadEncryptedBackup(
    String filePath, {
    required String passphrase,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FormatException('Backup file not found');
    }

    final fileSize = await file.length();
    if (fileSize > _maxEncryptedBackupBytes) {
      throw const FormatException('Backup file is too large');
    }

    final payloadString = await file.readAsString();
    final payload = jsonDecode(payloadString) as Map<String, dynamic>;
    final decryptResult = await _decryptPayloadBytes(payload, passphrase);
    final decryptedZip = decryptResult.bytes;
    final archive = ZipDecoder().decodeBytes(decryptedZip, verify: true);
    _validateArchive(archive);

    final entriesFile = archive.files.firstWhere(
      (f) => f.name == 'entries.json',
      orElse: () => throw const FormatException('entries.json missing'),
    );

    final entriesPayload = utf8.decode(entriesFile.content as List<int>);
    final parsed = jsonDecode(entriesPayload) as Map<String, dynamic>;
    final rawEntries = (parsed['entries'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final exportedAtRaw = parsed['exportedAt'] as String?;
    final warnings = <String>[];
    if (!decryptResult.integrityVerified) {
      warnings.add('integrity_not_verified');
    }
    final preview = EncryptedBackupPreview(
      entryCount: rawEntries.length,
      mediaCount: archive.files
          .where((f) => f.name.startsWith('media/'))
          .length,
      version: (payload['version'] as int?) ?? 0,
      exportedAt: exportedAtRaw == null
          ? null
          : DateTime.tryParse(exportedAtRaw),
      integrityVerified: decryptResult.integrityVerified,
      kdf: payload['kdf'] as String?,
      iterations: payload['iterations'] as int?,
    );

    final mediaFiles = <String, List<int>>{};
    for (final file in archive.files.where(
      (f) => f.name.startsWith('media/'),
    )) {
      mediaFiles[file.name] = file.content as List<int>;
    }

    return LoadedEncryptedBackup(
      preview: preview,
      entries: rawEntries,
      mediaFiles: mediaFiles,
      warnings: warnings,
    );
  }

  /// Load a plain ZIP archive (with HTML + JSON) and return parsed payload.
  Future<LoadedEncryptedBackup> loadZipArchive(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FormatException('Archive file not found');
    }

    final zipBytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
    _validateArchive(archive);

    final entriesFile = archive.files.firstWhere(
      (f) => f.name == 'entries.json',
      orElse: () => throw const FormatException('entries.json missing'),
    );

    final entriesPayload = utf8.decode(entriesFile.content as List<int>);
    final parsed = jsonDecode(entriesPayload) as Map<String, dynamic>;
    final rawEntries = (parsed['entries'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    Map<String, dynamic> manifest = const {};
    final manifestFiles = archive.files.where((f) => f.name == 'manifest.json');
    if (manifestFiles.isNotEmpty) {
      try {
        manifest =
            jsonDecode(utf8.decode(manifestFiles.first.content as List<int>))
                as Map<String, dynamic>;
      } catch (e) {
        debugPrint('ExportService.loadZipArchive manifest parse failed: $e');
        manifest = const {};
      }
    }

    final mediaFiles = <String, List<int>>{};
    for (final file in archive.files.where(
      (f) => f.name.startsWith('media/'),
    )) {
      mediaFiles[file.name] = file.content as List<int>;
    }

    final warnings = <String>[];
    if (manifest['format'] != null &&
        manifest['format'] != 'seedling-archive') {
      warnings.add('unknown_archive_format');
    }

    final preview = EncryptedBackupPreview(
      entryCount: rawEntries.length,
      mediaCount: mediaFiles.length,
      version: (manifest['version'] as int?) ?? 1,
      exportedAt: DateTime.tryParse(
        manifest['exportedAt'] as String? ??
            (parsed['exportedAt'] as String? ?? ''),
      ),
      integrityVerified: false,
      kdf: null,
      iterations: null,
    );

    return LoadedEncryptedBackup(
      preview: preview,
      entries: rawEntries,
      mediaFiles: mediaFiles,
      warnings: warnings,
    );
  }

  /// Share an exported file
  Future<void> shareFile(
    String filePath, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    final xFile = XFile(filePath);
    final safeSharePositionOrigin = _normalizeSharePositionOrigin(
      sharePositionOrigin,
    );
    await Share.shareXFiles(
      [xFile],
      subject: subject ?? 'Seedling Export',
      sharePositionOrigin: safeSharePositionOrigin,
    );
  }

  /// Convert entries to JSON-serializable map
  Map<String, dynamic> _entriesToJson(List<Entry> entries) {
    return {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'entryCount': entries.length,
      'entries': entries.map((e) => _entryToJson(e)).toList(),
    };
  }

  /// Convert a single entry to JSON
  Map<String, dynamic> _entryToJson(Entry entry) {
    return {
      'id': entry.id,
      'syncUUID': entry.syncUUID,
      'type': entry.type.name,
      'createdAt': entry.createdAt.toIso8601String(),
      'modifiedAt': entry.modifiedAt?.toIso8601String(),
      'text': entry.text,
      'title': entry.title,
      'context': entry.context,
      'mood': entry.mood,
      'tags': entry.tags,
      'detectedTheme': entry.detectedTheme,
      'sentimentScore': entry.sentimentScore,
      'lastAnalyzedAt': entry.lastAnalyzedAt?.toIso8601String(),
      'mediaPath': entry.mediaPath != null
          ? 'media/${_getMediaFolder(entry.type)}/${_fileNameFromPath(entry.mediaPath!)}'
          : null,
      'isReleased': entry.isReleased,
      'capsuleUnlockDate': entry.capsuleUnlockDate?.toIso8601String(),
      'transcription': entry.transcription,
    };
  }

  String _fileNameFromPath(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  /// Get media folder name for entry type
  String _getMediaFolder(EntryType type) {
    switch (type) {
      case EntryType.photo:
        return 'photos';
      case EntryType.voice:
        return 'voices';
      case EntryType.object:
        return 'objects';
      default:
        return 'other';
    }
  }

  String _buildArchiveIndexHtml(List<Entry> entries) {
    final buffer = StringBuffer();
    buffer.writeln('<!doctype html>');
    buffer.writeln('<html lang="en"><head>');
    buffer.writeln('<meta charset="utf-8">');
    buffer.writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
    );
    buffer.writeln('<title>Seedling Archive</title>');
    buffer.writeln('<style>');
    buffer.writeln(
      'body{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;line-height:1.5;max-width:900px;margin:2rem auto;padding:0 1rem;color:#222;background:#f8f7f3;}',
    );
    buffer.writeln(
      'a{color:#1f4b31;text-decoration:none;}a:hover{text-decoration:underline;}',
    );
    buffer.writeln('li{margin:.45rem 0;}small{color:#666;}');
    buffer.writeln('</style></head><body>');
    buffer.writeln('<h1>Seedling Memory Archive</h1>');
    buffer.writeln('<p>Total entries: ${entries.length}</p>');
    buffer.writeln('<ul>');
    for (final entry in entries) {
      final fileName = 'entries/entry-${entry.syncUUID ?? entry.id}.html';
      final title = _htmlEscape(
        (entry.title ?? '').isNotEmpty ? entry.title! : entry.typeName,
      );
      final date = _htmlEscape(entry.createdAt.toIso8601String());
      buffer.writeln(
        '<li><a href="$fileName">$title</a> <small>($date)</small></li>',
      );
    }
    buffer.writeln('</ul>');
    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  String _buildEntryHtml(Entry entry) {
    final title = _htmlEscape(
      (entry.title ?? '').isNotEmpty ? entry.title! : entry.typeName,
    );
    final body = _htmlEscape(entry.displayContent);
    final created = _htmlEscape(entry.createdAt.toIso8601String());
    final media = entry.mediaPath;
    final mediaHtml = media == null || media.isEmpty
        ? ''
        : '<p><strong>Media:</strong> ${_htmlEscape(_entryToJson(entry)['mediaPath'] as String? ?? '')}</p>';

    return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$title</title>
  <style>
    body{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;line-height:1.6;max-width:760px;margin:2rem auto;padding:0 1rem;color:#222;background:#f8f7f3;}
    main{background:#fff;padding:1.2rem;border-radius:12px;border:1px solid #e8e5dd;}
    h1{margin-top:0;}
    p{white-space:pre-wrap;}
  </style>
</head>
<body>
  <p><a href="../index.html">Back to index</a></p>
  <main>
    <h1>$title</h1>
    <p><strong>Created:</strong> $created</p>
    $mediaHtml
    <p>$body</p>
  </main>
</body>
</html>
''';
  }

  String _htmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt, {
    int iterations = _pbkdf2Iterations,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  Future<_DecryptResult> _decryptPayloadBytes(
    Map<String, dynamic> payload,
    String passphrase,
  ) async {
    final version = payload['version'] as int?;
    if (version != _encryptedBackupVersion) {
      throw const FormatException('Unsupported backup version');
    }

    final iterations = payload['iterations'] as int?;
    if (iterations == null || iterations < 100000) {
      throw const FormatException('Invalid backup metadata');
    }

    final salt = base64Decode(payload['salt'] as String);
    final nonce = base64Decode(payload['nonce'] as String);
    final macBytes = base64Decode(payload['mac'] as String);
    final ciphertext = base64Decode(payload['ciphertext'] as String);

    if (salt.length != 16 || nonce.length != 12 || macBytes.length != 16) {
      throw const FormatException('Invalid backup encryption metadata');
    }

    final key = await _deriveKey(passphrase, salt, iterations: iterations);
    final algorithm = AesGcm.with256bits();
    final bytes = await algorithm.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(macBytes)),
      secretKey: key,
    );
    final integrityVerified = await _verifyPayloadSignature(payload, key);
    return _DecryptResult(bytes: bytes, integrityVerified: integrityVerified);
  }

  void _validateArchive(Archive archive) {
    if (archive.files.length > _maxArchiveEntries) {
      throw const FormatException('Backup archive contains too many files');
    }

    var totalBytes = 0;
    for (final file in archive.files) {
      final name = file.name;
      if (_isUnsafeArchivePath(name)) {
        throw const FormatException('Unsafe backup path detected');
      }

      totalBytes += file.size;
      if (totalBytes > _maxArchiveBytes) {
        throw const FormatException('Backup archive is too large');
      }
    }
  }

  bool _isUnsafeArchivePath(String path) {
    if (path.contains('..')) return true;
    if (path.startsWith('/') || path.startsWith('\\')) return true;
    if (path.contains(':')) return true;
    return false;
  }

  String _canonicalPayloadString(Map<String, dynamic> payload) {
    return [
      payload['version']?.toString() ?? '',
      payload['kdf']?.toString() ?? '',
      payload['iterations']?.toString() ?? '',
      payload['salt']?.toString() ?? '',
      payload['nonce']?.toString() ?? '',
      payload['mac']?.toString() ?? '',
      payload['ciphertext']?.toString() ?? '',
      payload['sigAlg']?.toString() ?? '',
    ].join('|');
  }

  Future<String> _computePayloadSignature(
    Map<String, dynamic> payload,
    SecretKey key,
  ) async {
    final canonical = _canonicalPayloadString(payload);
    final mac = await Hmac.sha256().calculateMac(
      utf8.encode(canonical),
      secretKey: key,
    );
    return base64Encode(mac.bytes);
  }

  Future<bool> _verifyPayloadSignature(
    Map<String, dynamic> payload,
    SecretKey key,
  ) async {
    final signature = payload['signature'] as String?;
    final sigAlg = payload['sigAlg'] as String?;
    if (signature == null || signature.isEmpty) {
      // Backward-compatible with older backups before signatures were added.
      return false;
    }
    if (sigAlg != _payloadSignatureAlgorithm) {
      throw const FormatException('Unsupported backup integrity algorithm');
    }
    final expected = await _computePayloadSignature(payload, key);
    if (expected != signature) {
      throw const FormatException('Backup integrity check failed');
    }
    return true;
  }

  Rect? _normalizeSharePositionOrigin(Rect? rect) {
    if (rect == null) return null;
    final isFinite =
        rect.left.isFinite &&
        rect.top.isFinite &&
        rect.width.isFinite &&
        rect.height.isFinite;
    if (!isFinite) return const Rect.fromLTWH(1, 1, 1, 1);
    if (rect.width <= 0 || rect.height <= 0) {
      return Rect.fromLTWH(rect.left, rect.top, 1, 1);
    }
    return rect;
  }
}

class _DecryptResult {
  final List<int> bytes;
  final bool integrityVerified;

  const _DecryptResult({required this.bytes, required this.integrityVerified});
}

/// Encodes the archive to ZIP format
///
/// This is a top-level function to allow it to be run in an isolate via [compute].
List<int>? _encodeZip(Archive archive) {
  final encoder = ZipEncoder();
  return encoder.encode(archive);
}
