import 'dart:io';

import 'package:flutter/foundation.dart';

/// Removes media files that no entry references.
///
/// A crash or kill mid-capture can leave a draft photo/voice memo behind.
/// This sweep reclaims that space without ever
/// touching a file an entry (including a soft-deleted one in the 30-day
/// trash) still points at.
///
/// Safety rails:
/// * references match by file name, so stale absolute paths (iOS container
///   moves) still protect their file;
/// * files younger than [minAge] are skipped: they may belong to a draft
///   being captured, an import or a sync download that has not saved its
///   entry yet;
/// * nothing is deleted when there are no entries at all, because an empty
///   or unreadable database is more likely a problem than a clean slate.
class MediaOrphanSweeper {
  const MediaOrphanSweeper({this.minAge = const Duration(hours: 24)});

  final Duration minAge;

  /// Returns the number of files deleted.
  Future<int> sweep({
    required Directory mediaDirectory,
    required Iterable<String?> referencedPaths,
    Iterable<String> protectedPaths = const [],
    DateTime? now,
  }) async {
    final referencedNames = <String>{};
    var referenceCount = 0;
    for (final path in referencedPaths) {
      referenceCount++;
      if (path == null || path.trim().isEmpty) continue;
      referencedNames.add(_fileName(path));
    }
    if (referenceCount == 0) return 0;
    // Files held by open drafts (see DraftMediaTracker.liveDraftPaths).
    referencedNames.addAll(protectedPaths.map(_fileName));
    if (!await mediaDirectory.exists()) return 0;

    final cutoff = (now ?? DateTime.now()).subtract(minAge);
    var deleted = 0;
    try {
      await for (final entity in mediaDirectory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final name = _fileName(entity.path);
        if (name.startsWith('.')) continue; // OS metadata, e.g. .DS_Store
        if (referencedNames.contains(name)) continue;
        try {
          if ((await entity.lastModified()).isAfter(cutoff)) continue;
          await entity.delete();
          deleted++;
        } catch (e) {
          debugPrint('MediaOrphanSweeper skipped "${entity.path}": $e');
        }
      }
    } catch (e) {
      debugPrint('MediaOrphanSweeper could not list media: $e');
    }
    return deleted;
  }

  static String _fileName(String path) =>
      path.replaceAll('\\', '/').split('/').last;
}
