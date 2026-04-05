import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/widgets/glass/glass_container.dart';

/// A gentle reminder card that appears on the tree screen when the user
/// has not backed up their memories in more than 30 days.
///
/// Dismissing the card silences the reminder for another 30 days.
/// Tapping "Back up now" navigates to the settings screen where the
/// encrypted backup flow lives.
class BackupReminderCard extends ConsumerWidget {
  const BackupReminderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldShow = ref.watch(shouldShowBackupReminderProvider);
    if (!shouldShow) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brown = isDark
        ? SeedlingColors.warmBrownDark
        : SeedlingColors.warmBrown;
    final primary = isDark
        ? SeedlingColors.textPrimaryDark
        : SeedlingColors.textPrimary;
    final secondary = isDark
        ? SeedlingColors.textSecondaryDark
        : SeedlingColors.textSecondary;

    return GlassContainer(
      borderRadius: 18,
      opacity: PlatformUtils.isIOS ? 0.80 : 1.0,
      border: Border.all(color: brown.withValues(alpha: 0.25)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.cloud_outlined, color: brown, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "It's been a while since your last backup",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your memories are precious. Consider creating an encrypted backup to keep them safe.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondary),
                  ),
                  const SizedBox(height: 10),
                  _buildBackupButton(context),
                ],
              ),
            ),
            _buildDismissButton(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupButton(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        color: SeedlingColors.forestGreen,
        borderRadius: BorderRadius.circular(12),
        minimumSize: Size.zero,
        onPressed: () {
          HapticFeedback.selectionClick();
          context.push(AppRoutes.settings);
        },
        child: const Text(
          'Back up now',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        context.push(AppRoutes.settings);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: SeedlingColors.forestGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'Back up now',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDismissButton(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? SeedlingColors.textMutedDark
        : SeedlingColors.textMuted;
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        await ref.read(backupReminderServiceProvider).dismissReminder();
        // Force provider to re-evaluate after dismissal.
        ref.invalidate(shouldShowBackupReminderProvider);
      },
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          PlatformUtils.isIOS ? CupertinoIcons.xmark : Icons.close,
          color: muted,
          size: 18,
        ),
      ),
    );
  }
}
