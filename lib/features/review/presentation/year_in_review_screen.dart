import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/palette.dart';
import '../../../core/models/season.dart';
import '../../../core/presentation/seedling_iconography.dart';
import '../../../core/services/providers.dart';
import '../../../core/widgets/seedling_symbol.dart';
import '../../../data/models/entry.dart';
import '../../support/presentation/support_invitation_card.dart';
import '../domain/review_generator.dart';
import 'widgets/season_card.dart';
import 'widgets/theme_garden.dart';
import 'widgets/sentiment_arc.dart';
import 'widgets/shareable_card.dart';

/// A vertically scrollable year-in-review experience.
///
/// Sections:
/// 1. Opening - year title, entry count, tree symbol
/// 2. Seasons - four cards summarising each season
/// 3. Theme Garden - horizontal bars for theme distribution
/// 4. Sentiment Arc - monthly line chart
/// 5. Memorable Moments - 3-5 highlighted entries
/// 6. Closing - shareable card
///
/// The full review needs 10+ entries. Below that the screen shows what the
/// year already holds (count and a few recent memories) as a gentle
/// "still taking shape" state, never a locked gate.
class YearInReviewScreen extends ConsumerWidget {
  final int year;

  const YearInReviewScreen({super.key, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reviewDataProvider(year));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIOS = Platform.isIOS;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: isIOS
          ? CupertinoNavigationBar(
                  middle: Text('$year in Review'),
                  backgroundColor: Colors.transparent,
                  border: null,
                )
                as PreferredSizeWidget
          : AppBar(
              title: Text('$year in Review'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: data != null && data.hasEnoughEntries
          ? _ReviewBody(data: data, isDark: isDark)
          : _YearTakingShape(year: year, isDark: isDark),
    );
  }
}

// ---------------------------------------------------------------------------
// Gate: not enough entries
// ---------------------------------------------------------------------------

class _YearTakingShape extends ConsumerWidget {
  final int year;
  final bool isDark;

  const _YearTakingShape({required this.year, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild as memories are added.
    ref.watch(allEntriesStreamProvider);
    final db = ref.watch(databaseProvider);
    final count = db.getEntriesCount(year: year);
    final recent = count == 0
        ? const <Entry>[]
        : db.getEntriesPage(limit: 3, offset: 0, year: year);
    final theme = Theme.of(context);

    final String body;
    if (count == 0) {
      body =
          'Nothing planted in $year yet. Whenever you are ready, '
          'your first memory starts the story.';
    } else {
      final noun = count == 1 ? 'memory' : 'memories';
      body =
          '$count $noun planted in $year so far. Your full review '
          'blooms once a few more have taken root.';
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      physics: const BouncingScrollPhysics(),
      children: [
        const SizedBox(height: 32),
        Center(
          child: SeedlingSymbol(
            icon: SeedlingIconography.seasonIcon(Season.spring),
            size: 88,
            gradientColors: isDark
                ? [
                    SeedlingColors.surfaceContainerDark,
                    SeedlingColors.paleGreenDark,
                  ]
                : [
                    SeedlingColors.warmWhite,
                    context.palette.primaryContainer.withValues(alpha: 0.9),
                  ],
            iconColor: context.palette.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Your year is still taking shape',
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.palette.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(
            'So far',
            style: theme.textTheme.titleSmall?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...recent.map(
            (entry) => _MomentCard(
              entryId: entry.id,
              text: entry.displayContent,
              typeName: entry.typeName,
              date: entry.createdAt,
              isDark: isDark,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Full review body
// ---------------------------------------------------------------------------

class _ReviewBody extends StatelessWidget {
  final YearReviewData data;
  final bool isDark;

  const _ReviewBody({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      physics: const BouncingScrollPhysics(),
      children: [
        // ---- 1. Opening ----
        const SizedBox(height: 16),
        Center(
          child: Text(
            '${data.year}',
            style: theme.textTheme.displayLarge?.copyWith(
              color: context.palette.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: SeedlingSymbol(
            icon: SeedlingIconography.tree,
            size: 84,
            gradientColors: isDark
                ? [SeedlingColors.surfaceContainerDark, const Color(0xFF28452D)]
                : [
                    SeedlingColors.warmWhite,
                    context.palette.primaryContainer.withValues(alpha: 0.9),
                  ],
            iconColor: context.palette.primary,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'You planted ${data.totalEntries} memories',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Your tree grew into a ${data.treeStateLabel}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: context.palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (data.connectionCount > 0) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              '${data.connectionCount} connected memories',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        const SizedBox(height: 36),
        _sectionTitle(theme, 'Your seasons'),
        const SizedBox(height: 12),

        // ---- 2. Season cards ----
        _SeasonsGrid(seasons: data.seasons, isDark: isDark),

        const SizedBox(height: 36),
        _sectionTitle(theme, 'Theme garden'),
        const SizedBox(height: 12),

        // ---- 3. Theme Garden ----
        ThemeGarden(distribution: data.themeDistribution, isDark: isDark),

        const SizedBox(height: 36),
        _sectionTitle(theme, 'Sentiment arc'),
        const SizedBox(height: 12),

        // ---- 4. Sentiment Arc ----
        SentimentArc(data: data.sentimentArc, isDark: isDark),

        // ---- 5. Memorable moments ----
        if (data.memorableMoments.isNotEmpty) ...[
          const SizedBox(height: 36),
          _sectionTitle(theme, 'Memorable moments'),
          const SizedBox(height: 12),
          ...data.memorableMoments.map(
            (entry) => _MomentCard(
              entryId: entry.id,
              text: entry.displayContent,
              typeName: entry.typeName,
              date: entry.createdAt,
              isDark: isDark,
            ),
          ),
        ],

        // ---- 6. Closing / Share ----
        const SizedBox(height: 36),
        _sectionTitle(theme, 'Share your year'),
        const SizedBox(height: 12),
        ShareableCard(reviewData: data, isDark: isDark),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: () => context.push('/memories'),
          icon: const Icon(Icons.auto_stories_outlined),
          label: const Text('Browse memories'),
        ),
        // The one-time, dismissible support note. Never repeats.
        const SupportInvitationCard(),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.headlineMedium?.copyWith(
        color: theme.palette.textPrimary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Seasons 2x2 grid
// ---------------------------------------------------------------------------

class _SeasonsGrid extends StatelessWidget {
  final Map<String, SeasonData> seasons;
  final bool isDark;

  const _SeasonsGrid({required this.seasons, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const order = ['spring', 'summer', 'autumn', 'winter'];
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      children: order.map((key) {
        return SeasonCard(
          season: switch (key) {
            'spring' => Season.spring,
            'summer' => Season.summer,
            'autumn' => Season.autumn,
            _ => Season.winter,
          },
          data: seasons[key] ?? const SeasonData(name: '', entryCount: 0),
          isDark: isDark,
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Memorable moment card
// ---------------------------------------------------------------------------

class _MomentCard extends StatelessWidget {
  final int entryId;
  final String text;
  final String typeName;
  final DateTime date;
  final bool isDark;

  const _MomentCard({
    required this.entryId,
    required this.text,
    required this.typeName,
    required this.date,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateLabel = '${monthNames[date.month]} ${date.day}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push(AppRoutes.entryRoute(entryId)),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.palette.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    typeName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: context.palette.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(dateLabel, style: theme.textTheme.labelSmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                text,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
