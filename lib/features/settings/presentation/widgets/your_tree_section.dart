import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/services/providers.dart';
import 'settings_tiles.dart';

/// "Your tree": how the tree is shown, and the places to look back on it.
class YourTreeSection extends ConsumerWidget {
  const YourTreeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(currentTreeProvider);
    final entryCount = ref.watch(entryCountProvider);
    final homeFeedScope = ref.watch(homeFeedScopeProvider);
    final calm = ref.watch(calmModeProvider);
    final year = DateTime.now().year;
    // Sentence case, matching the stage names used across the app.
    final rawStage = tree?.stateName ?? 'Seed';
    final stage = rawStage[0] + rawStage.substring(1).toLowerCase();

    return SettingsGroup(
      title: 'Your tree',
      children: [
        SettingsRow(
          icon: AdaptiveIcons.tree,
          title: calm ? 'Your tree' : stage,
          subtitle: calm
              ? (tree?.stateDescription ?? 'Plant your first memory')
              : '$entryCount ${entryCount == 1 ? 'memory' : 'memories'} '
                    'this year',
        ),
        SettingsSwitchRow(
          icon: AdaptiveIcons.leaf,
          title: 'Calm mode',
          subtitle: 'Hide counts and stages',
          value: calm,
          onChanged: (value) =>
              ref.read(calmModeProvider.notifier).setEnabled(value),
        ),
        SettingsSwitchRow(
          icon: AdaptiveIcons.clock,
          title: 'Show past years on home',
          value: homeFeedScope == HomeFeedScope.allYears,
          onChanged: (value) => ref
              .read(homeFeedScopeProvider.notifier)
              .setScope(
                value ? HomeFeedScope.allYears : HomeFeedScope.currentYear,
              ),
        ),
        SettingsRow(
          icon: adaptiveIcon(CupertinoIcons.book, Icons.auto_stories_outlined),
          title: 'Year in review',
          value: '$year',
          onTap: () => context.push(AppRoutes.yearReviewRoute(year)),
        ),
        SettingsRow(
          icon: adaptiveIcon(CupertinoIcons.tree, Icons.forest_outlined),
          title: 'Your forest',
          subtitle: 'Every year, side by side',
          onTap: () => context.push(AppRoutes.forest),
        ),
      ],
    );
  }
}
