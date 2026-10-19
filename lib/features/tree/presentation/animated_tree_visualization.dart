import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/palette.dart';
import '../../../core/models/season.dart';
import '../../../data/models/tree.dart';
import '../domain/tree_personality.dart';
import 'painting/tree_art_palette.dart';
import 'painting/tree_illustration.dart';

export 'painting/tree_illustration.dart' show TreeScene;

/// Get current season based on month
Season getCurrentSeason() => seasonForMonth(DateTime.now().month);

/// Season for a calendar month (1-12), northern hemisphere.
Season seasonForMonth(int month) {
  return switch (month) {
    3 || 4 || 5 => Season.spring,
    6 || 7 || 8 => Season.summer,
    9 || 10 || 11 => Season.autumn,
    _ => Season.winter,
  };
}

/// Growth value for a tree state and progress within it (see [TreeScene]).
double treeGrowthValue(TreeState state, double progress) {
  final p = progress.isNaN ? 0.0 : progress;
  final cap = state == TreeState.ancientTree ? 1.0 : 0.999;
  return state.index + p.clamp(0.0, cap);
}

/// Memory lights for the home tree: memories from the last two weeks
/// (capped by [TreeScene.maxMemoryLights]).
int recentMemoryLightCount(Iterable<DateTime> createdAt, {DateTime? now}) {
  final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 14));
  final n = createdAt.where((d) => d.isAfter(cutoff)).length;
  return math.min(n, TreeScene.maxMemoryLights);
}

/// How many times the tree's static layers have been recorded (test hook).
@visibleForTesting
int get debugTreeLayerBuilds => _TreePainter._layerBuilds;

/// Drop cached tree layers (test hook).
@visibleForTesting
void debugClearTreeLayerCache() => _TreePainter._clearLayerCache();

/// Animated tree visualization with procedural graphics.
///
/// The tree is an illustration grown from a blueprint seeded by [seed] (the
/// tree's year by default), so a person's tree keeps its shape across
/// launches and every new memory adds to it. Features: idle sway, growth
/// transitions, seasonal palettes, a moonlit night variant, memory lights
/// and a soft bloom when the tree reaches a new stage.
class AnimatedTreeVisualization extends StatefulWidget {
  final TreeState state;
  final double progress;
  final VoidCallback? onTap;
  final bool celebrateGrowth;
  final TreePersonality? personality;

  /// Overrides the season (defaults to the current month's).
  final Season? season;

  /// Shapes the tree; defaults to the current year.
  final int? seed;

  /// Recent memories drawn as small glowing lights in the tree (capped).
  final int memoryLights;

  /// Whether to show the stage name and progress-to-next-stage bar under
  /// the tree. Calm mode turns this off; the tree itself still grows.
  final bool showGrowthDetails;

  /// Enlarges the whole drawing (the canvas still grows with the stage, so
  /// relative growth is kept). The home screen uses this to make the tree
  /// the hero of the page. Layers are rasterised at the scaled resolution,
  /// so the tree stays crisp.
  final double scale;

  /// Space around the painted tree.
  final EdgeInsets padding;

  const AnimatedTreeVisualization({
    super.key,
    required this.state,
    required this.progress,
    this.onTap,
    this.celebrateGrowth = false,
    this.personality,
    this.season,
    this.seed,
    this.memoryLights = 0,
    this.showGrowthDetails = true,
    this.scale = 1.0,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  State<AnimatedTreeVisualization> createState() =>
      _AnimatedTreeVisualizationState();
}

class _AnimatedTreeVisualizationState extends State<AnimatedTreeVisualization>
    with TickerProviderStateMixin {
  // Idle sway animation
  late AnimationController _swayController;
  late Animation<double> _swayAnimation;

  // Growth transition animation
  late AnimationController _growthController;
  late Animation<double> _growthAnimation;
  double _fromGrowth = 0;

  // Celebration bloom
  late AnimationController _celebrationController;
  final List<_Mote> _motes = [];
  final _random = math.Random();

  late Season _currentSeason;
  late int _defaultSeed;

  // Ambient layer: petals, pollen, fireflies, leaves or snow.
  List<_AmbientParticle> _ambientParticles = const [];
  Object? _ambientKey;

  // Honours the system Reduce Motion / Remove Animations setting: the tree
  // stands still, growth swaps in place and no celebration plays.
  bool? _motionReduced;
  bool get _reduceMotion => _motionReduced ?? false;

  Season get _season => widget.season ?? _currentSeason;
  double get _targetGrowth => treeGrowthValue(widget.state, widget.progress);

  @override
  void initState() {
    super.initState();
    _currentSeason = getCurrentSeason();
    _defaultSeed = DateTime.now().year;
    _fromGrowth = _targetGrowth;

    // Idle sway - continuous gentle movement
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..addListener(_advanceAmbientParticles);

    _swayAnimation = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(parent: _swayController, curve: Curves.easeInOutSine),
    );

    // Growth transition
    _growthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _growthAnimation = CurvedAnimation(
      parent: _growthController,
      curve: Curves.easeOutBack,
    );

    _celebrationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2400),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _motes.clear();
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAmbient();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce == _motionReduced) return;
    _motionReduced = reduce;
    if (reduce) {
      // Rest at the centre of the sway (value 0.5 maps to no lean).
      _swayController.stop();
      _swayController.value = 0.5;
      _celebrationController.stop();
      _motes.clear();
    } else {
      _swayController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _swayController.dispose();
    _growthController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnimatedTreeVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.state != widget.state) {
      _animateGrowth(treeGrowthValue(oldWidget.state, oldWidget.progress));
    } else if (!_growthController.isAnimating) {
      _fromGrowth = _targetGrowth;
    }
    if (oldWidget.season != widget.season || oldWidget.state != widget.state) {
      _syncAmbient();
    }

    if (widget.celebrateGrowth && !oldWidget.celebrateGrowth) {
      _triggerCelebration();
    }
  }

  bool get _night => context.palette.isDark;

  void _syncAmbient() {
    final stage = widget.state.index;
    final key = (_season, _night, stage);
    if (key == _ambientKey) return;
    _ambientKey = key;
    _ambientParticles = _seedAmbient(_season, _night, stage);
  }

  List<_AmbientParticle> _seedAmbient(Season season, bool night, int stage) {
    final out = <_AmbientParticle>[];
    // Seeded so the scene (and its golden tests) is the same every launch.
    final rnd = math.Random(
      (widget.seed ?? _defaultSeed) * 31 +
          season.index * 7 +
          stage * 3 +
          (night ? 1 : 0),
    );
    final art = TreeArtPalette.resolve(season: season, night: night);
    void add(int count, List<Color> colors, double size, _AmbientShape shape) {
      for (var i = 0; i < count; i++) {
        final drifts = shape == _AmbientShape.firefly;
        out.add(
          _AmbientParticle(
            x: 0.08 + rnd.nextDouble() * 0.84,
            y: drifts ? 0.15 + rnd.nextDouble() * 0.6 : rnd.nextDouble(),
            vx: (rnd.nextDouble() - 0.5) * 0.0009,
            vy: drifts ? 0 : 0.0007 + rnd.nextDouble() * 0.0012,
            phase: rnd.nextDouble() * math.pi * 2,
            size: size + rnd.nextDouble() * size * 0.5,
            color: colors[rnd.nextInt(colors.length)],
            shape: shape,
          ),
        );
      }
    }

    switch (season) {
      case Season.spring:
        add(
          stage >= 2 ? 6 : 3,
          [art.blossom, const Color(0xFFFFF1F4)],
          3.0,
          _AmbientShape.petal,
        );
      case Season.summer:
        if (!night) add(4, [const Color(0xFFFFF3C4)], 1.4, _AmbientShape.mote);
      case Season.autumn:
        add(stage >= 3 ? 7 : 3, art.fallenLeaves, 3.6, _AmbientShape.leaf);
      case Season.winter:
        add(12, [art.snow], 1.8, _AmbientShape.snow);
    }
    if (night && season != Season.winter) {
      final flies = stage >= 4 ? 7 : (season == Season.summer ? 4 : 0);
      add(flies, [const Color(0xFFFFE39A)], 1.5, _AmbientShape.firefly);
    }
    return out;
  }

  void _advanceAmbientParticles() {
    if (_ambientParticles.isEmpty) return;
    final swayInfluence = _swayAnimation.value * 0.0006;
    for (final p in _ambientParticles) {
      if (p.shape == _AmbientShape.firefly) {
        p.phase += 0.03;
        p.x += math.sin(p.phase * 0.7) * 0.0009 + p.vx * 0.3;
        p.y += math.cos(p.phase * 0.55) * 0.0007;
        if (p.x > 0.95 || p.x < 0.05) p.vx = -p.vx;
        p.x = p.x.clamp(0.04, 0.96);
        p.y = p.y.clamp(0.08, 0.85);
        continue;
      }
      p.x += p.vx + swayInfluence;
      p.y += p.vy;
      p.phase += 0.04;
      if (p.y > 1.05) p.y = -0.05;
      if (p.x > 1.05) p.x = -0.05;
      if (p.x < -0.05) p.x = 1.05;
    }
  }

  void _animateGrowth(double from) {
    HapticFeedback.mediumImpact();
    if (_reduceMotion) {
      _growthController.value = 1;
      _fromGrowth = _targetGrowth;
      return;
    }
    _fromGrowth = from;
    _growthController.forward(from: 0).then((_) {
      if (mounted) _fromGrowth = _targetGrowth;
    });
  }

  void _triggerCelebration() {
    _motes.clear();
    if (_reduceMotion) {
      HapticFeedback.lightImpact();
      return;
    }
    final art = TreeArtPalette.resolve(
      season: _season,
      night: _night,
      personality: widget.personality,
    );
    final colors = [
      art.memoryCore,
      art.memoryLight,
      widget.personality?.blossomColor ?? art.blossom,
      art.leafTones.first.highlight,
    ];
    for (var i = 0; i < 18; i++) {
      final a = _random.nextDouble() * math.pi * 2;
      final d = math.sqrt(_random.nextDouble()) * 0.75;
      _motes.add(
        _Mote(
          x: math.cos(a) * d,
          y: math.sin(a) * d * 0.8,
          rise: 0.5 + _random.nextDouble() * 0.7,
          drift: (_random.nextDouble() - 0.5) * 0.5,
          delay: _random.nextDouble() * 0.35,
          size: 1.4 + _random.nextDouble() * 2.0,
          color: colors[_random.nextInt(colors.length)],
        ),
      );
    }
    _celebrationController.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final night = _night;
    final seed = widget.seed ?? _defaultSeed;
    final scale = widget.scale;
    final pixelRatio =
        (MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0) * scale;
    return Semantics(
      button: widget.onTap != null,
      label: widget.showGrowthDetails
          ? 'Your tree is a ${_getStateName()}. Tap to open memories.'
          : 'Your tree. Tap to open memories.',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _getSize() * scale,
                height: _getSize() * scale,
                child: FittedBox(
                  child: SizedBox(
                    width: _getSize(),
                    height: _getSize(),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _swayAnimation,
                        _growthAnimation,
                        _celebrationController,
                      ]),
                      builder: (context, child) {
                        final animating = _growthController.isAnimating;
                        final target = _targetGrowth;
                        final growth = animating
                            ? (_fromGrowth +
                                      (target - _fromGrowth) *
                                          _growthAnimation.value)
                                  .clamp(0.0, 6.0)
                            : target;
                        return CustomPaint(
                          painter: _TreePainter(
                            scene: TreeScene(
                              growth: growth,
                              season: _season,
                              night: night,
                              seed: seed,
                              personality: widget.personality,
                              memoryLights: widget.memoryLights,
                            ),
                            settled: !animating,
                            pixelRatio: pixelRatio,
                            swayValue: _swayAnimation.value,
                            motes: _motes,
                            moteProgress: _celebrationController.value,
                            ambientParticles: _ambientParticles,
                            growthScale: animating
                                ? 0.9 + 0.1 * _growthAnimation.value
                                : 1.0,
                          ),
                          size: Size.infinite,
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (widget.showGrowthDetails) ...[
                const SizedBox(height: 16),
                Text(
                  _getStateName(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _getStateColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _buildProgressIndicator(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    if (widget.state == TreeState.ancientTree) {
      return Text(
        'Flourishing',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.palette.textMuted,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return SizedBox(
      width: 80,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: widget.progress,
          backgroundColor: Theme.of(context).dividerColor,
          valueColor: AlwaysStoppedAnimation<Color>(
            _getStateColor().withValues(alpha: 0.6),
          ),
          minHeight: 4,
        ),
      ),
    );
  }

  double _getSize() {
    return switch (widget.state) {
      TreeState.seed => 120,
      TreeState.sprout => 140,
      TreeState.sapling => 160,
      TreeState.youngTree => 180,
      TreeState.matureTree => 200,
      TreeState.ancientTree => 220,
    };
  }

  Color _getStateColor() {
    if (context.palette.isDark) return context.palette.primary;
    return switch (widget.state) {
      TreeState.seed => SeedlingColors.seed,
      TreeState.sprout => SeedlingColors.sprout,
      TreeState.sapling => SeedlingColors.sapling,
      TreeState.youngTree => SeedlingColors.youngTree,
      TreeState.matureTree => SeedlingColors.matureTree,
      TreeState.ancientTree => SeedlingColors.ancientTree,
    };
  }

  String _getStateName() {
    return switch (widget.state) {
      TreeState.seed => 'Seed',
      TreeState.sprout => 'Sprout',
      TreeState.sapling => 'Sapling',
      TreeState.youngTree => 'Young Tree',
      TreeState.matureTree => 'Mature Tree',
      TreeState.ancientTree => 'Ancient Tree',
    };
  }
}

/// A mote of light in the growth bloom, relative to the crown.
class _Mote {
  _Mote({
    required this.x,
    required this.y,
    required this.rise,
    required this.drift,
    required this.delay,
    required this.size,
    required this.color,
  });

  final double x, y, rise, drift, delay, size;
  final Color color;
}

/// Custom painter for the animated tree
class _TreePainter extends CustomPainter {
  _TreePainter({
    required this.scene,
    required this.settled,
    required this.pixelRatio,
    required this.swayValue,
    required this.motes,
    required this.moteProgress,
    required this.ambientParticles,
    required this.growthScale,
  });

  final TreeScene scene;

  /// Not mid-transition: the tree can be replayed from the cache.
  final bool settled;
  final double pixelRatio;
  final double swayValue;
  final List<_Mote> motes;
  final double moteProgress;
  final List<_AmbientParticle> ambientParticles;
  final double growthScale;

  static final _fill = Paint();
  static final _layerImagePaint = Paint()..filterQuality = FilterQuality.medium;
  static final Path _leafPath = Path()
    ..moveTo(-1, 0)
    ..quadraticBezierTo(0, -0.85, 1, 0)
    ..quadraticBezierTo(0, 0.85, -1, 0)
    ..close();

  /// Horizontal skew per unit of sway. The sway is applied as one transform
  /// over the cached tree: points on the ground line stay put and the crown
  /// moves ~3px, without re-tessellating anything.
  static const double _swaySkew = 0.02;

  /// Margin around the canvas kept in the cached image, so foliage that
  /// leans past the edge is not clipped.
  static const double _margin = 10;

  /// Cached static layers, most recently used last. Small because only the
  /// home tree (and a growth transition's endpoints) are ever on screen.
  // Map literals are insertion-ordered (LinkedHashMap), which gives LRU.
  static final _layerCache = <_TreeLayerKey, _TreeLayers>{};
  static const int _maxCachedLayers = 4;

  /// Number of times static layers were (re)built. Tests use this to prove
  /// idle frames replay the cache instead of re-recording the tree.
  static int _layerBuilds = 0;

  static void _clearLayerCache() {
    for (final layers in _layerCache.values) {
      layers.dispose();
    }
    _layerCache.clear();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(growthScale);
    canvas.translate(-center.dx, -center.dy);

    final TreeLayout layout;
    if (settled) {
      final layers = _layersFor(size);
      layout = layers.layout;
      if (layers.glow != null) {
        _layerImagePaint.color = Color.fromRGBO(0, 0, 0, _glowOpacity());
        canvas.drawImage(layers.glow!, layers.glowOrigin, _layerImagePaint);
      }
      _layerImagePaint.color = const Color(0xFF000000);
      _withSway(canvas, layout.groundY, () {
        final image = layers.body;
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(
            -_margin,
            -_margin,
            image.width / pixelRatio,
            image.height / pixelRatio,
          ),
          _layerImagePaint,
        );
      });
    } else {
      // Mid-transition: the growth value changes every frame, draw live.
      final art = TreeIllustration(scene);
      layout = art.layout(size);
      _drawGlow(canvas, layout, opacity: _glowOpacity());
      _withSway(canvas, layout.groundY, () => art.paint(canvas, size));
    }

    canvas.restore();

    if (ambientParticles.isNotEmpty) _drawAmbient(canvas, size);

    if (moteProgress > 0 && moteProgress < 1 && motes.isNotEmpty) {
      _drawBloom(canvas, layout);
    }
  }

  void _withSway(Canvas canvas, double groundY, VoidCallback draw) {
    canvas.save();
    // Skew about the ground line: x' = x + k * (groundY - y).
    canvas.translate(0, groundY);
    canvas.skew(-_swaySkew * swayValue, 0);
    canvas.translate(0, -groundY);
    draw();
    canvas.restore();
  }

  _TreeLayers _layersFor(Size size) {
    final key = _TreeLayerKey(size, scene, pixelRatio);
    final cached = _layerCache.remove(key);
    if (cached != null) {
      _layerCache[key] = cached; // mark most recently used
      return cached;
    }

    _layerBuilds++;
    final art = TreeIllustration(scene);
    final layout = art.layout(size);

    final width = ((size.width + _margin * 2) * pixelRatio).ceil();
    final height = ((size.height + _margin * 2) * pixelRatio).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(pixelRatio)
      ..translate(_margin, _margin);
    art.paint(canvas, size);
    final picture = recorder.endRecording();
    final ui.Image body;
    try {
      body = picture.toImageSync(width, height);
    } finally {
      picture.dispose();
    }

    final glow = _rasteriseGlow(layout);
    final layers = _TreeLayers(
      body,
      glow?.image,
      glow?.origin ?? Offset.zero,
      layout,
    );

    _layerCache[key] = layers;
    while (_layerCache.length > _maxCachedLayers) {
      final oldest = _layerCache.keys.first;
      _layerCache.remove(oldest)!.dispose();
    }
    return layers;
  }

  /// Where and how big the soft glow is for this scene, or null.
  ({Offset center, double radius, double sigma, Color color})? _glowSpec(
    TreeLayout layout,
  ) {
    final g = scene.growth;
    final art = TreeArtPalette.resolve(
      season: scene.season,
      night: scene.night,
    );
    if (g < 1) {
      final seedY = layout.groundY - 6 * kSeedScale;
      return (
        center: Offset(layout.crownCenter.dx, seedY),
        radius: 22.0 + g * 6,
        sigma: 14.0,
        color: art.glow,
      );
    }
    if (g >= 5 || (scene.night && g >= 3)) {
      return (
        center: layout.crownCenter,
        radius: layout.crownRadius * 0.7,
        sigma: 18.0,
        color: art.glow,
      );
    }
    return null;
  }

  /// Glow opacity this frame: the seed's glow breathes with the sway.
  double _glowOpacity() {
    final g = scene.growth;
    if (g < 1) {
      return (0.26 + 0.12 * math.sin(swayValue * math.pi)).clamp(0.0, 1.0);
    }
    if (scene.night) return g >= 5 ? 0.2 : 0.13;
    return 0.16;
  }

  void _drawGlow(Canvas canvas, TreeLayout layout, {required double opacity}) {
    final spec = _glowSpec(layout);
    if (spec == null) return;
    _fill
      ..shader = null
      ..color = spec.color.withValues(alpha: opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, spec.sigma);
    canvas.drawCircle(spec.center, spec.radius, _fill);
    _fill.maskFilter = null;
  }

  /// Rasterise the blur once: MaskFilter.blur is re-rasterised on every
  /// frame it is drawn, an image is just sampled. Opacity is applied when
  /// the image is drawn, so the seed's breathing glow still works.
  ({ui.Image image, Offset origin})? _rasteriseGlow(TreeLayout layout) {
    final spec = _glowSpec(layout);
    if (spec == null) return null;
    final extent = spec.radius + spec.sigma * 3;
    final origin = spec.center - Offset(extent, extent);
    final side = (extent * 2).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..translate(-origin.dx, -origin.dy);
    _drawGlow(canvas, layout, opacity: 1);
    final picture = recorder.endRecording();
    try {
      return (image: picture.toImageSync(side, side), origin: origin);
    } finally {
      picture.dispose();
    }
  }

  void _drawAmbient(Canvas canvas, Size size) {
    final paint = _fill
      ..shader = null
      ..maskFilter = null;
    for (final p in ambientParticles) {
      final x = p.x * size.width;
      final y = p.y * size.height;
      final pulse = (math.sin(p.phase) + 1) / 2;
      switch (p.shape) {
        case _AmbientShape.firefly:
          final glow = 0.35 + pulse * 0.65;
          paint.color = p.color.withValues(alpha: 0.18 * glow);
          canvas.drawCircle(Offset(x, y), p.size * 3.6, paint);
          paint.color = p.color.withValues(alpha: 0.3 * glow);
          canvas.drawCircle(Offset(x, y), p.size * 1.8, paint);
          paint.color = const Color(0xFFFFFBE8).withValues(alpha: glow);
          canvas.drawCircle(Offset(x, y), p.size * 0.6, paint);
        case _AmbientShape.mote:
          paint.color = p.color.withValues(alpha: 0.35 + pulse * 0.3);
          canvas.drawCircle(Offset(x, y), p.size, paint);
        case _AmbientShape.snow:
          paint.color = p.color.withValues(alpha: 0.55 + pulse * 0.3);
          canvas.drawCircle(Offset(x, y), p.size, paint);
        case _AmbientShape.petal:
        case _AmbientShape.leaf:
          paint.color = p.color.withValues(alpha: 0.75 + pulse * 0.15);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(p.phase * (p.shape == _AmbientShape.leaf ? 0.4 : 0.3));
          // Tumbling: the leaf narrows as it turns edge-on.
          final turn = 0.35 + 0.65 * (math.cos(p.phase * 0.9).abs());
          canvas.scale(p.size, p.size * turn);
          canvas.drawPath(_leafPath, paint);
          canvas.restore();
      }
    }
  }

  /// Growth bloom: a soft light opening in the crown and motes of light
  /// drifting up out of it.
  void _drawBloom(Canvas canvas, TreeLayout layout) {
    final t = moteProgress;
    final c = layout.crownCenter;
    final r = math.max(layout.crownRadius, 24.0);
    final ease = Curves.easeOutCubic.transform(t);
    final ringAlpha = math.sin(math.pi * t) * (scene.night ? 0.32 : 0.26);
    final art = TreeArtPalette.resolve(
      season: scene.season,
      night: scene.night,
    );
    final glowRadius = r * (0.5 + 0.8 * ease);
    _fill
      ..maskFilter = null
      ..shader = ui.Gradient.radial(
        c,
        glowRadius,
        [
          art.memoryCore.withValues(alpha: ringAlpha),
          art.memoryLight.withValues(alpha: ringAlpha * 0.4),
          art.memoryLight.withValues(alpha: 0),
        ],
        const [0, 0.55, 1],
      );
    canvas.drawCircle(c, glowRadius, _fill);
    _fill.shader = null;

    for (final m in motes) {
      final local = ((t - m.delay) / (1 - m.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final alpha = math.sin(math.pi * local);
      final rise = Curves.easeOutSine.transform(local) * m.rise * r;
      final x = c.dx + m.x * r + math.sin(local * math.pi * 1.5) * m.drift * r;
      final y = c.dy + m.y * r - rise;
      _fill.color = m.color.withValues(alpha: alpha * 0.25);
      canvas.drawCircle(Offset(x, y), m.size * 2.6, _fill);
      _fill.color = m.color.withValues(alpha: alpha * 0.9);
      canvas.drawCircle(Offset(x, y), m.size, _fill);
    }
  }

  @override
  bool shouldRepaint(_TreePainter oldDelegate) {
    return oldDelegate.scene != scene ||
        oldDelegate.settled != settled ||
        oldDelegate.swayValue != swayValue ||
        oldDelegate.moteProgress != moteProgress ||
        oldDelegate.growthScale != growthScale ||
        oldDelegate.pixelRatio != pixelRatio ||
        oldDelegate.motes.length != motes.length ||
        !identical(oldDelegate.ambientParticles, ambientParticles);
  }
}

/// Identity of a cached static tree: anything that changes its pixels.
class _TreeLayerKey {
  const _TreeLayerKey(this.size, this.scene, this.pixelRatio);

  final Size size;
  final TreeScene scene;
  final double pixelRatio;

  @override
  bool operator ==(Object other) =>
      other is _TreeLayerKey &&
      other.size == size &&
      other.scene == scene &&
      other.pixelRatio == pixelRatio;

  @override
  int get hashCode => Object.hash(size, scene, pixelRatio);
}

/// The tree rasterised once (ground, roots, bark, foliage, decorations)
/// plus its glow, replayed every frame under the sway transform.
class _TreeLayers {
  _TreeLayers(this.body, this.glow, this.glowOrigin, this.layout);

  final ui.Image body;
  final ui.Image? glow;
  final Offset glowOrigin;
  final TreeLayout layout;

  void dispose() {
    body.dispose();
    glow?.dispose();
  }
}

enum _AmbientShape { petal, firefly, mote, leaf, snow }

class _AmbientParticle {
  double x;
  double y;
  double vx;
  double vy;
  double phase;
  final double size;
  final Color color;
  final _AmbientShape shape;

  _AmbientParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.phase,
    required this.size,
    required this.color,
    required this.shape,
  });
}
