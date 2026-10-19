import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../../../app/theme/palette.dart';
import '../../../../core/presentation/seedling_iconography.dart';
import '../../../../core/services/ai/models/memory_theme.dart';
import '../../../tree/domain/tree_personality.dart';
import '../../../tree/presentation/still_tree.dart';
import '../../domain/review_generator.dart';

/// A privacy-safe shareable card for the year-in-review.
///
/// Contains only the year's tree and aggregate stats (stage, count,
/// dominant theme label). No actual memory content is included. Uses
/// [RepaintBoundary] + [toImage()] + share_plus to generate and share a PNG.
class ShareableCard extends StatefulWidget {
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
  State<ShareableCard> createState() => _ShareableCardState();
}

class _ShareableCardState extends State<ShareableCard> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isSharing = false;

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

      // Write to temp file.
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/seedling_${widget.reviewData.year}_review.png',
      );
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: widget.calm
            ? 'My ${widget.reviewData.year} in Seedling.'
            : 'My ${widget.reviewData.year} in Seedling: ${widget.reviewData.totalEntries} memories planted.',
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final data = widget.reviewData;
    final finished = widget.finished;

    return Column(
      children: [
        // The card to capture. Aggregate only: no memory text or photos.
        RepaintBoundary(
          key: _repaintKey,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                    palette.primaryContainer.withValues(alpha: 0.35),
                    palette.surface,
                  ),
                  palette.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
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
                const SizedBox(height: 4),
                SizedBox.square(
                  dimension: stillTreeExtent(data.treeState, 220),
                  child: StillTree.forYear(
                    year: data.year,
                    state: data.treeState,
                    progress: data.treeProgress,
                    night: palette.isDark,
                    personality: widget.personality,
                    now: widget.now,
                  ),
                ),
                if (!widget.calm) ...[
                  const SizedBox(height: 8),
                  Text(
                    data.treeStateLabel,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${data.totalEntries} memories',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
                if (data.dominantTheme != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        SeedlingIconography.themeIcon(data.dominantTheme!),
                        size: 16,
                        color: palette.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'A year of ${data.dominantTheme!.displayName.toLowerCase()}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Seedling',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Share button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isSharing ? null : _shareCard,
            icon: _isSharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined, size: 18),
            label: Text(_isSharing ? 'Preparing...' : 'Share your year'),
          ),
        ),
      ],
    );
  }
}
