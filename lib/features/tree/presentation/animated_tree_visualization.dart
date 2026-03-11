import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/colors.dart';
import '../../../core/models/season.dart';
import '../../../data/models/tree.dart';

/// Get current season based on month
Season getCurrentSeason() {
  final month = DateTime.now().month;
  return switch (month) {
    3 || 4 || 5 => Season.spring,
    6 || 7 || 8 => Season.summer,
    9 || 10 || 11 => Season.autumn,
    _ => Season.winter,
  };
}

/// Animated tree visualization with procedural graphics
/// Features: idle sway, growth transitions, seasonal colors, celebration particles
class AnimatedTreeVisualization extends StatefulWidget {
  final TreeState state;
  final double progress;
  final VoidCallback? onTap;
  final bool celebrateGrowth;

  const AnimatedTreeVisualization({
    super.key,
    required this.state,
    required this.progress,
    this.onTap,
    this.celebrateGrowth = false,
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
  TreeState? _previousState;
  double _displayedStateValue = 0;

  // Celebration particles
  late AnimationController _celebrationController;
  final List<_Particle> _particles = [];
  final _random = math.Random();

  // Season
  late Season _currentSeason;

  @override
  void initState() {
    super.initState();
    _currentSeason = getCurrentSeason();
    _displayedStateValue = widget.state.index.toDouble();
    _previousState = widget.state;

    // Idle sway - continuous gentle movement
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

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

    // Celebration particles
    _celebrationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2000),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _particles.clear();
          }
        });
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

    // Detect growth
    if (oldWidget.state != widget.state) {
      _animateGrowth(oldWidget.state, widget.state);
    }

    // Trigger celebration
    if (widget.celebrateGrowth && !oldWidget.celebrateGrowth) {
      _triggerCelebration();
    }
  }

  void _animateGrowth(TreeState from, TreeState to) {
    _previousState = from;
    _growthController.forward(from: 0).then((_) {
      _displayedStateValue = to.index.toDouble();
      _previousState = to;
    });

    // Haptic feedback for growth
    HapticFeedback.mediumImpact();
  }

  void _triggerCelebration() {
    _particles.clear();

    // Generate celebration particles
    for (int i = 0; i < 30; i++) {
      _particles.add(
        _Particle(
          x: 0.5 + (_random.nextDouble() - 0.5) * 0.3,
          y: 0.3 + (_random.nextDouble() - 0.5) * 0.2,
          vx: (_random.nextDouble() - 0.5) * 0.02,
          vy: -_random.nextDouble() * 0.015 - 0.005,
          size: _random.nextDouble() * 4 + 2,
          color: _getParticleColor(),
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.1,
        ),
      );
    }

    _celebrationController.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  Color _getParticleColor() {
    final colors = [
      SeedlingColors.freshSprout,
      SeedlingColors.leafGreen,
      SeedlingColors.paleGreen,
      Colors.amber.shade300,
      Colors.white,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: 'Your tree is a ${_getStateName()}. Tap to open memories.',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated tree
              SizedBox(
                width: _getSize(),
                height: _getSize(),
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _swayAnimation,
                    _growthAnimation,
                    _celebrationController,
                  ]),
                  builder: (context, child) {
                    // Interpolate state during growth animation
                    double stateValue = _displayedStateValue;
                    if (_growthController.isAnimating &&
                        _previousState != null) {
                      stateValue =
                          _previousState!.index +
                          (_displayedStateValue - _previousState!.index) *
                              _growthAnimation.value;
                    }

                    return CustomPaint(
                      painter: _TreePainter(
                        stateValue: stateValue,
                        swayValue: _swayAnimation.value,
                        season: _currentSeason,
                        particles: _particles,
                        particleProgress: _celebrationController.value,
                        growthScale: _growthController.isAnimating
                            ? 0.9 + 0.1 * _growthAnimation.value
                            : 1.0,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // State label
              Text(
                _getStateName(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _getStateColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              // Progress indicator
              _buildProgressIndicator(context),
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
          color: SeedlingColors.textMuted,
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
          backgroundColor: SeedlingColors.softCream,
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

/// Particle data for celebration effect
class _Particle {
  double x, y, vx, vy, size;
  double rotation = 0;
  final double rotationSpeed;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotationSpeed,
  });
}

/// Custom painter for the animated tree
class _TreePainter extends CustomPainter {
  final double stateValue;
  final double swayValue;
  final Season season;
  final List<_Particle> particles;
  final double particleProgress;
  final double growthScale;

  // Static paints to avoid allocation in render loop
  static final _groundPaint = Paint()
    ..color = SeedlingColors.warmBrown.withValues(alpha: 0.25)
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;

  static final _seedGroundPaint = Paint()
    ..color = SeedlingColors.warmBrown.withValues(alpha: 0.3)
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;

  static final _seedPaint = Paint()
    ..color = SeedlingColors.seed
    ..style = PaintingStyle.fill;

  static final _seedHighlightPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.3)
    ..style = PaintingStyle.fill;

  static final _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

  static final _stemPaint = Paint()
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final _trunkPaint = Paint()
    ..color = SeedlingColors.barkBrown
    ..style = PaintingStyle.fill;

  static final _texturePaint = Paint()
    ..color = SeedlingColors.warmBrown.withValues(alpha: 0.3)
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;

  static final _rootPaint = Paint()
    ..color = SeedlingColors.barkBrown.withValues(alpha: 0.7)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final _branchPaint = Paint()
    ..color = SeedlingColors.warmBrown
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final _leafPaint = Paint()..style = PaintingStyle.fill;

  static final _canopyPaint = Paint()..style = PaintingStyle.fill;

  static final _canopyHighlightPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.15)
    ..style = PaintingStyle.fill;

  static final _blossomPaint = Paint()
    ..color = Colors.pink.shade200.withValues(alpha: 0.8)
    ..style = PaintingStyle.fill;

  static final _particlePaint = Paint()..style = PaintingStyle.fill;

  _TreePainter({
    required this.stateValue,
    required this.swayValue,
    required this.season,
    required this.particles,
    required this.particleProgress,
    required this.growthScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(growthScale);
    canvas.translate(-center.dx, -center.dy);

    if (stateValue < 0.5) {
      _drawSeed(canvas, size, stateValue * 2);
    } else if (stateValue < 1.5) {
      _drawSprout(canvas, size, (stateValue - 0.5) / 1.0);
    } else if (stateValue < 2.5) {
      _drawSapling(canvas, size, (stateValue - 1.5) / 1.0);
    } else if (stateValue < 3.5) {
      _drawYoungTree(canvas, size, (stateValue - 2.5) / 1.0);
    } else if (stateValue < 4.5) {
      _drawMatureTree(canvas, size, (stateValue - 3.5) / 1.0);
    } else {
      _drawAncientTree(canvas, size, math.min(1.0, stateValue - 4.5));
    }

    canvas.restore();

    // Draw celebration particles
    if (particleProgress > 0 && particleProgress < 1) {
      _drawParticles(canvas, size);
    }
  }

  void _drawSeed(Canvas canvas, Size size, double progress) {
    final centerX = size.width / 2;
    final groundY = size.height * 0.85;

    // Ground line
    canvas.drawLine(
      Offset(centerX - 30, groundY),
      Offset(centerX + 30, groundY),
      _seedGroundPaint,
    );

    // Seed
    final seedSize = 12.0 + progress * 4;
    final seedY = groundY - seedSize / 2 - 2;

    // Seed body (oval)
    canvas.save();
    canvas.translate(centerX, seedY);
    canvas.rotate(swayValue * 0.05);

    final seedRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: seedSize,
        height: seedSize * 1.3,
      ),
      Radius.circular(seedSize / 2),
    );
    canvas.drawRRect(seedRect, _seedPaint);

    // Seed highlight
    canvas.drawCircle(
      Offset(-seedSize * 0.2, -seedSize * 0.3),
      seedSize * 0.2,
      _seedHighlightPaint,
    );

    canvas.restore();

    // Subtle glow
    _glowPaint
      ..color = SeedlingColors.paleGreen.withValues(
        alpha: 0.2 + 0.1 * math.sin(swayValue * math.pi),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(Offset(centerX, seedY), seedSize + 10, _glowPaint);
  }

  void _drawSprout(Canvas canvas, Size size, double progress) {
    final centerX = size.width / 2;
    final groundY = size.height * 0.85;

    // Ground
    _drawGround(canvas, size, groundY);

    // Stem
    final stemHeight = 30.0 + progress * 20;
    _stemPaint.color = _getStemColor();

    final stemPath = Path();
    stemPath.moveTo(centerX, groundY);

    // Curved stem with sway
    final swayOffset = swayValue * 3;
    stemPath.quadraticBezierTo(
      centerX + swayOffset,
      groundY - stemHeight / 2,
      centerX + swayOffset * 0.5,
      groundY - stemHeight,
    );

    canvas.drawPath(stemPath, _stemPaint);

    // Two leaves
    _drawLeaf(
      canvas,
      Offset(centerX + swayOffset * 0.5, groundY - stemHeight),
      12 + progress * 5,
      -0.4 + swayValue * 0.1,
      _getLeafColor(),
    );

    _drawLeaf(
      canvas,
      Offset(centerX + swayOffset * 0.5, groundY - stemHeight),
      12 + progress * 5,
      0.4 + swayValue * 0.1,
      _getLeafColor(),
    );
  }

  void _drawSapling(Canvas canvas, Size size, double progress) {
    final centerX = size.width / 2;
    final groundY = size.height * 0.85;

    _drawGround(canvas, size, groundY);

    // Trunk
    final trunkHeight = 50.0 + progress * 20;
    final trunkWidth = 4.0 + progress * 2;

    _drawTrunk(canvas, centerX, groundY, trunkHeight, trunkWidth);

    // Small branches with leaves
    final branchY = groundY - trunkHeight * 0.6;
    final topY = groundY - trunkHeight;

    // Left branch
    _drawBranch(canvas, centerX, branchY, -25, -15, 2, swayValue);
    _drawLeafCluster(
      canvas,
      Offset(centerX - 25, branchY - 15),
      3,
      10,
      swayValue,
    );

    // Right branch
    _drawBranch(canvas, centerX, branchY, 25, -15, 2, swayValue);
    _drawLeafCluster(
      canvas,
      Offset(centerX + 25, branchY - 15),
      3,
      10,
      swayValue,
    );

    // Top leaves
    _drawLeafCluster(canvas, Offset(centerX, topY), 5, 14, swayValue);
  }

  void _drawYoungTree(Canvas canvas, Size size, double progress) {
    final centerX = size.width / 2;
    final groundY = size.height * 0.85;

    _drawGround(canvas, size, groundY);

    final trunkHeight = 70.0 + progress * 15;
    final trunkWidth = 6.0 + progress * 2;

    _drawTrunk(canvas, centerX, groundY, trunkHeight, trunkWidth);

    // Multiple branch levels
    for (int i = 0; i < 3; i++) {
      final levelY = groundY - trunkHeight * (0.4 + i * 0.2);
      final spread = 20.0 + i * 10;
      final leafCount = 4 + i;
      final leafSize = 12.0 - i * 1.5;

      _drawBranch(
        canvas,
        centerX,
        levelY,
        -spread,
        -10 - i * 5,
        2.5 - i * 0.3,
        swayValue,
      );
      _drawBranch(
        canvas,
        centerX,
        levelY,
        spread,
        -10 - i * 5,
        2.5 - i * 0.3,
        swayValue,
      );

      _drawLeafCluster(
        canvas,
        Offset(centerX - spread, levelY - 10 - i * 5),
        leafCount,
        leafSize,
        swayValue,
      );
      _drawLeafCluster(
        canvas,
        Offset(centerX + spread, levelY - 10 - i * 5),
        leafCount,
        leafSize,
        swayValue,
      );
    }

    // Crown
    final topY = groundY - trunkHeight;
    _drawLeafCluster(canvas, Offset(centerX, topY), 8, 16, swayValue);
  }

  void _drawMatureTree(Canvas canvas, Size size, double progress) {
    final centerX = size.width / 2;
    final groundY = size.height * 0.88;

    _drawGround(canvas, size, groundY);

    final trunkHeight = 85.0 + progress * 10;
    final trunkWidth = 10.0 + progress * 2;

    // Roots
    _drawRoots(canvas, centerX, groundY, trunkWidth);

    _drawTrunk(canvas, centerX, groundY, trunkHeight, trunkWidth);

    // Full canopy
    final canopyCenter = Offset(centerX, groundY - trunkHeight * 0.7);
    _drawCanopy(canvas, canopyCenter, 55 + progress * 10, 0.8 + progress * 0.2);

    // Decorative elements based on season
    if (season == Season.spring) {
      _drawBlossoms(canvas, canopyCenter, 50);
    } else if (season == Season.autumn) {
      _drawFallingLeaves(canvas, size, canopyCenter);
    }
  }

  void _drawAncientTree(Canvas canvas, Size size, double progress) {
    final centerX = size.width / 2;
    final groundY = size.height * 0.9;

    _drawGround(canvas, size, groundY);

    final trunkHeight = 95.0;
    final trunkWidth = 14.0;

    // Elaborate roots
    _drawRoots(canvas, centerX, groundY, trunkWidth * 1.5);

    // Gnarled trunk
    _drawGnarledTrunk(canvas, centerX, groundY, trunkHeight, trunkWidth);

    // Massive canopy
    final canopyCenter = Offset(centerX, groundY - trunkHeight * 0.65);
    _drawCanopy(canvas, canopyCenter, 70, 1.0);

    // Extra foliage layers
    _drawCanopy(canvas, canopyCenter + const Offset(-15, 10), 40, 0.7);
    _drawCanopy(canvas, canopyCenter + const Offset(15, 10), 40, 0.7);

    if (season == Season.spring) {
      _drawBlossoms(canvas, canopyCenter, 65);
    } else if (season == Season.autumn) {
      _drawFallingLeaves(canvas, size, canopyCenter);
    }

    // Wisdom glow
    _glowPaint
      ..color = SeedlingColors.paleGreen.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(canopyCenter, 80, _glowPaint);
  }

  void _drawGround(Canvas canvas, Size size, double groundY) {
    final path = Path();
    path.moveTo(size.width * 0.2, groundY);
    path.quadraticBezierTo(
      size.width / 2,
      groundY + 3,
      size.width * 0.8,
      groundY,
    );
    canvas.drawPath(path, _groundPaint);
  }

  void _drawTrunk(
    Canvas canvas,
    double x,
    double groundY,
    double height,
    double width,
  ) {
    final path = Path();
    path.moveTo(x - width / 2, groundY);
    path.lineTo(x - width / 3, groundY - height);
    path.lineTo(x + width / 3, groundY - height);
    path.lineTo(x + width / 2, groundY);
    path.close();

    canvas.drawPath(path, _trunkPaint);

    // Bark texture
    for (int i = 1; i < 4; i++) {
      final y = groundY - height * i / 4;
      canvas.drawLine(
        Offset(x - width / 3, y),
        Offset(x + width / 3, y),
        _texturePaint,
      );
    }
  }

  void _drawGnarledTrunk(
    Canvas canvas,
    double x,
    double groundY,
    double height,
    double width,
  ) {
    final path = Path();
    path.moveTo(x - width / 2, groundY);

    // Gnarled left edge
    path.quadraticBezierTo(
      x - width / 2 - 5 + swayValue,
      groundY - height * 0.3,
      x - width / 3,
      groundY - height * 0.5,
    );
    path.quadraticBezierTo(
      x - width / 3 + 3,
      groundY - height * 0.7,
      x - width / 4,
      groundY - height,
    );

    // Top
    path.lineTo(x + width / 4, groundY - height);

    // Gnarled right edge
    path.quadraticBezierTo(
      x + width / 3 - 3,
      groundY - height * 0.7,
      x + width / 3,
      groundY - height * 0.5,
    );
    path.quadraticBezierTo(
      x + width / 2 + 5 + swayValue,
      groundY - height * 0.3,
      x + width / 2,
      groundY,
    );

    path.close();
    canvas.drawPath(path, _trunkPaint);
  }

  void _drawRoots(Canvas canvas, double x, double groundY, double width) {
    // Left roots
    canvas.drawLine(
      Offset(x - width / 2, groundY),
      Offset(x - width - 10, groundY + 5),
      _rootPaint,
    );
    canvas.drawLine(
      Offset(x - width / 3, groundY),
      Offset(x - width - 5, groundY + 8),
      _rootPaint,
    );

    // Right roots
    canvas.drawLine(
      Offset(x + width / 2, groundY),
      Offset(x + width + 10, groundY + 5),
      _rootPaint,
    );
    canvas.drawLine(
      Offset(x + width / 3, groundY),
      Offset(x + width + 5, groundY + 8),
      _rootPaint,
    );
  }

  void _drawBranch(
    Canvas canvas,
    double trunkX,
    double startY,
    double endXOffset,
    double endYOffset,
    double width,
    double sway,
  ) {
    _branchPaint.strokeWidth = width;

    final swayOffset = sway * 2 * (endXOffset > 0 ? 1 : -1);

    final path = Path();
    path.moveTo(trunkX, startY);
    path.quadraticBezierTo(
      trunkX + endXOffset / 2 + swayOffset,
      startY + endYOffset / 2,
      trunkX + endXOffset + swayOffset,
      startY + endYOffset,
    );

    canvas.drawPath(path, _branchPaint);
  }

  void _drawLeaf(
    Canvas canvas,
    Offset position,
    double size,
    double angle,
    Color color,
  ) {
    _leafPaint.color = color;

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(angle + swayValue * 0.1);

    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size * 0.5, -size * 0.3, size, 0);
    path.quadraticBezierTo(size * 0.5, size * 0.3, 0, 0);

    canvas.drawPath(path, _leafPaint);
    canvas.restore();
  }

  void _drawLeafCluster(
    Canvas canvas,
    Offset center,
    int count,
    double size,
    double sway,
  ) {
    final leafColor = _getLeafColor();

    for (int i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2 - math.pi / 2;
      final offset = Offset(
        math.cos(angle) * size * 0.5,
        math.sin(angle) * size * 0.3,
      );

      _drawLeaf(
        canvas,
        center + offset,
        size,
        angle + sway * 0.15,
        leafColor.withValues(alpha: 0.7 + (i % 3) * 0.1),
      );
    }
  }

  void _drawCanopy(
    Canvas canvas,
    Offset center,
    double radius,
    double density,
  ) {
    final baseColor = _getLeafColor();

    // Multiple overlapping circles for organic look
    final layers = [
      (offset: const Offset(0, 0), radiusMult: 1.0, alpha: 0.9),
      (
        offset: Offset(-radius * 0.3, radius * 0.1),
        radiusMult: 0.7,
        alpha: 0.8,
      ),
      (offset: Offset(radius * 0.3, radius * 0.1), radiusMult: 0.7, alpha: 0.8),
      (offset: Offset(0, -radius * 0.2), radiusMult: 0.6, alpha: 0.85),
    ];

    for (final layer in layers) {
      _canopyPaint.color = baseColor.withValues(alpha: layer.alpha * density);

      final swayOffset = Offset(swayValue * 3, swayValue * 1.5);
      final layerCenter = center + layer.offset + swayOffset;
      final layerRadius = radius * layer.radiusMult;

      // Organic blob shape
      final path = Path();
      const points = 12;
      for (int i = 0; i <= points; i++) {
        final angle = (i / points) * math.pi * 2;
        final wobble = math.sin(angle * 3 + swayValue) * layerRadius * 0.1;
        final r = layerRadius + wobble;
        final x = layerCenter.dx + math.cos(angle) * r;
        final y = layerCenter.dy + math.sin(angle) * r * 0.8;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      canvas.drawPath(path, _canopyPaint);
    }

    // Highlight
    canvas.drawCircle(
      center + Offset(-radius * 0.2 + swayValue, -radius * 0.2),
      radius * 0.3,
      _canopyHighlightPaint,
    );
  }

  void _drawBlossoms(Canvas canvas, Offset center, double radius) {
    final random = math.Random(42); // Fixed seed for consistent positions

    for (int i = 0; i < 15; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final r = random.nextDouble() * radius * 0.9;
      final x = center.dx + math.cos(angle) * r + swayValue * 2;
      final y = center.dy + math.sin(angle) * r * 0.7;
      final size = 3.0 + random.nextDouble() * 3;

      canvas.drawCircle(Offset(x, y), size, _blossomPaint);
    }
  }

  void _drawFallingLeaves(Canvas canvas, Size size, Offset treeCenter) {
    final random = math.Random(42);
    final leafColors = [
      Colors.orange.shade400,
      Colors.red.shade300,
      Colors.amber.shade600,
    ];

    for (int i = 0; i < 5; i++) {
      final progress = (swayValue + i * 0.3) % 2 - 1; // -1 to 1
      final x =
          treeCenter.dx + (random.nextDouble() - 0.5) * 80 + progress * 20;
      final y = treeCenter.dy + 30 + (progress + 1) * 40;

      if (y < size.height * 0.9) {
        _leafPaint.color = leafColors[i % leafColors.length].withValues(
          alpha: 0.7,
        );

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(progress * math.pi);
        canvas.drawCircle(Offset.zero, 4, _leafPaint);
        canvas.restore();
      }
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    for (final particle in particles) {
      // Update position based on progress
      final x = (particle.x + particle.vx * particleProgress * 60) * size.width;
      final y =
          (particle.y +
              particle.vy * particleProgress * 60 +
              particleProgress * particleProgress * 0.02) *
          size.height;
      final alpha = (1 - particleProgress).clamp(0.0, 1.0);

      _particlePaint.color = particle.color.withValues(alpha: alpha);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(
        particle.rotation + particle.rotationSpeed * particleProgress * 20,
      );

      // Star shape for sparkle
      final path = Path();
      for (int i = 0; i < 4; i++) {
        final angle = i * math.pi / 2;
        final outerX = math.cos(angle) * particle.size;
        final outerY = math.sin(angle) * particle.size;
        final innerAngle = angle + math.pi / 4;
        final innerX = math.cos(innerAngle) * particle.size * 0.4;
        final innerY = math.sin(innerAngle) * particle.size * 0.4;

        if (i == 0) {
          path.moveTo(outerX, outerY);
        } else {
          path.lineTo(outerX, outerY);
        }
        path.lineTo(innerX, innerY);
      }
      path.close();

      canvas.drawPath(path, _particlePaint);
      canvas.restore();
    }
  }

  Color _getStemColor() {
    return SeedlingColors.leafGreen;
  }

  Color _getLeafColor() {
    return switch (season) {
      Season.spring => SeedlingColors.freshSprout,
      Season.summer => SeedlingColors.leafGreen,
      Season.autumn => Colors.orange.shade400,
      Season.winter => SeedlingColors.paleGreen.withValues(alpha: 0.6),
    };
  }

  @override
  bool shouldRepaint(_TreePainter oldDelegate) {
    return oldDelegate.stateValue != stateValue ||
        oldDelegate.swayValue != swayValue ||
        oldDelegate.particleProgress != particleProgress ||
        oldDelegate.growthScale != growthScale ||
        oldDelegate.season != season;
  }
}
