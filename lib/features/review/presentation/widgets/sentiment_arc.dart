import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../../app/theme/colors.dart';
import '../../domain/review_generator.dart';

/// Monthly sentiment line chart drawn with [CustomPainter].
///
/// X-axis: months (Jan through Dec).
/// Y-axis: sentiment from -1.0 to 1.0.
/// A smooth curve is drawn through the monthly averages with a gradient fill
/// below the line.
class SentimentArc extends StatelessWidget {
  /// Twelve [MonthSentiment] items, one per month (index 0 = January).
  final List<MonthSentiment> data;

  /// Whether the host app is in dark mode.
  final bool isDark;

  /// Height of the chart area.
  final double height;

  const SentimentArc({
    super.key,
    required this.data,
    required this.isDark,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = data.any((m) => m.entryCount > 0);

    if (!hasData) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Not enough sentiment data yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? SeedlingColors.textMutedDark
                  : SeedlingColors.textMuted,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _SentimentArcPainter(data: data, isDark: isDark),
          ),
        ),
        const SizedBox(height: 6),
        // Month labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            _MonthLabel('J'),
            _MonthLabel('F'),
            _MonthLabel('M'),
            _MonthLabel('A'),
            _MonthLabel('M'),
            _MonthLabel('J'),
            _MonthLabel('J'),
            _MonthLabel('A'),
            _MonthLabel('S'),
            _MonthLabel('O'),
            _MonthLabel('N'),
            _MonthLabel('D'),
          ],
        ),
      ],
    );
  }
}

class _MonthLabel extends StatelessWidget {
  final String label;
  const _MonthLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.labelSmall);
  }
}

// ---------------------------------------------------------------------------
// CustomPainter
// ---------------------------------------------------------------------------

class _SentimentArcPainter extends CustomPainter {
  final List<MonthSentiment> data;
  final bool isDark;

  _SentimentArcPainter({required this.data, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final lineColor = isDark
        ? SeedlingColors.forestGreenDark
        : SeedlingColors.forestGreen;

    // Chart region padding.
    const leftPad = 0.0;
    const rightPad = 0.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height;

    // Map month index (0..11) to x, sentiment (-1..1) to y.
    double xFor(int index) => leftPad + (index / 11) * chartWidth;
    double yFor(double sentiment) =>
        chartHeight / 2 - (sentiment * chartHeight / 2);

    // Draw zero-line.
    final zeroLinePaint = Paint()
      ..color = (isDark ? SeedlingColors.dividerDark : SeedlingColors.softCream)
      ..strokeWidth = 1;
    final zeroY = yFor(0);
    canvas.drawLine(
      Offset(leftPad, zeroY),
      Offset(size.width - rightPad, zeroY),
      zeroLinePaint,
    );

    // Build points.
    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final sentiment = data[i].entryCount > 0 ? data[i].averageSentiment : 0.0;
      points.add(Offset(xFor(i), yFor(sentiment)));
    }

    // Create a smooth path using monotone cubic interpolation.
    final path = _smoothPath(points);

    // Gradient fill below the line.
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, chartHeight)
      ..lineTo(points.first.dx, chartHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, chartHeight), [
        lineColor.withValues(alpha: 0.3),
        lineColor.withValues(alpha: 0.0),
      ]);
    canvas.drawPath(fillPath, fillPaint);

    // Draw line.
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Draw dots on months with data.
    final dotPaint = Paint()..color = lineColor;
    for (var i = 0; i < data.length; i++) {
      if (data[i].entryCount > 0) {
        canvas.drawCircle(points[i], 3.5, dotPaint);
      }
    }
  }

  /// Attempt a smooth cubic Bezier approximation through the points.
  Path _smoothPath(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);

    if (pts.length == 1) return path;

    if (pts.length == 2) {
      path.lineTo(pts[1].dx, pts[1].dy);
      return path;
    }

    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[i];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : pts[i + 1];

      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant _SentimentArcPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.isDark != isDark;
  }
}
