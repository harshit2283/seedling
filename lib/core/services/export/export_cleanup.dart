import 'dart:io';

import 'package:flutter/foundation.dart';

/// File-name prefixes of the export artifacts Seedling writes to the
/// temporary directory. JSON and ZIP exports are plaintext copies of the
/// user's memories, so none of them may linger once the share sheet closes.
const List<String> exportArtifactPrefixes = [
  'seedling_export_',
  'seedling_backup_',
  'seedling_markdown_',
];

/// Sub-directories of the temporary directory that hold transient plaintext
/// copies: incoming shares (`shared_intake`, Android share intents) and
/// share_plus's own staging copy of outgoing files (`share_plus`, Android).
const List<String> transientShareDirectories = ['shared_intake', 'share_plus'];

/// Prefix of the staging directories imports extract media into.
const String importStagingPrefix = 'seedling_import_';

/// Deletes a single exported file. Never throws: cleanup must not turn a
/// successful share into a reported failure.
Future<void> deleteExportArtifact(String? path) async {
  if (path == null || path.isEmpty) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (e) {
    debugPrint('deleteExportArtifact failed for "$path": $e');
  }
}

/// Removes export artifacts and transient share files older than [maxAge]
/// from [tempDir]. Returns how many files were deleted.
///
/// Runs at startup to catch files left behind when the app was killed while
/// a share sheet was open (the `finally` that normally deletes them never
/// ran). Younger files are left alone: they may belong to a share that is
/// still in progress.
Future<int> sweepStaleExportArtifacts(
  Directory tempDir, {
  Duration maxAge = const Duration(hours: 1),
  DateTime? now,
}) async {
  final cutoff = (now ?? DateTime.now()).subtract(maxAge);
  var deleted = 0;

  Future<void> deleteIfStale(File file) async {
    try {
      final modified = await file.lastModified();
      if (modified.isBefore(cutoff)) {
        await file.delete();
        deleted++;
      }
    } catch (e) {
      debugPrint('sweepStaleExportArtifacts skipped "${file.path}": $e');
    }
  }

  if (!await tempDir.exists()) return 0;

  try {
    await for (final entity in tempDir.list(followLinks: false)) {
      final name = entity.path.replaceAll('\\', '/').split('/').last;
      if (entity is Directory && name.startsWith(importStagingPrefix)) {
        try {
          final modified = (await entity.stat()).modified;
          if (modified.isBefore(cutoff)) {
            await entity.delete(recursive: true);
            deleted++;
          }
        } catch (e) {
          debugPrint('sweepStaleExportArtifacts skipped "${entity.path}": $e');
        }
        continue;
      }
      if (entity is! File) continue;
      if (exportArtifactPrefixes.any(name.startsWith)) {
        await deleteIfStale(entity);
      }
    }
  } catch (e) {
    debugPrint('sweepStaleExportArtifacts could not list temp dir: $e');
  }

  for (final dirName in transientShareDirectories) {
    final dir = Directory('${tempDir.path}/$dirName');
    if (!await dir.exists()) continue;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) await deleteIfStale(entity);
      }
    } catch (e) {
      debugPrint('sweepStaleExportArtifacts could not list "${dir.path}": $e');
    }
  }

  return deleted;
}
