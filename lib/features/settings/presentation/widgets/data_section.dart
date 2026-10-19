import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:cryptography/cryptography.dart';
import 'package:intl/intl.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/palette.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/backup/backup_restore_service.dart';
import '../../../../core/services/export/export_service.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/services/storage/storage_usage_service.dart';
import '../../../../core/widgets/feedback/seedling_toast.dart';
import 'settings_helpers.dart';

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
              context.palette.primary,
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
              context.palette.primary,
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
              CupertinoIcons.doc_text,
              context.palette.primary,
            ),
            title: const Text('Export as Markdown'),
            subtitle: const Text('Readable files, opens in Obsidian'),
            trailing: _isExporting
                ? const CupertinoActivityIndicator()
                : const CupertinoListTileChevron(),
            onTap: _isExporting ? null : _exportMarkdown,
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.lock,
              context.palette.primary,
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
              context.palette.primary,
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
              context.palette.primary,
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
              CupertinoIcons.tray_arrow_down,
              context.palette.primary,
            ),
            title: const Text('Import from Day One / Markdown'),
            subtitle: const Text('Day One JSON or Markdown export (.zip)'),
            trailing: _isExporting
                ? const CupertinoActivityIndicator()
                : const CupertinoListTileChevron(),
            onTap: _isExporting ? null : _importJournal,
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              CupertinoIcons.refresh,
              context.palette.primary,
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
          icon: Icons.description_outlined,
          title: 'Export as Markdown',
          subtitle: 'Readable files, opens in Obsidian',
          onTap: _exportMarkdown,
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
          icon: Icons.move_to_inbox_outlined,
          title: 'Import from Day One / Markdown',
          subtitle: 'Day One JSON or Markdown export (.zip)',
          onTap: _importJournal,
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
          context.palette.primary,
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
          context.palette.primary,
        ),
        title: const Text('Storage Used'),
        trailing: const CupertinoActivityIndicator(),
      ),
      error: (error, stackTrace) => CupertinoListTile(
        leading: buildSettingsIconBox(
          context,
          CupertinoIcons.chart_pie,
          context.palette.textMuted,
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
              child: Icon(
                Icons.pie_chart_outline,
                color: context.palette.textSecondary,
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
        await exportService.shareAndDelete(
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
        await exportService.shareAndDelete(
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

  Future<void> _exportMarkdown() async {
    HapticFeedback.selectionClick();
    final authorized = await authorizeSensitiveAction(
      ref,
      context,
      'Authenticate to export your memories',
    );
    if (!authorized || !mounted) return;
    final shareOrigin = shareSheetOriginRect(context);
    setState(() => _isExporting = true);

    try {
      final entries = ref.read(allEntriesProvider);
      final exportService = ref.read(exportServiceProvider);
      final fileStorage = ref.read(fileStorageServiceProvider);
      final result = await exportService.exportToMarkdown(
        entries,
        fileStorage.basePath,
      );
      if (!mounted) return;
      if (result.success && result.filePath != null) {
        await exportService.shareAndDelete(
          result.filePath!,
          subject: 'Seedling Memories (Markdown)',
          sharePositionOrigin: shareOrigin,
        );
        if (!mounted) return;
        showSeedlingMessage(context, 'Markdown export ready to share');
      } else {
        showSeedlingMessage(
          context,
          result.error ?? 'Export failed',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showSeedlingMessage(context, 'Export failed', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Imports a Day One JSON export or a Seedling Markdown export: parse,
  /// show what would be added, then merge (never overwriting).
  Future<void> _importJournal() async {
    HapticFeedback.selectionClick();
    final authorized = await authorizeSensitiveAction(
      ref,
      context,
      'Authenticate to import memories',
    );
    if (!authorized) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || path.isEmpty || !mounted) return;

    setState(() => _isExporting = true);
    final exportService = ref.read(exportServiceProvider);
    JournalImport? journal;
    try {
      journal = await exportService.loadJournalArchive(path);
      if (!mounted) return;
      final service = BackupRestoreService(
        database: ref.read(databaseProvider),
        fileStorage: ref.read(fileStorageServiceProvider),
      );
      final preview = service.preview(journal.backup);
      if (preview.newEntries == 0) {
        showSeedlingMessage(
          context,
          preview.total == 0
              ? 'No memories found in this file'
              : 'Everything in this file is already in Seedling',
        );
        return;
      }

      final confirmed = await _confirmJournalImport(
        context,
        journal: journal,
        preview: preview,
      );
      if (!confirmed || !mounted) return;

      final result = await service.restore(
        journal.backup,
        mode: BackupImportMode.merge,
      );
      BackupRestoreService.queueForSync(result, ref.read(syncEngineProvider));
      if (!mounted) return;
      if (result.success) {
        HapticFeedback.lightImpact();
        await _showImportRecap(context, result);
      } else {
        showSeedlingMessage(
          context,
          result.error ?? 'Import failed',
          isError: true,
        );
      }
    } on FormatException catch (e) {
      if (!mounted) return;
      showSeedlingMessage(
        context,
        e.message.isEmpty ? 'This file could not be read' : e.message,
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      showSeedlingMessage(context, 'Import failed', isError: true);
    } finally {
      if (journal != null) {
        await exportService.discardJournalImport(journal);
      }
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<bool> _confirmJournalImport(
    BuildContext context, {
    required JournalImport journal,
    required ImportPreview preview,
  }) async {
    final sourceName = journal.source == JournalImportSource.dayOne
        ? 'Day One'
        : 'Markdown';
    final lines = <String>[
      '${preview.total} ${preview.total == 1 ? 'memory' : 'memories'} '
          'found in this $sourceName export.',
      if (preview.duplicates > 0)
        '${preview.duplicates} already in Seedling will be skipped.',
      if (preview.mediaFiles > 0)
        '${preview.mediaFiles} photos and voice memos come along.',
      if (journal.skipped > 0)
        '${journal.skipped} could not be read and will be left out.',
      'Nothing you already have is changed.',
    ];
    final title =
        'Import ${preview.newEntries} '
        '${preview.newEntries == 1 ? 'memory' : 'memories'}?';
    final content = lines.join('\n');

    if (PlatformUtils.isIOS) {
      final result = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      return result ?? false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    return result ?? false;
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
        // Record the backup date for reminder tracking (best-effort).
        try {
          await ref.read(backupReminderServiceProvider).recordBackup();
        } catch (e, st) {
          const ErrorReporter().report(
            e,
            stack: st,
            context: 'DataSection.recordBackup',
          );
        }
        await exportService.shareAndDelete(
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

      if (mode == BackupImportMode.replace) {
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

      if (mode == BackupImportMode.replace) {
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
    required BackupImportMode mode,
  }) async {
    final service = BackupRestoreService(
      database: ref.read(databaseProvider),
      fileStorage: ref.read(fileStorageServiceProvider),
    );
    final result = await service.restore(loaded, mode: mode);
    BackupRestoreService.queueForSync(result, ref.read(syncEngineProvider));
    return result;
  }

  String _formatWarning(String warningCode) {
    switch (warningCode) {
      case 'integrity_not_verified':
        return 'legacy backup integrity not verified';
      case 'missing_media':
        return 'some media files were missing';
      case 'unsupported_media':
        return 'videos and PDFs were not imported';
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

  Future<BackupImportMode?> _promptImportMode(
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
      return showCupertinoDialog<BackupImportMode>(
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
              onPressed: () =>
                  Navigator.of(context).pop(BackupImportMode.merge),
              child: const Text('Merge (Keep current + add missing)'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () =>
                  Navigator.of(context).pop(BackupImportMode.replace),
              child: const Text('Replace (Erase current and restore)'),
            ),
          ],
        ),
      );
    }

    return showDialog<BackupImportMode>(
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
            onPressed: () => Navigator.of(context).pop(BackupImportMode.merge),
            child: const Text('Merge'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(BackupImportMode.replace),
            style: TextButton.styleFrom(foregroundColor: context.palette.error),
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
            style: TextButton.styleFrom(foregroundColor: context.palette.error),
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
