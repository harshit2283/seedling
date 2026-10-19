import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/palette.dart';
import '../../../../app/theme/radius.dart';
import '../../../../data/models/entry.dart';

/// Preview card showing a recent memory entry
class RecentEntryPreview extends StatelessWidget {
  final Entry entry;
  final VoidCallback? onTap;

  const RecentEntryPreview({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _getTypeColor(context);
    return Semantics(
      button: true,
      // Transparent Material so the ink works under Cupertino scaffolds too.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: SeedlingRadius.small,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getTypeIcon(), color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.displayContent,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.palette.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(entry.createdAt),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (entry.type) {
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

  Color _getTypeColor(BuildContext context) {
    final palette = context.palette;
    return switch (entry.type) {
      EntryType.line => palette.accentLine,
      EntryType.photo => palette.accentPhoto,
      EntryType.voice => palette.accentVoice,
      EntryType.object => palette.accentObject,
      EntryType.fragment => palette.accentFragment,
      EntryType.ritual => palette.accentRitual,
      EntryType.release => palette.accentRelease,
    };
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(date); // Day name
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}
