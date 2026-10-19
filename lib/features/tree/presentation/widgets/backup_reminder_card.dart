import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/palette.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';

/// A quiet line at the very end of the home page when the last backup is
/// more than a month old. No card, no button colour: one muted sentence
/// with a link to the backup settings and a way to hush it for 30 days.
class BackupReminderCard extends ConsumerWidget {
  const BackupReminderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldShow = ref.watch(shouldShowBackupReminderProvider);
    if (!shouldShow) return const SizedBox.shrink();

    final palette = context.palette;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: palette.textSecondary);

    void openSettings() {
      HapticFeedback.selectionClick();
      context.push(AppRoutes.settings);
    }

    return Row(
      children: [
        Icon(
          PlatformUtils.isIOS ? CupertinoIcons.cloud : Icons.cloud_outlined,
          color: palette.textMuted,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            button: true,
            hint: 'Opens backup settings',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: openSettings,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'No backup in a while. '),
                        TextSpan(
                          text: 'Back up',
                          style: TextStyle(
                            color: palette.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    style: style,
                  ),
                ),
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Hide backup reminder for a month',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              HapticFeedback.selectionClick();
              await ref.read(backupReminderServiceProvider).dismissReminder();
              ref.invalidate(shouldShowBackupReminderProvider);
            },
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                PlatformUtils.isIOS ? CupertinoIcons.xmark : Icons.close,
                color: palette.textMuted,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
