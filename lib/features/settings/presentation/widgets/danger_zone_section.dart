import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import 'settings_helpers.dart';

/// Settings section for recently deleted entries and clear-all-data.
class DangerZoneSection extends ConsumerStatefulWidget {
  const DangerZoneSection({super.key});

  @override
  ConsumerState<DangerZoneSection> createState() => _DangerZoneSectionState();
}

class _DangerZoneSectionState extends ConsumerState<DangerZoneSection> {
  bool _isClearingData = false;

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: const Text('Danger zone'),
        children: [
          CupertinoListTile(
            leading: buildSettingsIconBox(
              AdaptiveIcons.trash,
              SeedlingColors.error,
              isDanger: true,
            ),
            title: const Text('Recently Deleted'),
            subtitle: Text(_getDeletedCountText()),
            trailing: const CupertinoListTileChevron(),
            onTap: () => context.push(AppRoutes.deletedEntries),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              CupertinoIcons.trash_fill,
              SeedlingColors.error,
              isDanger: true,
            ),
            title: const Text('Clear All Data'),
            subtitle: const Text('Delete everything permanently'),
            trailing: _isClearingData
                ? const CupertinoActivityIndicator()
                : const CupertinoListTileChevron(),
            onTap: _isClearingData
                ? null
                : () => _confirmClearAllData(context),
          ),
        ],
      );
    }

    return buildMaterialSection(
      context,
      title: 'Danger Zone',
      children: [
        buildMaterialActionTile(
          context,
          icon: AdaptiveIcons.trash,
          title: 'Recently Deleted',
          subtitle: _getDeletedCountText(),
          onTap: () => context.push(AppRoutes.deletedEntries),
          isDanger: true,
        ),
        buildMaterialActionTile(
          context,
          icon: Icons.delete_forever,
          title: 'Clear All Data',
          subtitle: 'Delete everything permanently',
          onTap: () => _confirmClearAllData(context),
          isDanger: true,
          isLoading: _isClearingData,
        ),
      ],
    );
  }

  String _getDeletedCountText() {
    final deletedEntries = ref.watch(deletedEntriesProvider);
    final count = deletedEntries.length;
    if (count == 0) return 'No deleted memories';
    if (count == 1) return '1 memory';
    return '$count memories';
  }

  void _confirmClearAllData(BuildContext context) {
    HapticFeedback.heavyImpact();
    if (PlatformUtils.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Clear All Data?'),
          content: const Text(
            'This will permanently delete ALL your memories, including photos and voice memos. This action cannot be undone.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _confirmClearAllDataSecond(context);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear All Data?'),
          content: const Text(
            'This will permanently delete ALL your memories, including photos and voice memos. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: SeedlingColors.error,
              ),
              onPressed: () {
                Navigator.pop(context);
                _confirmClearAllDataSecond(context);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    }
  }

  void _confirmClearAllDataSecond(BuildContext context) {
    if (PlatformUtils.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Are you absolutely sure?'),
          content: const Text(
            'This is your last chance to cancel this destructive action.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _clearAllData();
              },
              child: const Text('Delete Everything'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Are you absolutely sure?'),
          content: const Text('This is your last chance to cancel.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: SeedlingColors.error,
              ),
              onPressed: () {
                Navigator.pop(context);
                _clearAllData();
              },
              child: const Text('Delete Everything'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _clearAllData() async {
    if (_isClearingData) return;

    final didAuthorize = await authorizeSensitiveAction(
      ref,
      context,
      'Authenticate to clear all Seedling data',
    );
    if (!didAuthorize) return;

    setState(() => _isClearingData = true);

    try {
      final database = ref.read(databaseProvider);
      final fileStorage = ref.read(fileStorageServiceProvider);
      await fileStorage.clearAllMedia();
      await database.clearAllData();
      if (!mounted) return;
      showSettingsSuccess(context, 'All data was permanently deleted');
    } catch (e) {
      if (!mounted) return;
      showSettingsError(context, 'Failed to clear data: $e');
    } finally {
      if (mounted) {
        setState(() => _isClearingData = false);
      }
    }
  }
}
