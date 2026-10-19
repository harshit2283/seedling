import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import '../../../../data/models/entry.dart';
import '../../domain/resurfacing.dart';

/// A quiet "From your tree" card that brings back one past memory a day.
///
/// On-this-day memories from earlier years come first; otherwise an older
/// memory (30+ days), rotated once per day. Tapping opens it; the close
/// button hides the card until tomorrow. It never shows a sealed capsule,
/// anything in the trash, or something that was let go.
class FromYourTreeCard extends ConsumerWidget {
  const FromYourTreeCard({super.key, this.onOpen});

  /// Opens the memory. Defaults to pushing the entry detail route.
  final ValueChanged<Entry>? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(resurfaceDismissedTodayProvider);
    final memory = dismissed ? null : ref.watch(resurfacedMemoryProvider);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: memory == null
          ? const SizedBox.shrink(key: ValueKey('resurface-none'))
          : _ResurfaceCardBody(
              key: ValueKey('resurface-${memory.entry.id}'),
              memory: memory,
              today: ref.watch(resurfaceClockProvider)(),
              onOpen: () {
                HapticFeedback.selectionClick();
                if (onOpen != null) {
                  onOpen!(memory.entry);
                } else {
                  context.push(AppRoutes.entryRoute(memory.entry.id));
                }
              },
              onDismiss: () {
                HapticFeedback.selectionClick();
                ref
                    .read(resurfaceDismissedTodayProvider.notifier)
                    .dismissForToday();
              },
            ),
    );
  }
}

class _ResurfaceCardBody extends StatelessWidget {
  const _ResurfaceCardBody({
    super.key,
    required this.memory,
    required this.today,
    required this.onOpen,
    required this.onDismiss,
  });

  final ResurfacedMemory memory;
  final DateTime today;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  String _whenLabel(BuildContext context) {
    if (memory.reason == ResurfaceReason.onThisDay) {
      final years = memory.yearsAgo(today);
      return years == 1 ? 'A year ago today' : '$years years ago today';
    }
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    return 'From ${DateFormat.yMMMM(locale).format(memory.entry.createdAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? SeedlingColors.textSecondaryDark
        : SeedlingColors.textSecondary;
    final accent = isDark
        ? SeedlingColors.leafGreenDark
        : SeedlingColors.leafGreen;
    final when = _whenLabel(context);
    final entry = memory.entry;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(AdaptiveIcons.leaf, color: accent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'From your tree',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Hide until tomorrow',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: SizedBox(
                  width: 44,
                  height: 32,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      PlatformUtils.isIOS ? CupertinoIcons.xmark : Icons.close,
                      color: secondary,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          entry.displayContent,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            height: 1.45,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          when,
          style: theme.textTheme.bodySmall?.copyWith(
            color: secondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );

    final radius = PlatformUtils.isIOS ? 20.0 : 12.0;
    final card = PlatformUtils.isIOS
        ? ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground
                      .resolveFrom(context)
                      .withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: CupertinoColors.separator
                        .resolveFrom(context)
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: content,
              ),
            ),
          )
        : Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: theme.dividerColor),
            ),
            child: content,
          );

    return Semantics(
      container: true,
      button: true,
      label: 'From your tree, $when',
      hint: 'Opens this memory',
      onTap: onOpen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: card,
      ),
    );
  }
}
