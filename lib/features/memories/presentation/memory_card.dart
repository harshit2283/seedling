import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
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
            '${entry.typeName} memory from ${_formatDate(entry.createdAt)}. ${entry.displayContent}',
        hint: 'Double tap to open memory details',
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                Theme.of(context).cardTheme.color ??
                Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
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
            '${entry.typeName} memory from ${_formatDate(entry.createdAt)}. ${entry.displayContent}',
        hint: 'Double tap to open memory',
        child: Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).cardTheme.color ??
                Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.barkBrown.withValues(alpha: 0.08),
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
    final typeColor = _getTypeColor();
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
        error: (_, __) => _buildGridColorBlock(typeColor),
        data: (resolvedFile) {
          if (resolvedFile == null) {
            return _buildGridColorBlock(typeColor);
          }
          return Hero(
            tag: 'entry-${entry.id}',
            transitionOnUserGestures: true,
            flightShuttleBuilder: _heroShuttle,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.file(
                resolvedFile,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                errorBuilder: (context, error, stackTrace) =>
                    _buildGridColorBlock(typeColor),
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
          SeedlingColors.accentVoice,
          child: Icon(
            PlatformUtils.isIOS ? CupertinoIcons.waveform : Icons.graphic_eq,
            color: SeedlingColors.accentVoice,
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
    return Material(
      color: Colors.transparent,
      child: toHero.child,
    );
  }

  Widget _buildGridColorBlock(Color typeColor, {Widget? child}) {
    return Container(
      height: 80,
      width: double.infinity,
      color: typeColor.withValues(alpha: 0.12),
      child: child != null ? Center(child: child) : null,
    );
  }

  Widget _buildGridBadgeRow(BuildContext context) {
    final typeColor = _getTypeColor();
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
              color: typeColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Relative date
        Expanded(
          child: Text(
            _formatDateShort(entry.createdAt),
            style: TextStyle(color: SeedlingColors.textMuted, fontSize: 10),
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
      style: const TextStyle(
        fontSize: 14,
        height: 1.4,
        color: SeedlingColors.textPrimary,
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
        : _buildTypeIndicator();
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
            error: (_, __) => _buildTypeIndicator(),
            data: (resolvedFile) {
              if (resolvedFile == null) {
                return _buildTypeIndicator();
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
                      _buildTypeIndicator(),
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
            color: SeedlingColors.accentVoice.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PlatformUtils.isIOS
                    ? CupertinoIcons.waveform
                    : Icons.graphic_eq,
                color: SeedlingColors.accentVoice,
                size: 24,
              ),
              const SizedBox(height: 2),
              Icon(
                PlatformUtils.isIOS
                    ? CupertinoIcons.play_fill
                    : Icons.play_arrow,
                color: SeedlingColors.accentVoice,
                size: 14,
              ),
            ],
          ),
        );
      default:
        break;
    }
    return _buildTypeIndicator();
  }

  Widget _buildTypeIndicator() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _getTypeColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_getTypeIcon(), color: _getTypeColor(), size: 18),
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
              color: SeedlingColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (entry.hasText) ...[
            const SizedBox(height: 4),
            Text(
              entry.text!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SeedlingColors.textSecondary,
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
              ? SeedlingColors.textSecondary
              : SeedlingColors.textPrimary,
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
        color: SeedlingColors.textMuted,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context) {
    return Row(
      children: [
        // Date
        Text(
          _formatDate(entry.createdAt),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: SeedlingColors.textMuted),
        ),
        const SizedBox(width: 8),
        // Type label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _getTypeColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            entry.typeName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _getTypeColor(),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Theme badge (if entry has a detected theme)
        if (entry.hasTheme) ...[
          const SizedBox(width: 6),
          _buildThemeBadge(context),
        ],
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
        color: _getThemeColor(theme).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        theme.displayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _getThemeColor(theme),
          fontWeight: FontWeight.w500,
          fontSize: 10,
        ),
      ),
    );
  }

  Color _getThemeColor(MemoryTheme theme) {
    switch (theme) {
      case MemoryTheme.family:
        return SeedlingColors.themeFamily;
      case MemoryTheme.friends:
        return SeedlingColors.themeFriends;
      case MemoryTheme.work:
        return SeedlingColors.themeWork;
      case MemoryTheme.nature:
        return SeedlingColors.themeNature;
      case MemoryTheme.gratitude:
        return SeedlingColors.themeGratitude;
      case MemoryTheme.reflection:
        return SeedlingColors.themeReflection;
      case MemoryTheme.travel:
        return SeedlingColors.themeTravel;
      case MemoryTheme.creativity:
        return SeedlingColors.themeCreativity;
      case MemoryTheme.health:
        return SeedlingColors.themeHealth;
      case MemoryTheme.food:
        return SeedlingColors.themeFood;
      case MemoryTheme.moments:
        return SeedlingColors.themeMoments;
    }
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

  Color _getTypeColor() {
    switch (entry.type) {
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

  static final _timeFormat = DateFormat('h:mm a');
  static final _dayOfWeekFormat = DateFormat('EEEE');
  static final _monthDayFormat = DateFormat('MMMM d');
  static final _fullDateFormat = DateFormat('MMMM d, y');
  static final _shortMonthDayFormat = DateFormat('MMM d');

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(entryDate).inDays;

    if (difference == 0) {
      return 'Today at ${_timeFormat.format(date)}';
    } else if (difference == 1) {
      return 'Yesterday at ${_timeFormat.format(date)}';
    } else if (difference < 7) {
      return '${_dayOfWeekFormat.format(date)} at ${_timeFormat.format(date)}';
    } else if (date.year == now.year) {
      return _monthDayFormat.format(date);
    } else {
      return _fullDateFormat.format(date);
    }
  }

  String _formatDateShort(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(entryDate).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (date.year == now.year) return _shortMonthDayFormat.format(date);
    return _fullDateFormat.format(date);
  }
}
