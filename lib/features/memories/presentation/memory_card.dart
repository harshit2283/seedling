import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/util/date_labels.dart';
import '../../../app/router.dart';
import '../../../app/theme/palette.dart';
import '../../../app/theme/radius.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/providers/media_providers.dart';
import '../../../core/services/ai/models/memory_theme.dart';
import '../../../data/models/entry.dart';

/// Display style for MemoryCard
enum MemoryCardStyle { list, grid }

/// Card displaying a single memory entry
class MemoryCard extends ConsumerWidget {
  static const double _listThumbnailDisplaySize = 56;
  static const double _gridImageDisplayHeight = 160;
  static const double _gridImageDisplayWidth = 180;

  final Entry entry;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final MemoryCardStyle style;

  const MemoryCard({
    super.key,
    required this.entry,
    this.onLongPress,
    this.onTap,
    this.style = MemoryCardStyle.list,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (style == MemoryCardStyle.grid) {
      return _buildGridCard(context, ref);
    }
    return _buildListCard(context, ref);
  }

  // ─────────────────────────────────────────────────────────────────
  // LIST STYLE (unchanged)
  // ─────────────────────────────────────────────────────────────────

  Widget _buildListCard(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap ?? () => _navigateToDetail(context),
      onLongPress: onLongPress,
      child: Semantics(
        button: true,
        label:
            '${entry.typeName} memory from ${_formatDate(context, entry.createdAt)}. ${entry.displayContent}',
        hint: 'Double tap to open memory details',
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: SeedlingRadius.card,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type indicator or media thumbnail
              _buildLeading(context, ref),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main content
                    _buildMainContent(context),
                    const SizedBox(height: 8),
                    // Metadata row
                    _buildMetadataRow(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // GRID STYLE
  // ─────────────────────────────────────────────────────────────────

  Widget _buildGridCard(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap ?? () => _navigateToDetail(context),
      onLongPress: onLongPress,
      child: Semantics(
        button: true,
        label:
            '${entry.typeName} memory from ${_formatDate(context, entry.createdAt)}. ${entry.displayContent}',
        hint: 'Double tap to open memory',
        child: Container(
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: context.palette.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top visual block: image for media entries, colored block for text
              _buildGridTopBlock(context, ref),
              // Bottom info area
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge + date row
                    _buildGridBadgeRow(context),
                    const SizedBox(height: 6),
                    // Title or text preview
                    _buildGridPreview(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridTopBlock(BuildContext context, WidgetRef ref) {
    final typeColor = _getTypeColor(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (_gridImageDisplayWidth * dpr).round();
    final cacheHeight = (_gridImageDisplayHeight * dpr).round();

    // Photo / object with image path — show full-width image
    if ((entry.type == EntryType.photo || entry.type == EntryType.object) &&
        entry.mediaPath != null) {
      final resolved = ref.watch(resolvedMediaFileProvider(entry.mediaPath!));
      return resolved.when(
        loading: () => Container(
          height: 160,
          width: double.infinity,
          color: typeColor.withValues(alpha: 0.08),
        ),
        error: (_, _) => _buildGridColorBlock(context, typeColor),
        data: (resolvedFile) {
          if (resolvedFile == null) {
            return _buildGridColorBlock(context, typeColor);
          }
          return Hero(
            tag: 'entry-${entry.id}',
            transitionOnUserGestures: true,
            flightShuttleBuilder: _heroShuttle,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.file(
                resolvedFile,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                errorBuilder: (context, error, stackTrace) =>
                    _buildGridColorBlock(context, typeColor),
              ),
            ),
          );
        },
      );
    }

    // Voice entries: waveform icon on colored block
    if (entry.type == EntryType.voice) {
      return Hero(
        tag: 'entry-${entry.id}',
        transitionOnUserGestures: true,
        flightShuttleBuilder: _heroShuttle,
        child: _buildGridColorBlock(
          context,
          context.palette.accentVoice,
          child: Icon(
            PlatformUtils.isIOS ? CupertinoIcons.waveform : Icons.graphic_eq,
            color: context.palette.accentVoice,
            size: 32,
          ),
        ),
      );
    }

    // Text-only entries: colored solid block with type emoji/icon centered
    return Hero(
      tag: 'entry-${entry.id}',
      transitionOnUserGestures: true,
      flightShuttleBuilder: _heroShuttle,
      child: _buildGridColorBlock(
        context,
        typeColor,
        child: Icon(_getTypeIcon(), color: typeColor, size: 28),
      ),
    );
  }

  static Widget _heroShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final toHero = toHeroContext.widget as Hero;
    return Material(color: Colors.transparent, child: toHero.child);
  }

  Widget _buildGridColorBlock(
    BuildContext context,
    Color typeColor, {
    Widget? child,
  }) {
    return Container(
      height: 80,
      width: double.infinity,
      color: typeColor.withValues(alpha: 0.12),
      child: child != null ? Center(child: child) : null,
    );
  }

  Widget _buildGridBadgeRow(BuildContext context) {
    final typeColor = _getTypeColor(context);
    return Row(
      children: [
        // Type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            entry.typeName,
            style: TextStyle(
              color: context.palette.inkFor(typeColor),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Relative date
        Expanded(
          child: Text(
            _formatDateShort(context, entry.createdAt),
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGridPreview(BuildContext context) {
    final displayText = _gridPreviewText();
    if (displayText == null) return const SizedBox.shrink();

    return Text(
      displayText,
      style: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: context.palette.textPrimary,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  String? _gridPreviewText() {
    if (entry.type == EntryType.object && entry.title != null) {
      return entry.title;
    }
    if (entry.hasText) return entry.text;
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // SHARED LIST HELPERS
  // ─────────────────────────────────────────────────────────────────

  Widget _buildLeading(BuildContext context, WidgetRef ref) {
    final inner = entry.hasMedia
        ? _buildMediaThumbnail(context, ref)
        : _buildTypeIndicator(context);
    return Hero(
      tag: 'entry-${entry.id}',
      transitionOnUserGestures: true,
      flightShuttleBuilder: _heroShuttle,
      child: inner,
    );
  }

  Widget _buildMediaThumbnail(BuildContext context, WidgetRef ref) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (_listThumbnailDisplaySize * dpr).round();
    switch (entry.type) {
      case EntryType.photo:
      case EntryType.object:
        if (entry.mediaPath != null) {
          final resolved = ref.watch(
            resolvedMediaFileProvider(entry.mediaPath!),
          );
          return resolved.when(
            loading: () => Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            error: (_, _) => _buildTypeIndicator(context),
            data: (resolvedFile) {
              if (resolvedFile == null) {
                return _buildTypeIndicator(context);
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  resolvedFile,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  cacheWidth: cacheSize,
                  cacheHeight: cacheSize,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildTypeIndicator(context),
                ),
              );
            },
          );
        }
        break;
      case EntryType.voice:
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: context.palette.accentVoice.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PlatformUtils.isIOS
                    ? CupertinoIcons.waveform
                    : Icons.graphic_eq,
                color: context.palette.accentVoice,
                size: 24,
              ),
              const SizedBox(height: 2),
              Icon(
                PlatformUtils.isIOS
                    ? CupertinoIcons.play_fill
                    : Icons.play_arrow,
                color: context.palette.accentVoice,
                size: 14,
              ),
            ],
          ),
        );
      default:
        break;
    }
    return _buildTypeIndicator(context);
  }

  Widget _buildTypeIndicator(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _getTypeColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_getTypeIcon(), color: _getTypeColor(context), size: 18),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    // For objects, show title as primary content
    if (entry.type == EntryType.object && entry.title != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: context.palette.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (entry.hasText) ...[
            const SizedBox(height: 4),
            Text(
              entry.text!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }

    // For entries with text
    if (entry.hasText) {
      return Text(
        entry.text!,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: 1.5,
          color: entry.type == EntryType.release
              ? context.palette.textSecondary
              : context.palette.textPrimary,
          fontStyle: entry.type == EntryType.release
              ? FontStyle.italic
              : FontStyle.normal,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Empty content (fragments, media without notes)
    return Text(
      _getEmptyContentText(),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: context.palette.textMuted,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context) {
    // Wrap, not Row: with larger text sizes the date and badges flow onto a
    // second line instead of overflowing.
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Date
        Text(
          _formatDate(context, entry.createdAt),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary),
        ),
        // Type label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _getTypeColor(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            entry.typeName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.palette.inkFor(_getTypeColor(context)),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        // Theme badge (if entry has a detected theme)
        if (entry.hasTheme) _buildThemeBadge(context),
      ],
    );
  }

  Widget _buildThemeBadge(BuildContext context) {
    final theme = MemoryThemeExtension.fromString(entry.detectedTheme);
    if (theme == null || theme == MemoryTheme.moments) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.palette.themeColor(theme.name).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        theme.displayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.palette.inkFor(context.palette.themeColor(theme.name)),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context) {
    HapticFeedback.selectionClick();
    context.push(AppRoutes.entryRoute(entry.id));
  }

  IconData _getTypeIcon() {
    if (PlatformUtils.isIOS) {
      switch (entry.type) {
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
    switch (entry.type) {
      case EntryType.line:
        return palette.accentLine;
      case EntryType.photo:
        return palette.accentPhoto;
      case EntryType.voice:
        return palette.accentVoice;
      case EntryType.object:
        return palette.accentObject;
      case EntryType.fragment:
        return palette.accentFragment;
      case EntryType.ritual:
        return palette.accentRitual;
      case EntryType.release:
        return palette.accentRelease;
    }
  }

  String _getEmptyContentText() {
    switch (entry.type) {
      case EntryType.fragment:
        return 'A wordless fragment';
      case EntryType.release:
        return 'Released into the wind';
      case EntryType.photo:
        return 'A captured moment';
      case EntryType.voice:
        return 'A voice memo';
      case EntryType.object:
        return 'A meaningful object';
      default:
        return entry.typeName;
    }
  }

  String _formatDate(BuildContext context, DateTime date) =>
      DateLabels.dayAndTimeOf(context, date);

  String _formatDateShort(BuildContext context, DateTime date) =>
      DateLabels.dayOf(context, date);
}
