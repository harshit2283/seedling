import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';

/// Settings section for memory capsules.
class CapsulesSection extends ConsumerWidget {
  const CapsulesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: const Text('Time capsules'),
        children: [
          CupertinoListTile(
            leading: _buildCapsuleIcon(),
            title: const Text('Memory Capsules'),
            subtitle: Text(_getCapsuleCountText(ref)),
            trailing: const CupertinoListTileChevron(),
            onTap: () => context.push(AppRoutes.capsules),
          ),
        ],
      );
    }

    // The original file only had a capsules section for iOS.
    return const SizedBox.shrink();
  }

  String _getCapsuleCountText(WidgetRef ref) {
    final capsules = ref.watch(capsulesProvider);
    final locked = capsules.where((c) => c.isLocked).length;
    final unlocked = capsules.where((c) => c.isUnlocked).length;
    if (capsules.isEmpty) return 'No capsules yet';
    if (locked == 0) return '$unlocked unlocked';
    if (unlocked == 0) return '$locked waiting to unlock';
    return '$locked locked, $unlocked unlocked';
  }

  Widget _buildCapsuleIcon() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: SeedlingColors.themeGratitude.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          AdaptiveIcons.leaf,
          size: 16,
          color: SeedlingColors.themeGratitude,
        ),
      ),
    );
  }
}
