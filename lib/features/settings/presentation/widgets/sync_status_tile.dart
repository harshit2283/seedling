import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/services/sync/sync_backend.dart';
import '../../../../core/services/sync/sync_models.dart';

// ---------------------------------------------------------------------------
// Providers for Google Drive hardening features
// ---------------------------------------------------------------------------

/// Resolves the locked Google account email (Android only).
final _lockedAccountProvider = FutureProvider<String?>((ref) async {
  final backend = ref.watch(googleDriveSyncServiceProvider);
  return backend.lockedAccount;
});

/// Resolves how many records are currently in quarantine (Android only).
final _quarantineCountProvider = FutureProvider<int>((ref) async {
  final backend = ref.watch(googleDriveSyncServiceProvider);
  return backend.quarantineCount;
});

// ---------------------------------------------------------------------------

/// Settings tile showing cloud sync status with enable/disable toggle.
class SyncStatusTile extends ConsumerWidget {
  const SyncStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(syncEnabledProvider);
    final syncStateAsync = ref.watch(syncStateProvider);
    final providerType = ref.watch(syncProviderTypeProvider);
    final accountConnectedAsync = ref.watch(syncAccountConnectedProvider);
    final accountStatusAsync = ref.watch(syncAccountStatusProvider);
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    final syncState = syncStateAsync.asData?.value ?? SyncState.disabled;
    final accountConnected = accountConnectedAsync.asData?.value ?? false;
    final accountStatus = accountStatusAsync.asData?.value ?? 'Checking...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (Platform.isIOS) ...[
          _buildProviderPicker(context, ref, providerType, isDark),
          const SizedBox(height: 8),
        ],
        _buildAccountRow(
          context,
          ref,
          providerType,
          accountConnected,
          accountStatus,
          isDark,
        ),
        const SizedBox(height: 8),
        _buildToggle(context, ref, isEnabled, isDark),
        if (isEnabled) ...[
          const SizedBox(height: 8),
          _buildStatusRow(context, syncState, isDark),
          const SizedBox(height: 4),
          _buildLastSyncRow(context, ref, isDark),
        ],
        // Android-only hardening UI
        if (Platform.isAndroid) ...[
          _buildLockedAccountRow(context, ref, isDark),
          _buildLastErrorRow(context, ref, isDark),
          _buildQuarantineRow(context, ref, isDark),
        ],
      ],
    );
  }

  Widget _buildToggle(
    BuildContext context,
    WidgetRef ref,
    bool isEnabled,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(
          Platform.isIOS ? CupertinoIcons.cloud : Icons.cloud_queue,
          color: isEnabled
              ? SeedlingColors.forestGreen
              : SeedlingColors.textMuted,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Cloud sync',
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? SeedlingColors.textPrimaryDark
                  : SeedlingColors.textPrimary,
            ),
          ),
        ),
        Platform.isIOS
            ? CupertinoSwitch(
                value: isEnabled,
                activeTrackColor: SeedlingColors.forestGreen,
                onChanged: (value) => _toggleSync(context, ref, value),
              )
            : Switch(
                value: isEnabled,
                activeThumbColor: SeedlingColors.forestGreen,
                onChanged: (value) => _toggleSync(context, ref, value),
              ),
      ],
    );
  }

  Widget _buildProviderPicker(
    BuildContext context,
    WidgetRef ref,
    SyncProviderType selected,
    bool isDark,
  ) {
    return Row(
      children: [
        const Icon(CupertinoIcons.cloud, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Sync provider',
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? SeedlingColors.textPrimaryDark
                  : SeedlingColors.textPrimary,
            ),
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showProviderPicker(context, ref, selected),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selected.label,
                style: TextStyle(
                  fontSize: 15,
                  color: SeedlingColors.forestGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(CupertinoIcons.chevron_down, size: 14),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showProviderPicker(
    BuildContext parentContext,
    WidgetRef ref,
    SyncProviderType selected,
  ) async {
    final values = SyncProviderType.values;
    final initialIndex = values.indexOf(selected).clamp(0, values.length - 1);
    int pickedIndex = initialIndex;
    final controller = FixedExtentScrollController(initialItem: initialIndex);
    try {
      await showCupertinoModalPopup<void>(
        context: parentContext,
        builder: (sheetContext) {
          var isProcessing = false;
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                height: 260,
                color: CupertinoColors.systemBackground.resolveFrom(
                  sheetContext,
                ),
                child: Column(
                  children: [
                    Container(
                      height: 44,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: isProcessing
                            ? null
                            : () async {
                                final picked = values[pickedIndex];
                                setSheetState(() => isProcessing = true);
                                await _changeProvider(
                                  parentContext: parentContext,
                                  sheetContext: sheetContext,
                                  ref: ref,
                                  picked: picked,
                                );
                                if (sheetContext.mounted) {
                                  setSheetState(() => isProcessing = false);
                                }
                              },
                        child: Text(isProcessing ? 'Working...' : 'Done'),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 36,
                        scrollController: controller,
                        onSelectedItemChanged: (index) => pickedIndex = index,
                        children: values
                            .map(
                              (provider) => Center(
                                child: Text(
                                  provider.label,
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _buildAccountRow(
    BuildContext context,
    WidgetRef ref,
    SyncProviderType providerType,
    bool isConnected,
    String status,
    bool isDark,
  ) {
    final textColor = isDark
        ? SeedlingColors.textSecondaryDark
        : SeedlingColors.textSecondary;
    final providerName =
        Platform.isIOS && providerType == SyncProviderType.cloudKit
        ? 'CloudKit'
        : 'Google Drive';

    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$providerName: ${isConnected ? status : 'Not connected'}',
              style: TextStyle(fontSize: 12, color: textColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (providerType == SyncProviderType.googleDrive || !Platform.isIOS)
            TextButton(
              onPressed: () =>
                  _toggleAccountConnection(context, ref, isConnected),
              child: Text(isConnected ? 'Disconnect' : 'Connect'),
            ),
        ],
      ),
    );
  }

  /// Shows the locked Google account on Android with a lock icon.
  Widget _buildLockedAccountRow(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    final lockedAsync = ref.watch(_lockedAccountProvider);
    final locked = lockedAsync.asData?.value;
    if (locked == null) return const SizedBox.shrink();

    final textColor = isDark
        ? SeedlingColors.textSecondaryDark
        : SeedlingColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 8),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 14, color: textColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Locked to $locked',
              style: TextStyle(fontSize: 12, color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
            ),
            onPressed: () => _resetAccountLock(context, ref),
            child: const Text('Reset sync', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// Shows the last sync error message with timestamp.
  Widget _buildLastErrorRow(BuildContext context, WidgetRef ref, bool isDark) {
    final metadata = ref.watch(syncMetadataProvider);
    final lastError = metadata.lastError;
    final lastErrorAt = metadata.lastErrorAt;

    if (lastError == null) return const SizedBox.shrink();

    final timeLabel = lastErrorAt != null
        ? ' (${_formatTime(lastErrorAt)})'
        : '';

    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 14, color: Colors.red),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$lastError$timeLabel',
              style: const TextStyle(fontSize: 12, color: Colors.red),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows quarantine count badge and a Clear button if there are bad records.
  Widget _buildQuarantineRow(BuildContext context, WidgetRef ref, bool isDark) {
    final quarantineAsync = ref.watch(_quarantineCountProvider);
    final count = quarantineAsync.asData?.value ?? 0;
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$count quarantined record${count == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
            ),
            onPressed: () => _clearQuarantine(context, ref),
            child: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, SyncState state, bool isDark) {
    final (icon, label, color) = switch (state) {
      SyncState.idle => (
        Icons.check_circle_outline,
        'Up to date',
        SeedlingColors.forestGreen,
      ),
      SyncState.pushing => (
        Icons.cloud_upload_outlined,
        'Pushing...',
        SeedlingColors.accentVoice,
      ),
      SyncState.pulling => (
        Icons.cloud_download_outlined,
        'Pulling...',
        SeedlingColors.accentVoice,
      ),
      SyncState.merging => (
        Icons.merge_type,
        'Merging...',
        SeedlingColors.accentVoice,
      ),
      SyncState.error => (Icons.error_outline, 'Sync error', Colors.red),
      SyncState.disabled => (
        Icons.cloud_off,
        'Disabled',
        SeedlingColors.textMuted,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _buildLastSyncRow(BuildContext context, WidgetRef ref, bool isDark) {
    final metadata = ref.watch(syncMetadataProvider);
    final lastSync = metadata.lastSyncTime;

    final label = lastSync == null
        ? 'Never synced'
        : 'Last synced ${_formatTime(lastSync)}';

    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: SeedlingColors.textMuted),
      ),
    );
  }

  Future<void> _toggleSync(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    try {
      await ref.read(syncEngineProvider).setEnabled(enabled);
      ref.invalidate(syncStateProvider);
      ref.invalidate(syncAccountConnectedProvider);
      ref.invalidate(syncAccountStatusProvider);
    } catch (e) {
      if (context.mounted) {
        _showMessage(
          context,
          enabled
              ? 'Could not enable sync right now'
              : 'Could not disable sync right now',
          isError: true,
        );
      }
    }
  }

  Future<void> _toggleAccountConnection(
    BuildContext context,
    WidgetRef ref,
    bool isConnected,
  ) async {
    final backend = ref.read(syncBackendProvider);
    try {
      if (isConnected) {
        final appLockEnabled = ref.read(appLockEnabledProvider);
        if (appLockEnabled) {
          final didAuth = await ref
              .read(appLockServiceProvider)
              .authenticate(reason: 'Authenticate to change your sync account');
          if (!didAuth) return;
        }
        try {
          await backend.disconnect();
        } catch (e) {
          if (context.mounted) {
            _showMessage(
              context,
              'Could not disconnect this sync account',
              isError: true,
            );
          }
          return;
        }
        try {
          await ref.read(syncEngineProvider).setEnabled(false);
          ref.invalidate(syncStateProvider);
        } catch (e) {
          if (context.mounted) {
            _showMessage(
              context,
              'Sync was updated, but cleanup did not finish',
              isError: true,
            );
          }
        }
      } else {
        bool connected;
        try {
          connected = await backend.connect();
        } catch (e) {
          if (context.mounted) {
            _showMessage(
              context,
              'Could not connect this sync account',
              isError: true,
            );
          }
          return;
        }
        if (!connected) {
          if (context.mounted) {
            _showMessage(
              context,
              'Could not connect this sync account',
              isError: true,
            );
          }
          return;
        }
        if (ref.read(syncEnabledProvider)) {
          try {
            await ref.read(syncEngineProvider).init();
            ref.invalidate(syncStateProvider);
          } catch (e) {
            if (context.mounted) {
              _showMessage(
                context,
                'Account connected, but sync could not start',
                isError: true,
              );
            }
          }
        }
      }
    } finally {
      ref.invalidate(syncStateProvider);
      ref.invalidate(syncAccountConnectedProvider);
      ref.invalidate(syncAccountStatusProvider);
      ref.invalidate(_lockedAccountProvider);
    }
  }

  Future<void> _changeProvider({
    required BuildContext parentContext,
    required BuildContext sheetContext,
    required WidgetRef ref,
    required SyncProviderType picked,
  }) async {
    final current = ref.read(syncProviderTypeProvider);
    final wasEnabled = ref.read(syncEnabledProvider);
    if (current == picked) {
      Navigator.of(sheetContext).pop();
      return;
    }

    try {
      if (wasEnabled) {
        await ref.read(syncEngineProvider).setEnabled(false);
        ref.invalidate(syncStateProvider);
      }
      await ref.read(syncProviderTypeProvider.notifier).setProvider(picked);
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
      if (parentContext.mounted) {
        _showMessage(parentContext, 'Sync provider updated');
      }
    } catch (e) {
      if (wasEnabled) {
        try {
          await ref.read(syncEngineProvider).setEnabled(true);
          ref.invalidate(syncStateProvider);
        } catch (_) {}
      }
      if (parentContext.mounted) {
        _showMessage(
          parentContext,
          'Could not switch sync provider',
          isError: true,
        );
      }
    } finally {
      ref.invalidate(syncStateProvider);
      ref.invalidate(syncAccountConnectedProvider);
      ref.invalidate(syncAccountStatusProvider);
      ref.invalidate(_lockedAccountProvider);
    }
  }

  Future<void> _resetAccountLock(BuildContext context, WidgetRef ref) async {
    final appLockEnabled = ref.read(appLockEnabledProvider);
    if (appLockEnabled) {
      final didAuth = await ref
          .read(appLockServiceProvider)
          .authenticate(reason: 'Authenticate to reset your sync account');
      if (!didAuth) return;
    }
    final driveService = ref.read(googleDriveSyncServiceProvider);
    await driveService.resetAccountLock();
    await ref.read(syncEngineProvider).setEnabled(false);
    ref.invalidate(_lockedAccountProvider);
    ref.invalidate(syncAccountConnectedProvider);
    ref.invalidate(syncAccountStatusProvider);
  }

  Future<void> _clearQuarantine(BuildContext context, WidgetRef ref) async {
    final driveService = ref.read(googleDriveSyncServiceProvider);
    await driveService.clearQuarantine();
    ref.invalidate(_quarantineCountProvider);
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : SeedlingColors.forestGreen,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
