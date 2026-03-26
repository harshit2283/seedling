import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';
import 'settings_helpers.dart';

const _appVersion = '1.0.0';

/// Settings section showing app version and about dialog.
class AboutSection extends ConsumerWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: const Text('About'),
        children: [
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.info,
              SeedlingColors.textSecondary,
              isLight: true,
            ),
            title: const Text('About Seedling'),
            additionalInfo: const Text('v$_appVersion'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      );
    }

    return buildMaterialSection(
      context,
      title: 'About',
      children: [
        buildMaterialActionTile(
          context,
          icon: AdaptiveIcons.info,
          title: 'About Seedling',
          subtitle: 'Version $_appVersion',
          onTap: () => _showAboutDialog(context),
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    if (PlatformUtils.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AdaptiveIcons.leaf,
                color: SeedlingColors.forestGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text('Seedling'),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                Text(
                  'Memory-keeping that feels like breathing, not documenting.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: SeedlingColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Seedling is a space for capturing moments that matter to you. '
                  'Not every memory needs explanation. Not every thought needs to be complete.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Watch your tree grow as you plant seeds of memory throughout the year.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  'Version $_appVersion',
                  style: TextStyle(
                    fontSize: 12,
                    color: SeedlingColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                AdaptiveIcons.leaf,
                color: SeedlingColors.forestGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text('Seedling'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Memory-keeping that feels like breathing, not documenting.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: SeedlingColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Seedling is a space for capturing moments that matter to you. '
                'Not every memory needs explanation. Not every thought needs to be complete.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Text(
                'Watch your tree grow as you plant seeds of memory throughout the year.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Text(
                'Version $_appVersion',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SeedlingColors.textMuted,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}
