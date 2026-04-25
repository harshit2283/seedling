import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/constants/prefs_keys.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import '../../../../data/models/entry.dart';

/// Card that surfaces memories from the same day in previous years.
///
/// Shows a sparkle icon, an "X years ago today" label, a preview of the
/// matching entry, and a View button. When more than one match exists,
/// users can page through them and an "n of N" indicator appears.
///
/// Hides itself for the rest of the day when the close button is tapped.
class OnThisDayCard extends ConsumerStatefulWidget {
  const OnThisDayCard({super.key});

  @override
  ConsumerState<OnThisDayCard> createState() => _OnThisDayCardState();
}

class _OnThisDayCardState extends ConsumerState<OnThisDayCard> {
  int _pageIndex = 0;
  bool _dismissedToday = false;

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final stored = prefs.getString(PrefsKeys.onThisDayDismissedDate);
    if (stored == _todayKey()) {
      _dismissedToday = true;
    }
  }

  Future<void> _dismiss() async {
    HapticFeedback.selectionClick();
    setState(() => _dismissedToday = true);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(PrefsKeys.onThisDayDismissedDate, _todayKey());
  }

  void _nextEntry(int total) {
    HapticFeedback.selectionClick();
    setState(() => _pageIndex = (_pageIndex + 1) % total);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedToday) return const SizedBox.shrink();
    final entries = ref.watch(onThisDayProvider);
    if (entries.isEmpty) return const SizedBox.shrink();

    final safeIndex = _pageIndex.clamp(0, entries.length - 1);
    final current = entries[safeIndex];

    if (PlatformUtils.isIOS) {
      return _buildIOSCard(context, current, entries.length, safeIndex);
    }
    return _buildAndroidCard(context, current, entries.length, safeIndex);
  }

  Widget _buildIOSCard(
    BuildContext context,
    Entry current,
    int total,
    int index,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground
                .resolveFrom(context)
                .withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: CupertinoColors.separator
                  .resolveFrom(context)
                  .withValues(alpha: 0.2),
            ),
          ),
          child: _buildCardContent(context, current, total, index),
        ),
      ),
    );
  }

  Widget _buildAndroidCard(
    BuildContext context,
    Entry current,
    int total,
    int index,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: _buildCardContent(context, current, total, index),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    Entry current,
    int total,
    int index,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brown = isDark
        ? SeedlingColors.warmBrownDark
        : SeedlingColors.warmBrown;
    final secondary = isDark
        ? SeedlingColors.textSecondaryDark
        : SeedlingColors.textSecondary;
    final primary = isDark
        ? SeedlingColors.textPrimaryDark
        : SeedlingColors.textPrimary;
    final yearsAgo = DateTime.now().year - current.createdAt.year;
    final headerText = yearsAgo == 1
        ? 'A year ago today'
        : '$yearsAgo years ago today';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              PlatformUtils.isIOS
                  ? CupertinoIcons.sparkles
                  : Icons.auto_awesome_outlined,
              color: brown,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                headerText,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: secondary),
              ),
            ),
            if (total > 1)
              GestureDetector(
                onTap: () => _nextEntry(total),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    '${index + 1} of $total',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            _buildDismissButton(context, secondary),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          current.displayContent,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: primary,
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: PlatformUtils.isIOS
              ? CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push(AppRoutes.entryRoute(current.id));
                  },
                  child: Text(
                    'View',
                    style: TextStyle(
                      color: SeedlingColors.forestGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push(AppRoutes.entryRoute(current.id));
                  },
                  child: Text(
                    'View',
                    style: TextStyle(color: SeedlingColors.forestGreen),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDismissButton(BuildContext context, Color color) {
    final icon = Icon(
      PlatformUtils.isIOS ? CupertinoIcons.xmark : Icons.close,
      color: color,
      size: 16,
    );
    if (PlatformUtils.isIOS) {
      return CupertinoButton(
        padding: const EdgeInsets.all(4),
        minimumSize: Size.zero,
        onPressed: _dismiss,
        child: icon,
      );
    }
    return IconButton(
      icon: icon,
      iconSize: 16,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: _dismiss,
      tooltip: 'Dismiss',
    );
  }
}
