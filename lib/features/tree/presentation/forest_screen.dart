import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/palette.dart';
import '../../../app/theme/radius.dart';
import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/providers.dart';
import '../../../data/models/tree.dart';
import '../../review/domain/review_generator.dart' show treeStageLabel;
import '../domain/tree_personality.dart';
import 'still_tree.dart';

/// Your forest: every year you have kept, each as a small portrait of that
/// year's actual tree (same seed, same growth as it had on home). Finished
/// years rest in late autumn; the current year shows today's season.
/// Tapping a year opens its review.
class ForestScreen extends ConsumerWidget {
  const ForestScreen({super.key, this.now});

  /// Clock override for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trees = ref.watch(allTreesProvider);
    // Calm mode: the forest is still there, it just stops keeping score
    // (no totals, no growth-stage names, no per-year counts).
    final calm = ref.watch(calmModeProvider);
    final personality = ref.watch(treePersonalityProvider);
    final today = now ?? DateTime.now();

    final view = _ForestView(
      trees: trees,
      calm: calm,
      today: today,
      currentPersonality: personality,
    );

    // Safe area on both platforms: the back button and title never sit
    // under the status bar or a notch; the list scrolls under the home
    // indicator but ends above it.
    final body = SafeArea(
      bottom: false,
      child: Column(
        children: [
          const _TopBar(),
          Expanded(child: view),
        ],
      ),
    );

    if (PlatformUtils.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: context.palette.background,
        child: Material(type: MaterialType.transparency, child: body),
      );
    }
    return Scaffold(backgroundColor: context.palette.background, body: body);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(AdaptiveIcons.back, color: context.palette.textPrimary),
            tooltip: 'Back',
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Your forest',
                textAlign: TextAlign.center,
                style:
                    (Theme.of(context).appBarTheme.titleTextStyle ??
                            Theme.of(context).textTheme.titleLarge)
                        ?.copyWith(color: context.palette.textPrimary),
              ),
            ),
          ),
          // Balances the back button so the title stays centred.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _ForestView extends StatelessWidget {
  const _ForestView({
    required this.trees,
    required this.calm,
    required this.today,
    required this.currentPersonality,
  });

  final List<Tree> trees;
  final bool calm;
  final DateTime today;
  final TreePersonality currentPersonality;

  bool _isCurrent(Tree t) => t.year >= today.year;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    if (trees.isEmpty) {
      return _FirstYear(tree: null, view: this, bottomInset: bottomInset);
    }
    final current = trees.where(_isCurrent).toList();
    final past = trees.where((t) => !_isCurrent(t)).toList();
    if (past.isEmpty) {
      return _FirstYear(
        tree: current.first,
        view: this,
        bottomInset: bottomInset,
      );
    }

    final theme = Theme.of(context);
    final palette = context.palette;
    final total = trees.fold<int>(0, (sum, t) => sum + t.entryCount);
    final years = trees.length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
            child: Text(
              calm
                  ? 'Every year you have kept, each with its own tree.'
                  : '$total memories across $years years',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        ),
        if (current.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _YearTile(tree: current.first, view: this, featured: true),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Semantics(
              header: true,
              child: Text(
                'Past years',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.textPrimary,
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 24),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: past.length,
            itemBuilder: (context, i) => _YearTile(tree: past[i], view: this),
          ),
        ),
      ],
    );
  }
}

/// One year: its tree on a soft patch of sky, its year and stage beneath.
class _YearTile extends StatelessWidget {
  const _YearTile({
    required this.tree,
    required this.view,
    this.featured = false,
  });

  final Tree tree;
  final _ForestView view;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final calm = view.calm;
    final current = view._isCurrent(tree);
    final stage = treeStageLabel(tree.state);
    final label = calm ? '${tree.year}' : '${tree.year} · $stage';
    final count = tree.entryCount == 1
        ? '1 memory'
        : '${tree.entryCount} memories';
    final semantics = [
      '${tree.year}',
      if (current) 'this year',
      if (!calm) stage,
      if (!calm) count,
      'Opens its year in review',
    ].join(', ');

    final art = LayoutBuilder(
      builder: (context, c) {
        final full = c.biggest.shortestSide;
        // In calm mode every year is drawn the same size: size would be a
        // score. Otherwise young trees stay small, as they were.
        final side = calm ? full : stillTreeExtent(tree.state, full);
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox.square(
            dimension: side,
            child: StillTree.forYear(
              year: tree.year,
              state: tree.state,
              progress: tree.progressToNextStage,
              night: palette.isDark,
              personality: current ? view.currentPersonality : null,
              now: view.today,
            ),
          ),
        );
      },
    );

    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: SeedlingRadius.card,
          side: BorderSide(color: palette.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push(AppRoutes.yearReviewRoute(tree.year));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: featured ? 0 : 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        palette.primaryContainer.withValues(
                          alpha: palette.isDark ? 0.18 : 0.45,
                        ),
                        palette.card,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                    child: featured
                        ? SizedBox(
                            height: calm
                                ? 230
                                : stillTreeExtent(
                                    tree.state,
                                    230,
                                  ).clamp(150.0, 230.0),
                            child: art,
                          )
                        : art,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Column(
                  crossAxisAlignment: featured
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    if (featured)
                      Text(
                        'This year',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: palette.primary,
                        ),
                      ),
                    Text(
                      label,
                      style:
                          (featured
                                  ? theme.textTheme.titleLarge
                                  : theme.textTheme.titleSmall)
                              ?.copyWith(color: palette.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!calm) ...[
                      const SizedBox(height: 2),
                      Text(
                        count,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                        ),
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

/// The first year (or none yet): one tree, and a calm word about how the
/// forest grows.
class _FirstYear extends StatelessWidget {
  const _FirstYear({
    required this.tree,
    required this.view,
    required this.bottomInset,
  });

  final Tree? tree;
  final _ForestView view;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final tree = this.tree;
    final year = tree?.year ?? view.today.year;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 32),
      children: [
        if (tree != null)
          Center(
            child: SizedBox(
              width: 260,
              child: _YearTile(tree: tree, view: view, featured: true),
            ),
          ),
        const SizedBox(height: 32),
        Text(
          tree == null
              ? 'Your forest begins with your first memory.'
              : 'Your forest starts here.',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'When $year closes, its tree will rest here, and a new seed '
          'will be planted for the year ahead. Year by year, a forest.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
