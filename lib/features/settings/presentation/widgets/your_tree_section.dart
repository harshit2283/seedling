import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/colors.dart';
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

    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: const Text('Your tree'),
        children: [
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.tree,
              SeedlingColors.forestGreen,
            ),
            title: Text(tree?.stateName ?? 'Seed'),
            subtitle: Text(tree?.stateDescription ?? 'Plant your first memory'),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.list,
              SeedlingColors.forestGreen,
            ),
            title: Text('$entryCount memories'),
            subtitle: const Text('This year'),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              AdaptiveIcons.clock,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Show past years on home'),
            subtitle: Text(
              homeFeedScope == HomeFeedScope.allYears
                  ? 'All years'
                  : 'Current year only',
            ),
            trailing: CupertinoSwitch(
              value: homeFeedScope == HomeFeedScope.allYears,
              activeTrackColor: SeedlingColors.forestGreen,
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
          title: tree?.stateName ?? 'Seed',
          subtitle: tree?.stateDescription ?? 'Plant your first memory',
        ),
        buildMaterialInfoTile(
          context,
          icon: AdaptiveIcons.list,
          title: '$entryCount memories',
          subtitle: 'This year',
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
