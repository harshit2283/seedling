import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../data/models/entry.dart';

/// Card displaying a memory capsule - locked or unlocked state
class CapsuleCard extends StatelessWidget {
  final Entry entry;
  final bool isDark;
  final VoidCallback? onTap;

  const CapsuleCard({
    super.key,
    required this.entry,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = entry.isLocked;

    if (isLocked) {
      return _buildLockedCard(context);
    }
    return _buildUnlockedCard(context);
  }

  Widget _buildLockedCard(BuildContext context) {
    final cardColor = isDark
        ? SeedlingColors.cardDark
        : SeedlingColors.warmWhite;
    final borderColor = isDark
        ? SeedlingColors.dividerDark
        : SeedlingColors.softCream;
    final textPrimary = isDark
        ? SeedlingColors.textPrimaryDark
        : SeedlingColors.textPrimary;
    final textSecondary = isDark
        ? SeedlingColors.textSecondaryDark
        : SeedlingColors.textSecondary;
    final textMuted = isDark
        ? SeedlingColors.textMutedDark
        : SeedlingColors.textMuted;

    return Semantics(
      label:
          'Locked time capsule. ${entry.unlockTimeDescription}. '
          'Unlocks on ${_formatUnlockDate(entry.capsuleUnlockDate!)}.',
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            // Main content area
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Lock icon with countdown
                  _buildLockIndicator(context),
                  const SizedBox(width: 16),
                  // Info section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time Capsule',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.unlockTimeDescription,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatUnlockDate(entry.capsuleUnlockDate!),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Blurred preview hint
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (isDark
                            ? SeedlingColors.surfaceDark
                            : SeedlingColors.softCream)
                        .withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(15),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Text(
                    entry.displayContent.isNotEmpty
                        ? entry.displayContent
                        : 'A message awaits...',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockIndicator(BuildContext context) {
    final accentColor = isDark
        ? SeedlingColors.forestGreenDark
        : SeedlingColors.forestGreen;

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular progress
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: _getProgress(),
              strokeWidth: 3,
              backgroundColor: accentColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(accentColor),
            ),
          ),
          // Lock icon
          Icon(
            PlatformUtils.isIOS ? CupertinoIcons.lock_fill : Icons.lock,
            color: accentColor,
            size: 24,
          ),
        ],
      ),
    );
  }

  double _getProgress() {
    // Calculate progress based on how close we are to unlock
    // This is a simplified version - could be enhanced with actual creation date
    final totalDays = entry.capsuleUnlockDate!
        .difference(entry.createdAt)
        .inDays;
    final remainingDays = entry.daysUntilUnlock;

    if (totalDays <= 0) return 1.0;
    return 1.0 - (remainingDays / totalDays);
  }

  Widget _buildUnlockedCard(BuildContext context) {
    final cardColor = isDark
        ? SeedlingColors.cardDark
        : SeedlingColors.warmWhite;
    final textPrimary = isDark
        ? SeedlingColors.textPrimaryDark
        : SeedlingColors.textPrimary;
    final textMuted = isDark
        ? SeedlingColors.textMutedDark
        : SeedlingColors.textMuted;
    final accentColor = isDark
        ? SeedlingColors.themeGratitudeDark
        : SeedlingColors.themeGratitude;

    return Semantics(
      button: onTap != null,
      label: 'Unlocked capsule. ${entry.displayContent}. Tap to open.',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // Unlocked badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PlatformUtils.isIOS
                          ? CupertinoIcons.lock_open_fill
                          : Icons.lock_open,
                      color: accentColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Unlocked ${_formatDate(entry.capsuleUnlockDate!)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayContent,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: textPrimary),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          PlatformUtils.isIOS
                              ? CupertinoIcons.time
                              : Icons.access_time,
                          size: 14,
                          color: textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Created ${_formatDate(entry.createdAt)}',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: textMuted),
                        ),
                        const Spacer(),
                        Icon(
                          PlatformUtils.isIOS
                              ? CupertinoIcons.chevron_right
                              : Icons.chevron_right,
                          size: 16,
                          color: textMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatUnlockDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
