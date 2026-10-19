import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

import '../../../../core/models/season.dart';
import '../../domain/tree_personality.dart';
import 'tree_art_palette.dart';
import 'tree_blueprint.dart';

/// Everything that decides how a settled tree looks. Two equal scenes paint
/// identical pixels, so a scene doubles as a cache key.
@immutable
class TreeScene {
  const TreeScene({
    required this.growth,
    required this.season,
    required this.night,
    required this.seed,
    this.personality,
    this.memoryLights = 0,
  });

  /// 0 (seed) .. 6 (ancient tree in full); see [kTreeGrowthMin].
  final double growth;
  final Season season;
  final bool night;

  /// Shapes the tree: the same seed always grows the same tree.
  final int seed;
  final TreePersonality? personality;

  /// Recent memories shown as small glowing lights in the crown.
  final int memoryLights;

  static const int maxMemoryLights = 7;

  int get stage => growth.floor().clamp(0, 5);

  @override
  bool operator ==(Object other) =>
      other is TreeScene &&
      other.growth == growth &&
      other.season == season &&
      other.night == night &&
      other.seed == seed &&
      other.personality == personality &&
      other.memoryLights == memoryLights;

  @override
  int get hashCode =>
      Object.hash(growth, season, night, seed, personality, memoryLights);
}

/// Enlargement of the seed and sprout drawings about the ground line.
const double kSeedScale = 1.6;
const double kSproutScale = 1.3;

/// Where the ground line sits, as a fraction of the canvas height.
double treeGroundFraction(double growth) => growth < 2 ? 0.85 : 0.87;

/// Geometry the animated layers need (glow, falling leaves, fireflies).
class TreeLayout {
  const TreeLayout({
    required this.groundY,
    required this.crownCenter,
    required this.crownRadius,
    required this.hasFoliage,
  });

  final double groundY;
  final Offset crownCenter;
  final double crownRadius;
  final bool hasFoliage;
}

/// Paints the tree illustration: ground, roots, bark, layered foliage,
/// seasonal details and memory lights. Pure function of [TreeScene] and
/// canvas size; callers record it once and replay it.
class TreeIllustration {
  TreeIllustration(this.scene)
    : palette = TreeArtPalette.resolve(
        season: scene.season,
        night: scene.night,
        personality: scene.personality,
      );

  final TreeScene scene;
  final TreeArtPalette palette;

  static final Path _leafPath = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(0.45, -0.42, 1, 0)
    ..quadraticBezierTo(0.45, 0.42, 0, 0)
    ..close();

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  TreePose? _pose;

  TreePose poseFor(Size size) {
    final groundY = size.height * treeGroundFraction(scene.growth);
    return _pose ??= TreeBlueprint.forSeed(scene.seed).pose(
      g: scene.growth,
      base: Offset(size.width / 2, groundY),
      maxHeight: groundY - 6,
      maxHalfWidth: size.width / 2 - 6,
      foliageDensity: scene.personality?.foliageDensity ?? 1,
    );
  }

  TreeLayout layout(Size size) {
    final groundY = size.height * treeGroundFraction(scene.growth);
    if (scene.growth < kTreeGrowthMin) {
      return TreeLayout(
        groundY: groundY,
        crownCenter: Offset(size.width / 2, groundY - 20),
        crownRadius: 20,
        hasFoliage: false,
      );
    }
    final pose = poseFor(size);
    final bounds = pose.foliageBounds;
    return TreeLayout(
      groundY: groundY,
      crownCenter: pose.crownCenter,
      crownRadius: math.max(bounds.width, groundY - bounds.top) / 2,
      hasFoliage: scene.season != Season.winter && pose.clusters.isNotEmpty,
    );
  }

  void paint(Canvas canvas, Size size) {
    final g = scene.growth;
    if (g < kTreeGrowthMin) {
      // Seed and sprout are drawn small and enlarged about the ground.
      final pivot = Offset(size.width / 2, size.height * treeGroundFraction(g));
      final k = g < 1 ? kSeedScale : kSproutScale;
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.scale(k);
      canvas.translate(-pivot.dx, -pivot.dy);
      if (g < 1) {
        _paintSeed(canvas, size, g);
      } else {
        _paintSprout(canvas, size, g - 1);
      }
      canvas.restore();
    } else {
      _paintTree(canvas, size);
    }
  }

  // ---------------------------------------------------------------- helpers

  math.Random _rng(int salt) => math.Random(scene.seed * 31 + salt);

  /// A soft, lumpy closed shape: a smoothed wobbly circle.
  Path _blob(
    Offset c,
    double r,
    int seed, {
    int points = 9,
    double wobble = 0.14,
    double squash = 0.88,
  }) {
    final rnd = math.Random(seed);
    final pts = <Offset>[];
    final start = rnd.nextDouble() * math.pi * 2;
    for (var i = 0; i < points; i++) {
      final a =
          start + (i + (rnd.nextDouble() - 0.5) * 0.4) / points * math.pi * 2;
      final rr = r * (1 - wobble + rnd.nextDouble() * wobble * 2);
      pts.add(c + Offset(math.cos(a) * rr, math.sin(a) * rr * squash));
    }
    final path = Path();
    Offset mid(int i) => (pts[i % points] + pts[(i + 1) % points]) / 2;
    path.moveTo(mid(points - 1).dx, mid(points - 1).dy);
    for (var i = 0; i < points; i++) {
      final m = mid(i);
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, m.dx, m.dy);
    }
    return path..close();
  }

  void _leaf(
    Canvas canvas,
    Offset at,
    double length,
    double angle,
    Color color, {
    double squash = 1,
  }) {
    _fill
      ..color = color
      ..maskFilter = null
      ..shader = null;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.scale(length, length * squash);
    canvas.drawPath(_leafPath, _fill);
    canvas.restore();
  }

  /// A band along a tapered curve, between two fractions of the half-width
  /// (-1 = left edge, 1 = right edge, relative to the direction of growth).
  Path _ribbon(
    PosedLimb b,
    double from,
    double to, {
    double t0 = 0,
    double t1 = 1,
    int steps = 10,
  }) {
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = t0 + (t1 - t0) * i / steps;
      final p = b.pointAt(t);
      final d = b.tangentAt(t);
      final n = Offset(-d.dy, d.dx);
      final hw = b.widthAt(t) / 2;
      left.add(p + n * (from * hw));
      right.add(p + n * (to * hw));
    }
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in right.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  // ------------------------------------------------------------------ seed

  void _paintSeed(Canvas canvas, Size size, double p) {
    final cx = size.width / 2;
    final groundY = size.height * treeGroundFraction(scene.growth);
    _paintSoilMound(canvas, cx, groundY, 34, 5);
    _paintGrass(canvas, cx, groundY, 30, 3, gap: 10);

    final len = 15.0 + p * 4;
    final wid = 10.5 + p * 3;
    final seedC = Offset(cx, groundY - wid * 0.38);

    // Sprouting tip once the seed has been tended a while.
    if (p > 0.35) {
      final h = (p - 0.35) / 0.65 * 13 + 2;
      final top = seedC + Offset(1.5, -wid * 0.4 - h);
      _stroke
        ..color = palette.stem
        ..strokeWidth = 1.6
        ..maskFilter = null
        ..shader = null;
      final shoot = Path()
        ..moveTo(seedC.dx, seedC.dy - wid * 0.3)
        ..quadraticBezierTo(seedC.dx - 2, top.dy + h * 0.4, top.dx, top.dy);
      canvas.drawPath(shoot, _stroke);
      _leaf(canvas, top, 4 + h * 0.25, -0.5, palette.stemLight, squash: 1.1);
    }

    canvas.save();
    canvas.translate(seedC.dx, seedC.dy);
    canvas.rotate(-0.42);
    final body = Path()
      ..moveTo(-len / 2, 0)
      ..cubicTo(-len * 0.35, -wid * 0.62, len * 0.3, -wid * 0.6, len / 2, 0)
      ..cubicTo(len * 0.3, wid * 0.62, -len * 0.35, wid * 0.6, -len / 2, 0)
      ..close();
    _fill
      ..shader = null
      ..maskFilter = null
      ..color = palette.seed;
    canvas.drawPath(body, _fill);
    canvas.save();
    canvas.clipPath(body);
    _fill.color = palette.barkShadow.withValues(alpha: 0.45);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(len * 0.05, wid * 0.42),
        width: len * 1.2,
        height: wid * 0.7,
      ),
      _fill,
    );
    _fill.color = palette.seedLight.withValues(alpha: 0.75);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-len * 0.12, -wid * 0.22),
        width: len * 0.55,
        height: wid * 0.28,
      ),
      _fill,
    );
    canvas.restore();
    _stroke
      ..color = palette.barkShadow.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    canvas.drawPath(
      Path()
        ..moveTo(-len * 0.42, 0)
        ..quadraticBezierTo(0, -wid * 0.12, len * 0.42, 0),
      _stroke,
    );
    canvas.restore();

    // Front lip of soil tucks the seed in.
    _fill
      ..color = palette.soil
      ..shader = null;
    final lip = Path()
      ..moveTo(cx - 16, groundY + 0.5)
      ..quadraticBezierTo(cx, groundY - 5.5, cx + 16, groundY + 0.5)
      ..quadraticBezierTo(cx, groundY + 2.5, cx - 16, groundY + 0.5)
      ..close();
    canvas.drawPath(lip, _fill);
  }

  // ---------------------------------------------------------------- sprout

  void _paintSprout(Canvas canvas, Size size, double p) {
    final cx = size.width / 2;
    final groundY = size.height * treeGroundFraction(scene.growth);
    _paintShadow(canvas, Offset(cx + 2, groundY + 1), 18 + p * 6, 3);
    _paintSoilMound(canvas, cx, groundY, 40, 5);
    _paintGrass(canvas, cx, groundY, 40, 5, gap: 8);

    final rnd = _rng(5);
    final h = 24.0 + p * 18;
    final sway = (rnd.nextDouble() - 0.5) * 8;
    final top = Offset(cx + sway * 0.4, groundY - h);
    final stem = Path()
      ..moveTo(cx - 1.4, groundY)
      ..quadraticBezierTo(cx + sway - 0.6, groundY - h * 0.55, top.dx, top.dy)
      ..lineTo(top.dx + 0.8, top.dy)
      ..quadraticBezierTo(
        cx + sway + 1.6,
        groundY - h * 0.55,
        cx + 1.6,
        groundY,
      )
      ..close();
    _fill
      ..shader = null
      ..maskFilter = null
      ..color = palette.stem;
    canvas.drawPath(stem, _fill);
    _stroke
      ..shader = null
      ..maskFilter = null
      ..color = palette.stemLight.withValues(alpha: 0.6)
      ..strokeWidth = 0.7;
    canvas.drawPath(
      Path()
        ..moveTo(cx - 0.8, groundY - 2)
        ..quadraticBezierTo(
          cx + sway - 1.0,
          groundY - h * 0.55,
          top.dx - 0.4,
          top.dy + 3,
        ),
      _stroke,
    );

    final tone = palette.leafTones.first;
    final leafLen = 15.0 + p * 7;
    void cotyledon(double angle, bool lit) {
      final base = lit ? tone.light : tone.mid;
      _leaf(canvas, top, leafLen, angle, base, squash: 1.05);
      // Shaded lower half below the midrib.
      canvas.save();
      canvas.translate(top.dx, top.dy);
      canvas.rotate(angle);
      canvas.scale(leafLen, leafLen * 1.05);
      canvas.clipRect(const Rect.fromLTWH(0, 0, 1, 1));
      _fill.color = lit ? tone.mid : tone.shadow;
      canvas.drawPath(_leafPath, _fill);
      canvas.restore();
      _stroke
        ..color = tone.highlight.withValues(alpha: 0.7)
        ..strokeWidth = 0.6;
      final tip = top + Offset(math.cos(angle), math.sin(angle)) * leafLen;
      canvas.drawLine(
        top + (tip - top) * 0.12,
        top + (tip - top) * 0.8,
        _stroke,
      );
    }

    cotyledon(math.pi + 0.45, true);
    cotyledon(-0.45, false);

    if (p > 0.3) {
      final q = (p - 0.3) / 0.7;
      final len = 4 + q * 8;
      _leaf(canvas, top, len, -math.pi / 2 - 0.5, tone.light, squash: 1.1);
      _leaf(canvas, top, len * 0.85, -math.pi / 2 + 0.45, tone.mid);
    }
    if (scene.season == Season.spring && p > 0.6) {
      _flower(canvas, top + Offset(-1, -6 - p * 6), 1.3);
    }
  }

  // ------------------------------------------------------------------ tree

  void _paintTree(Canvas canvas, Size size) {
    final pose = poseFor(size);
    final g = scene.growth;
    final base = pose.base;
    final bounds = pose.foliageBounds;
    final crownHalf = math.max(bounds.width / 2, 18.0);
    final winter = scene.season == Season.winter;

    // Ground: shadow pooled under the crown, soil, grass.
    _paintShadow(
      canvas,
      Offset(base.dx + crownHalf * 0.06, base.dy + 1.5),
      crownHalf * (winter ? 0.6 : 0.82),
      3.5 + crownHalf * 0.05,
    );
    final groundHalf = math.min(size.width / 2 - 4, crownHalf * 1.15 + 14);
    _paintSoilMound(canvas, base.dx, base.dy, groundHalf, 4 + g * 0.6);
    if (winter) _paintSnowDrift(canvas, base.dx, base.dy, groundHalf * 0.9);

    final front = <PosedCluster>[];
    final back = <PosedCluster>[];
    if (!winter) {
      for (final c in pose.clusters) {
        (c.z < 0.34 || c.depth <= 2 && c.z < 0.6 ? back : front).add(c);
      }
      // Shaded clusters first, sunlit ones on top: the crown reads as one
      // volume lit from the upper left rather than a stack of bubbles.
      final crownBox = pose.foliageBounds;
      double key(PosedCluster c) =>
          _lightAt(c.center, crownBox) + c.center.dy / crownBox.height * 0.25;
      front.sort((a, b) => key(a).compareTo(key(b)));
    }

    _paintRoots(canvas, pose);
    _paintBackFoliage(canvas, back);
    _paintBranches(canvas, pose);
    if (winter) {
      _paintTwigs(canvas, pose);
      _paintSnowOnBranches(canvas, pose);
    }
    _paintGrass(
      canvas,
      base.dx,
      base.dy,
      groundHalf * 0.95,
      6 + scene.stage * 2,
      gap: pose.trunkWidth * 0.9 + 4,
    );
    if (scene.season == Season.autumn) {
      _paintFallenLeaves(canvas, base, crownHalf);
    }

    final crown = Rect.fromLTRB(
      bounds.left,
      bounds.top,
      bounds.right,
      pose.clusters.isEmpty ? base.dy : _crownBottom(pose),
    );
    for (final c in front) {
      _paintCluster(canvas, c, crown);
    }
    if (scene.season == Season.spring) _paintBlossoms(canvas, front, crown);

    final personality = scene.personality;
    if (personality?.showFruit == true && !winter) {
      _paintFruit(canvas, front);
    }
    _paintMemoryLights(canvas, pose, front);
    if (personality?.showBirds == true) _paintBirds(canvas, bounds);
  }

  double _crownBottom(TreePose pose) {
    var bottom = pose.foliageBounds.top;
    for (final c in pose.clusters) {
      bottom = math.max(bottom, c.center.dy + c.radius);
    }
    return bottom;
  }

  void _paintShadow(Canvas canvas, Offset c, double rx, double ry) {
    _fill
      ..shader = null
      ..color = palette.soilShadow.withValues(alpha: palette.night ? 0.5 : 0.22)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, ry * 0.9);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
      _fill,
    );
    _fill.maskFilter = null;
  }

  void _paintSoilMound(
    Canvas canvas,
    double cx,
    double y,
    double half,
    double rise,
  ) {
    final soil = palette.soil;
    final path = Path()
      ..moveTo(cx - half, y + 1)
      ..quadraticBezierTo(cx, y - rise, cx + half, y + 1)
      ..quadraticBezierTo(cx, y + rise * 0.7, cx - half, y + 1)
      ..close();
    _fill
      ..maskFilter = null
      ..shader = ui.Gradient.linear(
        Offset(cx - half, y),
        Offset(cx + half, y),
        [
          soil.withValues(alpha: 0),
          soil.withValues(alpha: palette.night ? 0.7 : 0.55),
          soil.withValues(alpha: palette.night ? 0.7 : 0.55),
          soil.withValues(alpha: 0),
        ],
        const [0, 0.3, 0.7, 1],
      );
    canvas.drawPath(path, _fill);
    _fill.shader = null;

    // A soft rim line where the soil meets the air.
    _stroke
      ..maskFilter = null
      ..strokeWidth = 1.1
      ..shader = ui.Gradient.linear(
        Offset(cx - half, y),
        Offset(cx + half, y),
        [
          palette.soilShadow.withValues(alpha: 0),
          palette.soilShadow.withValues(alpha: palette.night ? 0.6 : 0.3),
          palette.soilShadow.withValues(alpha: 0),
        ],
        const [0, 0.5, 1],
      );
    canvas.drawPath(
      Path()
        ..moveTo(cx - half, y + 1)
        ..quadraticBezierTo(cx, y - rise, cx + half, y + 1),
      _stroke,
    );
    _stroke.shader = null;
  }

  void _paintSnowDrift(Canvas canvas, double cx, double y, double half) {
    _fill
      ..shader = ui.Gradient.linear(
        Offset(cx - half, y),
        Offset(cx + half, y),
        [
          palette.snow.withValues(alpha: 0),
          palette.snow.withValues(alpha: 0.95),
          palette.snow.withValues(alpha: 0.95),
          palette.snow.withValues(alpha: 0),
        ],
        const [0, 0.25, 0.75, 1],
      )
      ..maskFilter = null;
    final path = Path()
      ..moveTo(cx - half, y + 1.5)
      ..quadraticBezierTo(cx - half * 0.4, y - 4, cx, y - 2.5)
      ..quadraticBezierTo(cx + half * 0.5, y - 5, cx + half, y + 1.5)
      ..quadraticBezierTo(cx, y + 3, cx - half, y + 1.5)
      ..close();
    canvas.drawPath(path, _fill);
    _fill.shader = null;
    _stroke
      ..maskFilter = null
      ..strokeWidth = 0.9
      ..shader = ui.Gradient.linear(
        Offset(cx - half, y),
        Offset(cx + half, y),
        [
          palette.snowShade.withValues(alpha: 0),
          palette.snowShade,
          palette.snowShade.withValues(alpha: 0),
        ],
        const [0, 0.5, 1],
      );
    canvas.drawPath(
      Path()
        ..moveTo(cx - half, y + 1.5)
        ..quadraticBezierTo(cx, y + 3, cx + half, y + 1.5),
      _stroke,
    );
    _stroke.shader = null;
  }

  void _paintGrass(
    Canvas canvas,
    double cx,
    double y,
    double half,
    int tufts, {
    double gap = 0,
  }) {
    final rnd = _rng(101);
    _stroke
      ..shader = null
      ..maskFilter = null;
    final winter = scene.season == Season.winter;
    for (var i = 0; i < tufts; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final dist = gap + rnd.nextDouble() * (half - gap) * 0.95;
      final x = cx + side * dist;
      // Taller near the middle, shorter towards the edges.
      final fall = 1 - (dist / half).clamp(0.0, 1.0) * 0.6;
      final blades = 2 + rnd.nextInt(3);
      for (var j = 0; j < blades; j++) {
        final bx = x + (j - blades / 2) * 1.6;
        final h = (3.0 + rnd.nextDouble() * 5) * fall * (winter ? 0.7 : 1);
        final lean = (rnd.nextDouble() - 0.5) * 4 + (j - blades / 2) * 0.9;
        _stroke
          ..strokeWidth = 0.9 + rnd.nextDouble() * 0.5
          ..color = Color.lerp(
            palette.grass,
            palette.grassLight,
            rnd.nextDouble(),
          )!.withValues(alpha: 0.85);
        final blade = Path()
          ..moveTo(bx, y + 1)
          ..quadraticBezierTo(bx + lean * 0.2, y - h * 0.6, bx + lean, y - h);
        canvas.drawPath(blade, _stroke);
      }
    }
  }

  void _paintFallenLeaves(Canvas canvas, Offset base, double crownHalf) {
    final rnd = _rng(211);
    final count = 4 + (scene.growth - kTreeGrowthMin).round() * 3;
    for (var i = 0; i < count; i++) {
      final x = base.dx + (rnd.nextDouble() * 2 - 1) * crownHalf * 0.95;
      final y = base.dy + rnd.nextDouble() * 3 - 0.5;
      final color =
          palette.fallenLeaves[rnd.nextInt(palette.fallenLeaves.length)];
      _leaf(
        canvas,
        Offset(x, y),
        3.5 + rnd.nextDouble() * 2,
        rnd.nextDouble() * math.pi * 2,
        color.withValues(alpha: 0.9),
        squash: 0.55,
      );
    }
  }

  void _paintRoots(Canvas canvas, TreePose pose) {
    if (pose.roots.isEmpty) return;
    final base = pose.base;
    final tw = pose.trunkWidth;
    for (final root in pose.roots) {
      final sign = root.side.sign;
      final spread = 0.4 + 0.6 * root.side.abs();
      final w = root.width;
      // Surface roots: they rise into the trunk and taper along the ground.
      final top = base + Offset(sign * tw * 0.28, -w * 2.2);
      final foot = base + Offset(sign * tw * 0.2, 1.2);
      final end = base + Offset(sign * (tw * 0.5 + root.length * spread), 0.9);
      final ctrl = Offset(
        top.dx + (end.dx - top.dx) * 0.3,
        base.dy - w * (0.5 + root.curl * 0.3),
      );
      final path = Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy)
        ..quadraticBezierTo(
          (end.dx + foot.dx) / 2,
          base.dy + 1.6,
          foot.dx,
          foot.dy,
        )
        ..close();
      _fill
        ..shader = null
        ..maskFilter = null
        ..color = sign > 0 ? palette.barkShadow : palette.bark;
      canvas.drawPath(path, _fill);
      _stroke
        ..shader = null
        ..maskFilter = null
        ..strokeWidth = math.max(0.6, w * 0.3)
        ..color = palette.barkLight.withValues(alpha: sign > 0 ? 0.25 : 0.5);
      canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy + w * 0.4)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy + w * 0.25, end.dx, end.dy),
        _stroke,
      );
    }
  }

  void _paintBranches(Canvas canvas, TreePose pose) {
    _fill
      ..shader = null
      ..maskFilter = null;
    final trunk = pose.branches.isEmpty ? null : pose.branches.first;

    // Root flare where the trunk meets the ground.
    if (trunk != null && scene.growth >= 2.6) {
      final w = trunk.startWidth;
      final b = pose.base;
      final flare = Path()
        ..moveTo(b.dx - w * 1.05, b.dy + 1)
        ..quadraticBezierTo(
          b.dx - w * 0.5,
          b.dy - w * 0.15,
          b.dx - w * 0.45,
          b.dy - w * 1.6,
        )
        ..lineTo(b.dx + w * 0.45, b.dy - w * 1.6)
        ..quadraticBezierTo(
          b.dx + w * 0.5,
          b.dy - w * 0.15,
          b.dx + w * 1.05,
          b.dy + 1,
        )
        ..close();
      _fill.color = palette.bark;
      canvas.drawPath(flare, _fill);
    }

    // Draw thick to thin so twigs sit on their limbs.
    for (final b in pose.branches) {
      final steps = b.depth <= 1 ? 14 : 6;
      final shape = _ribbon(b, -1, 1, steps: steps);
      // Moonlight catches the fine twigs, which would vanish in the dark.
      _fill.color = palette.night && b.startWidth < 2.2
          ? Color.lerp(palette.bark, palette.barkLight, 0.45)!
          : palette.bark;
      canvas.drawPath(shape, _fill);
      final tipR = b.endWidth / 2;
      canvas.drawCircle(b.end, tipR, _fill);
      if (b.startWidth < 1.4) continue;
      // Shadow side (away from the light, upper left).
      _fill.color = palette.barkShadow.withValues(alpha: 0.7);
      canvas.drawPath(_ribbon(b, 0.2, 1, steps: steps), _fill);
      if (b.startWidth >= 2.5) {
        _fill.color = palette.barkLight.withValues(alpha: 0.55);
        canvas.drawPath(_ribbon(b, -0.8, -0.35, t1: 0.92, steps: steps), _fill);
      }
    }

    // Bark texture on the trunk and main limbs.
    final rnd = _rng(307);
    for (final b in pose.branches) {
      if (b.depth > 1 || b.startWidth < 5) continue;
      final lines = b.depth == 0 ? 5 : 2;
      for (var i = 0; i < lines; i++) {
        final across = -0.6 + 1.2 * (i + 0.5) / lines;
        final t0 = 0.05 + rnd.nextDouble() * 0.3;
        final t1 = t0 + 0.25 + rnd.nextDouble() * 0.4;
        final path = Path();
        const steps = 6;
        for (var s = 0; s <= steps; s++) {
          final t = t0 + (math.min(t1, 0.95) - t0) * s / steps;
          final d = b.tangentAt(t);
          final n = Offset(-d.dy, d.dx);
          final wob = math.sin((t * 13 + i * 1.7)) * 0.08;
          final p = b.pointAt(t) + n * ((across + wob) * b.widthAt(t) / 2);
          if (s == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        _stroke
          ..shader = null
          ..maskFilter = null
          ..strokeWidth = 0.7
          ..color = (across > 0 ? palette.barkShadow : palette.barkLight)
              .withValues(alpha: 0.45);
        canvas.drawPath(path, _stroke);
      }
    }

    // An old tree earns a knot or two.
    if (trunk != null && scene.growth >= 4.6) {
      for (final t in const [0.32, 0.6]) {
        final p = trunk.pointAt(t) + Offset(trunk.widthAt(t) * 0.12, 0);
        final w = trunk.widthAt(t);
        _fill.color = palette.barkShadow.withValues(alpha: 0.8);
        canvas.drawOval(
          Rect.fromCenter(center: p, width: w * 0.22, height: w * 0.32),
          _fill,
        );
        _stroke
          ..strokeWidth = 0.8
          ..color = palette.barkLight.withValues(alpha: 0.5);
        canvas.drawArc(
          Rect.fromCenter(center: p, width: w * 0.38, height: w * 0.5),
          math.pi * 0.6,
          math.pi * 0.9,
          false,
          _stroke,
        );
      }
    }
  }

  void _paintTwigs(Canvas canvas, TreePose pose) {
    final rnd = _rng(401);
    _stroke
      ..shader = null
      ..maskFilter = null
      ..color = palette.night
          ? Color.lerp(palette.bark, palette.barkLight, 0.45)!
          : palette.bark;
    for (final b in pose.branches) {
      if (b.hasVisibleChildren || b.depth == 0) continue;
      final dir = b.tangentAt(1);
      final base = math.atan2(dir.dy, dir.dx);
      final len = pose.unit * 0.1 * b.grow;
      for (var i = 0; i < 2; i++) {
        final a = base + (i - 0.5) * 0.9 + (rnd.nextDouble() - 0.5) * 0.3;
        final from = b.pointAt(0.88 + i * 0.07);
        final to = from + Offset(math.cos(a), math.sin(a)) * len;
        _stroke.strokeWidth = math.max(0.6, b.endWidth * 0.7);
        canvas.drawLine(from, to, _stroke);
      }
    }
  }

  void _paintSnowOnBranches(Canvas canvas, TreePose pose) {
    _stroke
      ..shader = null
      ..maskFilter = null
      ..color = palette.snow.withValues(alpha: 0.95);
    for (final b in pose.branches) {
      if (b.depth == 0 || b.startWidth < 0.9) continue;
      final slope = b.angle.abs();
      if (slope < 0.25) continue;
      final up = b.angle > 0 ? -1.0 : 1.0;
      // Thicker on flatter, thicker limbs: snow settles where it can.
      final flat = ((slope - 0.25) / 0.9).clamp(0.0, 1.0);
      final sw = (b.startWidth * 0.35 * (0.6 + flat)).clamp(0.8, 2.4);
      final path = Path();
      const steps = 8;
      for (var i = 0; i <= steps; i++) {
        final t = 0.1 + 0.75 * i / steps;
        final d = b.tangentAt(t);
        final n = Offset(-d.dy, d.dx);
        final p = b.pointAt(t) + n * (up * (b.widthAt(t) / 2 + sw * 0.15));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      // A cool shade under the snow keeps it readable on a pale card.
      _stroke
        ..strokeWidth = sw + 0.8
        ..color = palette.snowShade;
      canvas.drawPath(path.shift(const Offset(0, 0.4)), _stroke);
      _stroke
        ..strokeWidth = sw
        ..color = palette.snow;
      canvas.drawPath(path, _stroke);
    }
  }

  double _lightAt(Offset p, Rect crown) {
    final c = crown.center;
    final rx = math.max(crown.width / 2, 1.0);
    final ry = math.max(crown.height / 2, 1.0);
    final nx = (p.dx - c.dx) / rx;
    final ny = (p.dy - c.dy) / ry;
    // Light from the upper left.
    final dot = nx * -0.55 + ny * -0.83;
    return (0.5 + 0.55 * dot).clamp(0.0, 1.0);
  }

  LeafTone _toneFor(PosedCluster c, Rect crown) {
    final tones = palette.leafTones;
    if (tones.length == 1) return tones.first;
    if (scene.season == Season.autumn) {
      // Outer, higher leaves turn first: rust and amber outside, gold and the
      // last green deeper in, with a little chance mixed through.
      final dx = (c.center.dx - crown.center.dx) / math.max(crown.width, 1);
      final dy = (c.center.dy - crown.center.dy) / math.max(crown.height, 1);
      final outer = (math.sqrt(dx * dx + dy * dy) * 2).clamp(0.0, 1.0);
      final v = (outer * 0.55 + c.tone * 0.6 - 0.05).clamp(0.0, 0.999);
      // 0: last green, 1: gold, 2: amber, 3: rust
      const order = [3, 2, 0, 1];
      return tones[order[(v * 4).floor()]];
    }
    return tones[c.tone < 0.62 ? 0 : 1];
  }

  void _paintBackFoliage(Canvas canvas, List<PosedCluster> back) {
    if (back.isEmpty) return;
    _fill
      ..shader = null
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.45);
    for (final c in back) {
      _fill.color = palette.backLeaf;
      canvas.drawPath(_blob(c.center, c.radius * 1.02, c.seed), _fill);
    }
    for (final c in back) {
      final tones = palette.leafTones;
      final tone = tones[(c.tone * tones.length).floor() % tones.length];
      _fill.color = Color.lerp(palette.backLeaf, tone.shadow, 0.65)!;
      canvas.drawPath(
        _blob(
          c.center + Offset(-c.radius * 0.12, -c.radius * 0.14),
          c.radius * 0.72,
          c.seed + 1,
        ),
        _fill,
      );
    }
    _fill.maskFilter = null;
  }

  void _paintCluster(Canvas canvas, PosedCluster c, Rect crown) {
    final r = c.radius;
    final lf = _lightAt(c.center, crown);
    final tone = _toneFor(c, crown);
    final rnd = math.Random(c.seed);

    _fill
      ..shader = null
      ..maskFilter = null
      ..color = tone.shadow;
    canvas.drawPath(
      _blob(c.center + Offset(r * 0.06, r * 0.1), r, c.seed),
      _fill,
    );
    _fill.maskFilter = null;

    // Leaves breaking the silhouette along the lower edge.
    final edge = 4 + (r / 3).round().clamp(0, 6);
    for (var i = 0; i < edge; i++) {
      final a = math.pi * (0.05 + 0.9 * rnd.nextDouble());
      final p =
          c.center + Offset(math.cos(a) * r * 0.92, math.sin(a) * r * 0.82);
      _leaf(
        canvas,
        p - Offset(math.cos(a), math.sin(a)) * r * 0.1,
        r * (0.2 + rnd.nextDouble() * 0.08),
        a + (rnd.nextDouble() - 0.5) * 0.8,
        Color.lerp(tone.shadow, tone.mid, 0.25)!,
      );
    }

    _fill.color = Color.lerp(tone.mid, tone.shadow, (1 - lf) * 0.35)!;
    canvas.drawPath(
      _blob(c.center + Offset(-r * 0.07, -r * 0.08), r * 0.84, c.seed + 7),
      _fill,
    );

    if (lf > 0.18) {
      _fill.color = Color.lerp(tone.mid, tone.light, 0.35 + lf * 0.65)!;
      canvas.drawPath(
        _blob(
          c.center + Offset(-r * 0.2, -r * 0.26),
          r * (0.34 + 0.32 * lf),
          c.seed + 13,
          points: 7,
        ),
        _fill,
      );
    }

    // Sunlit leaves on top.
    final lit = (lf * 5).round();
    for (var i = 0; i < lit; i++) {
      final a = -math.pi * (0.25 + 0.6 * rnd.nextDouble());
      final d = r * (0.35 + rnd.nextDouble() * 0.45);
      final p = c.center + Offset(math.cos(a) * d - r * 0.1, math.sin(a) * d);
      _leaf(
        canvas,
        p,
        r * (0.2 + rnd.nextDouble() * 0.1),
        a + (rnd.nextDouble() - 0.5) * 1.2,
        tone.highlight.withValues(alpha: 0.85),
      );
    }
  }

  void _flower(Canvas canvas, Offset c, double s, {Color? color}) {
    final petal = color ?? scene.personality?.blossomColor ?? palette.blossom;
    _fill
      ..shader = null
      ..maskFilter = null
      ..color = petal;
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 - math.pi / 2;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * s,
        s * 0.9,
        _fill,
      );
    }
    _fill.color = palette.blossomCenter;
    canvas.drawCircle(c, s * 0.55, _fill);
  }

  void _paintBlossoms(Canvas canvas, List<PosedCluster> front, Rect crown) {
    final base = scene.personality?.blossomColor ?? palette.blossom;
    final night = palette.night;
    for (final c in front) {
      final rnd = math.Random(c.seed + 99);
      final lf = _lightAt(c.center, crown);
      final n = (c.grow * lf * (night ? 1.0 : 1.3) + rnd.nextDouble() * 0.6)
          .floor();
      for (var i = 0; i < n; i++) {
        final a = rnd.nextDouble() * math.pi * 2;
        final d = c.radius * (0.2 + rnd.nextDouble() * 0.65);
        final p = c.center + Offset(math.cos(a) * d, math.sin(a) * d * 0.8);
        final shade = rnd.nextDouble();
        final color = Color.lerp(
          base,
          night ? const Color(0xFFEDE4F0) : const Color(0xFFFFF7F8),
          shade * 0.6,
        )!.withValues(alpha: night ? 0.7 : 1);
        _flower(canvas, p, 1.1 + rnd.nextDouble() * 0.7, color: color);
      }
    }
  }

  void _paintFruit(Canvas canvas, List<PosedCluster> front) {
    final picks = [...front]
      ..sort((a, b) => (a.seed % 977).compareTo(b.seed % 977));
    final count = math.min(5, picks.length);
    for (var i = 0; i < count; i++) {
      final c = picks[i];
      final p = c.center + Offset(c.radius * 0.25, c.radius * 0.45);
      const fruit = Color(0xFFD99A3E);
      _fill
        ..shader = null
        ..maskFilter = null
        ..color = fruit;
      canvas.drawCircle(p, 2.8, _fill);
      _fill.color = const Color(0xFFA8662A);
      canvas.drawCircle(p + const Offset(0.7, 0.9), 1.6, _fill);
      _fill.color = const Color(0xFFFFE3A8).withValues(alpha: 0.85);
      canvas.drawCircle(p + const Offset(-0.9, -0.9), 0.9, _fill);
    }
  }

  /// Recent memories, hung in the tree as small warm lights.
  void _paintMemoryLights(
    Canvas canvas,
    TreePose pose,
    List<PosedCluster> front,
  ) {
    final n = scene.memoryLights.clamp(0, TreeScene.maxMemoryLights);
    if (n == 0) return;
    final spots = <Offset>[];
    if (front.isNotEmpty) {
      final picks = [...front.where((c) => c.grow > 0.5)]
        ..sort((a, b) => (a.seed % 1009).compareTo(b.seed % 1009));
      for (final c in picks.take(n)) {
        spots.add(c.center + Offset(c.radius * 0.18, c.radius * 0.38));
      }
    } else {
      final tips = [...pose.branches.where((b) => !b.hasVisibleChildren)]
        ..sort((a, b) => (a.index * 37 % 101).compareTo(b.index * 37 % 101));
      for (final b in tips.take(n)) {
        spots.add(b.end);
      }
    }
    final night = palette.night;
    final s = 1.8 + scene.stage * 0.22;
    for (final p in spots) {
      final halo = s * (night ? 4.2 : 3.0);
      _fill
        ..maskFilter = null
        ..shader = ui.Gradient.radial(p, halo, [
          palette.memoryLight.withValues(alpha: night ? 0.55 : 0.4),
          palette.memoryLight.withValues(alpha: 0),
        ]);
      canvas.drawCircle(p, halo, _fill);
      _fill
        ..shader = null
        ..color = palette.memoryLight;
      canvas.drawCircle(p, s, _fill);
      _fill.color = palette.memoryCore;
      canvas.drawCircle(p + Offset(-s * 0.3, -s * 0.3), s * 0.45, _fill);
    }
  }

  void _paintBirds(Canvas canvas, Rect crown) {
    _stroke
      ..shader = null
      ..maskFilter = null
      ..color = palette.barkShadow.withValues(alpha: palette.night ? 0.8 : 0.55)
      ..strokeWidth = 1.3;
    for (var i = 0; i < 2; i++) {
      final bx = crown.right - crown.width * (0.12 + i * 0.22);
      final by = crown.top - 4 - i * 7;
      final w = 4.5 + i * 1.5;
      canvas.drawPath(
        Path()
          ..moveTo(bx - w, by + 1.5)
          ..quadraticBezierTo(bx - w * 0.35, by - 1.5, bx, by + 0.5)
          ..quadraticBezierTo(bx + w * 0.35, by - 1.5, bx + w, by + 1.5),
        _stroke,
      );
    }
  }
}
