import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/providers.dart';
import '../../../data/models/tree.dart';

/// Forest view showing all yearly trees.
class ForestScreen extends ConsumerWidget {
  const ForestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trees = ref.watch(allTreesProvider);
    final content = trees.isEmpty
        ? _buildEmpty(context)
        : _buildForest(context, trees);

    if (PlatformUtils.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFFF5F5EF),
        child: SafeArea(child: content),
      );
    }

    return Scaffold(backgroundColor: const Color(0xFFF5F5EF), body: content);
  }

  Widget _buildEmpty(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(context, totalLeaves: 0),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Your forest will appear as the years grow.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForest(BuildContext context, List<Tree> trees) {
    final latest = trees.first;
    final totalLeaves = trees.fold<int>(
      0,
      (sum, tree) => sum + tree.entryCount,
    );

    return Column(
      children: [
        _buildTopBar(context, totalLeaves: totalLeaves),
        const SizedBox(height: 30),
        Text(
          '${latest.year}',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: SeedlingColors.textPrimary,
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          _seasonSubtitle(latest.state),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: SeedlingColors.warmBrown,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap a year to open its review',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: SeedlingColors.textMuted),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              alignment: Alignment.center,
              children: _buildCanopyCircles(context, trees),
            ),
          ),
        ),
        _buildTimeline(context, trees),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, {required int totalLeaves}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(AdaptiveIcons.back, color: SeedlingColors.textPrimary),
            tooltip: 'Back',
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: SeedlingColors.softCream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SeedlingColors.lightBark.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'The Archive',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: SeedlingColors.barkBrown,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEAE6DA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$totalLeaves leaves',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SeedlingColors.barkBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCanopyCircles(BuildContext context, List<Tree> trees) {
    final visible = trees.take(5).toList();
    const offsets = <Offset>[
      Offset(0, 0),
      Offset(-70, 30),
      Offset(70, 32),
      Offset(0, 74),
      Offset(0, -54),
    ];
    return List<Widget>.generate(visible.length, (index) {
      final tree = visible[index];
      final size = 150.0 + tree.entryCount.clamp(0, 220) * 0.25;
      final color = _stateColor(tree.state);
      return Transform.translate(
        offset: offsets[index],
        child: Semantics(
          button: true,
          label:
              '${tree.year}: ${_seasonSubtitle(tree.state)}, '
              '${tree.entryCount} memories',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(AppRoutes.yearReviewRoute(tree.year)),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${tree.year}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: SeedlingColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildTimeline(BuildContext context, List<Tree> trees) {
    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: SeedlingColors.softCream.withValues(alpha: 0.65),
        border: Border(
          top: BorderSide(
            color: SeedlingColors.lightBark.withValues(alpha: 0.18),
          ),
        ),
      ),
      child: Center(
        child: SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemBuilder: (context, index) {
              final tree = trees[index];
              final isLatest = index == 0;
              return Semantics(
                button: true,
                selected: isLatest,
                label:
                    '${tree.year}, ${isLatest ? 'current year, ' : ''}'
                    '${_seasonSubtitle(tree.state)}, ${tree.entryCount} memories',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        context.push(AppRoutes.yearReviewRoute(tree.year)),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${tree.year}',
                              style: TextStyle(
                                color: isLatest
                                    ? SeedlingColors.textPrimary
                                    : SeedlingColors.textMuted,
                                fontSize: 11,
                                fontWeight: isLatest
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 20,
                              height: 3,
                              decoration: BoxDecoration(
                                color: isLatest
                                    ? SeedlingColors.forestGreen
                                    : SeedlingColors.lightBark.withValues(
                                        alpha: 0.5,
                                      ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 18),
            itemCount: trees.length,
          ),
        ),
      ),
    );
  }

  Color _stateColor(TreeState state) {
    return switch (state) {
      TreeState.seed => SeedlingColors.seed,
      TreeState.sprout => SeedlingColors.sprout,
      TreeState.sapling => SeedlingColors.sapling,
      TreeState.youngTree => SeedlingColors.youngTree,
      TreeState.matureTree => SeedlingColors.matureTree,
      TreeState.ancientTree => SeedlingColors.ancientTree,
    };
  }

  String _seasonSubtitle(TreeState state) {
    return switch (state) {
      TreeState.seed => 'The Planting Season',
      TreeState.sprout => 'The Seeding',
      TreeState.sapling => 'The Growth',
      TreeState.youngTree => 'The Branching',
      TreeState.matureTree => 'The Flourish',
      TreeState.ancientTree => 'The Deep Roots',
    };
  }
}
