import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/palette.dart';
import '../../../app/theme/radius.dart';
import '../../../core/models/season.dart';
import '../../../core/presentation/seedling_iconography.dart';
import '../../../core/services/providers.dart';
import '../../../data/models/entry.dart';
import '../../support/presentation/support_invitation_card.dart';
import '../../tree/domain/tree_personality.dart';
import '../../tree/presentation/still_tree.dart';
import '../domain/review_generator.dart';
import 'widgets/review_photo.dart';
import 'widgets/season_card.dart';
import 'widgets/theme_garden.dart';
import 'widgets/shareable_card.dart';
import '../../../core/platform/platform_utils.dart';

const _months = [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// A vertically scrollable year in review.
///
/// Opens on the year's own tree (the same procedural tree as home, grown
/// from that year's memories), then walks through its seasons, themes and
/// a few moments, and closes with a shareable card.
///
/// A finished year is told in the past tense ("Your 2025"); the current
/// year is still taking shape. Released memories and sealed capsules never
/// resurface here. Below 10 memories the screen shows what the year holds
/// as a quiet, complete state, never a locked gate.
class YearInReviewScreen extends ConsumerWidget {
  final int year;

  /// Clock override for tests.
  final DateTime? now;

  const YearInReviewScreen({super.key, required this.year, this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reviewDataProvider(year));
    // Calm mode: the year is told without keeping score (no counts, no
    // growth-stage labels).
    final calm = ref.watch(calmModeProvider);
    final today = now ?? DateTime.now();
    final finished = year < today.year;
    // A finished year rests plain; the current one wears today's
    // personality, exactly like the tree on home.
    final personality = finished ? null : ref.watch(treePersonalityProvider);
    final isIOS = PlatformUtils.isIOS;

    final ctx = _ReviewContext(
      year: year,
      now: today,
      finished: finished,
      calm: calm,
      personality: personality,
    );

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: isIOS
          ? CupertinoNavigationBar(
                  middle: const Text('Year in review'),
                  backgroundColor: context.palette.background.withValues(
                    alpha: 0.85,
                  ),
                  border: null,
                )
                as PreferredSizeWidget
          : AppBar(
              title: const Text('Year in review'),
              backgroundColor: context.palette.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
      body: data != null && data.hasEnoughEntries
          ? _ReviewBody(data: data, ctx: ctx)
          : _QuietYear(ctx: ctx),
    );
  }
}

class _ReviewContext {
  const _ReviewContext({
    required this.year,
    required this.now,
    required this.finished,
    required this.calm,
    required this.personality,
  });

  final int year;
  final DateTime now;
  final bool finished;
  final bool calm;
  final TreePersonality? personality;

  /// The support note belongs to the close of a year: a finished one, or
  /// the current one once December arrives.
  bool get closingMoment => finished || now.month == 12;
}

// ---------------------------------------------------------------------------
// Hero: the year's tree
// ---------------------------------------------------------------------------

class _TreeHero extends StatelessWidget {
  const _TreeHero({required this.ctx, required this.count});

  final _ReviewContext ctx;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = treeStateForCount(count);
    final side = stillTreeExtent(state, 290);
    return SizedBox(
      height: math.max(side, 180),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // A soft halo so the tree sits in light, not on a flat page.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.2),
                  radius: 0.5,
                  colors: [
                    palette.primaryContainer.withValues(
                      alpha: palette.isDark ? 0.28 : 0.5,
                    ),
                    palette.background.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: side,
            height: side,
            child: StillTree.forYear(
              year: ctx.year,
              state: state,
              progress: treeProgressForCount(count),
              night: palette.isDark,
              personality: ctx.personality,
              now: ctx.now,
              semanticLabel: ctx.calm
                  ? 'The tree of ${ctx.year}'
                  : 'The tree of ${ctx.year}, a '
                        '${treeStageLabel(state).toLowerCase()}',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// A young or quiet year (fewer than 10 memories)
// ---------------------------------------------------------------------------

class _QuietYear extends ConsumerWidget {
  final _ReviewContext ctx;

  const _QuietYear({required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild as memories are added.
    ref.watch(allEntriesStreamProvider);
    final db = ref.watch(databaseProvider);
    final year = ctx.year;
    final count = db.getEntriesCount(year: year);
    final recent = count == 0
        ? const <Entry>[]
        : db
              .getEntriesPage(limit: 12, offset: 0, year: year)
              .where(isReviewable)
              .take(3)
              .toList();
    final theme = Theme.of(context);
    final palette = context.palette;
    final noun = count == 1 ? 'memory' : 'memories';

    final String title;
    final String body;
    if (ctx.finished) {
      title = 'Your $year';
      if (count == 0) {
        body = 'Nothing was planted in $year. Some years are for resting.';
      } else if (ctx.calm) {
        body = 'A quiet year, and every memory from it is still here.';
      } else {
        body = 'A quiet year: $count $noun, each one kept.';
      }
    } else {
      title = 'Your year is still taking shape';
      if (count == 0) {
        body =
            'Nothing planted in $year yet. Whenever you are ready, '
            'your first memory starts the story.';
      } else if (ctx.calm) {
        body =
            'Your $year is growing. Your full review blooms once a few '
            'more memories have taken root.';
      } else {
        body =
            '$count $noun planted in $year so far. Your full review '
            'blooms once a few more have taken root.';
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
      physics: const BouncingScrollPhysics(),
      children: [
        _TreeHero(ctx: ctx, count: count),
        const SizedBox(height: 8),
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: palette.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(
            ctx.finished ? 'From $year' : 'So far',
            style: theme.textTheme.titleSmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          for (final entry in recent) _MomentCard(entry: entry),
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
  final _ReviewContext ctx;

  const _ReviewBody({required this.data, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final calm = ctx.calm;
    final finished = ctx.finished;
    final isDark = palette.isDark;
    final stage = data.treeStateLabel.toLowerCase();

    final String headline;
    final String? subline;
    if (calm) {
      headline = finished
          ? 'The memories you kept'
          : 'The memories you are keeping';
      subline = null;
    } else if (finished) {
      headline = 'You planted ${data.totalEntries} memories';
      subline = 'By December it had grown into a $stage.';
    } else {
      headline = 'You planted ${data.totalEntries} memories';
      subline = '${_article(stage)} $stage for now, still taking shape.';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
      physics: const BouncingScrollPhysics(),
      children: [
        // ---- 1. Opening: the year's tree ----
        _TreeHero(ctx: ctx, count: data.totalEntries),
        Center(
          child: Text(
            finished ? 'Your ${data.year}' : 'Your ${data.year}, so far',
            style: theme.textTheme.displaySmall?.copyWith(
              color: palette.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            headline,
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (subline != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              subline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        if (!calm && data.connectionCount > 0) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              '${data.connectionCount} connected memories',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        // ---- 2. Seasons ----
        const SizedBox(height: 40),
        _sectionTitle(context, 'Your seasons'),
        const SizedBox(height: 12),
        for (final season in Season.values) ...[
          SeasonCard(
            season: season,
            data:
                data.seasons[season.name] ??
                const SeasonData(name: '', entryCount: 0),
            isDark: isDark,
            showCount: !calm,
          ),
          const SizedBox(height: 12),
        ],

        // ---- 3. Theme garden ----
        const SizedBox(height: 28),
        _sectionTitle(context, 'Theme garden'),
        const SizedBox(height: 12),
        ThemeGarden(
          distribution: data.themeDistribution,
          isDark: isDark,
          showCounts: !calm,
        ),

        // ---- 4. Moments ----
        if (data.memorableMoments.isNotEmpty) ...[
          const SizedBox(height: 40),
          _sectionTitle(context, 'Memorable moments'),
          const SizedBox(height: 12),
          for (final entry in data.memorableMoments) _MomentCard(entry: entry),
        ],

        // ---- 5. Closing ----
        const SizedBox(height: 40),
        _Closing(data: data, ctx: ctx),
      ],
    );
  }
}

/// "A sapling", "An ancient tree": sentence-initial article for a stage.
String _article(String stage) =>
    'aeiou'.contains(stage[0].toLowerCase()) ? 'An' : 'A';

Widget _sectionTitle(BuildContext context, String text) {
  return Semantics(
    header: true,
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(color: context.palette.textPrimary),
    ),
  );
}

class _Closing extends StatelessWidget {
  const _Closing({required this.data, required this.ctx});

  final YearReviewData data;
  final _ReviewContext ctx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final finished = ctx.finished;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShareableCard(
          reviewData: data,
          isDark: palette.isDark,
          calm: ctx.calm,
          finished: finished,
          personality: ctx.personality,
          now: ctx.now,
        ),
        const SizedBox(height: 48),
        Icon(
          SeedlingIconography.seasonIcon(Season.spring),
          size: 22,
          color: palette.primary,
        ),
        const SizedBox(height: 12),
        Text(
          finished
              ? 'Thank you for keeping ${data.year}.'
              : '${data.year} is still growing.',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: palette.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          finished
              ? 'Every memory from it stays here, whenever you want '
                    'to come back.'
              : 'Keep planting when something stays with you. Its full '
                    'story will be here when the year closes.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.textSecondary,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        // The one-time, dismissible support note belongs to a year's
        // close. It claims its showing on first mount, so it never repeats.
        if (ctx.closingMoment) const SupportInvitationCard(),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => context.push(AppRoutes.memories),
          style: TextButton.styleFrom(
            foregroundColor: palette.primary,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.auto_stories_outlined, size: 18),
          label: const Text('Browse memories'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// A single moment: a picture with its words, or the words alone
// ---------------------------------------------------------------------------

class _MomentCard extends StatelessWidget {
  final Entry entry;

  const _MomentCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final date = entry.createdAt;
    final dateLabel = '${_months[date.month]} ${date.day}';
    final picture = hasPicture(entry);
    final text = entry.displayContent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: SeedlingRadius.card,
          side: BorderSide(color: palette.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.entryRoute(entry.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (picture)
                AspectRatio(
                  aspectRatio: 3 / 2,
                  child: ReviewPhoto(
                    entry: entry,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                    if (text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        text,
                        style:
                            (picture
                                    ? theme.textTheme.bodyMedium
                                    : theme.textTheme.bodyLarge)
                                ?.copyWith(
                                  color: palette.textPrimary,
                                  height: 1.45,
                                ),
                        maxLines: picture ? 2 : 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
