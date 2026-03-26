import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import 'settings_helpers.dart';

/// Settings section for year-in-review link.
class MemoriesSection extends ConsumerWidget {
  const MemoriesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: const Text('Memories'),
        children: [
          CupertinoListTile(
            leading: buildSettingsIconBox(
              CupertinoIcons.tree,
              SeedlingColors.forestGreen,
            ),
            title: const Text('Year in Review'),
            subtitle: Text('${DateTime.now().year}'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => context.push('/review/${DateTime.now().year}'),
          ),
        ],
      );
    }

    return buildMaterialSection(
      context,
      title: 'Memories',
      children: [
        buildMaterialActionTile(
          context,
          icon: Icons.park_outlined,
          title: 'Year in Review',
          subtitle: '${DateTime.now().year}',
          onTap: () => context.push('/review/${DateTime.now().year}'),
        ),
      ],
    );
  }
}
