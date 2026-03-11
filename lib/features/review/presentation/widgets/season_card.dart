import 'package:flutter/material.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/models/season.dart';
import '../../../../core/presentation/seedling_iconography.dart';
import '../../domain/review_generator.dart';

/// Displays a single season's summary inside the year-in-review.
///
/// Shows the season emoji, name, entry count, and an optional snippet
/// from one of the entries captured that season.
class SeasonCard extends StatelessWidget {
  final Season season;

  /// The data for this season.
  final SeasonData data;

  /// Whether the host app is in dark mode.
  final bool isDark;

  const SeasonCard({
    super.key,
    required this.season,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? SeedlingColors.dividerDark : SeedlingColors.softCream,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Season icon + name
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  SeedlingIconography.seasonIcon(season),
                  size: 18,
                  color: isDark
                      ? SeedlingColors.textPrimaryDark
                      : SeedlingColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(data.name, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),

          // Entry count
          Text(
            data.entryCount == 1 ? '1 memory' : '${data.entryCount} memories',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? SeedlingColors.textSecondaryDark
                  : SeedlingColors.textSecondary,
            ),
          ),

          // Sample snippet
          if (data.sampleSnippet != null) ...[
            const SizedBox(height: 10),
            Text(
              '"${data.sampleSnippet}"',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: isDark
                    ? SeedlingColors.textMutedDark
                    : SeedlingColors.textMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Color get _backgroundColor {
    if (isDark) {
      return switch (season) {
        Season.spring => const Color(0xFF2A3A2A),
        Season.summer => const Color(0xFF3A3A2A),
        Season.autumn => const Color(0xFF3A2E2A),
        Season.winter => const Color(0xFF2A2E3A),
      };
    }
    return switch (season) {
      Season.spring => const Color(0xFFF0F8F0),
      Season.summer => const Color(0xFFFFF8F0),
      Season.autumn => const Color(0xFFFFF0E8),
      Season.winter => const Color(0xFFF0F4F8),
    };
  }
}
