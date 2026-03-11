import 'package:flutter/material.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/presentation/seedling_iconography.dart';
import '../../../../core/services/ai/models/memory_theme.dart';

/// Horizontal bar chart visualising the theme distribution for a year.
///
/// Each [MemoryTheme] with at least one entry is shown as a labelled bar
/// proportional to the maximum theme count.
class ThemeGarden extends StatelessWidget {
  /// Theme -> count mapping.
  final Map<MemoryTheme, int> distribution;

  /// Whether the host app is in dark mode.
  final bool isDark;

  const ThemeGarden({
    super.key,
    required this.distribution,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Sort descending by count, skip themes with 0 entries.
    final sorted = distribution.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) {
      return Text(
        'No themes detected yet.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isDark
              ? SeedlingColors.textMutedDark
              : SeedlingColors.textMuted,
        ),
      );
    }

    final maxCount = sorted.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ThemeBar(
              theme: entry.key,
              count: entry.value,
              maxCount: maxCount,
              isDark: isDark,
            ),
          ),
      ],
    );
  }
}

class _ThemeBar extends StatelessWidget {
  final MemoryTheme theme;
  final int count;
  final int maxCount;
  final bool isDark;

  const _ThemeBar({
    required this.theme,
    required this.count,
    required this.maxCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount > 0 ? count / maxCount : 0.0;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        // Icon + label (fixed width)
        SizedBox(
          width: 110,
          child: Row(
            children: [
              Icon(
                SeedlingIconography.themeIcon(theme),
                size: 15,
                color: _themeColor(theme),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  theme.displayName,
                  style: textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Bar
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth * fraction;
              return Stack(
                children: [
                  // Track
                  Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: isDark
                          ? SeedlingColors.surfaceContainerDark
                          : SeedlingColors.softCream,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  // Fill
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    height: 18,
                    width: barWidth.clamp(0, constraints.maxWidth),
                    decoration: BoxDecoration(
                      color: _themeColor(theme),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 8),

        // Count
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            style: textTheme.bodySmall,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Color _themeColor(MemoryTheme theme) {
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
