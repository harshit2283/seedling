import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/notifications/gentle_reminder_service.dart';
import '../../../../core/services/providers.dart';
import 'settings_tiles.dart';
import '../../../../core/util/date_labels.dart';

/// "Gentle nudges": prompts, the weekly memory, reminders and the
/// person's own capture cue.
class PromptsSection extends ConsumerStatefulWidget {
  const PromptsSection({super.key});

  @override
  ConsumerState<PromptsSection> createState() => _PromptsSectionState();
}

class _PromptsSectionState extends ConsumerState<PromptsSection> {
  @override
  Widget build(BuildContext context) {
    final reminderSettings = ref.watch(reminderSettingsProvider);
    final intention = ref.watch(captureIntentionProvider);

    return SettingsGroup(
      title: 'Gentle nudges',
      footer: 'All optional, all quiet. Seedling never counts streaks.',
      children: [
        SettingsSwitchRow(
          icon: adaptiveIcon(CupertinoIcons.sparkles, Icons.auto_awesome),
          title: 'Gentle prompts',
          subtitle: 'A soft suggestion on home',
          value: ref.watch(promptsEnabledProvider),
          onChanged: (value) {
            ref.read(promptSelectorProvider).setEnabled(value);
            ref.invalidate(promptsEnabledProvider);
          },
        ),
        SettingsSwitchRow(
          icon: adaptiveIcon(
            CupertinoIcons.leaf_arrow_circlepath,
            Icons.history_toggle_off,
          ),
          title: 'A memory from your tree',
          subtitle: 'Once a week, a quiet look back',
          value: ref.watch(resurfaceNotificationsEnabledProvider),
          onChanged: (value) => ref
              .read(resurfaceNotificationsEnabledProvider.notifier)
              .setEnabled(value),
        ),
        SettingsSwitchRow(
          icon: adaptiveIcon(CupertinoIcons.bell, Icons.notifications_none),
          title: 'Gentle reminder',
          subtitle: 'Only after a quiet stretch',
          value: reminderSettings.enabled,
          onChanged: (value) =>
              ref.read(reminderSettingsProvider.notifier).setEnabled(value),
        ),
        if (reminderSettings.enabled) ...[
          SettingsRow(
            icon: adaptiveIcon(
              CupertinoIcons.calendar,
              Icons.calendar_today_outlined,
            ),
            title: 'How often',
            value: reminderSettings.cadence.label,
            onTap: _pickReminderCadence,
          ),
          SettingsRow(
            icon: adaptiveIcon(CupertinoIcons.clock, Icons.access_time),
            title: 'Reminder time',
            value: _formatTime(reminderSettings.hour, reminderSettings.minute),
            onTap: _pickReminderTime,
          ),
        ],
        SettingsRow(
          icon: adaptiveIcon(CupertinoIcons.sun_haze, Icons.wb_twilight),
          title: 'Your moment',
          subtitle: intention ?? 'A cue for capturing, if you like',
          onTap: _editIntention,
        ),
      ],
    );
  }

  /// Edit (or clear) the optional "When I make my morning coffee" cue that
  /// the capture sheet shows as its hint.
  Future<void> _editIntention() async {
    final initial = ref.read(captureIntentionProvider) ?? '';
    final result = PlatformUtils.isIOS
        ? await showCupertinoDialog<String>(
            context: context,
            builder: (_) => _IntentionDialog(initial: initial),
          )
        : await showDialog<String>(
            context: context,
            builder: (_) => _IntentionDialog(initial: initial),
          );
    if (result == null || !mounted) return;
    await ref.read(captureIntentionProvider.notifier).set(result);
  }

  String _formatTime(int hour, int minute) =>
      DateLabels.timeOf(context, DateTime(2000, 1, 1, hour, minute));

  Future<void> _pickReminderCadence() async {
    final current = ref.read(reminderSettingsProvider);

    if (PlatformUtils.isIOS) {
      final selected = await showCupertinoModalPopup<ReminderCadence>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('How often'),
          actions: ReminderCadence.values.map((cadence) {
            return CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(cadence),
              child: Text(cadence.label),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
      if (selected != null) {
        await ref.read(reminderSettingsProvider.notifier).setCadence(selected);
      }
      return;
    }

    // Android: existing showModalBottomSheet code
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

    if (PlatformUtils.isIOS) {
      var selectedTime = TimeOfDay(hour: current.hour, minute: current.minute);
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) => Container(
          height: 250,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref
                          .read(reminderSettingsProvider.notifier)
                          .setTime(
                            hour: selectedTime.hour,
                            minute: selectedTime.minute,
                          );
                    },
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(
                    2024,
                    1,
                    1,
                    current.hour,
                    current.minute,
                  ),
                  onDateTimeChanged: (dateTime) {
                    selectedTime = TimeOfDay(
                      hour: dateTime.hour,
                      minute: dateTime.minute,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Android: existing showTimePicker code
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

/// Edits the optional capture cue. Returns the new text ('' clears it), or
/// null when dismissed.
class _IntentionDialog extends StatefulWidget {
  const _IntentionDialog({required this.initial});

  final String initial;

  @override
  State<_IntentionDialog> createState() => _IntentionDialogState();
}

class _IntentionDialogState extends State<_IntentionDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const title = Text('When do small moments find you?');
    const hint = 'e.g. With my morning coffee';
    void clear() => Navigator.of(context).pop('');
    void save() => Navigator.of(context).pop(_controller.text);

    if (PlatformUtils.isIOS) {
      return CupertinoAlertDialog(
        title: title,
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: _controller,
            placeholder: hint,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: clear, child: const Text('Clear')),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: save,
            child: const Text('Save'),
          ),
        ],
      );
    }
    return AlertDialog(
      title: title,
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: clear, child: const Text('Clear')),
        TextButton(onPressed: save, child: const Text('Save')),
      ],
    );
  }
}
