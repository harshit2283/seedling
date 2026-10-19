import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/palette.dart';
import '../../../../core/models/season.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/presentation/seedling_iconography.dart';
import '../../../../core/services/ai/models/memory_theme.dart';
import '../../../../core/services/providers.dart';
import '../../../../data/models/entry.dart';
import '../../../tree/domain/tree_personality.dart';
import '../../../tree/presentation/still_tree.dart';
import '../../domain/review_generator.dart';

/// The one line under the tree on the share card. Aggregate words only.
String shareCardLine(YearReviewData data, {required bool calm}) {
  final theme = data.dominantTheme;
  if (calm) {
    return theme == null
        ? 'A year, kept'
        : 'A year of ${theme.displayName.toLowerCase()}';
  }
  final n = data.totalEntries;
  final memories = n == 1 ? '1 memory' : '$n memories';
  return '${data.treeStateLabel}, grown from $memories';
}

/// One photo per season (spring, summer, autumn, winter) for the optional
/// season strip, or null where a season has none.
List<Entry?> seasonStripPhotos(YearReviewData data) => [
  for (final key in const ['spring', 'summer', 'autumn', 'winter'])
    data.seasons[key]?.photos.firstOrNull,
];

/// A shareable card for the year in review: the year, its tree, a strip of
/// twelve months (or, if the person chooses, four seasonal photos) and one
/// line. No memory text ever, and no photos unless the person turns them on
/// just before sharing. Captured with [RepaintBoundary] and shared as a PNG.
class ShareableCard extends ConsumerStatefulWidget {
  final YearReviewData reviewData;
  final bool isDark;

  /// Calm mode: the card shows the year and its theme, not a score.
  final bool calm;

  /// Whether the year is over ("My 2025") or still growing ("2026, so far").
  final bool finished;

  /// The tree's personality (current year only; finished years rest plain).
  final TreePersonality? personality;

  /// Clock override for tests.
  final DateTime? now;

  const ShareableCard({
    super.key,
    required this.reviewData,
    required this.isDark,
    this.calm = false,
    this.finished = false,
    this.personality,
    this.now,
  });

  @override
  ConsumerState<ShareableCard> createState() => _ShareableCardState();
}

class _ShareableCardState extends ConsumerState<ShareableCard> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isSharing = false;

  /// Photos are private until the person says otherwise, every time.
  bool _includePhotos = false;

  Future<void> _shareCard() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/seedling_${widget.reviewData.year}_review.png',
      );
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'My ${widget.reviewData.year} in Seedling');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final data = widget.reviewData;
    final photos = seasonStripPhotos(data);
    final hasPhotos = photos.any((p) => p != null);
    final showPhotos = _includePhotos && hasPhotos;

    return Column(
      children: [
        RepaintBoundary(
          key: _repaintKey,
          child: ShareCardFace(
            data: data,
            calm: widget.calm,
            finished: widget.finished,
            personality: widget.personality,
            now: widget.now,
            photos: showPhotos ? photos : null,
          ),
        ),
        if (hasPhotos) ...[
          const SizedBox(height: 12),
          _PhotosToggle(
            value: _includePhotos,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _includePhotos = v);
            },
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: PlatformUtils.isIOS
              ? CupertinoButton(
                  color: palette.primaryContainer.withValues(alpha: 0.5),
                  onPressed: _isSharing ? null : _shareCard,
                  child: Text(
                    _isSharing ? 'Preparing…' : 'Share your year',
                    style: TextStyle(color: palette.onPrimaryContainer),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: _isSharing ? null : _shareCard,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_outlined, size: 18),
                  label: Text(_isSharing ? 'Preparing…' : 'Share your year'),
                ),
        ),
      ],
    );
  }
}

class _PhotosToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PhotosToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Include season photos',
                  style: TextStyle(fontSize: 15, color: palette.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'One photo from each season. Off unless you choose.',
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PlatformUtils.isIOS
              ? CupertinoSwitch(
                  key: const ValueKey('share-card-photos-toggle'),
                  value: value,
                  activeTrackColor: palette.primaryFill,
                  onChanged: onChanged,
                )
              : Switch.adaptive(
                  key: const ValueKey('share-card-photos-toggle'),
                  value: value,
                  onChanged: onChanged,
                ),
        ],
      ),
    );
  }
}

/// The face of the share card, the exact pixels that get shared.
class ShareCardFace extends StatelessWidget {
  final YearReviewData data;
  final bool calm;
  final bool finished;
  final TreePersonality? personality;
  final DateTime? now;

  /// Four season photos (nulls for empty seasons), or null for the
  /// twelve-month strip.
  final List<Entry?>? photos;

  const ShareCardFace({
    super.key,
    required this.data,
    this.calm = false,
    this.finished = false,
    this.personality,
    this.now,
    this.photos,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final glow = palette.primaryContainer.withValues(
      alpha: palette.isDark ? 0.28 : 0.5,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(glow, palette.surface),
            palette.surface,
            Color.alphaBlend(
              palette.bark.withValues(alpha: palette.isDark ? 0.12 : 0.06),
              palette.surface,
            ),
          ],
          stops: const [0, 0.62, 1],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        children: [
          Text(
            finished ? 'My ${data.year}' : '${data.year}, so far',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox.square(
            dimension: stillTreeExtent(data.treeState, 250),
            child: StillTree.forYear(
              year: data.year,
              state: data.treeState,
              progress: data.treeProgress,
              night: palette.isDark,
              personality: personality,
              now: now,
            ),
          ),
          const SizedBox(height: 14),
          if (photos != null)
            _SeasonPhotoStrip(photos: photos!)
          else
            MonthDotStrip(counts: data.monthCounts),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (data.dominantTheme != null) ...[
                Icon(
                  SeedlingIconography.themeIcon(data.dominantTheme!),
                  size: 16,
                  color: palette.primary,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  shareCardLine(data, calm: calm),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Seedling',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Twelve dots, January to December: larger and deeper where more was kept,
/// a faint ring where a month rested. Counts only.
class MonthDotStrip extends StatelessWidget {
  final List<int> counts;

  const MonthDotStrip({super.key, required this.counts});

  static const _initials = [
    'J',
    'F',
    'M',
    'A',
    'M',
    'J',
    'J',
    'A',
    'S',
    'O',
    'N',
    'D',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final values = counts.length == 12 ? counts : List.filled(12, 0);
    final most = values.fold<int>(0, (a, b) => a > b ? a : b);
    final kept = values.where((c) => c > 0).length;
    return Semantics(
      label: 'Memories kept in $kept of 12 months',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var m = 0; m < 12; m++)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: Center(child: _dot(palette, values[m], most)),
                ),
                const SizedBox(height: 4),
                Text(
                  _initials[m],
                  style: TextStyle(fontSize: 10, color: palette.textMuted),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dot(SeedlingPalette palette, int count, int most) {
    if (count == 0 || most == 0) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.textMuted.withValues(alpha: 0.5)),
        ),
      );
    }
    final t = count / most;
    final size = 7 + 9 * t;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.primary.withValues(alpha: 0.45 + 0.55 * t),
      ),
    );
  }
}

class _SeasonPhotoStrip extends StatelessWidget {
  final List<Entry?> photos;

  const _SeasonPhotoStrip({required this.photos});

  static const _seasons = [
    Season.spring,
    Season.summer,
    Season.autumn,
    Season.winter,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: _CardPhoto(entry: photos[i], season: _seasons[i]),
            ),
          ),
        ],
      ],
    );
  }
}

/// A photo on the card: no caption, no label from the memory's words.
class _CardPhoto extends ConsumerWidget {
  final Entry? entry;
  final Season season;

  const _CardPhoto({required this.entry, required this.season});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final radius = BorderRadius.circular(10);
    final empty = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: radius,
      ),
      child: Center(
        child: Icon(
          SeedlingIconography.seasonIcon(season),
          size: 18,
          color: palette.textMuted,
        ),
      ),
    );
    final path = entry?.mediaPath;
    if (path == null || path.isEmpty) return empty;
    final file = ref.watch(resolvedMediaFileProvider(path)).value;
    if (file == null) return empty;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: radius,
      child: Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: (120 * dpr).round(),
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => empty,
      ),
    );
  }
}
