import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/palette.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/diagnostics_log.dart';
import '../../../../core/widgets/feedback/seedling_toast.dart';
import '../../../../core/constants/support_links.dart';
import '../../../../core/services/providers.dart';
import 'settings_helpers.dart';
import 'settings_tiles.dart';

const String shareDiagnosticsTitle = 'Share diagnostics';
const String shareDiagnosticsSubtitle = 'Errors only, never memories';

/// "About": support, privacy policy, diagnostics, version, and a quiet
/// "Advanced" disclosure for maintenance tools.
class AboutSection extends ConsumerStatefulWidget {
  const AboutSection({super.key});

  @override
  ConsumerState<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends ConsumerState<AboutSection> {
  String _appVersion = '...';
  bool _advancedOpen = false;
  bool _isRecountingTrees = false;
  bool _isClearingData = false;

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
    final collage = ref.watch(collageViewEnabledProvider);
    return SettingsGroup(
      title: 'About',
      children: [
        SettingsRow(
          key: const ValueKey('settings-support'),
          icon: adaptiveIcon(CupertinoIcons.heart, Icons.favorite_border),
          isWarm: true,
          title: 'Support Seedling',
          subtitle: 'Free and open source. Nothing is locked.',
          onTap: () => context.push(AppRoutes.support),
        ),
        SettingsRow(
          icon: AdaptiveIcons.shield,
          title: 'Privacy policy',
          subtitle: 'What Seedling keeps, and never does',
          onTap: () => _copyLink(context, SupportLinks.privacyPolicyUrl),
        ),
        SettingsRow(
          icon: adaptiveIcon(
            CupertinoIcons.doc_text,
            Icons.description_outlined,
          ),
          title: shareDiagnosticsTitle,
          subtitle: shareDiagnosticsSubtitle,
          onTap: () => _shareDiagnostics(context),
        ),
        SettingsRow(
          icon: AdaptiveIcons.info,
          title: 'About Seedling',
          value: _appVersion == 'unknown' || _appVersion == '...'
              ? null
              : 'Version $_appVersion',
          onTap: () => _showAboutDialog(context),
        ),
        SettingsRow(
          key: const ValueKey('settings-advanced'),
          icon: adaptiveIcon(CupertinoIcons.wrench, Icons.build_outlined),
          title: 'Advanced',
          showChevron: false,
          trailing: AnimatedRotation(
            duration: _reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            turns: _advancedOpen ? 0.25 : 0,
            child: Icon(
              AdaptiveIcons.chevronRight,
              size: PlatformUtils.isIOS ? 18 : 24,
              color: context.palette.textMuted,
            ),
          ),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _advancedOpen = !_advancedOpen);
          },
        ),
        if (_advancedOpen) ...[
          SettingsRow(
            key: const ValueKey('settings-rebuild-tree'),
            icon: adaptiveIcon(CupertinoIcons.refresh, Icons.refresh),
            title: 'Rebuild tree counts',
            subtitle: 'If your tree looks out of step',
            isLoading: _isRecountingTrees,
            onTap: _recountTrees,
          ),
          SettingsSwitchRow(
            icon: adaptiveIcon(CupertinoIcons.square_grid_2x2, Icons.grid_view),
            title: 'Photo grid in Memories',
            subtitle: 'Experimental. May change.',
            value: collage,
            onChanged: (v) =>
                ref.read(collageViewEnabledProvider.notifier).set(v),
          ),
          SettingsRow(
            icon: adaptiveIcon(
              CupertinoIcons.trash,
              Icons.delete_forever_outlined,
            ),
            isDanger: true,
            title: 'Clear all data',
            subtitle: 'Delete every memory here',
            isLoading: _isClearingData,
            onTap: () => _confirmClearAllData(context),
          ),
        ],
      ],
    );
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  Future<void> _copyLink(BuildContext context, String url) async {
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    showSeedlingMessage(context, 'Link copied. Paste it in your browser.');
  }

  Future<void> _recountTrees() async {
    HapticFeedback.selectionClick();
    setState(() => _isRecountingTrees = true);
    try {
      await ref.read(databaseMaintenanceProvider.notifier).recountTrees();
      if (!mounted) return;
      showSettingsSuccess(context, 'Your tree is up to date');
    } catch (e) {
      if (!mounted) return;
      showSettingsError(context, 'Could not rebuild tree counts');
    } finally {
      if (mounted) setState(() => _isRecountingTrees = false);
    }
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
                color: context.palette.primary,
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
                    color: context.palette.textSecondary,
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
                    color: context.palette.textMuted,
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
                color: context.palette.primary,
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
                  color: context.palette.textSecondary,
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
                  color: context.palette.textMuted,
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

  void _confirmClearAllData(BuildContext context) {
    // A warning, not a jolt: the double confirmation carries the weight.
    HapticFeedback.mediumImpact();
    if (PlatformUtils.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Clear all data?'),
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
          title: const Text('Clear all data?'),
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
                foregroundColor: context.palette.error,
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
              child: const Text('Delete everything'),
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
                foregroundColor: context.palette.error,
              ),
              onPressed: () {
                Navigator.pop(context);
                _clearAllData();
              },
              child: const Text('Delete everything'),
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
      showSettingsError(
        context,
        "Your memories weren't cleared. Please try again.",
      );
    } finally {
      if (mounted) {
        setState(() => _isClearingData = false);
      }
    }
  }
}
