import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/notifications/gentle_reminder_service.dart';
import '../../../../core/services/providers.dart';
import 'settings_helpers.dart';

/// Settings section for gentle prompts and reminder settings.
class PromptsSection extends ConsumerStatefulWidget {
  const PromptsSection({super.key});

  @override
  ConsumerState<PromptsSection> createState() => _PromptsSectionState();
}

class _PromptsSectionState extends ConsumerState<PromptsSection> {
  @override
  Widget build(BuildContext context) {
    final reminderSettings = ref.watch(reminderSettingsProvider);

    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: const Text('Prompts'),
        children: [
          CupertinoListTile(
            leading: buildSettingsIconBox(context,
              CupertinoIcons.sparkles,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Gentle Prompts'),
            subtitle: const Text(
              'Thoughtful suggestions on the home screen',
            ),
            trailing: CupertinoSwitch(
              value: ref.watch(promptsEnabledProvider),
              activeTrackColor: SeedlingColors.forestGreen,
              onChanged: (value) {
                ref.read(promptSelectorProvider).setEnabled(value);
                // Force rebuild
                setState(() {});
              },
            ),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(context,
              CupertinoIcons.bell,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Gentle Reminder'),
            subtitle: const Text(
              'Quiet reminder when no memories are added',
            ),
            trailing: CupertinoSwitch(
              value: reminderSettings.enabled,
              activeTrackColor: SeedlingColors.forestGreen,
              onChanged: (value) {
                ref
                    .read(reminderSettingsProvider.notifier)
                    .setEnabled(value);
              },
            ),
          ),
          if (reminderSettings.enabled)
            CupertinoListTile(
              leading: buildSettingsIconBox(context,
                CupertinoIcons.calendar,
                SeedlingColors.forestGreen,
              ),
              title: const Text('Reminder cadence'),
              subtitle: Text(reminderSettings.cadence.label),
              trailing: const CupertinoListTileChevron(),
              onTap: _pickReminderCadence,
            ),
          if (reminderSettings.enabled)
            CupertinoListTile(
              leading: buildSettingsIconBox(context,
                CupertinoIcons.time,
                SeedlingColors.forestGreen,
              ),
              title: const Text('Reminder time'),
              subtitle: Text(
                _formatTime(
                  reminderSettings.hour,
                  reminderSettings.minute,
                ),
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: _pickReminderTime,
            ),
        ],
      );
    }

    return buildMaterialSection(
      context,
      title: 'Prompts',
      children: [
        buildMaterialSwitchTile(
          context,
          icon: Icons.auto_awesome,
          title: 'Gentle Prompts',
          subtitle: 'Thoughtful suggestions on the home screen',
          value: ref.watch(promptsEnabledProvider),
          onChanged: (value) {
            ref.read(promptSelectorProvider).setEnabled(value);
            setState(() {});
          },
        ),
        buildMaterialSwitchTile(
          context,
          icon: Icons.notifications_outlined,
          title: 'Gentle Reminder',
          subtitle: 'Quiet reminder if no memories are added',
          value: reminderSettings.enabled,
          onChanged: (value) {
            ref.read(reminderSettingsProvider.notifier).setEnabled(value);
          },
        ),
        if (reminderSettings.enabled)
          buildMaterialActionTile(
            context,
            icon: Icons.calendar_today_outlined,
            title: 'Reminder cadence',
            subtitle: reminderSettings.cadence.label,
            onTap: _pickReminderCadence,
          ),
        if (reminderSettings.enabled)
          buildMaterialActionTile(
            context,
            icon: Icons.access_time,
            title: 'Reminder time',
            subtitle: _formatTime(
              reminderSettings.hour,
              reminderSettings.minute,
            ),
            onTap: _pickReminderTime,
          ),
      ],
    );
  }

  String _formatTime(int hour, int minute) {
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final mm = minute.toString().padLeft(2, '0');
    return '$h12:$mm $suffix';
  }

  Future<void> _pickReminderCadence() async {
    final current = ref.read(reminderSettingsProvider);
    final selected = await showModalBottomSheet<ReminderCadence>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: ReminderCadence.values.map((cadence) {
              return ListTile(
                title: Text(cadence.label),
                trailing: cadence == current.cadence
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(cadence),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selected != null) {
      await ref.read(reminderSettingsProvider.notifier).setCadence(selected);
    }
  }

  Future<void> _pickReminderTime() async {
    final current = ref.read(reminderSettingsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    await ref
        .read(reminderSettingsProvider.notifier)
        .setTime(hour: picked.hour, minute: picked.minute);
  }
}
