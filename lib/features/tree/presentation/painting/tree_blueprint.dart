import 'dart:math' as math;
import 'dart:ui';

/// Growth value `g` runs from 0 (a seed) to 6 (an ancient tree in full):
/// the integer part is the [TreeState] index and the fraction is progress
/// towards the next state. Trees are drawn from [TreeBlueprint] for g >= 2.
const double kTreeGrowthMin = 2.0;

double _smooth(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// One branch of the full-grown skeleton, in skeleton units (trunk = 1).
class BlueprintLimb {
  BlueprintLimb({
    required this.parent,
    required this.depth,
    required this.attachT,
    required this.angle,
    required this.length,
    required this.bend,
    required this.birth,
    required this.widthRatio,
  });

  /// Index of the parent limb, or -1 for the trunk.
  final int parent;
  final int depth;

  /// Where along the parent this limb leaves it (0 = base, 1 = tip).
  final double attachT;

  /// Absolute direction, radians from vertical (positive leans right).
  final double angle;

  /// Full length relative to the trunk.
  final double length;

  /// Sideways curvature as a fraction of length.
  final double bend;

  /// Growth value at which this limb starts to grow.
  final double birth;

  /// Base width relative to the parent's width where it attaches.
  final double widthRatio;

  final List<int> children = [];
}

/// A clump of foliage hung on a limb.
class BlueprintSpot {
  const BlueprintSpot({
    required this.limb,
    required this.t,
    required this.dx,
    required this.dy,
    required this.radius,
    required this.birth,
    required this.z,
    required this.seed,
    required this.tone,
  });

  final int limb;
  final double t;

  /// Offset from the limb point, in units of [radius].
  final double dx;
  final double dy;

  /// Full radius in skeleton units.
  final double radius;
  final double birth;

  /// Depth in the crown: low values sit behind the branches.
  final double z;
  final int seed;

  /// 0..1, used to pick a tone set.
  final double tone;
}

/// The full-grown shape of one person's tree, generated once from a seed
/// (the tree's year). Every stage of growth is a partial evaluation of the
/// same blueprint, so growing adds to the tree instead of redrawing it.
class TreeBlueprint {
  TreeBlueprint._(this.seed, this.limbs, this.spots, this.roots);

  final int seed;
  final List<BlueprintLimb> limbs;
  final List<BlueprintSpot> spots;

  /// Surface roots: (angle from straight down, length, birth, width ratio).
  final List<({double side, double length, double birth, double curl})> roots;

  static final Map<int, TreeBlueprint> _cache = {};

  factory TreeBlueprint.forSeed(int seed) =>
      _cache[seed] ??= TreeBlueprint._generate(seed);

  static const int _maxDepth = 4;

  static TreeBlueprint _generate(int seed) {
    final rnd = math.Random(seed * 7919 + 17);
    double r(double a, double b) => a + rnd.nextDouble() * (b - a);

    final limbs = <BlueprintLimb>[];
    final lean = r(-0.07, 0.07);
    limbs.add(
      BlueprintLimb(
        parent: -1,
        depth: 0,
        attachT: 0,
        angle: lean,
        length: 1,
        bend: r(-0.08, 0.08),
        birth: 1.0,
        widthRatio: 1,
      ),
    );

    void grow(int index) {
      final limb = limbs[index];
      if (limb.depth >= _maxDepth) return;
      final d = limb.depth;
      final kids = <({double t, double angle, double len, double w})>[];

      // Fork at the tip into two (sometimes three) limbs.
      final forkCount = d == 0 ? (rnd.nextDouble() < 0.55 ? 3 : 2) : 2;
      final forkSpread = d == 0 ? r(0.42, 0.58) : r(0.32, 0.52);
      final firstSide = rnd.nextBool() ? 1.0 : -1.0;
      for (var i = 0; i < forkCount; i++) {
        double offset;
        if (forkCount == 3) {
          offset = (i - 1) * forkSpread * 1.1 + r(-0.08, 0.08);
        } else {
          offset = (i == 0 ? -1 : 1) * forkSpread * r(0.8, 1.15);
        }
        final isCentre = forkCount == 3 && i == 1;
        kids.add((
          t: 1.0,
          angle: offset,
          len: isCentre ? r(0.72, 0.84) : r(0.66, 0.8),
          w: isCentre ? r(0.7, 0.8) : r(0.6, 0.74),
        ));
      }

      // Side branches along the limb.
      final sideCount = switch (d) {
        0 => 2,
        1 => 1 + (rnd.nextDouble() < 0.6 ? 1 : 0),
        2 => 1,
        _ => rnd.nextDouble() < 0.5 ? 1 : 0,
      };
      for (var i = 0; i < sideCount; i++) {
        final side = (i.isEven ? firstSide : -firstSide);
        kids.add((
          t: d == 0 ? r(0.55, 0.78) : r(0.4, 0.7),
          angle: side * r(0.7, 1.05),
          len: d == 0 ? r(0.5, 0.62) : r(0.45, 0.6),
          w: r(0.45, 0.6),
        ));
      }

      for (final k in kids) {
        // Upward tropism: wide limbs bend back toward the light.
        var angle = limb.angle + k.angle;
        angle = angle * (d == 0 ? 0.92 : 0.88);
        angle = angle.clamp(-1.3, 1.3);
        final child = BlueprintLimb(
          parent: index,
          depth: d + 1,
          attachT: k.t,
          angle: angle,
          length: limb.length * k.len,
          bend: r(-0.14, 0.14),
          birth: limb.birth + r(0.45, 0.95) + (k.t < 1 ? 0.25 : 0),
          widthRatio: k.w,
        );
        limbs.add(child);
        limb.children.add(limbs.length - 1);
        grow(limbs.length - 1);
      }
    }

    grow(0);

    final spots = <BlueprintSpot>[];
    for (var i = 0; i < limbs.length; i++) {
      final limb = limbs[i];
      if (limb.depth == 0) continue;
      final terminal = limb.children.isEmpty;
      final baseRadius = switch (limb.depth) {
        1 => 0.36,
        2 => 0.33,
        3 => 0.3,
        _ => 0.27,
      };
      void add(double t, double scale, double delay) {
        final a = rnd.nextDouble() * math.pi * 2;
        spots.add(
          BlueprintSpot(
            limb: i,
            t: t,
            dx: math.cos(a) * r(0.0, 0.35),
            dy: math.sin(a) * r(0.0, 0.3) - 0.15,
            radius: baseRadius * scale * r(0.82, 1.18),
            birth: limb.birth + delay + r(0.1, 0.5),
            z: rnd.nextDouble(),
            seed: rnd.nextInt(1 << 30),
            tone: rnd.nextDouble(),
          ),
        );
      }

      add(1.0, terminal ? 1.0 : 0.9, 0.15);
      if (limb.depth >= 2) add(r(0.45, 0.65), 0.8, 0.55);
      if (terminal) add(r(0.75, 0.9), 0.75, 0.9);
    }

    final roots = <({double side, double length, double birth, double curl})>[];
    final rootCount = 3 + rnd.nextInt(2);
    for (var i = 0; i < rootCount * 2; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      roots.add((
        side: side * r(0.15, 1.0),
        length: r(0.35, 0.7),
        birth: 3.0 + (i ~/ 2) * 0.5 + r(0, 0.4),
        curl: r(-0.3, 0.3),
      ));
    }

    return TreeBlueprint._(seed, limbs, spots, roots);
  }

  /// Lay the blueprint out in pixels for growth [g], with the trunk base at
  /// [base]. [maxHeight] and [maxHalfWidth] bound the result (foliage
  /// included) so each stage fits its canvas.
  TreePose pose({
    required double g,
    required Offset base,
    required double maxHeight,
    required double maxHalfWidth,
    double foliageDensity = 1,
  }) {
    final growth = g.clamp(kTreeGrowthMin, 6.0);
    // Pixels per skeleton unit: the whole tree also grows in size.
    final unit = 38.0 + 7.0 * (growth - kTreeGrowthMin);
    final trunkWidth = 3.6 + 2.9 * (growth - kTreeGrowthMin);

    var pose = _layout(growth, base, unit, trunkWidth, foliageDensity);
    final bounds = pose.foliageBounds;
    final height = base.dy - bounds.top;
    final halfWidth = math.max(base.dx - bounds.left, bounds.right - base.dx);
    final fit = math.min(
      1.0,
      math.min(maxHeight / height, maxHalfWidth / halfWidth),
    );
    if (fit < 1) {
      pose = _layout(growth, base, unit * fit, trunkWidth, foliageDensity);
    }
    return pose;
  }

  TreePose _layout(
    double g,
    Offset base,
    double unit,
    double trunkWidth,
    double density,
  ) {
    final placed = List<PosedLimb?>.filled(limbs.length, null);
    for (var i = 0; i < limbs.length; i++) {
      final limb = limbs[i];
      final grow = _smooth((g - limb.birth) / 1.1);
      if (grow <= 0.02) continue;
      Offset start;
      double startWidth;
      if (limb.parent < 0) {
        start = base;
        startWidth = trunkWidth;
      } else {
        final parent = placed[limb.parent];
        if (parent == null) continue;
        start = parent.pointAt(limb.attachT);
        startWidth =
            parent.widthAt(limb.attachT) *
            limb.widthRatio *
            (0.55 + 0.45 * grow);
      }
      final length = limb.length * unit * grow;
      final dir = Offset(math.sin(limb.angle), -math.cos(limb.angle));
      final end = start + dir * length;
      final normal = Offset(-dir.dy, dir.dx);
      final control = (start + end) / 2 + normal * (limb.bend * length);
      final tip = math.max(0.6, startWidth * 0.32);
      placed[i] = PosedLimb(
        index: i,
        depth: limb.depth,
        start: start,
        control: control,
        end: end,
        startWidth: math.max(0.7, startWidth),
        endWidth: tip,
        angle: limb.angle,
        grow: grow,
      );
    }

    final branches = placed.whereType<PosedLimb>().toList();
    for (final b in branches) {
      b.hasVisibleChildren = limbs[b.index].children.any(
        (c) => placed[c] != null,
      );
    }

    final clusters = <PosedCluster>[];
    for (final spot in spots) {
      final limb = placed[spot.limb];
      if (limb == null) continue;
      final grow = _smooth((g - spot.birth) / 0.9);
      if (grow <= 0.05) continue;
      // Young trees carry proportionally bigger, softer clumps of leaves.
      final youth = 1 + 0.45 * (1 - ((g - kTreeGrowthMin) / 3).clamp(0.0, 1.0));
      final radius =
          spot.radius *
          unit *
          youth *
          (0.35 + 0.65 * grow) *
          (0.85 + 0.15 * density);
      final p = limb.pointAt(spot.t);
      clusters.add(
        PosedCluster(
          center: p + Offset(spot.dx * radius, spot.dy * radius),
          radius: radius,
          z: spot.z,
          seed: spot.seed,
          tone: spot.tone,
          grow: grow,
          depth: limb.depth,
        ),
      );
    }

    final rootPoses = <PosedRoot>[];
    for (final root in roots) {
      final grow = _smooth((g - root.birth) / 1.0);
      if (grow <= 0.05) continue;
      rootPoses.add(
        PosedRoot(
          side: root.side,
          length: root.length * unit * grow,
          width: trunkWidth * (0.32 + 0.12 * root.side.abs()) * grow,
          curl: root.curl,
        ),
      );
    }

    return TreePose(
      g: g,
      base: base,
      unit: unit,
      trunkWidth: trunkWidth,
      branches: branches,
      clusters: clusters,
      roots: rootPoses,
    );
  }
}

class PosedLimb {
  PosedLimb({
    required this.index,
    required this.depth,
    required this.start,
    required this.control,
    required this.end,
    required this.startWidth,
    required this.endWidth,
    required this.angle,
    required this.grow,
  });

  final int index;
  final int depth;
  final Offset start;
  final Offset control;
  final Offset end;
  final double startWidth;
  final double endWidth;
  final double angle;
  final double grow;
  bool hasVisibleChildren = false;

  Offset pointAt(double t) {
    final u = 1 - t;
    return start * (u * u) + control * (2 * u * t) + end * (t * t);
  }

  Offset tangentAt(double t) {
    final d = (control - start) * (2 * (1 - t)) + (end - control) * (2 * t);
    final len = d.distance;
    return len == 0 ? const Offset(0, -1) : d / len;
  }

  double widthAt(double t) => startWidth + (endWidth - startWidth) * t;
}

class PosedCluster {
  const PosedCluster({
    required this.center,
    required this.radius,
    required this.z,
    required this.seed,
    required this.tone,
    required this.grow,
    required this.depth,
  });

  final Offset center;
  final double radius;
  final double z;
  final int seed;
  final double tone;
  final double grow;
  final int depth;
}

class PosedRoot {
  const PosedRoot({
    required this.side,
    required this.length,
    required this.width,
    required this.curl,
  });

  final double side;
  final double length;
  final double width;
  final double curl;
}

/// The blueprint laid out for one growth value, in canvas pixels.
class TreePose {
  TreePose({
    required this.g,
    required this.base,
    required this.unit,
    required this.trunkWidth,
    required this.branches,
    required this.clusters,
    required this.roots,
  });

  final double g;
  final Offset base;
  final double unit;
  final double trunkWidth;
  final List<PosedLimb> branches;
  final List<PosedCluster> clusters;
  final List<PosedRoot> roots;

  Rect? _bounds;

  /// Bounds of branches and foliage together.
  Rect get foliageBounds => _bounds ??= _computeBounds();

  Rect _computeBounds() {
    var rect = Rect.fromCircle(center: base, radius: trunkWidth);
    for (final b in branches) {
      rect = rect.expandToInclude(Rect.fromPoints(b.start, b.end));
    }
    for (final c in clusters) {
      rect = rect.expandToInclude(
        Rect.fromCircle(center: c.center, radius: c.radius * 1.05),
      );
    }
    return rect;
  }

  /// Centre of the crown (where foliage is), for glows and particles.
  Offset get crownCenter {
    if (clusters.isEmpty) {
      final b = foliageBounds;
      return Offset(base.dx, (b.top + base.dy) / 2);
    }
    var sx = 0.0, sy = 0.0, w = 0.0;
    for (final c in clusters) {
      final weight = c.radius * c.radius;
      sx += c.center.dx * weight;
      sy += c.center.dy * weight;
      w += weight;
    }
    return Offset(sx / w, sy / w);
  }
}
