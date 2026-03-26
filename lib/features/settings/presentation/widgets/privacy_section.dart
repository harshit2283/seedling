import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import 'sync_status_tile.dart';
import 'settings_helpers.dart';

/// Settings section for privacy, app lock, sync passphrase, and widget previews.
class PrivacySection extends ConsumerWidget {
  const PrivacySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLockEnabled = ref.watch(appLockEnabledProvider);
    final widgetMemoryPreviewsEnabled = ref.watch(
      widgetMemoryPreviewsEnabledProvider,
    );
    final syncPassphraseConfiguredAsync = ref.watch(
      syncPassphraseConfiguredProvider,
    );
    final isSyncPassphraseConfigured =
        syncPassphraseConfiguredAsync.asData?.value ?? false;

    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: const Text('Privacy'),
        children: [
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.smartphone,
              SeedlingColors.forestGreen,
            ),
            title: const Text('On your device'),
            subtitle: const Text(
              'Stored locally by default. Sync, widgets, export, and sharing are optional.',
            ),
          ),
          const CupertinoListTile(title: SyncStatusTile()),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              CupertinoIcons.square_grid_2x2,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Widget previews'),
            subtitle: Text(
              widgetMemoryPreviewsEnabled && !appLockEnabled
                  ? 'Memory text can appear in widgets'
                  : 'Aggregate-only widgets keep memory text hidden',
            ),
            trailing: CupertinoSwitch(
              value: widgetMemoryPreviewsEnabled,
              activeTrackColor: SeedlingColors.forestGreen,
              onChanged: (enabled) =>
                  _toggleWidgetMemoryPreviews(context, ref, enabled),
            ),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.lock,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Sync passphrase'),
            subtitle: Text(
              isSyncPassphraseConfigured
                  ? 'Set (tap to update)'
                  : 'Required for encrypted cloud sync',
            ),
            trailing: const CupertinoListTileChevron(),
            onTap: () => _configureSyncPassphrase(context, ref),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.lock,
              SeedlingColors.forestGreen,
            ),
            title: const Text('App Lock'),
            subtitle: Text(
              appLockEnabled ? 'Enabled' : 'Use device auth to unlock',
            ),
            trailing: CupertinoSwitch(
              value: appLockEnabled,
              activeTrackColor: SeedlingColors.forestGreen,
              onChanged: (enabled) => _toggleAppLock(context, ref, enabled),
            ),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.lock,
              SeedlingColors.forestGreen,
            ),
            title: const Text('No tracking'),
            subtitle: const Text('No analytics or data collection'),
          ),
        ],
      );
    }

    return buildMaterialSection(
      context,
      title: 'Privacy',
      children: [
        buildMaterialInfoTile(
          context,
          icon: AdaptiveIcons.smartphone,
          title: 'On your device',
          subtitle:
              'Stored locally by default. Sync, widgets, export, and sharing are optional.',
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SyncStatusTile(),
        ),
        buildMaterialInfoTile(
          context,
          icon: AdaptiveIcons.lock,
          title: 'Sync passphrase',
          subtitle: isSyncPassphraseConfigured
              ? 'Set (tap to update)'
              : 'Required for encrypted cloud sync',
        ),
        buildMaterialActionTile(
          context,
          icon: AdaptiveIcons.lock,
          title: isSyncPassphraseConfigured
              ? 'Update Sync Passphrase'
              : 'Set Sync Passphrase',
          subtitle: 'Used for end-to-end encrypted sync payloads',
          onTap: () => _configureSyncPassphrase(context, ref),
        ),
        buildMaterialInfoTile(
          context,
          icon: AdaptiveIcons.lock,
          title: 'App Lock',
          subtitle: appLockEnabled ? 'Enabled' : 'Use device auth to unlock',
        ),
        buildMaterialSwitchTile(
          context,
          icon: AdaptiveIcons.lock,
          title: 'Enable App Lock',
          subtitle: 'Uses device biometrics/passcode',
          value: appLockEnabled,
          onChanged: (enabled) => _toggleAppLock(context, ref, enabled),
        ),
        buildMaterialSwitchTile(
          context,
          icon: Icons.widgets_outlined,
          title: 'Widget memory previews',
          subtitle: widgetMemoryPreviewsEnabled && !appLockEnabled
              ? 'Memory text may appear in widgets'
              : 'Widgets show aggregate-only details',
          value: widgetMemoryPreviewsEnabled,
          onChanged: (enabled) =>
              _toggleWidgetMemoryPreviews(context, ref, enabled),
        ),
        buildMaterialInfoTile(
          context,
          icon: AdaptiveIcons.lock,
          title: 'No tracking',
          subtitle: 'No analytics or data collection',
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
      if (enabled) {
        await ref
            .read(widgetMemoryPreviewsEnabledProvider.notifier)
            .setEnabled(false);
      }
      await ref.read(appLockEnabledProvider.notifier).setEnabled(enabled);
    } catch (e) {
      if (!context.mounted) return;
      showSettingsError(
        context,
        enabled
            ? 'Could not enable App Lock right now'
            : 'Could not disable App Lock right now',
      );
      return;
    }
    if (!context.mounted) return;
    showSettingsSuccess(
      context,
      enabled ? 'App lock enabled' : 'App lock disabled',
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
        'Disable App Lock before showing memory previews in widgets',
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
          ? 'Widget previews enabled'
          : 'Widget previews hidden for privacy',
    );
  }

  Future<void> _configureSyncPassphrase(
    BuildContext context,
    WidgetRef ref,
  ) async {
    HapticFeedback.selectionClick();
    final authorized = await authorizeSensitiveAction(
      ref,
      context,
      'Authenticate to change your sync passphrase',
    );
    if (!authorized) return;
    if (!context.mounted) return;
    final passphrase = await _promptForPassphrase(
      context,
      title: 'Sync Passphrase',
      message: 'Set or update the passphrase used to encrypt sync payloads.',
      confirm: true,
    );
    if (passphrase == null || passphrase.isEmpty) {
      return;
    }

    try {
      await ref.read(syncCryptoServiceProvider).setPassphrase(passphrase);
      ref.invalidate(syncPassphraseConfiguredProvider);
      if (!context.mounted) return;
      showSettingsSuccess(context, 'Sync passphrase saved');
    } catch (e) {
      if (!context.mounted) return;
      showSettingsError(context, e.toString());
    }
  }

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
}
