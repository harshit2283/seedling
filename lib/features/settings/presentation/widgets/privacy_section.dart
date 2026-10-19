import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/services/providers.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import 'settings_helpers.dart';
import 'settings_tiles.dart';

/// Title of the note explaining that device backups skip memories.
const String deviceBackupNoteTitle = 'Keeping a copy';

/// Memories are excluded from iCloud/iTunes (and Android) device backups, so a
/// lost phone means lost memories unless the person keeps their own copy.
const String deviceBackupNoteSubtitle =
    "Device backups don't include your memories, so they stay with you. "
    'To keep a copy somewhere safe, export a backup or turn on sync.';

/// "Privacy & sync": app lock (one row, with what it changes shown only
/// while it's on), widget previews, and a single way into cloud sync.
class PrivacySection extends ConsumerWidget {
  const PrivacySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLockEnabled = ref.watch(appLockEnabledProvider);
    final widgetPreviews = ref.watch(widgetMemoryPreviewsEnabledProvider);
    final cloudSync = ref.watch(cloudSyncEnabledProvider);
    final syncActive = ref.watch(syncEnabledProvider);

    final String syncSummary;
    if (!cloudSync) {
      syncSummary = 'Off. Nothing leaves this device.';
    } else if (syncActive) {
      syncSummary = 'On, end-to-end encrypted';
    } else {
      syncSummary = 'Allowed, not set up yet';
    }

    return SettingsGroup(
      title: 'Privacy & sync',
      footer:
          'Your memories live on this device. No accounts, no ads, '
          'no tracking.',
      children: [
        SettingsSwitchRow(
          switchKey: const ValueKey('settings-app-lock'),
          icon: AdaptiveIcons.lock,
          title: 'App lock',
          subtitle: 'Face, fingerprint or passcode to open',
          value: appLockEnabled,
          onChanged: (enabled) => _toggleAppLock(context, ref, enabled),
        ),
        if (appLockEnabled)
          SettingsRow(
            icon: adaptiveIcon(
              CupertinoIcons.square_grid_2x2,
              Icons.widgets_outlined,
            ),
            title: 'Widgets stay private',
            subtitle: 'No memory text while locked',
          )
        else
          SettingsSwitchRow(
            icon: adaptiveIcon(
              CupertinoIcons.square_grid_2x2,
              Icons.widgets_outlined,
            ),
            title: 'Memory text in widgets',
            subtitle: widgetPreviews
                ? 'Widgets may show a line'
                : 'Widgets show only your tree',
            value: widgetPreviews,
            onChanged: (enabled) =>
                _toggleWidgetMemoryPreviews(context, ref, enabled),
          ),
        SettingsRow(
          key: const ValueKey('settings-cloud-sync'),
          icon: AdaptiveIcons.cloud,
          title: 'Cloud sync',
          subtitle: syncSummary,
          onTap: () => context.push(AppRoutes.settingsSync),
        ),
      ],
    );
  }

  Future<void> _toggleAppLock(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled) {
      final lockService = ref.read(appLockServiceProvider);
      final canAuth = await lockService.canAuthenticate();
      if (!canAuth) {
        if (!context.mounted) return;
        showSettingsError(
          context,
          'Device authentication is not available on this device',
        );
        return;
      }
    } else {
      final authorized = await authorizeSensitiveAction(
        ref,
        context,
        'Authenticate to disable app lock',
      );
      if (!authorized) return;
    }

    try {
      await ref.read(appLockEnabledProvider.notifier).setEnabled(enabled);
      if (enabled) {
        await ref
            .read(widgetMemoryPreviewsEnabledProvider.notifier)
            .setEnabled(false);
      }
    } catch (e) {
      if (!context.mounted) return;
      showSettingsError(
        context,
        enabled
            ? 'Could not turn on app lock right now'
            : 'Could not turn off app lock right now',
      );
      return;
    }
    if (!context.mounted) return;
    showSettingsSuccess(
      context,
      enabled ? 'App lock is on' : 'App lock is off',
    );
  }

  Future<void> _toggleWidgetMemoryPreviews(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled && ref.read(appLockEnabledProvider)) {
      showSettingsError(
        context,
        'Turn off app lock before showing memory text in widgets',
      );
      return;
    }

    await ref
        .read(widgetMemoryPreviewsEnabledProvider.notifier)
        .setEnabled(enabled);
    if (!context.mounted) return;
    showSettingsSuccess(
      context,
      enabled
          ? 'Widgets can show memory text'
          : 'Widgets keep your words private',
    );
  }
}
