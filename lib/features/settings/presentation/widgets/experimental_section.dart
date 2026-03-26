import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import 'settings_helpers.dart';

/// Settings section for experimental feature flags (mood arc, collage view).
class ExperimentalSection extends ConsumerWidget {
  const ExperimentalSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: const Text('Experimental'),
        footer: const Text('These features are in testing and may change.'),
        children: [
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              CupertinoIcons.waveform,
              SeedlingColors.accentVoice,
            ),
            title: const Text('Mood Arc'),
            subtitle: const Text('Visualize sentiment across your entries'),
            trailing: CupertinoSwitch(
              value: ref.watch(moodVisualizationEnabledProvider),
              activeTrackColor: SeedlingColors.accentVoice,
              onChanged: (v) =>
                  ref.read(moodVisualizationEnabledProvider.notifier).set(v),
            ),
          ),
          CupertinoListTile(
            leading: buildSettingsIconBox(
              context,
              CupertinoIcons.square_grid_2x2,
              SeedlingColors.accentPhoto,
            ),
            title: const Text('Memory Collage'),
            subtitle: const Text('Grid view for photo memories'),
            trailing: CupertinoSwitch(
              value: ref.watch(collageViewEnabledProvider),
              activeTrackColor: SeedlingColors.accentPhoto,
              onChanged: (v) =>
                  ref.read(collageViewEnabledProvider.notifier).set(v),
            ),
          ),
        ],
      );
    }

    // The original file only had an Experimental section for iOS.
    return const SizedBox.shrink();
  }
}
