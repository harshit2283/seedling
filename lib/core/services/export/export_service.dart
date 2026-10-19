import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart'
    show SecretBoxAuthenticationError;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/entry.dart';
import '../error_reporter.dart';
import '../media/file_storage_service.dart';
import 'backup_codec.dart';
import 'export_cleanup.dart';
import 'export_models.dart';
import 'markdown_export.dart';

export 'export_models.dart';

/// Presents the platform share sheet for [file]. Injectable for tests.
typedef ShareFileFn =
    Future<void> Function(XFile file, {String? subject, Rect? origin});

Future<void> _defaultShareFile(
  XFile file, {
  String? subject,
  Rect? origin,
}) async {
  await Share.shareXFiles(
    [file],
    subject: subject,
    sharePositionOrigin: origin,
  );
}

/// Service for exporting user data
class ExportService {
  final ErrorReporter _errorReporter;
  final ShareFileFn _shareFile;
  final int _kdfIterations;

  ExportService({
    ErrorReporter? errorReporter,
    ShareFileFn? shareFile,
    @visibleForTesting int kdfIterations = BackupCodec.pbkdf2Iterations,
  }) : _errorReporter = errorReporter ?? const ErrorReporter(),
       _shareFile = shareFile ?? _defaultShareFile,
       _kdfIterations = kdfIterations;

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
    } catch (e, st) {
      _errorReporter.report(
        e,
        stack: st,
        context: 'ExportService.exportToJson',
      );
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
    } catch (e, st) {
      _errorReporter.report(e, stack: st, context: 'ExportService.exportToZip');
      return const ExportResult.failure('Could not create backup archive');
    }
  }

  /// Export every memory as an open, human-readable Markdown archive: one
  /// `.md` file per memory (YAML front matter + body) under
  /// `memories/<year>/<month>/`, still-sealed capsules under `capsules/`,
  /// media under `media/`, and an `index.md`. Opens in any Markdown editor
  /// or as an Obsidian vault, and imports back into Seedling.
  ///
  /// Media paths are resolved on this isolate (path_provider needs the
  /// platform channel); building and zipping run in a background isolate,
  /// streaming media from disk instead of loading it all into memory.
  Future<ExportResult> exportToMarkdown(
    List<Entry> entries,
    String mediaBasePath, {
    DateTime? now,
  }) async {
    try {
      final exportedAt = now ?? DateTime.now();
      final baseDir = mediaBasePath.trim().isEmpty
          ? null
          : Directory(mediaBasePath);
      final items = <MarkdownExportItem>[];
      for (final entry in entries) {
        String? mediaPath;
        if (entry.hasMedia && baseDir != null) {
          mediaPath = await FileStorageService.resolveMediaPath(
            entry.mediaPath,
            baseDir: baseDir,
          );
          if (mediaPath != null && !await _isInside(mediaPath, baseDir.path)) {
            mediaPath = null;
          }
        }
        items.add(
          MarkdownExportItem.fromEntry(
            entry,
            resolvedMediaPath: mediaPath,
            now: exportedAt,
          ),
        );
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = exportedAt.toIso8601String().replaceAll(':', '-');
      final filePath = '${tempDir.path}/seedling_markdown_$timestamp.zip';
      await _runMarkdownExport(items, exportedAt, filePath);
      return ExportResult.success(filePath);
    } catch (e, st) {
      _errorReporter.report(
        e,
        stack: st,
        context: 'ExportService.exportToMarkdown',
      );
      return const ExportResult.failure('Could not create Markdown export');
    }
  }

  static Future<bool> _isInside(String path, String base) async {
    try {
      final resolvedBase = await Directory(base).resolveSymbolicLinks();
      final resolved = await File(path).resolveSymbolicLinks();
      return resolved.startsWith('$resolvedBase${Platform.pathSeparator}');
    } on FileSystemException {
      return false;
    }
  }

  static Future<void> _runMarkdownExport(
    List<MarkdownExportItem> items,
    DateTime exportedAt,
    String outputPath,
  ) {
    return Isolate.run(() {
      final plan = buildMarkdownExport(items, exportedAt: exportedAt);
      writeMarkdownExportZip(plan, outputPath);
    });
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
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filePath = '${tempDir.path}/seedling_backup_$timestamp.seedling';
      // KDF + AES-GCM + base64 take seconds; keep them off the UI isolate.
      await _runEncrypt(zipBytes, passphrase, _kdfIterations, filePath);
      return ExportResult.success(filePath);
    } catch (e, st) {
      _errorReporter.report(
        e,
        stack: st,
        context: 'ExportService.exportEncryptedBackup',
      );
      return const ExportResult.failure('Could not create encrypted backup');
    }
  }

  Future<List<int>?> _buildZipBytes(
    List<Entry> entries,
    String mediaBasePath, {
    void Function(double progress)? onProgress,
  }) async {
    final normalizedMediaBasePath = mediaBasePath.trim();
    String? resolvedMediaBasePath;
    if (normalizedMediaBasePath.isNotEmpty) {
      final baseDir = Directory(normalizedMediaBasePath);
      if (await baseDir.exists()) {
        resolvedMediaBasePath = await baseDir.resolveSymbolicLinks();
      }
    }

    onProgress?.call(0.05);

    // Collect media bytes on the main isolate (dart:io File is platform-bound).
    final mediaPayloads = <_MediaPayload>[];
    final hasValidMediaBasePath =
        resolvedMediaBasePath != null &&
        resolvedMediaBasePath.trim().isNotEmpty;
    final totalMedia = entries
        .where((e) => e.mediaPath != null && e.mediaPath!.isNotEmpty)
        .length;
    var processedMedia = 0;
    for (final entry in entries) {
      final mediaPath = entry.mediaPath;
      if (mediaPath == null || mediaPath.isEmpty) continue;
      if (!hasValidMediaBasePath) continue;
      // Stored paths go stale when iOS moves the app container; re-anchor
      // them on the current media directory instead of silently skipping.
      final resolvedPath = await FileStorageService.resolveMediaPath(
        mediaPath,
        baseDir: Directory(resolvedMediaBasePath),
      );
      if (resolvedPath == null) continue;
      final mediaFile = File(resolvedPath);
      final resolvedFilePath = await mediaFile.resolveSymbolicLinks();
      if (!resolvedFilePath.startsWith(
        '$resolvedMediaBasePath${Platform.pathSeparator}',
      )) {
        continue;
      }
      final bytes = await mediaFile.readAsBytes();
      mediaPayloads.add(
        _MediaPayload(
          archivePath:
              'media/${_getMediaFolder(entry.type)}/${_fileNameFromPath(mediaPath)}',
          bytes: bytes,
        ),
      );
      processedMedia++;
      if (totalMedia > 0) {
        onProgress?.call(0.05 + (processedMedia / totalMedia) * 0.5);
      }
    }

    onProgress?.call(0.6);

    final entryPayloads = entries
        .map(
          (e) => _EntryArchivePayload(
            syncUUID: e.syncUUID,
            id: e.id,
            json: _entryToJson(e),
            title: (e.title ?? '').isNotEmpty ? e.title! : e.typeName,
            displayContent: e.displayContent,
            createdAtIso: e.createdAt.toIso8601String(),
            mediaPath: e.mediaPath,
            archiveMediaPath: e.mediaPath != null
                ? 'media/${_getMediaFolder(e.type)}/${_fileNameFromPath(e.mediaPath!)}'
                : null,
          ),
        )
        .toList(growable: false);

    final payload = _ZipBuildPayload(
      entries: entryPayloads,
      media: mediaPayloads,
      exportedAtIso: DateTime.now().toIso8601String(),
      entryCount: entries.length,
    );

    final result = await compute(_buildAndEncodeZip, payload);
    onProgress?.call(1.0);
    return result;
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
    } catch (e, st) {
      _errorReporter.report(
        e,
        stack: st,
        context: 'ExportService.importEncryptedBackup',
      );
      return const ImportResult.failure('Import failed');
    }
  }

  /// Load and decrypt an encrypted backup, returning full payload data.
  ///
  /// File read, KDF, decryption and ZIP decoding all run in a background
  /// isolate so the UI keeps animating while a large backup unlocks.
  Future<LoadedEncryptedBackup> loadEncryptedBackup(
    String filePath, {
    required String passphrase,
  }) {
    return _runLoadEncrypted(filePath, passphrase);
  }

  /// Load a plain ZIP archive (with HTML + JSON) and return parsed payload.
  Future<LoadedEncryptedBackup> loadZipArchive(String filePath) {
    return _runLoadZip(filePath);
  }

  // Static so the isolate closures never capture `this`.
  static Future<void> _runEncrypt(
    List<int> zipBytes,
    String passphrase,
    int iterations,
    String outputPath,
  ) {
    return Isolate.run(
      () => writeEncryptedBackupFile(
        zipBytes: zipBytes,
        passphrase: passphrase,
        iterations: iterations,
        outputPath: outputPath,
      ),
    );
  }

  static Future<LoadedEncryptedBackup> _runLoadEncrypted(
    String filePath,
    String passphrase,
  ) {
    return Isolate.run(() => readEncryptedBackupFile(filePath, passphrase));
  }

  static Future<LoadedEncryptedBackup> _runLoadZip(String filePath) {
    return Isolate.run(() => readZipArchiveFile(filePath));
  }

  /// Share an exported file
  Future<void> shareFile(
    String filePath, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    await _shareFile(
      XFile(filePath),
      subject: subject ?? 'Seedling Export',
      origin: _normalizeSharePositionOrigin(sharePositionOrigin),
    );
  }

  /// Shares an exported file, then deletes it whether or not sharing
  /// succeeded. Exports are plaintext copies of the user's memories in the
  /// temp/cache directory; they must not outlive the share sheet.
  ///
  /// Safe on both platforms: iOS completes the share before this returns, and
  /// share_plus on Android hands the receiver its own staged copy (which the
  /// startup sweep removes later).
  Future<void> shareAndDelete(
    String filePath, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    try {
      await shareFile(
        filePath,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      await deleteExportArtifact(filePath);
    }
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
      'connectionIds': entry.connectionIds,
      'manualLinkIds': entry.manualLinkIds,
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

/// Payload sent to the ZIP-build isolate. Holds pre-resolved entry metadata,
/// JSON-ready maps, and media bytes (loaded on the main isolate).
class _ZipBuildPayload {
  final List<_EntryArchivePayload> entries;
  final List<_MediaPayload> media;
  final String exportedAtIso;
  final int entryCount;

  const _ZipBuildPayload({
    required this.entries,
    required this.media,
    required this.exportedAtIso,
    required this.entryCount,
  });
}

class _EntryArchivePayload {
  final String? syncUUID;
  final int id;
  final Map<String, dynamic> json;
  final String title;
  final String displayContent;
  final String createdAtIso;
  final String? mediaPath;
  final String? archiveMediaPath;

  const _EntryArchivePayload({
    required this.syncUUID,
    required this.id,
    required this.json,
    required this.title,
    required this.displayContent,
    required this.createdAtIso,
    required this.mediaPath,
    required this.archiveMediaPath,
  });
}

class _MediaPayload {
  final String archivePath;
  final List<int> bytes;

  const _MediaPayload({required this.archivePath, required this.bytes});
}

String _isolateHtmlEscape(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _isolateBuildEntryHtml(_EntryArchivePayload entry) {
  final title = _isolateHtmlEscape(entry.title);
  final body = _isolateHtmlEscape(entry.displayContent);
  final created = _isolateHtmlEscape(entry.createdAtIso);
  final media = entry.mediaPath;
  final mediaHtml = (media == null || media.isEmpty)
      ? ''
      : '<p><strong>Media:</strong> ${_isolateHtmlEscape(entry.archiveMediaPath ?? '')}</p>';

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

String _isolateBuildIndexHtml(_ZipBuildPayload payload) {
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
  buffer.writeln('<p>Total entries: ${payload.entryCount}</p>');
  buffer.writeln('<ul>');
  for (final entry in payload.entries) {
    final fileName = 'entries/entry-${entry.syncUUID ?? entry.id}.html';
    final title = _isolateHtmlEscape(entry.title);
    final date = _isolateHtmlEscape(entry.createdAtIso);
    buffer.writeln(
      '<li><a href="$fileName">$title</a> <small>($date)</small></li>',
    );
  }
  buffer.writeln('</ul>');
  buffer.writeln('</body></html>');
  return buffer.toString();
}

/// Builds the entry JSON, manifest, HTML pages, and ZIP-encodes the archive.
/// Runs entirely in an isolate via [compute] to keep the main thread responsive.
List<int>? _buildAndEncodeZip(_ZipBuildPayload payload) {
  final archive = Archive();

  final entriesJson = <String, dynamic>{
    'version': '1.0',
    'exportedAt': payload.exportedAtIso,
    'entryCount': payload.entryCount,
    'entries': payload.entries.map((e) => e.json).toList(),
  };
  final entriesBytes = utf8.encode(
    const JsonEncoder.withIndent('  ').convert(entriesJson),
  );
  archive.add(ArchiveFile('entries.json', entriesBytes.length, entriesBytes));

  final manifestBytes = utf8.encode(
    const JsonEncoder.withIndent('  ').convert({
      'format': 'seedling-archive',
      'version': 1,
      'exportedAt': payload.exportedAtIso,
      'entryCount': payload.entryCount,
    }),
  );
  archive.add(
    ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
  );

  final indexBytes = utf8.encode(_isolateBuildIndexHtml(payload));
  archive.add(ArchiveFile('index.html', indexBytes.length, indexBytes));

  for (final entry in payload.entries) {
    final pagePath = 'entries/entry-${entry.syncUUID ?? entry.id}.html';
    final pageBytes = utf8.encode(_isolateBuildEntryHtml(entry));
    archive.add(ArchiveFile(pagePath, pageBytes.length, pageBytes));
  }

  for (final media in payload.media) {
    archive.add(
      ArchiveFile(media.archivePath, media.bytes.length, media.bytes),
    );
  }

  return ZipEncoder().encode(archive);
}
