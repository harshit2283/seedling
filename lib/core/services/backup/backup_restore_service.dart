import 'dart:io';

import '../../../data/datasources/local/objectbox_database.dart';
import '../../../data/models/entry.dart';
import '../ai/theme_detector_service.dart';
import '../export/export_service.dart';
import '../media/file_storage_service.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_models.dart';

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
  static final _themeDetector = ThemeDetectorService();
  final FileStorageService _fileStorage;

  /// Counts what a merge of [loaded] would add, without writing anything.
  ImportPreview preview(LoadedEncryptedBackup loaded) {
    final known = _knownIdentities();
    var duplicates = 0;
    var media = 0;
    for (final entryMap in loaded.entries) {
      if (known.isDuplicate(entryMap)) {
        duplicates++;
        continue;
      }
      known.add(entryMap);
      final mediaPath = entryMap['mediaPath'] as String?;
      if (mediaPath != null &&
          (loaded.mediaFiles.containsKey(mediaPath) ||
              loaded.mediaFilePaths.containsKey(mediaPath))) {
        media++;
      }
    }
    return ImportPreview(
      total: loaded.entries.length,
      duplicates: duplicates,
      mediaFiles: media,
    );
  }

  /// Fingerprints and sync identities of everything already stored,
  /// including the 30-day trash (a deliberately deleted memory must not
  /// reappear on the next import).
  _KnownIdentities _knownIdentities() {
    final existing = [
      ..._database.getAllEntries(),
      ..._database.getDeletedEntries(),
    ];
    return _KnownIdentities(
      fingerprints: existing.map(entryFingerprint).toSet(),
      syncUUIDs: existing
          .map((e) => e.syncUUID)
          .whereType<String>()
          .where((u) => u.isNotEmpty)
          .toSet(),
    );
  }

  Future<ImportResult> restore(
    LoadedEncryptedBackup loaded, {
    required BackupImportMode mode,
  }) async {
    final known = mode == BackupImportMode.merge
        ? _knownIdentities()
        : _KnownIdentities(fingerprints: {}, syncUUIDs: {});

    if (mode == BackupImportMode.replace) {
      // Stage deletion: soft-delete existing entries instead of destroying
      // immediately. If import fails, entries remain recoverable.
      final existing = _database.getAllEntries();
      for (final entry in existing) {
        await _database.softDeleteEntry(entry.id);
      }
    }

    final createdEntries = <Entry>[];
    final deletedEntries = <Entry>[];
    var importedEntries = 0;
    var importedMediaFiles = 0;
    var skippedDuplicates = 0;
    final warnings = [...loaded.warnings];

    for (final entryMap in loaded.entries) {
      // Merge never overwrites: an entry whose content or sync identity is
      // already present is skipped. (Within one import, duplicates are
      // skipped in either mode.)
      if (known.isDuplicate(entryMap)) {
        skippedDuplicates++;
        continue;
      }

      final restoredMediaPath = await _restoreMediaForEntry(
        entryMap: entryMap,
        loaded: loaded,
      );
      final pendingDownload =
          restoredMediaPath == null && _hasRemoteMedia(entryMap);
      if (pendingDownload) {
        warnings.add('media_pending_download');
      } else if (restoredMediaPath == null && entryMap['mediaPath'] != null) {
        warnings.add('missing_media');
      } else if (restoredMediaPath != null) {
        importedMediaFiles++;
      }

      final entry = entryFromBackupMap(
        entryMap,
        restoredMediaPath: restoredMediaPath,
      );
      // Older backups carry no theme: store one so counts stay cheap.
      if (!entry.hasTheme) _themeDetector.assignTheme(entry);
      await _database.saveEntry(entry);
      createdEntries.add(entry.copy());
      known.add(entryMap);
      importedEntries++;
    }

    await _database.recountTrees();

    // Import succeeded — permanently remove the staged old entries. Each hard
    // delete removes that entry's own media file. The media directory must
    // NOT be wiped wholesale: it now also holds the files restored above.
    if (mode == BackupImportMode.replace) {
      final deleted = _database.getDeletedEntries();
      for (final entry in deleted) {
        if (await _database.deleteEntry(entry.id)) deletedEntries.add(entry);
      }
    }

    return ImportResult.success(
      importedEntries: importedEntries,
      importedMediaFiles: importedMediaFiles,
      skippedDuplicates: skippedDuplicates,
      warnings: warnings,
      createdEntries: createdEntries,
      deletedEntries: deletedEntries,
    );
  }

  /// Queues everything [result] touched through the sync engine: restores
  /// write the database directly, so without this imported memories never
  /// reach other devices and replace-mode deletions linger there.
  ///
  /// Deletes are queued first and skipped for any syncUUID the restore
  /// re-created (restoring the same backup over itself must not delete the
  /// restored entries remotely; the sync queue keeps the latest change).
  static void queueForSync(ImportResult result, SyncEngine sync) {
    if (!result.success) return;
    final recreated = {
      for (final e in result.createdEntries)
        if (e.syncUUID != null) e.syncUUID!,
    };
    for (final entry in result.deletedEntries) {
      if (entry.syncUUID == null || recreated.contains(entry.syncUUID)) {
        continue;
      }
      sync.queuePush(entry, SyncChangeType.delete);
    }
    for (final entry in result.createdEntries) {
      sync.queuePush(entry, SyncChangeType.create);
    }
  }

  static bool _hasRemoteMedia(Map<String, dynamic> entryMap) {
    final id = entryMap['mediaAssetId'];
    final key = entryMap['mediaKey'];
    return id is String && id.isNotEmpty && key is String && key.isNotEmpty;
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
    // Remote media link (encrypted backups only). Without local media the
    // entry is left with no mediaPath so sync downloads it again.
    if (_hasRemoteMedia(entryMap)) {
      entry.mediaAssetId = entryMap['mediaAssetId'] as String;
      entry.mediaKey = entryMap['mediaKey'] as String;
      if (restoredMediaPath == null) entry.mediaPath = null;
    }
    entry.deviceId = entryMap['deviceId'] as String?;
    return entry;
  }

  Future<String?> _restoreMediaForEntry({
    required Map<String, dynamic> entryMap,
    required LoadedEncryptedBackup loaded,
  }) async {
    final rawMediaPath = entryMap['mediaPath'] as String?;
    if (rawMediaPath == null || rawMediaPath.isEmpty) {
      return null;
    }
    final bytes = loaded.mediaFiles[rawMediaPath];
    final stagedPath = loaded.mediaFilePaths[rawMediaPath];
    final staged = stagedPath == null ? null : File(stagedPath);
    if (bytes == null && (staged == null || !await staged.exists())) {
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

    if (bytes != null) {
      await File(targetPath).writeAsBytes(bytes, flush: true);
    } else {
      await staged!.copy(targetPath);
    }
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

  /// Normalises a timestamp to a UTC instant so the same moment matches
  /// whether it was written as local time, UTC or with an offset.
  static String _instant(String? raw) {
    final parsed = DateTime.tryParse(raw ?? '');
    return parsed == null ? (raw ?? '') : parsed.toUtc().toIso8601String();
  }

  static String entryFingerprint(Entry entry) {
    final createdAt = entry.createdAt.toUtc().toIso8601String();
    final type = entry.type.name;
    final text = (entry.text ?? '').trim().toLowerCase();
    final title = (entry.title ?? '').trim().toLowerCase();
    final capsule = entry.capsuleUnlockDate?.toUtc().toIso8601String() ?? '';
    return '$createdAt|$type|$text|$title|$capsule';
  }

  static String mapFingerprint(Map<String, dynamic> map) {
    final createdAt = _instant(map['createdAt'] as String?);
    final type = (map['type'] as String?) ?? '';
    final text = ((map['text'] as String?) ?? '').trim().toLowerCase();
    final title = ((map['title'] as String?) ?? '').trim().toLowerCase();
    final rawCapsule = map['capsuleUnlockDate'] as String?;
    final capsule = rawCapsule == null || rawCapsule.isEmpty
        ? ''
        : _instant(rawCapsule);
    return '$createdAt|$type|$text|$title|$capsule';
  }
}

class _KnownIdentities {
  _KnownIdentities({required this.fingerprints, required this.syncUUIDs});

  final Set<String> fingerprints;
  final Set<String> syncUUIDs;

  bool isDuplicate(Map<String, dynamic> entryMap) {
    final uuid = entryMap['syncUUID'];
    if (uuid is String && uuid.isNotEmpty && syncUUIDs.contains(uuid)) {
      return true;
    }
    return fingerprints.contains(BackupRestoreService.mapFingerprint(entryMap));
  }

  void add(Map<String, dynamic> entryMap) {
    fingerprints.add(BackupRestoreService.mapFingerprint(entryMap));
    final uuid = entryMap['syncUUID'];
    if (uuid is String && uuid.isNotEmpty) syncUUIDs.add(uuid);
  }
}
