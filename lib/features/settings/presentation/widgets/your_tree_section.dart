import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/palette.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import 'settings_helpers.dart';

/// Settings section showing tree state, entry count, and feed scope toggle.
class YourTreeSection extends ConsumerWidget {
  const YourTreeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryCount = ref.watch(entryCountProvider);
    final tree = ref.watch(currentTreeProvider);
    final homeFeedScope = ref.watch(homeFeedScopeProvider);
    final calm = ref.watch(calmModeProvider);
    const calmTitle = 'Calm mode';
    const calmSubtitle = 'Hide counts and stages. Your tree still grows.';

    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: const Text('Your tree'),
        children: [
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.tree,
              context.palette.primary,
            ),
            title: Text(calm ? 'Your tree' : (tree?.stateName ?? 'Seed')),
            subtitle: Text(tree?.stateDescription ?? 'Plant your first memory'),
          ),
          if (!calm)
            CupertinoListTile(
              leading: buildSettingsIconBox(
                context,
                AdaptiveIcons.list,
                context.palette.primary,
              ),
              title: Text('$entryCount memories'),
              subtitle: const Text('This year'),
            ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.leaf,
              context.palette.primary,
            ),
            title: const Text(calmTitle),
            subtitle: const Text(calmSubtitle),
            trailing: CupertinoSwitch(
              value: calm,
              activeTrackColor: context.palette.primary,
              onChanged: (value) =>
                  ref.read(calmModeProvider.notifier).setEnabled(value),
            ),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.clock,
              context.palette.primary,
            ),
            title: const Text('Show past years on home'),
            subtitle: Text(
              homeFeedScope == HomeFeedScope.allYears
                  ? 'All years'
                  : 'Current year only',
            ),
            trailing: CupertinoSwitch(
              value: homeFeedScope == HomeFeedScope.allYears,
              activeTrackColor: context.palette.primaryFill,
              onChanged: (value) {
                ref
                    .read(homeFeedScopeProvider.notifier)
                    .setScope(
                      value
                          ? HomeFeedScope.allYears
                          : HomeFeedScope.currentYear,
                    );
              },
            ),
          ),
        ],
      );
    }

    return buildMaterialSection(
      context,
      title: 'Your Tree',
      children: [
        buildMaterialInfoTile(
          context,
          icon: AdaptiveIcons.tree,
          title: calm ? 'Your tree' : (tree?.stateName ?? 'Seed'),
          subtitle: tree?.stateDescription ?? 'Plant your first memory',
        ),
        if (!calm)
          buildMaterialInfoTile(
            context,
            icon: AdaptiveIcons.list,
            title: '$entryCount memories',
            subtitle: 'This year',
          ),
        buildMaterialSwitchTile(
          context,
          icon: AdaptiveIcons.leaf,
          title: calmTitle,
          subtitle: calmSubtitle,
          value: calm,
          onChanged: (value) =>
              ref.read(calmModeProvider.notifier).setEnabled(value),
        ),
        buildMaterialSwitchTile(
          context,
          icon: AdaptiveIcons.clock,
          title: 'Show past years on home',
          subtitle: homeFeedScope == HomeFeedScope.allYears
              ? 'All years'
              : 'Current year only',
          value: homeFeedScope == HomeFeedScope.allYears,
          onChanged: (value) {
            ref
                .read(homeFeedScopeProvider.notifier)
                .setScope(
                  value ? HomeFeedScope.allYears : HomeFeedScope.currentYear,
                );
          },
        ),
      ],
    );
  }
}
