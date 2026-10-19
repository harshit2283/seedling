import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/ai/models/memory_theme.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/services/ai/models/ritual_candidate.dart';
import 'settings_helpers.dart';

/// Settings section for theme insights and ritual patterns.
class InsightsSection extends ConsumerStatefulWidget {
  const InsightsSection({super.key});

  @override
  ConsumerState<InsightsSection> createState() => _InsightsSectionState();
}

class _InsightsSectionState extends ConsumerState<InsightsSection> {
  bool _themePreviewExpanded = false;

  void _toggleThemePreview() {
    HapticFeedback.selectionClick();
    setState(() => _themePreviewExpanded = !_themePreviewExpanded);
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: const Text('Insights'),
        children: [
          _buildThemeInsightsRowIOS(context),
          if (_themePreviewExpanded) _buildThemePreviewTile(context),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              CupertinoIcons.arrow_2_circlepath,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Ritual Patterns'),
            subtitle: const Text('View recurring memory patterns'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => _showRitualPatterns(context),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              CupertinoIcons.repeat,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Manage Rituals'),
            subtitle: const Text('View and manage your confirmed rituals'),
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
        _buildThemeInsightsRowMaterial(context),
        if (_themePreviewExpanded) _buildThemePreviewTile(context),
        buildMaterialActionTile(
          context,
          icon: Icons.autorenew,
          title: 'Ritual Patterns',
          subtitle: 'View recurring memory patterns',
          onTap: () => _showRitualPatterns(context),
        ),
      ],
    );
  }

  Widget _buildThemeInsightsRowIOS(BuildContext context) {
    return CupertinoListTile(
      leading: buildSettingsIconBox(
        context,
        CupertinoIcons.chart_pie,
        SeedlingColors.forestGreen,
      ),
      title: const Text('Theme Insights'),
      subtitle: const Text('See patterns in your memories'),
      trailing: AnimatedRotation(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        turns: _themePreviewExpanded ? 0.25 : 0,
        child: const Icon(
          CupertinoIcons.chevron_right,
          size: 18,
          color: CupertinoColors.systemGrey,
        ),
      ),
      onTap: _toggleThemePreview,
    );
  }

  Widget _buildThemeInsightsRowMaterial(BuildContext context) {
    return ListTile(
      leading: buildSettingsIconBox(
        context,
        Icons.pie_chart_outline,
        SeedlingColors.forestGreen,
      ),
      title: const Text('Theme Insights'),
      subtitle: const Text('See patterns in your memories'),
      trailing: AnimatedRotation(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        turns: _themePreviewExpanded ? 0.25 : 0,
        child: const Icon(Icons.chevron_right, color: SeedlingColors.textMuted),
      ),
      onTap: _toggleThemePreview,
    );
  }

  Widget _buildThemePreviewTile(BuildContext context) {
    final counts = ref.watch(memoryThemeCountsProvider);
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    if (total == 0) {
      final emptyText = Text(
        'Capture a few memories to see theme patterns.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: SeedlingColors.textMuted),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Align(alignment: Alignment.centerLeft, child: emptyText),
      );
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in top)
            _ThemeBarRow(theme: entry.key, count: entry.value, total: total),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: PlatformUtils.isIOS
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => context.push(AppRoutes.themeInsights),
                    child: Text(
                      'Open full insights',
                      style: TextStyle(
                        color: SeedlingColors.forestGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: () => context.push(AppRoutes.themeInsights),
                    child: Text(
                      'Open full insights',
                      style: TextStyle(color: SeedlingColors.forestGreen),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRitualPatterns(BuildContext context) async {
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
                          _confirmRitual(context, candidate);
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
                          _confirmRitual(context, candidate);
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

    HapticFeedback.lightImpact();
    if (context.mounted) {
      showSettingsSuccess(context, 'Ritual created');
    }
  }
}

/// A single horizontal bar showing a theme name, a colored fill, and percent.
class _ThemeBarRow extends StatelessWidget {
  final MemoryTheme theme;
  final int count;
  final int total;

  const _ThemeBarRow({
    required this.theme,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    final percent = (fraction * 100).round();
    final color = _colorFor(context, theme);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  theme.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SeedlingColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SeedlingColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: 6,
                      width: constraints.maxWidth,
                      color: Theme.of(context).dividerColor,
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => Container(
                        height: 6,
                        width: constraints.maxWidth * t,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(BuildContext context, MemoryTheme theme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return switch (theme) {
        MemoryTheme.family => SeedlingColors.themeFamilyDark,
        MemoryTheme.friends => SeedlingColors.themeFriendsDark,
        MemoryTheme.work => SeedlingColors.themeWorkDark,
        MemoryTheme.nature => SeedlingColors.themeNatureDark,
        MemoryTheme.gratitude => SeedlingColors.themeGratitudeDark,
        MemoryTheme.reflection => SeedlingColors.themeReflectionDark,
        MemoryTheme.travel => SeedlingColors.themeTravelDark,
        MemoryTheme.creativity => SeedlingColors.themeCreativityDark,
        MemoryTheme.health => SeedlingColors.themeHealthDark,
        MemoryTheme.food => SeedlingColors.themeFoodDark,
        MemoryTheme.moments => SeedlingColors.themeMomentsDark,
      };
    }
    return switch (theme) {
      MemoryTheme.family => SeedlingColors.themeFamily,
      MemoryTheme.friends => SeedlingColors.themeFriends,
      MemoryTheme.work => SeedlingColors.themeWork,
      MemoryTheme.nature => SeedlingColors.themeNature,
      MemoryTheme.gratitude => SeedlingColors.themeGratitude,
      MemoryTheme.reflection => SeedlingColors.themeReflection,
      MemoryTheme.travel => SeedlingColors.themeTravel,
      MemoryTheme.creativity => SeedlingColors.themeCreativity,
      MemoryTheme.health => SeedlingColors.themeHealth,
      MemoryTheme.food => SeedlingColors.themeFood,
      MemoryTheme.moments => SeedlingColors.themeMoments,
    };
  }
}
