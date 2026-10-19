import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app/theme/palette.dart';
import '../../../core/models/season.dart';
import '../../../data/models/tree.dart';
import '../domain/tree_personality.dart';
import 'animated_tree_visualization.dart' show treeGrowthValue, seasonForMonth;
import 'painting/tree_illustration.dart';

/// A still portrait of a year's tree: the same procedural illustration as
/// the home tree, without sway or particles.
///
/// Each distinct scene is painted once into an image and cached, so a list
/// of many small trees (the forest) or a rebuild-heavy screen (the year in
/// review) only samples a texture per frame.
class StillTree extends StatefulWidget {
  const StillTree({super.key, required this.scene, this.semanticLabel});

  /// A year's tree as it looks for display: the same seed (its year) and
  /// growth as the home tree. A finished year rests in [restingSeason];
  /// the current year shows the season it is in now.
  factory StillTree.forYear({
    Key? key,
    required int year,
    required TreeState state,
    required double progress,
    required bool night,
    TreePersonality? personality,
    DateTime? now,
    String? semanticLabel,
  }) {
    return StillTree(
      key: key,
      scene: yearTreeScene(
        year: year,
        state: state,
        progress: progress,
        night: night,
        personality: personality,
        now: now,
      ),
      semanticLabel: semanticLabel,
    );
  }

  final TreeScene scene;

  /// Read by screen readers; null hides the picture from them.
  final String? semanticLabel;

  /// The season a finished year is shown in: late autumn, the year's
  /// last full canopy, warm and settled.
  static const Season restingSeason = Season.autumn;

  @override
  State<StillTree> createState() => _StillTreeState();

  /// Drop every cached image (tests).
  @visibleForTesting
  static void debugClearCache() => _StillTreeCache.clear();

  /// How many images have been painted so far (tests).
  @visibleForTesting
  static int get debugRenderCount => _StillTreeCache.renders;
}

/// The scene for [year]'s tree, deterministic for a given year and state.
TreeScene yearTreeScene({
  required int year,
  required TreeState state,
  required double progress,
  required bool night,
  TreePersonality? personality,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final season = year < today.year
      ? StillTree.restingSeason
      : seasonForMonth(today.month);
  return TreeScene(
    growth: treeGrowthValue(state, progress),
    season: season,
    night: night,
    seed: year,
    personality: personality,
  );
}

/// A comfortable square size for a tree of [state] when [full] is the
/// size of a fully grown one: young stages are small drawings, so their
/// canvas shrinks with them instead of leaving them adrift in empty sky.
double stillTreeExtent(TreeState state, double full) {
  const factor = {
    TreeState.seed: 0.5,
    TreeState.sprout: 0.6,
    TreeState.sapling: 0.78,
    TreeState.youngTree: 0.88,
    TreeState.matureTree: 0.95,
    TreeState.ancientTree: 1.0,
  };
  return full * factor[state]!;
}

/// Whether trees should be painted at night (dark palette).
bool stillTreeNight(BuildContext context) => context.palette.isDark;

class _StillTreeState extends State<StillTree> {
  _CacheKey? _key;
  ui.Image? _image;

  void _resolve(Size size, double dpr) {
    final key = _CacheKey(widget.scene, size, dpr);
    if (key == _key) return;
    _image?.dispose();
    _key = key;
    _image = _StillTreeCache.imageFor(key);
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final child = LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
        _resolve(size, dpr);
        return CustomPaint(
          size: size,
          painter: _StillTreePainter(_image!, dpr),
        );
      },
    );
    if (widget.semanticLabel == null) return ExcludeSemantics(child: child);
    return Semantics(image: true, label: widget.semanticLabel, child: child);
  }
}

class _StillTreePainter extends CustomPainter {
  _StillTreePainter(this.image, this.dpr);

  final ui.Image image;
  final double dpr;

  static final Paint _paint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    const m = _StillTreeCache.margin;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(-m, -m, image.width / dpr, image.height / dpr),
      _paint,
    );
  }

  @override
  bool shouldRepaint(_StillTreePainter old) =>
      !identical(old.image, image) && !old.image.isCloneOf(image);
}

@immutable
class _CacheKey {
  const _CacheKey(this.scene, this.size, this.dpr);

  final TreeScene scene;
  final Size size;
  final double dpr;

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      other.scene == scene &&
      other.size == size &&
      other.dpr == dpr;

  @override
  int get hashCode => Object.hash(scene, size, dpr);
}

/// A small LRU of painted trees. The cache owns one handle per image and
/// hands out clones, so an evicted image stays valid for widgets still
/// showing it until they dispose their own handle.
abstract final class _StillTreeCache {
  static const double margin = 10;
  static const int _capacity = 20;
  static final LinkedHashMap<_CacheKey, ui.Image> _images = LinkedHashMap();
  static int renders = 0;

  static ui.Image imageFor(_CacheKey key) {
    final hit = _images.remove(key);
    if (hit != null) {
      _images[key] = hit; // most recently used
      return hit.clone();
    }
    final image = _render(key);
    _images[key] = image;
    while (_images.length > _capacity) {
      _images.remove(_images.keys.first)!.dispose();
    }
    return image.clone();
  }

  static ui.Image _render(_CacheKey key) {
    renders++;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(key.dpr)
      ..translate(margin, margin);
    TreeIllustration(key.scene).paint(canvas, key.size);
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(
        ((key.size.width + margin * 2) * key.dpr).ceil(),
        ((key.size.height + margin * 2) * key.dpr).ceil(),
      );
    } finally {
      picture.dispose();
    }
  }

  static void clear() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    renders = 0;
  }
}
