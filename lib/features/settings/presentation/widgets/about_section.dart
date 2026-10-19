import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/diagnostics_log.dart';
import '../../../../core/widgets/feedback/seedling_toast.dart';
import 'settings_helpers.dart';

const String shareDiagnosticsTitle = 'Share diagnostics';
const String shareDiagnosticsSubtitle =
    'Only if you choose to. Errors only, no memories.';

/// Settings section showing app version and about dialog.
class AboutSection extends ConsumerStatefulWidget {
  const AboutSection({super.key});

  @override
  ConsumerState<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends ConsumerState<AboutSection> {
  String _appVersion = '...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {
      if (mounted) setState(() => _appVersion = 'unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
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
            additionalInfo: Text('v$_appVersion'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => _showAboutDialog(context),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              CupertinoIcons.heart,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Support Seedling'),
            additionalInfo: const Text('Free, always'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => context.push(AppRoutes.support),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              CupertinoIcons.doc_text,
              SeedlingColors.textSecondary,
              isLight: true,
            ),
            title: const Text(shareDiagnosticsTitle),
            subtitle: const Text(shareDiagnosticsSubtitle),
            trailing: const CupertinoListTileChevron(),
            onTap: () => _shareDiagnostics(context),
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
        buildMaterialActionTile(
          context,
          icon: Icons.favorite_border,
          title: 'Support Seedling',
          subtitle: 'Free and open source. Nothing is locked.',
          onTap: () => context.push(AppRoutes.support),
        ),
        buildMaterialActionTile(
          context,
          icon: Icons.description_outlined,
          title: shareDiagnosticsTitle,
          subtitle: shareDiagnosticsSubtitle,
          onTap: () => _shareDiagnostics(context),
        ),
      ],
    );
  }

  /// Shares the local error log, only after the person confirms. The log
  /// never leaves the device any other way.
  Future<void> _shareDiagnostics(BuildContext context) async {
    final log = ref.read(diagnosticsLogProvider);
    if (log == null || log.entries.isEmpty) {
      showSeedlingMessage(context, 'Nothing to share. No errors recorded.');
      return;
    }
    final count = log.entries.length;
    const body =
        'This shares a list of recent app errors so you can send it to '
        'whoever is helping you. It has no memory text, and file paths are '
        'removed. You choose where it goes.';
    final confirmed = PlatformUtils.isIOS
        ? await showCupertinoDialog<bool>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: Text('Share $count error${count == 1 ? '' : 's'}?'),
              content: const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(body),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Not now'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Share'),
                ),
              ],
            ),
          )
        : await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Share $count error${count == 1 ? '' : 's'}?'),
              content: const Text(body),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Not now'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Share'),
                ),
              ],
            ),
          );
    if (confirmed != true) return;
    await log.flush();
    try {
      await Share.share(
        log.exportText(appVersion: _appVersion),
        subject: 'Seedling diagnostics',
      );
    } catch (_) {
      if (context.mounted) {
        showSeedlingMessage(context, 'Could not open sharing', isError: true);
      }
    }
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
