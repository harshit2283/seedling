import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/palette.dart';
import '../../../../app/theme/radius.dart';
import '../../../../app/theme/typography.dart';
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

class _ResurfaceCardBody extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final secondary = palette.textSecondary;
    final when = _whenLabel(context);
    final entry = memory.entry;
    final hasPhoto =
        (entry.type == EntryType.photo || entry.type == EntryType.object) &&
        entry.mediaPath != null;
    final photo = hasPhoto
        ? ref.watch(resolvedMediaFileProvider(entry.mediaPath!)).value
        : null;

    final dismiss = Semantics(
      button: true,
      label: 'Hide until tomorrow',
      onTap: onDismiss,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        // A full 44x44 target; the icon stays small and right-aligned.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Align(
            alignment: Alignment.centerRight,
            child: Icon(
              PlatformUtils.isIOS ? CupertinoIcons.xmark : Icons.close,
              color: palette.textMuted,
              size: 16,
            ),
          ),
        ),
      ),
    );

    final header = Row(
      children: [
        Icon(AdaptiveIcons.leaf, color: palette.primary, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'From your tree',
            style: theme.textTheme.labelLarge?.copyWith(
              color: secondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        dismiss,
      ],
    );

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (entry.displayContent.trim().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                entry.displayContent,
                style: TextStyle(
                  fontFamily: SeedlingTypography.serifFamily,
                  fontSize: photo != null ? 17 : 19,
                  height: 1.4,
                  color: palette.textPrimary,
                ),
                maxLines: photo != null ? 2 : 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            when,
            style: theme.textTheme.bodySmall?.copyWith(
              color: secondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photo != null)
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.file(
              photo,
              fit: BoxFit.cover,
              cacheWidth: 900,
              semanticLabel: 'Photo from this memory',
              errorBuilder: (_, _, _) => ColoredBox(
                color: palette.accentPhoto.withValues(alpha: 0.12),
              ),
            ),
          ),
        body,
      ],
    );

    // Warm paper, a touch of the tree's green; glass over the page on iOS.
    final tint = Color.alphaBlend(
      palette.primaryContainer.withValues(alpha: palette.isDark ? 0.10 : 0.16),
      palette.card,
    );
    final card = PlatformUtils.isIOS
        ? ClipRRect(
            borderRadius: SeedlingRadius.card,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.78),
                  borderRadius: SeedlingRadius.card,
                  border: Border.all(
                    color: palette.border.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
                child: content,
              ),
            ),
          )
        : Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: SeedlingRadius.card,
              border: Border.all(color: palette.border, width: 0.5),
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
