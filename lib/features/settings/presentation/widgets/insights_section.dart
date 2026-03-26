import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/services/ai/models/ritual_candidate.dart';
import 'settings_helpers.dart';

/// Settings section for theme insights and ritual patterns.
class InsightsSection extends ConsumerWidget {
  const InsightsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: const Text('Insights'),
        children: [
          CupertinoListTile(
            leading: buildSettingsIconBox(context,
              CupertinoIcons.chart_pie,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Theme Insights'),
            subtitle: const Text('See patterns in your memories'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => context.push(AppRoutes.themeInsights),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(context,
              CupertinoIcons.arrow_2_circlepath,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Ritual Patterns'),
            subtitle: const Text('View recurring memory patterns'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => _showRitualPatterns(context, ref),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(context,
              CupertinoIcons.repeat,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Manage Rituals'),
            subtitle: const Text(
              'View and manage your confirmed rituals',
            ),
            trailing: const CupertinoListTileChevron(),
            onTap: () => context.push(AppRoutes.rituals),
          ),
        ],
      );
    }

    return buildMaterialSection(
      context,
      title: 'Insights',
      children: [
        buildMaterialActionTile(
          context,
          icon: Icons.pie_chart_outline,
          title: 'Theme Insights',
          subtitle: 'See patterns in your memories',
          onTap: () => context.push(AppRoutes.themeInsights),
        ),
        buildMaterialActionTile(
          context,
          icon: Icons.autorenew,
          title: 'Ritual Patterns',
          subtitle: 'View recurring memory patterns',
          onTap: () => _showRitualPatterns(context, ref),
        ),
      ],
    );
  }

  Future<void> _showRitualPatterns(BuildContext context, WidgetRef ref) async {
    final candidates = ref.read(ritualCandidatesProvider);
    if (candidates.isEmpty) {
      showSettingsSuccess(context, 'No recurring patterns yet');
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
                          _confirmRitual(context, ref, candidate);
                        },
                        child: Text(
                          'Confirm',
                          style: TextStyle(
                            color: SeedlingColors.forestGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _confirmRitual(context, ref, candidate);
                        },
                        child: Text(
                          'Confirm',
                          style: TextStyle(color: SeedlingColors.forestGreen),
                        ),
                      ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmRitual(
    BuildContext context,
    WidgetRef ref,
    RitualCandidate candidate,
  ) async {
    final nameController = TextEditingController(
      text: candidate.signature
          .replaceAll('-', ' ')
          .replaceAll(':', ' ')
          .trim(),
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
                            color: SeedlingColors.textMuted.withValues(
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
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: SeedlingColors.textSecondary),
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
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: SeedlingColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: cadenceOptions.map((opt) {
                          final selected = cadenceDays == opt.days;
                          return ChoiceChip(
                            label: Text(opt.label),
                            selected: selected,
                            selectedColor: SeedlingColors.forestGreen
                                .withValues(alpha: 0.2),
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
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: SeedlingColors.textSecondary),
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
                                    setSheetState(
                                      () => preferredHour = dt.hour,
                                    );
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
                                color: SeedlingColors.textSecondary,
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
                                child: const Text('Create Ritual'),
                              )
                            : FilledButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: SeedlingColors.forestGreen,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text('Create Ritual'),
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

    HapticFeedback.mediumImpact();
    if (context.mounted) {
      showSettingsSuccess(context, 'Ritual created');
    }
  }
}
