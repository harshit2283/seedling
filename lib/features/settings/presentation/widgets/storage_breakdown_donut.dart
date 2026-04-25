import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/services/storage/storage_usage_service.dart';

/// Animated donut chart showing storage breakdown by category.
///
/// Categories: photos, voices, objects, database, other (reserved).
class StorageBreakdownDonut extends StatelessWidget {
  final StorageUsage usage;
  final double size;

  const StorageBreakdownDonut({
    super.key,
    required this.usage,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    final segments = _segmentsFor(usage);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DonutPainter(
              segments: segments,
              progress: t,
              trackColor: Theme.of(context).dividerColor,
            ),
          ),
        );
      },
    );
  }

  static List<_DonutSegment> _segmentsFor(StorageUsage usage) {
    final total = usage.totalBytes;
    if (total <= 0) {
      return const [];
    }
    return [
      _DonutSegment(
        bytes: usage.photosBytes,
        color: SeedlingColors.accentPhoto,
      ),
      _DonutSegment(
        bytes: usage.voicesBytes,
        color: SeedlingColors.accentVoice,
      ),
      _DonutSegment(
        bytes: usage.objectsBytes,
        color: SeedlingColors.accentObject,
      ),
      _DonutSegment(
        bytes: usage.databaseBytes,
        color: SeedlingColors.forestGreen,
      ),
    ];
  }
}

class _DonutSegment {
  final int bytes;
  final Color color;
  const _DonutSegment({required this.bytes, required this.color});
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double progress;
  final Color trackColor;

  _DonutPainter({
    required this.segments,
    required this.progress,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.16;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.shortestSide - stroke) / 2,
    );
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(rect.center, rect.width / 2, trackPaint);

    final total = segments.fold<int>(0, (sum, s) => sum + s.bytes);
    if (total == 0) return;

    double startAngle = -math.pi / 2;
    for (final segment in segments) {
      if (segment.bytes <= 0) continue;
      final fraction = segment.bytes / total;
      final sweep = fraction * 2 * math.pi * progress;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += fraction * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.segments != segments ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Legend row showing a colored swatch and label/value next to a donut.
class StorageBreakdownLegend extends StatelessWidget {
  final StorageUsage usage;
  const StorageBreakdownLegend({super.key, required this.usage});

  @override
  Widget build(BuildContext context) {
    final entries = <_LegendEntry>[
      _LegendEntry(
        label: 'Photos',
        value: usage.photosFormatted,
        color: SeedlingColors.accentPhoto,
      ),
      _LegendEntry(
        label: 'Voices',
        value: usage.voicesFormatted,
        color: SeedlingColors.accentVoice,
      ),
      _LegendEntry(
        label: 'Objects',
        value: usage.objectsFormatted,
        color: SeedlingColors.accentObject,
      ),
      _LegendEntry(
        label: 'Database',
        value: usage.databaseFormatted,
        color: SeedlingColors.forestGreen,
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: e.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    e.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SeedlingColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    e.value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SeedlingColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _LegendEntry {
  final String label;
  final String value;
  final Color color;
  const _LegendEntry({
    required this.label,
    required this.value,
    required this.color,
  });
}
