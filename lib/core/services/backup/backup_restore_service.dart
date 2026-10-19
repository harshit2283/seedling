import 'dart:io';

import '../../../data/datasources/local/objectbox_database.dart';
import '../../../data/models/entry.dart';
import '../export/export_service.dart';
import '../media/file_storage_service.dart';

/// How a backup is applied to the existing library.
enum BackupImportMode { merge, replace }

/// Applies a decrypted backup payload to the local database and media store.
///
/// Kept out of the settings UI so the riskiest data path (replace/merge on
/// restore) can be unit-tested.
class BackupRestoreService {
  BackupRestoreService({
    required ObjectBoxDatabase database,
    required FileStorageService fileStorage,
  }) : _database = database,
       _fileStorage = fileStorage;

  final ObjectBoxDatabase _database;
  final FileStorageService _fileStorage;

  Future<ImportResult> restore(
    LoadedEncryptedBackup loaded, {
    required BackupImportMode mode,
  }) async {
    final existingEntries = mode == BackupImportMode.merge
        ? _database.getAllEntries()
        : <Entry>[];
    final seenFingerprints = existingEntries.map(entryFingerprint).toSet();

    if (mode == BackupImportMode.replace) {
      // Stage deletion: soft-delete existing entries instead of destroying
      // immediately. If import fails, entries remain recoverable.
      final existing = _database.getAllEntries();
      for (final entry in existing) {
        await _database.softDeleteEntry(entry.id);
      }
      seenFingerprints.clear();
    }

    var importedEntries = 0;
    var importedMediaFiles = 0;
    var skippedDuplicates = 0;
    final warnings = [...loaded.warnings];

    for (final entryMap in loaded.entries) {
      final fingerprint = mapFingerprint(entryMap);
      if (mode == BackupImportMode.merge &&
          seenFingerprints.contains(fingerprint)) {
        skippedDuplicates++;
        continue;
      }

      final restoredMediaPath = await _restoreMediaForEntry(
        entryMap: entryMap,
        mediaFiles: loaded.mediaFiles,
      );
      if (restoredMediaPath == null && entryMap['mediaPath'] != null) {
        warnings.add('missing_media');
      } else if (restoredMediaPath != null) {
        importedMediaFiles++;
      }

      final entry = entryFromBackupMap(
        entryMap,
        restoredMediaPath: restoredMediaPath,
      );
      await _database.saveEntry(entry);
      seenFingerprints.add(fingerprint);
      importedEntries++;
    }

    await _database.recountTrees();

    // Import succeeded — permanently remove the staged old entries. Each hard
    // delete removes that entry's own media file. The media directory must
    // NOT be wiped wholesale: it now also holds the files restored above.
    if (mode == BackupImportMode.replace) {
      final deleted = _database.getDeletedEntries();
      for (final entry in deleted) {
        await _database.deleteEntry(entry.id);
      }
    }

    return ImportResult.success(
      importedEntries: importedEntries,
      importedMediaFiles: importedMediaFiles,
      skippedDuplicates: skippedDuplicates,
      warnings: warnings,
    );
  }

  /// Builds an [Entry] from one exported entry map.
  static Entry entryFromBackupMap(
    Map<String, dynamic> entryMap, {
    String? restoredMediaPath,
  }) {
    final createdAt =
        DateTime.tryParse((entryMap['createdAt'] as String?) ?? '') ??
        DateTime.now();
    final type = parseEntryType(entryMap['type'] as String?);

    // Use factory constructors for proper type initialization
    final Entry entry;
    switch (type) {
      case EntryType.line:
        entry = Entry.line(
          text: entryMap['text'] as String?,
          context: entryMap['context'] as String?,
          mood: entryMap['mood'] as String?,
        );
      case EntryType.photo:
        entry = Entry.photo(
          mediaPath: restoredMediaPath ?? '',
          text: entryMap['text'] as String?,
        );
      case EntryType.voice:
        entry = Entry.voice(
          mediaPath: restoredMediaPath ?? '',
          text: entryMap['text'] as String?,
        );
      case EntryType.object:
        entry = Entry.object(
          title: entryMap['title'] as String? ?? '',
          mediaPath: restoredMediaPath,
          text: entryMap['text'] as String?,
        );
      case EntryType.fragment:
        entry = Entry.fragment(text: entryMap['text'] as String?);
      case EntryType.ritual:
        entry = Entry.ritual(
          title: entryMap['title'] as String? ?? '',
          text: entryMap['text'] as String?,
        );
      case EntryType.release:
        entry = Entry.release(text: entryMap['text'] as String?);
    }

    // Rehydrate fields not set by factories
    entry.createdAt = createdAt;
    if (restoredMediaPath != null) entry.mediaPath = restoredMediaPath;
    entry.title ??= entryMap['title'] as String?;
    entry.context ??= entryMap['context'] as String?;
    entry.mood ??= entryMap['mood'] as String?;
    entry.tags = entryMap['tags'] as String?;
    entry.isReleased = (entryMap['isReleased'] as bool?) ?? false;
    entry.detectedTheme = entryMap['detectedTheme'] as String?;
    entry.sentimentScore = (entryMap['sentimentScore'] as num?)?.toDouble();
    entry.lastAnalyzedAt = DateTime.tryParse(
      (entryMap['lastAnalyzedAt'] as String?) ?? '',
    );
    entry.capsuleUnlockDate = DateTime.tryParse(
      (entryMap['capsuleUnlockDate'] as String?) ?? '',
    );
    // Fields the exporter writes that were previously dropped on import.
    entry.transcription = entryMap['transcription'] as String?;
    entry.manualLinkIds = entryMap['manualLinkIds'] as String?;
    entry.connectionIds = entryMap['connectionIds'] as String?;
    final modifiedAt = DateTime.tryParse(
      (entryMap['modifiedAt'] as String?) ?? '',
    );
    if (modifiedAt != null) entry.modifiedAt = modifiedAt;
    // Rehydrate sync identity
    entry.syncUUID = entryMap['syncUUID'] as String?;
    entry.deviceId = entryMap['deviceId'] as String?;
    return entry;
  }

  Future<String?> _restoreMediaForEntry({
    required Map<String, dynamic> entryMap,
    required Map<String, List<int>> mediaFiles,
  }) async {
    final rawMediaPath = entryMap['mediaPath'] as String?;
    if (rawMediaPath == null || rawMediaPath.isEmpty) {
      return null;
    }
    final bytes = mediaFiles[rawMediaPath];
    if (bytes == null) {
      return null;
    }

    final type = parseEntryType(entryMap['type'] as String?);
    final extension = _extensionFromArchivePath(rawMediaPath);

    final String targetPath;
    switch (type) {
      case EntryType.object:
        targetPath = await _fileStorage.generateObjectPhotoPath(
          extension: extension,
        );
      case EntryType.voice:
        targetPath = await _fileStorage.generateVoicePath(extension: extension);
      default:
        targetPath = await _fileStorage.generatePhotoPath(extension: extension);
    }

    await File(targetPath).writeAsBytes(bytes, flush: true);
    return targetPath;
  }

  static EntryType parseEntryType(String? rawType) {
    if (rawType == null) return EntryType.line;
    return EntryType.values.firstWhere(
      (type) => type.name == rawType,
      orElse: () => EntryType.line,
    );
  }

  static String _extensionFromArchivePath(String path) {
    final fileName = path.split('/').last;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) {
      return 'bin';
    }
    final ext = fileName.substring(dot + 1);
    // Only short alphanumeric extensions; anything else is not trusted.
    return RegExp(r'^[A-Za-z0-9]{1,8}$').hasMatch(ext) ? ext : 'bin';
  }

  static String entryFingerprint(Entry entry) {
    final createdAt = entry.createdAt.toIso8601String();
    final type = entry.type.name;
    final text = (entry.text ?? '').trim().toLowerCase();
    final title = (entry.title ?? '').trim().toLowerCase();
    final capsule = entry.capsuleUnlockDate?.toIso8601String() ?? '';
    return '$createdAt|$type|$text|$title|$capsule';
  }

  static String mapFingerprint(Map<String, dynamic> map) {
    final createdAt = (map['createdAt'] as String?) ?? '';
    final type = (map['type'] as String?) ?? '';
    final text = ((map['text'] as String?) ?? '').trim().toLowerCase();
    final title = ((map['title'] as String?) ?? '').trim().toLowerCase();
    final capsule = (map['capsuleUnlockDate'] as String?) ?? '';
    return '$createdAt|$type|$text|$title|$capsule';
  }
}
