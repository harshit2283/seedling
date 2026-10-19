import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/providers.dart';
import 'widgets/privacy_section.dart';
import 'widgets/settings_helpers.dart';
import 'widgets/settings_tiles.dart';
import 'widgets/sync_status_tile.dart';

/// What cloud sync does, in plain words. Shown at the top of the sync screen.
const String syncIntro =
    'Keep an end-to-end encrypted copy of your memories in your own iCloud '
    'or Google Drive, so your other devices can share them. Off until you '
    'allow it.';

/// Everything about cloud sync, in one place: the opt-in, the passphrase,
/// the account and backend, status, and any changes set aside.
class SyncSettingsScreen extends ConsumerWidget {
  const SyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(cloudSyncEnabledProvider);
    final passphraseSet =
        ref.watch(syncPassphraseConfiguredProvider).asData?.value ?? false;

    return SettingsSubScreen(
      title: 'Cloud sync',
      children: [
        const SettingsNote(syncIntro),
        SettingsGroup(
          footer: allowed
              ? 'Turning this off stops uploads at once. Your memories here '
                    'stay as they are.'
              : null,
          children: [
            SettingsSwitchRow(
              switchKey: const ValueKey('sync-allow-switch'),
              icon: AdaptiveIcons.cloud,
              title: 'Allow cloud sync',
              subtitle: allowed
                  ? 'You can stop it any time'
                  : 'Nothing leaves this device',
              value: allowed,
              onChanged: (value) =>
                  ref.read(cloudSyncEnabledProvider.notifier).setEnabled(value),
            ),
          ],
        ),
        if (allowed) ...[
          SettingsGroup(
            title: 'Encryption',
            children: [
              SettingsRow(
                icon: adaptiveIcon(CupertinoIcons.lock_shield, Icons.key),
                title: 'Sync passphrase',
                subtitle: passphraseSet
                    ? 'Set. Tap to change it.'
                    : 'Needed before anything syncs',
                value: passphraseSet ? null : 'Not set',
                onTap: () => _configureSyncPassphrase(context, ref),
              ),
            ],
          ),
          const SettingsGroup(
            title: 'Account & status',
            children: [SyncStatusTile()],
          ),
        ],
        SettingsNote(deviceBackupNoteSubtitle, icon: AdaptiveIcons.info),
      ],
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
      title: 'Sync passphrase',
      message:
          'Everything is encrypted with this before it leaves your '
          'device. Use the same one on each device. Keep it safe; it '
          'cannot be recovered.',
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

    try {
      if (PlatformUtils.isIOS) {
        return await showCupertinoDialog<String>(
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

      return await showDialog<String>(
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
    } finally {
      passController.dispose();
      confirmController.dispose();
    }
  }
}
