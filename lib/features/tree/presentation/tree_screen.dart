import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/providers.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/tree.dart';
import '../../capture/presentation/quick_capture_sheet.dart';
import '../../prompts/data/prompt_repository.dart';
import '../../prompts/presentation/prompt_card.dart';
import 'animated_tree_visualization.dart';
import 'widgets/empty_state.dart';
import 'widgets/recent_entry_preview.dart';

/// Main home screen showing the tree and recent memories
class TreeScreen extends ConsumerStatefulWidget {
  const TreeScreen({super.key});

  @override
  ConsumerState<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends ConsumerState<TreeScreen> {
  void _dismissPrompt() {
    final selector = ref.read(promptSelectorProvider);
    selector.dismissPrompt();
  }

  void _tapPrompt(GentlePrompt prompt) {
    // Record that the prompt was shown
    final selector = ref.read(promptSelectorProvider);
    selector.markPromptShown(prompt);

    // Open capture sheet with the prompt text pre-filled
    showQuickCaptureSheet(context, initialText: prompt.text);
  }

  @override
  Widget build(BuildContext context) {
    final treeState = ref.watch(treeStateProvider);
    final treeProgress = ref.watch(treeProgressProvider);
    final treeDescription = ref.watch(treeDescriptionProvider);
    final recentEntries = ref.watch(homeRecentEntriesProvider);
    final entryCount = ref.watch(entryCountProvider);
    final shouldCelebrate = ref.watch(treeGrowthEventProvider);
    final prompt = ref.watch(currentPromptProvider);

    // Activate growth detector (must be watched to work)
    ref.watch(treeGrowthDetectorProvider);

    if (PlatformUtils.isIOS) {
      return _buildIOSLayout(
        context,
        treeState: treeState,
        treeProgress: treeProgress,
        treeDescription: treeDescription,
        recentEntries: recentEntries,
        entryCount: entryCount,
        shouldCelebrate: shouldCelebrate,
        prompt: prompt,
      );
    }
    return _buildAndroidLayout(
      context,
      treeState: treeState,
      treeProgress: treeProgress,
      treeDescription: treeDescription,
      recentEntries: recentEntries,
      entryCount: entryCount,
      shouldCelebrate: shouldCelebrate,
      prompt: prompt,
    );
  }

  Widget _buildIOSLayout(
    BuildContext context, {
    required TreeState treeState,
    required double treeProgress,
    required String treeDescription,
    required List<Entry> recentEntries,
    required int entryCount,
    required bool shouldCelebrate,
    required GentlePrompt? prompt,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            _buildContent(
              context,
              treeState: treeState,
              treeProgress: treeProgress,
              treeDescription: treeDescription,
              recentEntries: recentEntries,
              entryCount: entryCount,
              shouldCelebrate: shouldCelebrate,
              prompt: prompt,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + 10,
              child: _buildPrimaryAddMemoryButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidLayout(
    BuildContext context, {
    required TreeState treeState,
    required double treeProgress,
    required String treeDescription,
    required List<Entry> recentEntries,
    required int entryCount,
    required bool shouldCelebrate,
    required GentlePrompt? prompt,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            _buildContent(
              context,
              treeState: treeState,
              treeProgress: treeProgress,
              treeDescription: treeDescription,
              recentEntries: recentEntries,
              entryCount: entryCount,
              shouldCelebrate: shouldCelebrate,
              prompt: prompt,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + 10,
              child: _buildPrimaryAddMemoryButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required TreeState treeState,
    required double treeProgress,
    required String treeDescription,
    required List<Entry> recentEntries,
    required int entryCount,
    required bool shouldCelebrate,
    required GentlePrompt? prompt,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [SeedlingColors.backgroundDark, SeedlingColors.surfaceDark]
              : [const Color(0xFFF9F8F5), const Color(0xFFF2EEE6)],
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            14,
            18,
            math.max(30, bottomInset + 16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTopBar(context),
              if (prompt != null) ...[
                const SizedBox(height: 10),
                PromptCard(
                  prompt: prompt,
                  onTap: () => _tapPrompt(prompt),
                  onDismiss: _dismissPrompt,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${DateTime.now().year}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: SeedlingColors.forestGreen,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'This year: ${_treeStageLabel(treeState)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SeedlingColors.warmBrown,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                  child: RepaintBoundary(
                    child: AnimatedTreeVisualization(
                      state: treeState,
                      progress: treeProgress,
                      celebrateGrowth: shouldCelebrate,
                      onTap: () => context.push(AppRoutes.memories),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  treeDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SeedlingColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (entryCount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '$entryCount ${entryCount == 1 ? 'memory' : 'memories'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SeedlingColors.textMuted,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (recentEntries.isEmpty)
                EmptyState(onAddTap: () => showQuickCaptureSheet(context))
              else ...[
                _buildOpenGalleryButton(context),
                const SizedBox(height: 12),
                _buildRecentEntries(context, recentEntries),
              ],
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryAddMemoryButton(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 190,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          color: SeedlingColors.forestGreen,
          borderRadius: BorderRadius.circular(24),
          onPressed: () => showQuickCaptureSheet(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(AdaptiveIcons.add, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Add Memory',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.push(AppRoutes.settings),
          icon: Icon(AdaptiveIcons.settings, color: SeedlingColors.textPrimary),
          tooltip: 'Settings',
        ),
        Expanded(
          child: Text(
            'Your Tree',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: SeedlingColors.textPrimary,
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          onPressed: () => context.push(AppRoutes.forest),
          icon: Icon(AdaptiveIcons.tree, color: SeedlingColors.textPrimary),
          tooltip: 'Forest',
        ),
      ],
    );
  }

  Widget _buildRecentEntries(BuildContext context, List<Entry> entries) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent memories',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
              PlatformUtils.isIOS
                  ? CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () => context.push(AppRoutes.memories),
                      child: Text(
                        'See all',
                        style: TextStyle(
                          color: SeedlingColors.forestGreen,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: () => context.push(AppRoutes.memories),
                      child: const Text('See all'),
                    ),
            ],
          ),
          const SizedBox(height: 4),
          ...entries
              .take(2)
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RecentEntryPreview(
                    entry: entry,
                    onTap: () => context.push(AppRoutes.entryRoute(entry.id)),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildOpenGalleryButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: PlatformUtils.isIOS
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              onPressed: () => context.push(AppRoutes.memories),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AdaptiveIcons.list,
                      color: SeedlingColors.forestGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Open Memory Gallery',
                      style: TextStyle(
                        color: SeedlingColors.forestGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.memories),
              icon: Icon(AdaptiveIcons.list, color: SeedlingColors.forestGreen),
              label: const Text('Open Memory Gallery'),
            ),
    );
  }

  String _treeStageLabel(TreeState state) {
    return switch (state) {
      TreeState.seed => 'Seed',
      TreeState.sprout => 'Sprout',
      TreeState.sapling => 'Sapling',
      TreeState.youngTree => 'Young Tree',
      TreeState.matureTree => 'Mature Tree',
      TreeState.ancientTree => 'Ancient Tree',
    };
  }
}
