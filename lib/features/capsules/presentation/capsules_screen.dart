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
import '../../capture/presentation/quick_capture_sheet.dart';
import 'widgets/capsule_card.dart';

/// Screen for viewing all memory capsules (locked and unlocked)
class CapsulesScreen extends ConsumerWidget {
  const CapsulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capsules = ref.watch(capsulesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (PlatformUtils.isIOS) {
      return _buildIOSLayout(context, ref, capsules, isDark);
    }
    return _buildAndroidLayout(context, ref, capsules, isDark);
  }

  Widget _buildIOSLayout(
    BuildContext context,
    WidgetRef ref,
    List<Entry> capsules,
    bool isDark,
  ) {
    final backgroundColor = isDark
        ? SeedlingColors.backgroundDark
        : CupertinoColors.systemGroupedBackground;

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark
            ? SeedlingColors.surfaceDark.withValues(alpha: 0.9)
            : CupertinoColors.systemGroupedBackground.withValues(alpha: 0.9),
        border: null,
        middle: Text(
          'Memory Capsules',
          style: TextStyle(
            color: isDark
                ? SeedlingColors.textPrimaryDark
                : SeedlingColors.textPrimary,
          ),
        ),
        leading: CupertinoNavigationBarBackButton(
          color: isDark
              ? SeedlingColors.forestGreenDark
              : SeedlingColors.forestGreen,
          onPressed: () => context.pop(),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _openCapsuleCapture(context),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        top: false,
        child: capsules.isEmpty
            ? _buildEmptyState(context, isDark)
            : _buildCapsulesList(context, ref, capsules, isDark),
      ),
    );
  }

  Widget _buildAndroidLayout(
    BuildContext context,
    WidgetRef ref,
    List<Entry> capsules,
    bool isDark,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Capsules'),
        leading: IconButton(
          icon: Icon(AdaptiveIcons.back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openCapsuleCapture(context),
            tooltip: 'Create capsule',
          ),
        ],
      ),
      body: capsules.isEmpty
          ? _buildEmptyState(context, isDark)
          : _buildCapsulesList(context, ref, capsules, isDark),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final textPrimary = isDark
        ? SeedlingColors.textPrimaryDark
        : SeedlingColors.textPrimary;
    final textSecondary = isDark
        ? SeedlingColors.textSecondaryDark
        : SeedlingColors.textSecondary;
    final textMuted = isDark
        ? SeedlingColors.textMutedDark
        : SeedlingColors.textMuted;
    final accentColor = isDark
        ? SeedlingColors.paleGreenDark
        : SeedlingColors.paleGreen;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  PlatformUtils.isIOS
                      ? CupertinoIcons.archivebox
                      : Icons.inventory_2_outlined,
                  size: 44,
                  color: SeedlingColors.forestGreen,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Memory Capsules',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'Create a memory capsule to send\na message to your future self.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap Create capsule to start\na new Time Capsule.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PlatformUtils.isIOS
                ? CupertinoButton.filled(
                    onPressed: () => _openCapsuleCapture(context),
                    child: const Text('Create capsule'),
                  )
                : FilledButton.icon(
                    onPressed: () => _openCapsuleCapture(context),
                    icon: const Icon(Icons.lock_clock_outlined),
                    label: const Text('Create capsule'),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsulesList(
    BuildContext context,
    WidgetRef ref,
    List<Entry> capsules,
    bool isDark,
  ) {
    final lockedCapsules = capsules.where((c) => c.isLocked).toList();
    final unlockedCapsules = capsules.where((c) => c.isUnlocked).toList();

    final textPrimary = isDark
        ? SeedlingColors.textPrimaryDark
        : SeedlingColors.textPrimary;
    final textSecondary = isDark
        ? SeedlingColors.textSecondaryDark
        : SeedlingColors.textSecondary;
    final accentColor = isDark
        ? SeedlingColors.forestGreenDark
        : SeedlingColors.forestGreen;

    return CustomScrollView(
      slivers: [
        // Info banner
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    PlatformUtils.isIOS
                        ? CupertinoIcons.archivebox
                        : Icons.inventory_2_outlined,
                    size: 22,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Messages to your future self',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Capsules unlock on their scheduled date.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Locked section
        if (lockedCapsules.isNotEmpty) ...[
          _buildSectionHeader(context, 'Locked', lockedCapsules.length, isDark),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CapsuleCard(
                    entry: lockedCapsules[index],
                    isDark: isDark,
                  ),
                ),
                childCount: lockedCapsules.length,
              ),
            ),
          ),
        ],

        // Unlocked section
        if (unlockedCapsules.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            'Unlocked',
            unlockedCapsules.length,
            isDark,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CapsuleCard(
                    entry: unlockedCapsules[index],
                    isDark: isDark,
                    onTap: () => context.push(
                      AppRoutes.entryRoute(unlockedCapsules[index].id),
                    ),
                  ),
                ),
                childCount: unlockedCapsules.length,
              ),
            ),
          ),
        ],

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int count,
    bool isDark,
  ) {
    final textSecondary = isDark
        ? SeedlingColors.textSecondaryDark
        : SeedlingColors.textSecondary;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Semantics(
              header: true,
              label: title,
              excludeSemantics: true,
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCapsuleCapture(BuildContext context) {
    showQuickCaptureSheet(context, startAsCapsule: true);
  }
}
