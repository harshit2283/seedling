import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/palette.dart';
import '../../../app/theme/typography.dart';
import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/providers.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/tree.dart';
import '../../capture/presentation/quick_capture_sheet.dart';
import '../../prompts/data/prompt_repository.dart';
import '../../prompts/presentation/prompt_card.dart';
import 'animated_tree_visualization.dart';
import 'widgets/add_memory_button.dart';
import 'widgets/backup_reminder_card.dart';
import 'widgets/empty_state.dart';
import 'widgets/from_your_tree_card.dart';
import 'widgets/recent_entry_preview.dart';

/// The size [AnimatedTreeVisualization] paints each stage at before scaling.
double _naturalTreeSize(TreeState state) => switch (state) {
  TreeState.seed => 120,
  TreeState.sprout => 140,
  TreeState.sapling => 160,
  TreeState.youngTree => 180,
  TreeState.matureTree => 200,
  TreeState.ancientTree => 220,
};

/// The stage names shown to people (sentence case, shared vocabulary).
String treeStageName(TreeState state) => switch (state) {
  TreeState.seed => 'Seed',
  TreeState.sprout => 'Sprout',
  TreeState.sapling => 'Sapling',
  TreeState.youngTree => 'Young tree',
  TreeState.matureTree => 'Mature tree',
  TreeState.ancientTree => 'Ancient tree',
};

/// Home: this year's tree, one quiet line about it, one thing from the
/// past (or a gentle prompt), and the latest few memories.
///
/// The tree is the page. Nothing here keeps score beyond a single muted
/// count, and calm mode hides even that.
class TreeScreen extends ConsumerStatefulWidget {
  const TreeScreen({super.key});

  @override
  ConsumerState<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends ConsumerState<TreeScreen> {
  @override
  void initState() {
    super.initState();
    // Onboarding's "Add your first memory" lands here, then opens capture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      openPendingFirstCapture(context, ref);
    });
  }

  void _dismissPrompt() {
    ref.read(promptSelectorProvider).dismissPrompt();
  }

  void _tapPrompt(GentlePrompt prompt) {
    ref.read(promptSelectorProvider).markPromptShown(prompt);
    showQuickCaptureSheet(context, initialText: prompt.text);
  }

  void _addMemory() => showQuickCaptureSheet(context);

  @override
  Widget build(BuildContext context) {
    // Activate growth detector (must be watched to work)
    ref.watch(treeGrowthDetectorProvider);

    final palette = context.palette;
    final reserve = AddMemoryButton.reservedHeight(context);
    final page = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.backgroundGradientStart,
            palette.backgroundGradientEnd,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _buildScroll(context, reserve)),
          // Content dissolves into the page under the button instead of
          // being cut off by it.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: reserve * 0.8,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.backgroundGradientEnd.withValues(alpha: 0),
                      palette.backgroundGradientEnd.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (PlatformUtils.isIOS)
            Positioned(
              left: 0,
              right: 0,
              bottom: AddMemoryButton.iosBottomOffset(context),
              child: Center(child: AddMemoryButton(onPressed: _addMemory)),
            ),
        ],
      ),
    );

    if (PlatformUtils.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: page,
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AddMemoryButton(onPressed: _addMemory),
      body: page,
    );
  }

  Widget _buildScroll(BuildContext context, double reserve) {
    final treeState = ref.watch(treeStateProvider);
    final treeProgress = ref.watch(treeProgressProvider);
    final treeDescription = ref.watch(treeDescriptionProvider);
    final recentEntries = ref.watch(homeRecentEntriesProvider);
    final entryCount = ref.watch(entryCountProvider);
    final shouldCelebrate = ref.watch(treeGrowthEventProvider);
    final personality = ref.watch(treePersonalityProvider);
    final calm = ref.watch(calmModeProvider);
    final isEmpty = recentEntries.isEmpty && entryCount == 0;

    final media = MediaQuery.of(context);
    final width = media.size.width;
    final gutter = width < 360 ? 16.0 : 20.0;
    final hero = math.min(
      math.min(width - gutter * 2, 380.0),
      media.size.height * 0.46,
    );
    // The tree is the page: early stages are drawn large too, and each
    // stage still reads a little bigger than the one before.
    final treeScale =
        hero * (0.72 + 0.056 * treeState.index) / _naturalTreeSize(treeState);

    final children = <Widget>[
      _buildTopBar(context),
      SizedBox(height: isEmpty ? 24 : 4),
      RepaintBoundary(
        child: AnimatedTreeVisualization(
          state: treeState,
          progress: treeProgress,
          celebrateGrowth: shouldCelebrate,
          onTap: isEmpty ? _addMemory : () => context.push(AppRoutes.memories),
          personality: personality,
          // The stage name lives in the quiet line below, once.
          showGrowthDetails: false,
          scale: math.max(1.0, treeScale),
          padding: const EdgeInsets.symmetric(vertical: 4),
          memoryLights: recentMemoryLightCount(
            recentEntries.map((e) => e.createdAt),
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (isEmpty)
        const EmptyState()
      else
        _StageLine(
          state: treeState,
          description: treeDescription,
          count: entryCount,
          calm: calm,
        ),
    ];

    if (!isEmpty) {
      final moment = _buildMoment();
      if (moment != null) children.addAll([const SizedBox(height: 28), moment]);
      if (recentEntries.isNotEmpty) {
        children.addAll([
          const SizedBox(height: 28),
          _buildRecentEntries(context, recentEntries),
        ]);
      }
      if (ref.watch(shouldShowBackupReminderProvider)) {
        children.addAll([
          const SizedBox(height: 16),
          const BackupReminderCard(),
        ]);
      }
    }

    // The last real item carries a key so tests can check the add button
    // never covers it.
    final last = children.removeLast();
    children.add(
      KeyedSubtree(key: const ValueKey('home-last-item'), child: last),
    );

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        gutter,
        media.padding.top + 6,
        gutter,
        reserve,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// One calm element: a memory from the tree when there is one, else the
  /// gentle prompt. Never both.
  Widget? _buildMoment() {
    final dismissed = ref.watch(resurfaceDismissedTodayProvider);
    final resurfaced = dismissed ? null : ref.watch(resurfacedMemoryProvider);
    if (resurfaced != null) return const FromYourTreeCard();
    final prompt = ref.watch(currentPromptProvider);
    if (prompt == null) return null;
    return PromptCard(
      key: ValueKey('prompt-${prompt.text}'),
      prompt: prompt,
      onTap: () => _tapPrompt(prompt),
      onDismiss: _dismissPrompt,
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final color = context.palette.textSecondary;
    return Row(
      children: [
        IconButton(
          onPressed: () => context.push(AppRoutes.settings),
          icon: Icon(AdaptiveIcons.settings, color: color, size: 22),
          tooltip: 'Settings',
        ),
        Expanded(
          child: Text(
            'Your tree',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.palette.textPrimary,
              fontFamily: SeedlingTypography.serifFamily,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          onPressed: () => context.push(AppRoutes.forest),
          icon: Icon(AdaptiveIcons.tree, color: color, size: 22),
          tooltip: 'Your forest',
        ),
      ],
    );
  }

  Widget _buildRecentEntries(BuildContext context, List<Entry> entries) {
    final palette = context.palette;
    final shown = entries.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Recent',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            PlatformUtils.isIOS
                ? CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(44, 44),
                    onPressed: () => context.push(AppRoutes.memories),
                    child: Text(
                      'All memories',
                      style: TextStyle(color: palette.primary, fontSize: 15),
                    ),
                  )
                : TextButton(
                    onPressed: () => context.push(AppRoutes.memories),
                    child: const Text('All memories'),
                  ),
          ],
        ),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 52,
              color: palette.divider,
            ),
          RecentEntryPreview(
            entry: shown[i],
            onTap: () => context.push(AppRoutes.entryRoute(shown[i].id)),
          ),
        ],
      ],
    );
  }
}

/// "2026 · Sprout", what the tree is doing, and (outside calm mode) a muted
/// count. Each said once.
class _StageLine extends StatelessWidget {
  const _StageLine({
    required this.state,
    required this.description,
    required this.count,
    required this.calm,
  });

  final TreeState state;
  final String description;
  final int count;
  final bool calm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final year = '${DateTime.now().year}';
    final headline = calm ? year : '$year · ${treeStageName(state)}';
    return Column(
      children: [
        Text(
          headline,
          key: const ValueKey('home-stage-line'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: palette.textPrimary,
            fontFamily: SeedlingTypography.serifFamily,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          !calm && count > 0
              ? '$description · $count ${count == 1 ? 'memory' : 'memories'}'
              : description,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
