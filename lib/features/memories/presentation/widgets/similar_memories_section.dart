import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/services/media/file_storage_service.dart';
import '../../../../core/services/ai/models/memory_connection.dart';
import '../../../../core/widgets/glass/glass_container.dart';
import '../../../../data/models/entry.dart';

/// Section showing memories similar to the current entry
///
/// Displays a horizontal scrollable list of related memories
/// found through text similarity, temporal proximity, and shared themes.
class SimilarMemoriesSection extends ConsumerWidget {
  final int entryId;

  const SimilarMemoriesSection({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(entryConnectionsProvider(entryId));

    if (connections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                PlatformUtils.isIOS ? CupertinoIcons.link : Icons.link,
                size: 18,
                color: SeedlingColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Related Memories',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: SeedlingColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Horizontal list of related memories
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: connections.length,
            itemBuilder: (context, index) {
              return _RelatedMemoryCard(
                connection: connections[index],
                isFirst: index == 0,
                isLast: index == connections.length - 1,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RelatedMemoryCard extends StatelessWidget {
  final MemoryConnection connection;
  final bool isFirst;
  final bool isLast;

  const _RelatedMemoryCard({
    required this.connection,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final entry = connection.relatedEntry;

    return Padding(
      padding: EdgeInsets.only(left: isFirst ? 0 : 8, right: isLast ? 0 : 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(AppRoutes.entryRoute(entry.id));
        },
        child: GlassContainer(
          borderRadius: 16,
          opacity: 0.6,
          child: Container(
            width: 160,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media thumbnail or type icon
                _buildLeading(entry),
                const SizedBox(height: 8),
                // Content preview
                Expanded(
                  child: Text(
                    entry.displayContent,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SeedlingColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                // Connection info
                _buildConnectionInfo(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(Entry entry) {
    // Show thumbnail for media entries
    if (entry.hasMedia &&
        (entry.type == EntryType.photo || entry.type == EntryType.object)) {
      return FutureBuilder<File?>(
        future: FileStorageService.resolveMediaFile(entry.mediaPath),
        builder: (context, snapshot) {
          final resolvedFile = snapshot.data;
          if (resolvedFile == null) {
            return _buildTypeIcon(entry);
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              resolvedFile,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildTypeIcon(entry),
            ),
          );
        },
      );
    }

    return _buildTypeIcon(entry);
  }

  Widget _buildTypeIcon(Entry entry) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _getTypeColor(entry.type).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getTypeIcon(entry.type),
        color: _getTypeColor(entry.type),
        size: 18,
      ),
    );
  }

  Widget _buildConnectionInfo(BuildContext context) {
    // Show connection strength indicator
    return Row(
      children: [
        // Strength dots
        ...List.generate(3, (index) {
          final isActive = connection.similarityScore >= (0.3 + index * 0.2);
          return Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? SeedlingColors.forestGreen
                  : Theme.of(context).dividerColor,
            ),
          );
        }),
        const Spacer(),
        // Primary reason
        Text(
          connection.factors.primaryReason,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: SeedlingColors.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  IconData _getTypeIcon(EntryType type) {
    if (PlatformUtils.isIOS) {
      switch (type) {
        case EntryType.line:
          return CupertinoIcons.text_quote;
        case EntryType.photo:
          return CupertinoIcons.photo;
        case EntryType.voice:
          return CupertinoIcons.waveform;
        case EntryType.object:
          return CupertinoIcons.cube;
        case EntryType.fragment:
          return CupertinoIcons.sparkles;
        case EntryType.ritual:
          return CupertinoIcons.arrow_2_circlepath;
        case EntryType.release:
          return CupertinoIcons.wind;
      }
    }

    switch (type) {
      case EntryType.line:
        return Icons.format_quote;
      case EntryType.photo:
        return Icons.photo_outlined;
      case EntryType.voice:
        return Icons.graphic_eq;
      case EntryType.object:
        return Icons.category_outlined;
      case EntryType.fragment:
        return Icons.auto_awesome;
      case EntryType.ritual:
        return Icons.loop;
      case EntryType.release:
        return Icons.air;
    }
  }

  Color _getTypeColor(EntryType type) {
    switch (type) {
      case EntryType.line:
        return SeedlingColors.accentLine;
      case EntryType.photo:
        return SeedlingColors.accentPhoto;
      case EntryType.voice:
        return SeedlingColors.accentVoice;
      case EntryType.object:
        return SeedlingColors.accentObject;
      case EntryType.fragment:
        return SeedlingColors.accentFragment;
      case EntryType.ritual:
        return SeedlingColors.accentRitual;
      case EntryType.release:
        return SeedlingColors.accentRelease;
    }
  }
}
