import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/colors.dart';
import '../../../core/presentation/seedling_iconography.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/ai/models/memory_theme.dart';
import '../../../core/services/ai/models/analysis_result.dart';
import '../../../data/models/entry.dart';
import '../../review/domain/review_generator.dart';
import '../../review/presentation/widgets/sentiment_arc.dart';

/// Screen showing insights about theme distribution in memories
class ThemeInsightsScreen extends ConsumerWidget {
  const ThemeInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(collectionStatsProvider);
    final distribution = stats.themeDistribution;

    if (PlatformUtils.isIOS) {
      return _buildIOSLayout(context, ref, stats, distribution);
    }
    return _buildAndroidLayout(context, ref, stats, distribution);
  }

  Widget _buildIOSLayout(
    BuildContext context,
    WidgetRef ref,
    MemoryCollectionStats stats,
    Map<MemoryTheme, int> distribution,
  ) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGroupedBackground.withValues(
          alpha: 0.9,
        ),
        border: null,
        middle: const Text('Theme Insights'),
        leading: CupertinoNavigationBarBackButton(
          color: SeedlingColors.forestGreen,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _buildContent(context, ref, stats, distribution),
      ),
    );
  }

  Widget _buildAndroidLayout(
    BuildContext context,
    WidgetRef ref,
    MemoryCollectionStats stats,
    Map<MemoryTheme, int> distribution,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Insights'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildContent(context, ref, stats, distribution),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    MemoryCollectionStats stats,
    Map<MemoryTheme, int> distribution,
  ) {
    if (stats.totalEntries == 0) {
      return _buildEmptyState(context);
    }

    // Sort themes by count (descending)
    final sortedThemes = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Filter out themes with zero entries
    final activeThemes = sortedThemes.where((e) => e.value > 0).toList();

    final moodEnabled = ref.watch(moodVisualizationEnabledProvider);
    final allEntries = ref.watch(allEntriesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Mood Arc (flag-gated)
        if (moodEnabled) ...[
          _buildMoodArcCard(context, allEntries),
          const SizedBox(height: 24),
        ],
        // Summary card
        _buildSummaryCard(context, stats),
        const SizedBox(height: 24),
        // Theme distribution header
        Text(
          'Theme Distribution',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        // Theme bars
        ...activeThemes.map(
          (entry) => _buildThemeBar(
            context,
            entry.key,
            entry.value,
            stats.totalEntries,
          ),
        ),
        const SizedBox(height: 24),
        // Suggestions section
        if (stats.underrepresentedThemes.isNotEmpty) ...[
          Text(
            'Explore New Themes',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildSuggestionsCard(context, stats.underrepresentedThemes),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildMoodArcCard(BuildContext context, List<Entry> entries) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arcData = _computeMonthlyArc(entries);
    final entriesWithSentiment = entries
        .where((e) => e.sentimentScore != null)
        .toList();

    // Compute all-time average sentiment
    final avgSentiment = entriesWithSentiment.isEmpty
        ? 0.0
        : entriesWithSentiment
                  .map((e) => e.sentimentScore!)
                  .reduce((a, b) => a + b) /
              entriesWithSentiment.length;
    final sentimentLabel = avgSentiment > 0.25
        ? 'Generally positive'
        : avgSentiment < -0.25
        ? 'Reflective'
        : 'Balanced';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SeedlingColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SeedlingColors.softCream),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: SeedlingColors.accentVoice.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PlatformUtils.isIOS
                      ? CupertinoIcons.waveform
                      : Icons.show_chart,
                  color: SeedlingColors.accentVoice,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How your memories feel',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sentimentLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SeedlingColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (entriesWithSentiment.length >= 5) ...[
            const SizedBox(height: 16),
            SentimentArc(data: arcData, isDark: isDark, height: 140),
            const SizedBox(height: 8),
            Text(
              '${entriesWithSentiment.length} memories analysed',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: SeedlingColors.textMuted),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Capture ${5 - entriesWithSentiment.length} more memories to see your mood arc.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: SeedlingColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Compute a 12-item MonthSentiment list from all-time entries.
  List<MonthSentiment> _computeMonthlyArc(List<Entry> entries) {
    // Group by month index (0 = Jan)
    final grouped = <int, List<double>>{};
    for (final e in entries) {
      if (e.sentimentScore == null) continue;
      final monthIdx = e.createdAt.month - 1;
      grouped.putIfAbsent(monthIdx, () => []).add(e.sentimentScore!);
    }

    return List.generate(12, (i) {
      final scores = grouped[i];
      if (scores == null || scores.isEmpty) {
        return MonthSentiment(month: i + 1, averageSentiment: 0, entryCount: 0);
      }
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      return MonthSentiment(
        month: i + 1,
        averageSentiment: avg,
        entryCount: scores.length,
      );
    });
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PlatformUtils.isIOS
                  ? CupertinoIcons.chart_pie
                  : Icons.pie_chart_outline,
              size: 64,
              color: SeedlingColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No memories yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Start capturing memories to see\ntheme insights here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SeedlingColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, MemoryCollectionStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SeedlingColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SeedlingColors.softCream),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SeedlingColors.paleGreen.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  PlatformUtils.isIOS
                      ? CupertinoIcons.chart_pie
                      : Icons.pie_chart,
                  color: SeedlingColors.forestGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stats.totalEntries} memories',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${stats.entriesPerWeek.toStringAsFixed(1)} per week average',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SeedlingColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stats.dominantTheme != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Most captured theme:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SeedlingColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getThemeColor(
                      stats.dominantTheme!,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    stats.dominantTheme!.displayName,
                    style: TextStyle(
                      color: _getThemeColor(stats.dominantTheme!),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThemeBar(
    BuildContext context,
    MemoryTheme theme,
    int count,
    int total,
  ) {
    final percentage = total > 0 ? count / total : 0.0;
    final color = _getThemeColor(theme);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Icon(
                        SeedlingIconography.themeIcon(theme),
                        size: 13,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    theme.displayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '$count (${(percentage * 100).toStringAsFixed(0)}%)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: SeedlingColors.softCream,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsCard(BuildContext context, List<MemoryTheme> themes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SeedlingColors.paleGreen.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SeedlingColors.paleGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PlatformUtils.isIOS
                    ? CupertinoIcons.lightbulb
                    : Icons.lightbulb_outline,
                color: SeedlingColors.forestGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Consider capturing more:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SeedlingColors.forestGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: themes.take(5).map((theme) {
              final color = _getThemeColor(theme);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      SeedlingIconography.themeIcon(theme),
                      size: 13,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      theme.displayName,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getThemeColor(MemoryTheme theme) {
    switch (theme) {
      case MemoryTheme.family:
        return SeedlingColors.themeFamily;
      case MemoryTheme.friends:
        return SeedlingColors.themeFriends;
      case MemoryTheme.work:
        return SeedlingColors.themeWork;
      case MemoryTheme.nature:
        return SeedlingColors.themeNature;
      case MemoryTheme.gratitude:
        return SeedlingColors.themeGratitude;
      case MemoryTheme.reflection:
        return SeedlingColors.themeReflection;
      case MemoryTheme.travel:
        return SeedlingColors.themeTravel;
      case MemoryTheme.creativity:
        return SeedlingColors.themeCreativity;
      case MemoryTheme.health:
        return SeedlingColors.themeHealth;
      case MemoryTheme.food:
        return SeedlingColors.themeFood;
      case MemoryTheme.moments:
        return SeedlingColors.themeMoments;
    }
  }
}
