import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import '../../../../data/models/entry.dart';

/// Card that surfaces memories from the same day in previous years.
/// Returns [SizedBox.shrink] when there are no matching entries.
class OnThisDayCard extends ConsumerWidget {
  const OnThisDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(onThisDayProvider);
    if (entries.isEmpty) return const SizedBox.shrink();

    final displayEntries = entries.take(3).toList();

    if (PlatformUtils.isIOS) {
      return _buildIOSCard(context, displayEntries);
    }
    return _buildAndroidCard(context, displayEntries);
  }

  Widget _buildIOSCard(BuildContext context, List<Entry> entries) {
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
          child: _buildCardContent(context, entries),
        ),
      ),
    );
  }

  Widget _buildAndroidCard(BuildContext context, List<Entry> entries) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: _buildCardContent(context, entries),
    );
  }

  Widget _buildCardContent(BuildContext context, List<Entry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history_rounded,
              color: SeedlingColors.warmBrown,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'On This Day',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: SeedlingColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...entries.map((entry) => _buildEntryRow(context, entry)),
      ],
    );
  }

  Widget _buildEntryRow(BuildContext context, Entry entry) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.entryRoute(entry.id)),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: SeedlingColors.warmBrown.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${entry.createdAt.year}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SeedlingColors.warmBrown,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              _getTypeIcon(entry.type),
              color: SeedlingColors.textMuted,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.displayContent,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SeedlingColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              PlatformUtils.isIOS
                  ? Icons.arrow_forward_ios
                  : Icons.chevron_right,
              color: SeedlingColors.textMuted,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(EntryType type) {
    switch (type) {
      case EntryType.line:
        return Icons.format_quote;
      case EntryType.photo:
        return Icons.photo_outlined;
      case EntryType.voice:
        return Icons.mic_outlined;
      case EntryType.object:
        return Icons.category_outlined;
      case EntryType.fragment:
        return Icons.auto_awesome_outlined;
      case EntryType.ritual:
        return Icons.loop;
      case EntryType.release:
        return Icons.air;
    }
  }
}
