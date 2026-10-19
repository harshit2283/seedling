import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/palette.dart';
import '../../../app/theme/radius.dart';
import '../../../core/presentation/seedling_iconography.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/ai/models/memory_theme.dart';
import '../../../core/services/ai/models/analysis_result.dart';

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
        middle: const Text('Themes'),
        leading: CupertinoNavigationBarBackButton(
          color: context.palette.primary,
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
        title: const Text('Themes'),
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(context, stats),
        const SizedBox(height: 28),
        Semantics(
          header: true,
          child: Text(
            'How your memories are spread',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        ...activeThemes.map(
          (entry) => _buildThemeBar(
            context,
            entry.key,
            entry.value,
            stats.totalEntries,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Themes are guessed on this device from the words you use. '
          'There is no right mix.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.palette.textMuted),
        ),
        const SizedBox(height: 40),
      ],
    );
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
              color: context.palette.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No memories yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'As your tree grows, the themes\nin your memories will show here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, MemoryCollectionStats stats) {
    final dominant = stats.dominantTheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: SeedlingRadius.card,
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          if (dominant != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getThemeColor(
                  context,
                  dominant,
                ).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                SeedlingIconography.themeIcon(dominant),
                color: _getThemeColor(context, dominant),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Text(
              dominant == null
                  ? 'Your memories hold a little of everything.'
                  : '${dominant.displayName} shows up most often in your '
                        'memories.',
              style: textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
          ),
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
    final color = _getThemeColor(context, theme);

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
                '${(percentage * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: context.palette.surfaceMuted,
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

  Color _getThemeColor(BuildContext context, MemoryTheme theme) =>
      context.palette.themeColor(theme.name);
}
