import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/colors.dart';
import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/providers.dart';
import '../../../data/models/entry.dart';

/// Screen for viewing and recovering soft-deleted entries
class DeletedEntriesScreen extends ConsumerWidget {
  const DeletedEntriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedEntries = ref.watch(deletedEntriesProvider);

    if (PlatformUtils.isIOS) {
      return _buildIOSLayout(context, ref, deletedEntries);
    }
    return _buildAndroidLayout(context, ref, deletedEntries);
  }

  Widget _buildIOSLayout(
    BuildContext context,
    WidgetRef ref,
    List<Entry> entries,
  ) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGroupedBackground.withValues(
          alpha: 0.9,
        ),
        border: null,
        middle: const Text('Recently Deleted'),
        leading: CupertinoNavigationBarBackButton(
          color: SeedlingColors.forestGreen,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        top: false,
        child: entries.isEmpty
            ? _buildEmptyState(context)
            : _buildEntriesList(context, ref, entries),
      ),
    );
  }

  Widget _buildAndroidLayout(
    BuildContext context,
    WidgetRef ref,
    List<Entry> entries,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Deleted'),
        leading: IconButton(
          icon: Icon(AdaptiveIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: entries.isEmpty
          ? _buildEmptyState(context)
          : _buildEntriesList(context, ref, entries),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: SeedlingColors.paleGreen.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AdaptiveIcons.trash,
                size: 36,
                color: SeedlingColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No deleted memories',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: SeedlingColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deleted memories appear here\nand can be recovered for 30 days.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: SeedlingColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntriesList(
    BuildContext context,
    WidgetRef ref,
    List<Entry> entries,
  ) {
    return Column(
      children: [
        // Info banner
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SeedlingColors.paleGreen.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                AdaptiveIcons.info,
                color: SeedlingColors.forestGreen,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Memories are permanently deleted after 30 days.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SeedlingColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Entries list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _buildDeletedEntryCard(context, ref, entry);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeletedEntryCard(
    BuildContext context,
    WidgetRef ref,
    Entry entry,
  ) {
    final daysRemaining = _getDaysRemaining(entry.deletedAt);
    final typeColor = _getTypeColor(entry.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Entry content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getTypeIcon(entry.type),
                    color: typeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayContent,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SeedlingColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$daysRemaining days remaining',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: daysRemaining <= 7
                              ? SeedlingColors.error
                              : SeedlingColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Actions
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: AdaptiveIcons.restore,
                    label: 'Restore',
                    color: SeedlingColors.forestGreen,
                    onTap: () => _restoreEntry(context, ref, entry),
                  ),
                ),
                Container(
                  width: 1,
                  height: 44,
                  color: Theme.of(context).dividerColor,
                ),
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: AdaptiveIcons.deleteForever,
                    label: 'Delete Forever',
                    color: SeedlingColors.error,
                    onTap: () => _confirmPermanentDelete(context, ref, entry),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getDaysRemaining(DateTime? deletedAt) {
    if (deletedAt == null) return 30;
    final expirationDate = deletedAt.add(const Duration(days: 30));
    final remaining = expirationDate.difference(DateTime.now()).inDays;
    return remaining.clamp(0, 30);
  }

  Future<void> _restoreEntry(
    BuildContext context,
    WidgetRef ref,
    Entry entry,
  ) async {
    final authorized = await _authorizeSensitiveAction(
      context,
      ref,
      reason: 'Authenticate to restore this memory',
    );
    if (!authorized) return;
    if (!context.mounted) return;

    HapticFeedback.lightImpact();
    try {
      await ref.read(entryCreatorProvider.notifier).restoreEntry(entry.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not restore memory: $error'),
          backgroundColor: SeedlingColors.error,
        ),
      );
      return;
    }
    if (!context.mounted) return;

    // Show confirmation
    if (PlatformUtils.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Memory Restored'),
          content: const Text('Your memory has been restored to your tree.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Memory restored'),
          backgroundColor: SeedlingColors.forestGreen,
        ),
      );
    }
  }

  void _confirmPermanentDelete(
    BuildContext context,
    WidgetRef ref,
    Entry entry,
  ) {
    final pageContext = context;
    if (PlatformUtils.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Delete Forever?'),
          content: const Text(
            'This memory will be permanently deleted and cannot be recovered.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Delete Forever'),
              onPressed: () {
                Navigator.of(context).pop();
                _permanentlyDeleteEntry(pageContext, ref, entry);
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Forever?'),
          content: const Text(
            'This memory will be permanently deleted and cannot be recovered.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: SeedlingColors.error,
              ),
              child: const Text('Delete Forever'),
              onPressed: () {
                Navigator.of(context).pop();
                _permanentlyDeleteEntry(pageContext, ref, entry);
              },
            ),
          ],
        ),
      );
    }
  }

  Future<void> _permanentlyDeleteEntry(
    BuildContext context,
    WidgetRef ref,
    Entry entry,
  ) async {
    final authorized = await _authorizeSensitiveAction(
      context,
      ref,
      reason: 'Authenticate to permanently delete this memory',
    );
    if (!authorized) return;
    if (!context.mounted) return;

    HapticFeedback.mediumImpact();
    try {
      await ref
          .read(entryCreatorProvider.notifier)
          .permanentlyDeleteEntry(entry.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete memory: $error'),
          backgroundColor: SeedlingColors.error,
        ),
      );
    }
  }

  Future<bool> _authorizeSensitiveAction(
    BuildContext context,
    WidgetRef ref, {
    required String reason,
  }) async {
    if (!ref.read(appLockEnabledProvider)) {
      return true;
    }

    final didAuth = await ref
        .read(appLockServiceProvider)
        .authenticate(reason: reason);
    if (didAuth) {
      return true;
    }

    if (context.mounted) {
      if (PlatformUtils.isIOS) {
        showCupertinoDialog(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('Authentication Required'),
            content: const Text(
              'Device authentication failed or was cancelled.',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device authentication failed or was cancelled'),
          ),
        );
      }
    }
    return false;
  }

  Color _getTypeColor(EntryType type) {
    switch (type) {
      case EntryType.line:
        return SeedlingColors.accentLine;
      case EntryType.photo:
        return SeedlingColors.accentPhoto;
      case EntryType.voice:
        return SeedlingColors.accentVoice;
      case EntryType.object:
        return SeedlingColors.accentObject;
      case EntryType.fragment:
        return SeedlingColors.accentFragment;
      case EntryType.ritual:
        return SeedlingColors.accentRitual;
      case EntryType.release:
        return SeedlingColors.accentRelease;
    }
  }

  IconData _getTypeIcon(EntryType type) {
    if (PlatformUtils.isIOS) {
      switch (type) {
        case EntryType.line:
          return CupertinoIcons.text_quote;
        case EntryType.photo:
          return CupertinoIcons.photo;
        case EntryType.voice:
          return CupertinoIcons.waveform;
        case EntryType.object:
          return CupertinoIcons.cube;
        case EntryType.fragment:
          return CupertinoIcons.sparkles;
        case EntryType.ritual:
          return CupertinoIcons.arrow_2_circlepath;
        case EntryType.release:
          return CupertinoIcons.wind;
      }
    }

    switch (type) {
      case EntryType.line:
        return Icons.format_quote;
      case EntryType.photo:
        return Icons.photo_outlined;
      case EntryType.voice:
        return Icons.graphic_eq;
      case EntryType.object:
        return Icons.category_outlined;
      case EntryType.fragment:
        return Icons.auto_awesome;
      case EntryType.ritual:
        return Icons.loop;
      case EntryType.release:
        return Icons.air;
    }
  }
}
