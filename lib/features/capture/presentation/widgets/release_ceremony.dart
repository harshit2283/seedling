import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/palette.dart';
import '../../../../app/theme/radius.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/widgets/feedback/seedling_toast.dart';

/// Shows the letting-go ceremony over the current screen after a Release
/// entry was saved.
///
/// [onLetGo] permanently deletes the entry (and any media); it runs only if
/// the person chooses "Let it go completely", after the words have drifted
/// away. Closing the ceremony any other way keeps the entry: keeping is the
/// default.
Future<void> showReleaseCeremony(
  NavigatorState navigator, {
  required String? text,
  required Future<void> Function() onLetGo,
}) {
  return navigator.push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, _) =>
          ReleaseCeremony(text: text, onLetGo: onLetGo),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

enum _CeremonyPhase { drifting, choosing, releasing, gone }

/// A short, quiet ceremony: leaves drift up and away from the words, then a
/// choice — keep the words in the tree, or let them go for good.
class ReleaseCeremony extends StatefulWidget {
  const ReleaseCeremony({super.key, required this.text, required this.onLetGo});

  final String? text;
  final Future<void> Function() onLetGo;

  @override
  State<ReleaseCeremony> createState() => _ReleaseCeremonyState();
}

class _ReleaseCeremonyState extends State<ReleaseCeremony>
    with TickerProviderStateMixin {
  late final AnimationController _drift;
  late final AnimationController _release;
  _CeremonyPhase _phase = _CeremonyPhase.drifting;
  Timer? _closeTimer;
  bool _reduceMotion = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(vsync: this);
    _release = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_started) return;
    _started = true;
    _drift.duration = _reduceMotion
        ? const Duration(milliseconds: 400)
        : const Duration(milliseconds: 2400);
    _release.duration = _reduceMotion
        ? const Duration(milliseconds: 400)
        : const Duration(milliseconds: 1800);
    HapticFeedback.lightImpact();
    _drift.forward().whenComplete(() {
      if (mounted && _phase == _CeremonyPhase.drifting) {
        setState(() => _phase = _CeremonyPhase.choosing);
      }
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _drift.dispose();
    _release.dispose();
    super.dispose();
  }

  void _keep() {
    if (_phase == _CeremonyPhase.releasing || _phase == _CeremonyPhase.gone) {
      return;
    }
    HapticFeedback.selectionClick();
    Navigator.of(context).maybePop();
  }

  Future<void> _letGo() async {
    if (_phase != _CeremonyPhase.choosing &&
        _phase != _CeremonyPhase.drifting) {
      return;
    }
    HapticFeedback.mediumImpact();
    _drift.value = 1;
    setState(() => _phase = _CeremonyPhase.releasing);
    await _release.forward();
    if (!mounted) return;
    try {
      await widget.onLetGo();
    } catch (_) {
      if (!mounted) return;
      showSeedlingMessage(
        context,
        "Couldn't let this go. It's still in your tree.",
        isError: true,
      );
      Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _phase = _CeremonyPhase.gone);
    _closeTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = palette.isDark;
    final background = palette.background.withValues(alpha: 0.94);
    final muted = palette.textSecondary;
    final words = widget.text?.trim();

    return PopScope(
      // Closing mid-release would skip the deletion the person asked for.
      canPop: _phase != _CeremonyPhase.releasing,
      child: Material(
        color: background,
        child: SafeArea(
          child: Stack(
            children: [
              if (!_reduceMotion)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_drift, _release]),
                      builder: (context, _) => CustomPaint(
                        painter: _DriftingLeavesPainter(
                          drift: _drift.value,
                          release: _release.value,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (words != null && words.isNotEmpty)
                        _buildWords(context, words),
                      const SizedBox(height: 36),
                      _buildPhaseCopy(context, muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWords(BuildContext context, String words) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_drift, _release]),
      builder: (context, child) {
        final appear = Curves.easeOutCubic.transform(
          (_drift.value * 2.5).clamp(0.0, 1.0),
        );
        final away = Curves.easeInCubic.transform(_release.value);
        final opacity = (appear * (1 - away)).clamp(0.0, 1.0);
        Widget result = Opacity(opacity: opacity, child: child);
        if (!_reduceMotion) {
          result = Transform.translate(
            offset: Offset(18 * away, -60 * away + 8 * (1 - appear)),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 6 * away + 0.001,
                sigmaY: 6 * away + 0.001,
              ),
              child: result,
            ),
          );
        }
        return result;
      },
      child: Text(
        '“$words”',
        textAlign: TextAlign.center,
        maxLines: 6,
        overflow: TextOverflow.fade,
        style: theme.textTheme.titleLarge?.copyWith(
          fontFamily: PlatformUtils.isIOS ? null : 'Georgia',
          fontStyle: FontStyle.italic,
          height: 1.4,
          color: context.palette.textPrimary.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _buildPhaseCopy(BuildContext context, Color muted) {
    final theme = Theme.of(context);
    final Widget child = switch (_phase) {
      _CeremonyPhase.drifting ||
      _CeremonyPhase.releasing => SizedBox(key: ValueKey(_phase), height: 1),
      _CeremonyPhase.choosing => Column(
        key: const ValueKey('choosing'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "You've set it down.",
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: context.palette.primaryFill,
              borderRadius: SeedlingRadius.button,
              onPressed: _keep,
              child: Text(
                'Keep it in the tree',
                style: TextStyle(
                  color: context.palette.onPrimaryFill,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              onPressed: _letGo,
              child: Text(
                'Let it go completely',
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Letting go completely deletes these words from Seedling for '
            'good. There is no trash and no undo.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
      _CeremonyPhase.gone => Column(
        key: const ValueKey('gone'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "It's gone.",
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nothing of it was kept.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    };
    return AnimatedSwitcher(
      duration: _reduceMotion
          ? const Duration(milliseconds: 150)
          : const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: child,
    );
  }
}

/// Leaves rising and drifting away. [drift] runs once as the ceremony opens;
/// [release] carries the remaining leaves off when the person lets go.
class _DriftingLeavesPainter extends CustomPainter {
  _DriftingLeavesPainter({
    required this.drift,
    required this.release,
    required this.isDark,
  });

  final double drift;
  final double release;
  final bool isDark;

  static final List<_Leaf> _leaves = List.generate(14, (i) {
    final rnd = math.Random(i * 7919 + 13);
    return _Leaf(
      x: rnd.nextDouble(),
      y: 0.45 + rnd.nextDouble() * 0.4,
      size: 7 + rnd.nextDouble() * 8,
      speed: 0.6 + rnd.nextDouble() * 0.6,
      sway: 10 + rnd.nextDouble() * 22,
      phase: rnd.nextDouble() * math.pi * 2,
      spin: (rnd.nextDouble() - 0.5) * 3,
      colorIndex: i % 3,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = isDark
        ? const [
            SeedlingColors.accentRelease,
            SeedlingColors.warmBrownDark,
            SeedlingColors.leafGreenDark,
          ]
        : const [
            SeedlingColors.accentRelease,
            SeedlingColors.warmBrown,
            SeedlingColors.freshSprout,
          ];
    final paint = Paint()..style = PaintingStyle.fill;
    // Leaves rise during the drift, then fly off during the release.
    final t = (drift * 0.55 + release * 0.45).clamp(0.0, 1.0);
    for (final leaf in _leaves) {
      final progress = (t * leaf.speed).clamp(0.0, 1.0);
      final eased = Curves.easeOutSine.transform(progress);
      final dx =
          leaf.x * size.width +
          math.sin(leaf.phase + eased * math.pi * 2) * leaf.sway +
          eased * size.width * 0.15;
      final dy = leaf.y * size.height - eased * size.height * 0.7;
      final fadeIn = (drift * 4).clamp(0.0, 1.0);
      final fadeOut = 1 - Curves.easeIn.transform(progress);
      final opacity = (fadeIn * fadeOut * 0.55).clamp(0.0, 1.0);
      if (opacity <= 0.01) continue;

      paint.color = colors[leaf.colorIndex].withValues(alpha: opacity);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(leaf.phase + eased * leaf.spin * math.pi);
      final path = Path()
        ..moveTo(0, -leaf.size)
        ..quadraticBezierTo(leaf.size * 0.7, 0, 0, leaf.size)
        ..quadraticBezierTo(-leaf.size * 0.7, 0, 0, -leaf.size)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DriftingLeavesPainter old) =>
      old.drift != drift || old.release != release || old.isDark != isDark;
}

class _Leaf {
  const _Leaf({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.sway,
    required this.phase,
    required this.spin,
    required this.colorIndex,
  });

  final double x;
  final double y;
  final double size;
  final double speed;
  final double sway;
  final double phase;
  final double spin;
  final int colorIndex;
}
