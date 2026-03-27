import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:cryptography/cryptography.dart';
import 'package:intl/intl.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/export/export_service.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/services/storage/storage_usage_service.dart';
import '../../../../data/models/entry.dart';
import 'settings_helpers.dart';

enum _ImportMode { merge, replace }

/// Settings section for export, import, storage, and tree rebuild.
class DataSection extends ConsumerStatefulWidget {
  const DataSection({super.key});

  @override
  ConsumerState<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<DataSection> {
  bool _isExporting = false;
  bool _isRecountingTrees = false;

  @override
  Widget build(BuildContext context) {
    final storageAsync = ref.watch(storageUsageProvider);

    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: const Text('Your data'),
        children: [
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.download,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Export as JSON'),
            subtitle: const Text('Entries without media'),
            trailing: _isExporting
                ? const CupertinoActivityIndicator()
                : const CupertinoListTileChevron(),
            onTap: _isExporting ? null : _exportJson,
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              CupertinoIcons.archivebox,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Export as ZIP'),
            subtitle: const Text('Entries with all media'),
            trailing: _isExporting
                ? const CupertinoActivityIndicator()
                : const CupertinoListTileChevron(),
            onTap: _isExporting ? null : _exportZip,
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.lock,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Encrypted Backup'),
            subtitle: const Text('Password-protected .seedling file'),
            trailing: _isExporting
                ? const CupertinoActivityIndicator()
                : const CupertinoListTileChevron(),
            onTap: _isExporting ? null : _exportEncryptedBackup,
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.download,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Import Encrypted Backup'),
            subtitle: const Text('Restore from .seedling file'),
            trailing: _isExporting
                ? const CupertinoActivityIndicator()
                : const CupertinoListTileChevron(),
            onTap: _isExporting ? null : _importEncryptedBackup,
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.download,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Import Archive (ZIP)'),
            subtitle: const Text('Restore from .zip export'),
            trailing: _isExporting
                ? const CupertinoActivityIndicator()
                : const CupertinoListTileChevron(),
            onTap: _isExporting ? null : _importZipArchive,
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              CupertinoIcons.refresh,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Rebuild Tree Counts'),
            subtitle: const Text('Repair yearly growth totals'),
            trailing: _isRecountingTrees
                ? const CupertinoActivityIndicator()
                : const CupertinoListTileChevron(),
            onTap: _isRecountingTrees ? null : _recountTrees,
          ),
          _buildStorageTileIOS(storageAsync),
        ],
      );
    }

    return buildMaterialSection(
      context,
      title: 'Data',
      children: [
        buildMaterialActionTile(
          context,
          icon: AdaptiveIcons.download,
          title: 'Export as JSON',
          subtitle: 'Entries without media',
          onTap: _exportJson,
          isLoading: _isExporting,
        ),
        buildMaterialActionTile(
          context,
          icon: Icons.archive_outlined,
          title: 'Export as ZIP',
          subtitle: 'Entries with all media',
          onTap: _exportZip,
          isLoading: _isExporting,
        ),
        buildMaterialActionTile(
          context,
          icon: AdaptiveIcons.lock,
          title: 'Encrypted Backup',
          subtitle: 'Password-protected .seedling file',
          onTap: _exportEncryptedBackup,
          isLoading: _isExporting,
        ),
        buildMaterialActionTile(
          context,
          icon: AdaptiveIcons.download,
          title: 'Import Encrypted Backup',
          subtitle: 'Restore from .seedling file',
          onTap: _importEncryptedBackup,
          isLoading: _isExporting,
        ),
        buildMaterialActionTile(
          context,
          icon: AdaptiveIcons.download,
          title: 'Import Archive (ZIP)',
          subtitle: 'Restore from .zip export',
          onTap: _importZipArchive,
          isLoading: _isExporting,
        ),
        buildMaterialActionTile(
          context,
          icon: Icons.refresh,
          title: 'Rebuild Tree Counts',
          subtitle: 'Repair yearly growth totals',
          onTap: _recountTrees,
          isLoading: _isRecountingTrees,
        ),
        _buildStorageTileMaterial(context, storageAsync),
      ],
    );
  }

  Widget _buildStorageTileIOS(AsyncValue<StorageUsage> storageAsync) {
    return storageAsync.when(
      data: (storage) => CupertinoListTile(
        leading: buildSettingsIconBox(
          context,
          CupertinoIcons.chart_pie,
          SeedlingColors.forestGreen,
        ),
        title: const Text('Storage Used'),
        additionalInfo: Text(storage.totalFormatted),
        trailing: const CupertinoListTileChevron(),
        onTap: () => showStorageDetails(context, storage),
      ),
      loading: () => CupertinoListTile(
        leading: buildSettingsIconBox(
          context,
          CupertinoIcons.chart_pie,
          SeedlingColors.forestGreen,
        ),
        title: const Text('Storage Used'),
        trailing: const CupertinoActivityIndicator(),
      ),
      error: (error, stackTrace) => CupertinoListTile(
        leading: buildSettingsIconBox(
          context,
          CupertinoIcons.chart_pie,
          SeedlingColors.textMuted,
          isLight: true,
        ),
        title: const Text('Storage Used'),
        additionalInfo: const Text('Error'),
      ),
    );
  }

  Widget _buildStorageTileMaterial(
    BuildContext context,
    AsyncValue<StorageUsage> storageAsync,
  ) {
    return storageAsync.when(
      data: (storage) => buildMaterialActionTile(
        context,
        icon: Icons.pie_chart_outline,
        title: 'Storage Used',
        subtitle: storage.totalFormatted,
        onTap: () => showStorageDetails(context, storage),
      ),
      loading: () => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.pie_chart_outline,
                color: SeedlingColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Calculating...'),
            const Spacer(),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
      error: (error, stackTrace) => buildMaterialActionTile(
        context,
        icon: Icons.pie_chart_outline,
        title: 'Storage Used',
        subtitle: 'Error calculating',
        enabled: false,
        onTap: () {},
      ),
    );
  }

  // ============== Export Functions ==============

  Future<void> _exportJson() async {
    HapticFeedback.selectionClick();
    final authorized = await authorizeSensitiveAction(
      ref,
      context,
      'Authenticate to export your memories',
    );
    if (!authorized) return;
    if (!mounted) return;
    final shareOrigin = shareSheetOriginRect(context);
    setState(() => _isExporting = true);

    try {
      final entries = ref.read(allEntriesProvider);
      final exportService = ref.read(exportServiceProvider);
      final result = await exportService.exportToJson(entries);

      if (result.success && result.filePath != null) {
        await exportService.shareFile(
          result.filePath!,
          subject: 'Seedling Memories Export',
          sharePositionOrigin: shareOrigin,
        );
        if (!mounted) return;
        showSettingsSuccess(context, 'Export ready to share');
      } else {
        if (!mounted) return;
        showSettingsError(context, result.error ?? 'Export failed');
      }
    } catch (e) {
      if (!mounted) return;
      showSettingsError(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportZip() async {
    HapticFeedback.selectionClick();
    final authorized = await authorizeSensitiveAction(
      ref,
      context,
      'Authenticate to export your memories',
    );
    if (!authorized) return;
    if (!mounted) return;
    final shareOrigin = shareSheetOriginRect(context);
    setState(() => _isExporting = true);

    try {
      final entries = ref.read(allEntriesProvider);
      final exportService = ref.read(exportServiceProvider);
      final fileStorage = ref.read(fileStorageServiceProvider);
      final result = await exportService.exportToZip(
        entries,
        fileStorage.basePath,
      );

      if (result.success && result.filePath != null) {
        await exportService.shareFile(
          result.filePath!,
          subject: 'Seedling Backup',
          sharePositionOrigin: shareOrigin,
        );
        if (!mounted) return;
        showSettingsSuccess(context, 'Backup ready to share');
      } else {
        if (!mounted) return;
        showSettingsError(context, result.error ?? 'Export failed');
      }
    } catch (e) {
      if (!mounted) return;
      showSettingsError(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _recountTrees() async {
    HapticFeedback.selectionClick();
    setState(() => _isRecountingTrees = true);

    try {
      await ref.read(databaseMaintenanceProvider.notifier).recountTrees();
      if (!mounted) return;
      showSettingsSuccess(context, 'Tree counts rebuilt successfully');
    } catch (e) {
      if (!mounted) return;
      showSettingsError(context, 'Could not rebuild tree counts');
    } finally {
      if (mounted) {
        setState(() => _isRecountingTrees = false);
      }
    }
  }

  Future<void> _exportEncryptedBackup() async {
    HapticFeedback.selectionClick();
    final authorized = await authorizeSensitiveAction(
      ref,
      context,
      'Authenticate to create an encrypted backup',
    );
    if (!authorized) return;
    if (!mounted) return;
    final passphrase = await _promptForPassphrase(
      context,
      title: 'Create Encrypted Backup',
      message: 'Set a passphrase (minimum 8 characters).',
      confirm: true,
    );
    if (passphrase == null || passphrase.isEmpty) {
      return;
    }
    if (!mounted) return;
    final shareOrigin = shareSheetOriginRect(context);

    setState(() => _isExporting = true);
    try {
      final entries = ref.read(allEntriesProvider);
      final exportService = ref.read(exportServiceProvider);
      final fileStorage = ref.read(fileStorageServiceProvider);
      final result = await exportService.exportEncryptedBackup(
        entries,
        fileStorage.basePath,
        passphrase: passphrase,
      );

      if (result.success && result.filePath != null) {
        // Record the backup date for reminder tracking.
        await ref.read(backupReminderServiceProvider).recordBackup();
        await exportService.shareFile(
          result.filePath!,
          subject: 'Seedling Encrypted Backup',
          sharePositionOrigin: shareOrigin,
        );
        if (!mounted) return;
        showSettingsSuccess(context, 'Encrypted backup ready to share');
      } else {
        if (!mounted) return;
        showSettingsError(context, result.error ?? 'Encrypted backup failed');
      }
    } catch (e) {
      if (!mounted) return;
      showSettingsError(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importEncryptedBackup() async {
    HapticFeedback.selectionClick();
    final authorized = await authorizeSensitiveAction(
      ref,
      context,
      'Authenticate to import a backup',
    );
    if (!authorized) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['seedling'],
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || path.isEmpty) {
      return;
    }
    if (!mounted) return;

    final passphrase = await _promptForPassphrase(
      context,
      title: 'Unlock Backup',
      message: 'Enter the passphrase for this encrypted backup.',
    );
    if (passphrase == null || passphrase.isEmpty) {
      return;
    }

    setState(() => _isExporting = true);
    try {
      final exportService = ref.read(exportServiceProvider);
      final loaded = await exportService.loadEncryptedBackup(
        path,
        passphrase: passphrase,
      );

      if (!mounted) return;
      final mode = await _promptImportMode(context, loaded.preview);
      if (mode == null) {
        return;
      }
      if (!mounted) return;

      if (mode == _ImportMode.replace) {
        final localCountBefore = ref.read(allEntriesProvider).length;
        final confirmed = await _confirmReplaceImport(
          context,
          localCount: localCountBefore,
        );
        if (!confirmed) return;
        final appLockService = ref.read(appLockServiceProvider);
        final didAuth = await appLockService.authenticate();
        if (!didAuth) {
          if (!mounted) return;
          showSettingsError(context, 'Device authentication was cancelled');
          return;
        }
      }

      final result = await _restoreLoadedBackup(loaded, mode: mode);
      if (!mounted) return;

      if (result.success) {
        await _showImportRecap(context, result);
      } else {
        showSettingsError(context, result.error ?? 'Import failed');
      }
    } on SecretBoxAuthenticationError {
      if (!mounted) return;
      showSettingsError(context, 'Invalid backup passphrase');
    } catch (e) {
      if (!mounted) return;
      showSettingsError(context, 'Import failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importZipArchive() async {
    HapticFeedback.selectionClick();
    final authorized = await authorizeSensitiveAction(
      ref,
      context,
      'Authenticate to import a backup',
    );
    if (!authorized) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || path.isEmpty) {
      return;
    }
    if (!mounted) return;

    setState(() => _isExporting = true);
    try {
      final exportService = ref.read(exportServiceProvider);
      final loaded = await exportService.loadZipArchive(path);

      if (!mounted) return;
      final mode = await _promptImportMode(context, loaded.preview);
      if (mode == null) {
        return;
      }
      if (!mounted) return;

      if (mode == _ImportMode.replace) {
        final localCountBefore = ref.read(allEntriesProvider).length;
        final confirmed = await _confirmReplaceImport(
          context,
          localCount: localCountBefore,
        );
        if (!confirmed) return;
        final appLockService = ref.read(appLockServiceProvider);
        final didAuth = await appLockService.authenticate();
        if (!didAuth) {
          if (!mounted) return;
          showSettingsError(context, 'Device authentication was cancelled');
          return;
        }
      }

      final result = await _restoreLoadedBackup(loaded, mode: mode);
      if (!mounted) return;

      if (result.success) {
        await _showImportRecap(context, result);
      } else {
        showSettingsError(context, result.error ?? 'Import failed');
      }
    } catch (e) {
      if (!mounted) return;
      showSettingsError(context, 'Archive import failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // ============== Import Helpers ==============

  Future<ImportResult> _restoreLoadedBackup(
    LoadedEncryptedBackup loaded, {
    required _ImportMode mode,
  }) async {
    final database = ref.read(databaseProvider);
    final fileStorage = ref.read(fileStorageServiceProvider);
    final existingEntries = mode == _ImportMode.merge
        ? database.getAllEntries()
        : <Entry>[];
    final seenFingerprints = existingEntries
        .map((entry) => _entryFingerprint(entry))
        .toSet();

    if (mode == _ImportMode.replace) {
      // Stage deletion: soft-delete existing entries instead of destroying
      // immediately. If import fails, entries remain recoverable.
      final existing = database.getAllEntries();
      for (final entry in existing) {
        await database.softDeleteEntry(entry.id);
      }
      seenFingerprints.clear();
    }

    var importedEntries = 0;
    var importedMediaFiles = 0;
    var skippedDuplicates = 0;
    final warnings = [...loaded.warnings];

    for (final entryMap in loaded.entries) {
      final fingerprint = _mapFingerprint(entryMap);
      if (mode == _ImportMode.merge && seenFingerprints.contains(fingerprint)) {
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

      final createdAt =
          DateTime.tryParse((entryMap['createdAt'] as String?) ?? '') ??
          DateTime.now();
      final type = _parseEntryType(entryMap['type'] as String?);

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
      // Rehydrate sync identity
      entry.syncUUID = entryMap['syncUUID'] as String?;
      entry.deviceId = entryMap['deviceId'] as String?;

      await database.saveEntry(entry);
      seenFingerprints.add(fingerprint);
      importedEntries++;
    }

    await database.recountTrees();

    // Import succeeded — permanently remove old data for replace mode
    if (mode == _ImportMode.replace) {
      final deleted = database.getDeletedEntries();
      for (final entry in deleted) {
        await database.deleteEntry(entry.id);
      }
      await fileStorage.clearAllMedia();
    }

    return ImportResult.success(
      importedEntries: importedEntries,
      importedMediaFiles: importedMediaFiles,
      skippedDuplicates: skippedDuplicates,
      warnings: warnings,
    );
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

    final fileStorage = ref.read(fileStorageServiceProvider);
    final type = _parseEntryType(entryMap['type'] as String?);
    final extension = _extensionFromArchivePath(rawMediaPath);

    String targetPath;
    switch (type) {
      case EntryType.photo:
        targetPath = await fileStorage.generatePhotoPath(extension: extension);
        break;
      case EntryType.object:
        targetPath = await fileStorage.generateObjectPhotoPath(
          extension: extension,
        );
        break;
      case EntryType.voice:
        targetPath = await fileStorage.generateVoicePath(extension: extension);
        break;
      default:
        targetPath = await fileStorage.generatePhotoPath(extension: extension);
        break;
    }

    await File(targetPath).writeAsBytes(bytes, flush: true);
    return targetPath;
  }

  EntryType _parseEntryType(String? rawType) {
    if (rawType == null) return EntryType.line;
    return EntryType.values.firstWhere(
      (type) => type.name == rawType,
      orElse: () => EntryType.line,
    );
  }

  String _extensionFromArchivePath(String path) {
    final fileName = path.split('/').last;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) {
      return 'bin';
    }
    return fileName.substring(dot + 1);
  }

  String _entryFingerprint(Entry entry) {
    final createdAt = entry.createdAt.toIso8601String();
    final type = entry.type.name;
    final text = (entry.text ?? '').trim().toLowerCase();
    final title = (entry.title ?? '').trim().toLowerCase();
    final capsule = entry.capsuleUnlockDate?.toIso8601String() ?? '';
    return '$createdAt|$type|$text|$title|$capsule';
  }

  String _mapFingerprint(Map<String, dynamic> map) {
    final createdAt = (map['createdAt'] as String?) ?? '';
    final type = (map['type'] as String?) ?? '';
    final text = ((map['text'] as String?) ?? '').trim().toLowerCase();
    final title = ((map['title'] as String?) ?? '').trim().toLowerCase();
    final capsule = (map['capsuleUnlockDate'] as String?) ?? '';
    return '$createdAt|$type|$text|$title|$capsule';
  }

  String _formatWarning(String warningCode) {
    switch (warningCode) {
      case 'integrity_not_verified':
        return 'legacy backup integrity not verified';
      case 'missing_media':
        return 'some media files were missing';
      default:
        return warningCode;
    }
  }

  // ============== Dialogs ==============

  Future<String?> _promptForPassphrase(
    BuildContext context, {
    required String title,
    required String message,
    bool confirm = false,
  }) async {
    final passController = TextEditingController();
    final confirmController = TextEditingController();

    if (PlatformUtils.isIOS) {
      return showCupertinoDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Text(message),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: passController,
                    placeholder: 'Passphrase',
                    obscureText: true,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (confirm) ...[
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: confirmController,
                      placeholder: 'Confirm passphrase',
                      obscureText: true,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  final pass = passController.text.trim();
                  if (pass.length < 8) {
                    showSettingsError(
                      context,
                      'Passphrase must be at least 8 characters',
                    );
                    return;
                  }
                  if (confirm && pass != confirmController.text.trim()) {
                    showSettingsError(context, 'Passphrases do not match');
                    return;
                  }
                  Navigator.of(dialogContext).pop(pass);
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    }

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passphrase'),
            ),
            if (confirm) ...[
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm passphrase',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final pass = passController.text.trim();
              if (pass.length < 8) {
                showSettingsError(
                  context,
                  'Passphrase must be at least 8 characters',
                );
                return;
              }
              if (confirm && pass != confirmController.text.trim()) {
                showSettingsError(context, 'Passphrases do not match');
                return;
              }
              Navigator.of(dialogContext).pop(pass);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<_ImportMode?> _promptImportMode(
    BuildContext context,
    EncryptedBackupPreview preview,
  ) async {
    final exportDate = preview.exportedAt == null
        ? 'Unknown'
        : DateFormat('MMM d, y • h:mm a').format(preview.exportedAt!);
    final integrityText = preview.integrityVerified
        ? 'Integrity verified'
        : 'Legacy backup (integrity signature unavailable)';
    final summary =
        '${preview.entryCount} memories\n'
        '${preview.mediaCount} media files\n'
        'Exported: $exportDate\n'
        '$integrityText';

    if (PlatformUtils.isIOS) {
      return showCupertinoDialog<_ImportMode>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Import Backup'),
          content: Text(summary),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(_ImportMode.merge),
              child: const Text('Merge (Keep current + add missing)'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(_ImportMode.replace),
              child: const Text('Replace (Erase current and restore)'),
            ),
          ],
        ),
      );
    }

    return showDialog<_ImportMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Backup'),
        content: Text(summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ImportMode.merge),
            child: const Text('Merge'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ImportMode.replace),
            style: TextButton.styleFrom(foregroundColor: SeedlingColors.error),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmReplaceImport(
    BuildContext context, {
    required int localCount,
  }) async {
    final contentText =
        'This will delete $localCount local memories and restore only this backup.';
    if (PlatformUtils.isIOS) {
      final result = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Replace all local data?'),
          content: Text(contentText),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      return result ?? false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all local data?'),
        content: Text(contentText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: SeedlingColors.error),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showImportRecap(
    BuildContext context,
    ImportResult result,
  ) async {
    final hasWarnings = result.warnings.isNotEmpty;
    final warningText = hasWarnings
        ? '\nWarnings: ${result.warnings.map(_formatWarning).join(', ')}'
        : '';
    final message =
        'Imported ${result.importedEntries} memories\n'
        'Restored ${result.importedMediaFiles} media files\n'
        'Skipped ${result.skippedDuplicates} duplicates$warningText';

    final hasCapsules = ref.read(capsulesProvider).isNotEmpty;

    if (PlatformUtils.isIOS) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Import Complete'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.push(AppRoutes.memories);
              },
              child: const Text('Open Memories'),
            ),
            if (hasCapsules)
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.push(AppRoutes.capsules);
                },
                child: const Text('Open Capsules'),
              ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Complete'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push(AppRoutes.memories);
            },
            child: const Text('Open Memories'),
          ),
          if (hasCapsules)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.push(AppRoutes.capsules);
              },
              child: const Text('Open Capsules'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
