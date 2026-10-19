import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import 'settings_helpers.dart';

/// Settings section for the master cloud-sync opt-in.
///
/// Off by default. Tapping the row (not the switch) opens a disclosure sheet
/// that explains what is uploaded, where it goes, and that nothing leaves the
/// device until enabled.
class SyncOptionalSection extends ConsumerWidget {
  const SyncOptionalSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloudSyncEnabled = ref.watch(cloudSyncEnabledProvider);
    final subtitle = cloudSyncEnabled
        ? 'On. Tap to learn more.'
        : 'Off by default. Tap to learn more.';

    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: const Text('Sync (optional)'),
        children: [
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              CupertinoIcons.cloud,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Cloud sync (optional)'),
            subtitle: Text(subtitle),
            trailing: CupertinoSwitch(
              value: cloudSyncEnabled,
              activeTrackColor: SeedlingColors.forestGreen,
              onChanged: (value) => _setEnabled(ref, value),
            ),
            onTap: () => _showDisclosure(context, ref),
          ),
        ],
      );
    }

    return buildMaterialSection(
      context,
      title: 'Sync (optional)',
      children: [
        InkWell(
          onTap: () => _showDisclosure(context, ref),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SeedlingColors.paleGreen.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    AdaptiveIcons.cloud,
                    color: SeedlingColors.forestGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud sync (optional)',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SeedlingColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: cloudSyncEnabled,
                  activeThumbColor: SeedlingColors.forestGreen,
                  onChanged: (value) => _setEnabled(ref, value),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setEnabled(WidgetRef ref, bool enabled) async {
    await ref.read(cloudSyncEnabledProvider.notifier).setEnabled(enabled);
  }

  Future<void> _showDisclosure(BuildContext context, WidgetRef ref) async {
    final isEnabled = ref.read(cloudSyncEnabledProvider);

    if (PlatformUtils.isIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (sheetContext) => _IOSDisclosureSheet(
          isEnabled: isEnabled,
          onToggle: (value) async {
            await _setEnabled(ref, value);
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          },
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => _AndroidDisclosureSheet(
          isEnabled: isEnabled,
          onToggle: (value) async {
            await _setEnabled(ref, value);
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          },
        ),
      );
    }
  }
}

const _disclosureBody = [
  'Cloud sync is off by default. While it is off, your memories never leave '
      'this device.',
  'When enabled, Seedling can back up your entries and media to your own '
      'Google Drive (or iCloud on iOS, depending on the provider you choose) '
      'in an end-to-end encrypted format.',
  'You can turn cloud sync off any time. Disabling stops uploads immediately '
      'and keeps the local copy intact.',
];

class _IOSDisclosureSheet extends StatelessWidget {
  final bool isEnabled;
  final ValueChanged<bool> onToggle;

  const _IOSDisclosureSheet({required this.isEnabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return CupertinoActionSheet(
      title: const Text('Cloud sync (optional)'),
      message: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final paragraph in _disclosureBody) ...[
              Text(
                paragraph,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => onToggle(!isEnabled),
          child: Text(isEnabled ? 'Turn cloud sync off' : 'Turn cloud sync on'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        isDefaultAction: true,
        child: const Text('Close'),
      ),
    );
  }
}

class _AndroidDisclosureSheet extends StatelessWidget {
  final bool isEnabled;
  final ValueChanged<bool> onToggle;

  const _AndroidDisclosureSheet({
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cloud sync (optional)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final paragraph in _disclosureBody) ...[
              Text(paragraph, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: () => onToggle(!isEnabled),
                  child: Text(
                    isEnabled ? 'Turn cloud sync off' : 'Turn cloud sync on',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
