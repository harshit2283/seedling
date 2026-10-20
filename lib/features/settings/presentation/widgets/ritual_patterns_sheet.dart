import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/palette.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/services/ai/models/ritual_candidate.dart';
import 'settings_helpers.dart';

/// Shows recurring patterns Seedling has noticed, each with a "Confirm"
/// that turns it into a ritual.
Future<void> showRitualPatterns(BuildContext context, WidgetRef ref) async {
  final candidates = ref.read(ritualCandidatesProvider);
  if (candidates.isEmpty) {
    showSettingsSuccess(
      context,
      'Nothing recurring yet. Patterns appear as your tree grows.',
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: candidates.length.clamp(0, 12),
          itemBuilder: (context, index) {
            final candidate = candidates[index];
            return ListTile(
              leading: const Icon(Icons.autorenew),
              title: Text(candidate.signature.replaceAll(':', ' • ')),
              subtitle: Text(
                '${candidate.occurrences} times • '
                '${candidate.spanDays} day span • '
                'last ${candidate.daysSinceLastSeen}d ago',
              ),
              trailing: PlatformUtils.isIOS
                  ? CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        confirmRitualCandidate(context, ref, candidate);
                      },
                      child: Text(
                        'Confirm',
                        style: TextStyle(
                          color: context.palette.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        confirmRitualCandidate(context, ref, candidate);
                      },
                      child: Text(
                        'Confirm',
                        style: TextStyle(color: context.palette.primary),
                      ),
                    ),
            );
          },
        ),
      );
    },
  );
}

Future<void> confirmRitualCandidate(
  BuildContext context,
  WidgetRef ref,
  RitualCandidate candidate,
) async {
  final nameController = TextEditingController(
    text: candidate.signature.replaceAll('-', ' ').replaceAll(':', ' ').trim(),
  );
  int cadenceDays = 7;
  int preferredHour = 9;

  final cadenceOptions = [
    (label: 'Daily', days: 1),
    (label: 'Every 3 days', days: 3),
    (label: 'Weekly', days: 7),
    (label: 'Biweekly', days: 14),
  ];

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: PlatformUtils.isIOS
                  ? CupertinoColors.systemBackground.darkColor.withValues(
                      alpha: 0.95,
                    )
                  : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.palette.textMuted.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create ritual',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Name field
                    Text(
                      'Name',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    PlatformUtils.isIOS
                        ? CupertinoTextField(
                            controller: nameController,
                            placeholder: 'Ritual name',
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).dividerColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          )
                        : TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              hintText: 'Ritual name',
                              filled: true,
                              fillColor: Theme.of(context).dividerColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                    const SizedBox(height: 20),
                    // Cadence picker
                    Text(
                      'Cadence',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: cadenceOptions.map((opt) {
                        final selected = cadenceDays == opt.days;
                        return ChoiceChip(
                          label: Text(opt.label),
                          selected: selected,
                          selectedColor: context.palette.primaryFill.withValues(
                            alpha: 0.2,
                          ),
                          onSelected: (_) {
                            setSheetState(() => cadenceDays = opt.days);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Preferred hour
                    Text(
                      'Reminder time',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        if (PlatformUtils.isIOS) {
                          await showCupertinoModalPopup<void>(
                            context: context,
                            builder: (_) => Container(
                              height: 216,
                              color: CupertinoColors.systemBackground
                                  .resolveFrom(context),
                              child: CupertinoDatePicker(
                                mode: CupertinoDatePickerMode.time,
                                initialDateTime: DateTime(
                                  2024,
                                  1,
                                  1,
                                  preferredHour,
                                ),
                                onDateTimeChanged: (dt) {
                                  setSheetState(() => preferredHour = dt.hour);
                                },
                              ),
                            ),
                          );
                        } else {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: preferredHour,
                              minute: 0,
                            ),
                          );
                          if (picked != null) {
                            setSheetState(() => preferredHour = picked.hour);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              PlatformUtils.isIOS
                                  ? CupertinoIcons.clock
                                  : Icons.access_time,
                              size: 18,
                              color: context.palette.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${preferredHour.toString().padLeft(2, '0')}:00',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Create button
                    SizedBox(
                      width: double.infinity,
                      child: PlatformUtils.isIOS
                          ? CupertinoButton.filled(
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(true),
                              child: const Text('Create ritual'),
                            )
                          : FilledButton(
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: context.palette.primaryFill,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text('Create ritual'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  if (confirmed != true) {
    nameController.dispose();
    return;
  }

  final name = nameController.text.trim();
  nameController.dispose();

  await ref
      .read(ritualServiceProvider)
      .createFromCandidate(
        candidate,
        name: name,
        cadenceDays: cadenceDays,
        preferredHour: preferredHour,
      );

  HapticFeedback.lightImpact();
  if (context.mounted) {
    showSettingsSuccess(context, 'Ritual created');
  }
}
