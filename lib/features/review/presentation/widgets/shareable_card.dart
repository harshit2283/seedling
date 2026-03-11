import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../../../app/theme/colors.dart';
import '../../../../core/presentation/seedling_iconography.dart';
import '../../../../core/services/ai/models/memory_theme.dart';
import '../../domain/review_generator.dart';

/// A privacy-safe shareable card for the year-in-review.
///
/// Contains only aggregate stats (year, tree state, entry count, dominant
/// theme label). No actual memory content is included. Uses
/// [RepaintBoundary] + [toImage()] + share_plus to generate and share a PNG.
class ShareableCard extends StatefulWidget {
  final YearReviewData reviewData;
  final bool isDark;

  const ShareableCard({
    super.key,
    required this.reviewData,
    required this.isDark,
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
        subject:
            'My ${widget.reviewData.year} in Seedling: ${widget.reviewData.totalEntries} memories planted.',
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;
    final data = widget.reviewData;

    return Column(
      children: [
        // The card to capture.
        RepaintBoundary(
          key: _repaintKey,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [SeedlingColors.surfaceDark, const Color(0xFF1E2E1E)]
                    : [
                        SeedlingColors.creamPaper,
                        SeedlingColors.paleGreen.withValues(alpha: 0.4),
                      ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? SeedlingColors.dividerDark
                    : SeedlingColors.softCream,
              ),
            ),
            child: Column(
              children: [
                // Year
                Text(
                  '${data.year}',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: isDark
                        ? SeedlingColors.forestGreenDark
                        : SeedlingColors.forestGreen,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color:
                        (isDark
                                ? SeedlingColors.forestGreenDark
                                : SeedlingColors.forestGreen)
                            .withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.park_outlined,
                    size: 38,
                    color: isDark
                        ? SeedlingColors.forestGreenDark
                        : SeedlingColors.forestGreen,
                  ),
                ),
                const SizedBox(height: 8),

                // Tree state
                Text(
                  data.treeStateLabel,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),

                // Entry count
                Text(
                  '${data.totalEntries} memories planted',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isDark
                        ? SeedlingColors.textSecondaryDark
                        : SeedlingColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Dominant theme
                if (data.dominantTheme != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        SeedlingIconography.themeIcon(data.dominantTheme!),
                        size: 20,
                        color: isDark
                            ? SeedlingColors.textPrimaryDark
                            : SeedlingColors.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        data.dominantTheme!.displayName,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Seedling branding (subtle)
                Text(
                  'Seedling',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? SeedlingColors.textMutedDark
                        : SeedlingColors.textMuted,
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined, size: 18),
            label: Text(_isSharing ? 'Preparing...' : 'Share your year'),
          ),
        ),
      ],
    );
  }
}
