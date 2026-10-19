import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/palette.dart';
import '../../../../core/models/season.dart';
import '../../../tree/presentation/animated_tree_visualization.dart'
    show seasonForMonth;
import '../../../tree/presentation/painting/tree_art_palette.dart';

/// "An autumn evening": the season and part of day a memory was kept in.
String seasonMomentLine(DateTime date) {
  final season = switch (seasonForMonth(date.month)) {
    Season.spring => 'spring',
    Season.summer => 'summer',
    Season.autumn => 'autumn',
    Season.winter => 'winter',
  };
  final part = switch (date.hour) {
    >= 5 && < 12 => 'morning',
    >= 12 && < 17 => 'afternoon',
    >= 17 && < 22 => 'evening',
    _ => 'night',
  };
  final article = season == 'autumn' ? 'An' : 'A';
  return '$article $season $part';
}

/// A small seasonal sprig, painted from the tree's own palette, with the
/// season-and-time line beside it. Gives a memory without a photo a sense
/// of when it was kept. Static, so it needs nothing under Reduce Motion.
class SeasonSprigHeader extends StatelessWidget {
  final DateTime date;

  const SeasonSprigHeader({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final season = seasonForMonth(date.month);
    final night = Theme.of(context).brightness == Brightness.dark;
    final line = seasonMomentLine(date);
    return Semantics(
      label: line,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 58,
            height: 50,
            child: CustomPaint(
              painter: SeasonSprigPainter(
                season: season,
                art: TreeArtPalette.resolve(season: season, night: night),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.2,
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SeasonSprigPainter extends CustomPainter {
  final Season season;
  final TreeArtPalette art;

  SeasonSprigPainter({required this.season, required this.art});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final start = Offset(w * 0.12, h * 0.96);
    final control = Offset(w * 0.30, h * 0.30);
    final end = Offset(w * 0.90, h * 0.10);

    Offset at(double t) {
      final u = 1 - t;
      return start * (u * u) + control * (2 * u * t) + end * (t * t);
    }

    Offset tangent(double t) =>
        (control - start) * (2 * (1 - t)) + (end - control) * (2 * t);

    final stemColor = season == Season.winter
        ? (art.night ? art.barkLight : art.bark)
        : art.stem;
    final stem = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    canvas.drawPath(
      stem,
      Paint()
        ..color = stemColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    final tone = art.leafTones.first;
    final leafColors = switch (season) {
      Season.autumn when art.fallenLeaves.isNotEmpty => art.fallenLeaves,
      _ when art.night => [tone.light, tone.highlight, tone.light, tone.mid],
      _ => [tone.mid, tone.light, tone.mid, tone.highlight],
    };

    if (season == Season.winter) {
      // A bare twig with a little snow resting on it.
      final snow = Paint()..color = art.snow;
      final shade = Paint()..color = art.snowShade;
      for (final t in [0.35, 0.62, 0.86]) {
        final p = at(t);
        canvas.drawCircle(p.translate(0.6, 0.8), 2.6, shade);
        canvas.drawCircle(p.translate(0, -0.6), 2.4, snow);
      }
      _twig(canvas, at(0.5), tangent(0.5), -1, 9, stemColor);
      _twig(canvas, at(0.72), tangent(0.72), 1, 7, stemColor);
      return;
    }

    const stops = [0.28, 0.44, 0.60, 0.76];
    for (var i = 0; i < stops.length; i++) {
      final t = stops[i];
      final side = i.isEven ? -1.0 : 1.0;
      final dir = tangent(t);
      final angle = math.atan2(dir.dy, dir.dx) + side * 0.95;
      final length = h * 0.32 - i * 1.4;
      _leaf(canvas, at(t), angle, length, leafColors[i % leafColors.length]);
    }
    // A leaf at the tip.
    final tipDir = tangent(1);
    _leaf(canvas, end, math.atan2(tipDir.dy, tipDir.dx), 8, leafColors.first);

    if (season == Season.spring) {
      final p = at(0.52).translate(-6, -6);
      final petal = Paint()..color = art.blossom;
      for (var k = 0; k < 5; k++) {
        final a = k * 2 * math.pi / 5;
        canvas.drawCircle(
          p + Offset(math.cos(a), math.sin(a)) * 2.6,
          2.1,
          petal,
        );
      }
      canvas.drawCircle(p, 1.3, Paint()..color = art.blossomCenter);
    } else if (season == Season.autumn) {
      // One leaf drifting free.
      _leaf(
        canvas,
        Offset(w * 0.78, h * 0.78),
        0.6,
        7,
        leafColors.length > 1 ? leafColors[1] : leafColors.first,
      );
    }
  }

  void _twig(
    Canvas canvas,
    Offset from,
    Offset dir,
    double side,
    double length,
    Color color,
  ) {
    final angle = math.atan2(dir.dy, dir.dx) + side * 0.8;
    canvas.drawLine(
      from,
      from + Offset(math.cos(angle), math.sin(angle)) * length,
      Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _leaf(
    Canvas canvas,
    Offset base,
    double angle,
    double length,
    Color color,
  ) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);
    final width = length * 0.42;
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(length * 0.5, -width, length, 0)
      ..quadraticBezierTo(length * 0.5, width, 0, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SeasonSprigPainter old) =>
      old.season != season || old.art != art;
}
