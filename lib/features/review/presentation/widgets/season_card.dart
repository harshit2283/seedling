import 'package:flutter/material.dart';
import '../../../../app/theme/palette.dart';
import '../../../../app/theme/radius.dart';
import '../../../../core/models/season.dart';
import '../../../../core/presentation/seedling_iconography.dart';
import '../../domain/review_generator.dart';
import 'review_photo.dart';

/// One season of the year in review: its name, how many memories it holds
/// (unless calm mode), a small mosaic of its pictures and a line from it.
class SeasonCard extends StatelessWidget {
  final Season season;

  /// The data for this season.
  final SeasonData data;

  /// Whether the host app is in dark mode.
  final bool isDark;

  /// False in calm mode, which hides the memory count.
  final bool showCount;

  const SeasonCard({
    super.key,
    required this.season,
    required this.data,
    required this.isDark,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final tint = _tint(context);
    final quiet = data.entryCount == 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tint.withValues(alpha: isDark ? 0.10 : 0.08),
          palette.card,
        ),
        borderRadius: SeedlingRadius.card,
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                SeedlingIconography.seasonIcon(season),
                size: 18,
                color: tint,
              ),
              const SizedBox(width: 8),
              Text(
                data.name.isEmpty ? _name : data.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              const Spacer(),
              if (showCount && !quiet)
                Text(
                  data.entryCount == 1
                      ? '1 memory'
                      : '${data.entryCount} memories',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
            ],
          ),
          if (data.photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            PhotoMosaic(photos: data.photos),
          ],
          if (data.sampleSnippet != null) ...[
            const SizedBox(height: 10),
            Text(
              '“${data.sampleSnippet}”',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: palette.textSecondary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ] else if (quiet) ...[
            const SizedBox(height: 6),
            Text(
              'A quiet season.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _name => switch (season) {
    Season.spring => 'Spring',
    Season.summer => 'Summer',
    Season.autumn => 'Autumn',
    Season.winter => 'Winter',
  };

  Color _tint(BuildContext context) {
    final p = context.palette;
    return switch (season) {
      Season.spring => p.primary,
      Season.summer => p.accentGold,
      Season.autumn => p.accentVoice,
      Season.winter => p.accentPhoto,
    };
  }
}
