import 'package:flutter/material.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/services/haptic_service.dart';

/// Animated celebration when a capsule unlocks
/// Shows a brief, delightful animation before revealing content
class CapsuleUnlockAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  final Widget child;

  const CapsuleUnlockAnimation({
    super.key,
    required this.onComplete,
    required this.child,
  });

  @override
  State<CapsuleUnlockAnimation> createState() => _CapsuleUnlockAnimationState();
}

class _CapsuleUnlockAnimationState extends State<CapsuleUnlockAnimation>
    with TickerProviderStateMixin {
  late AnimationController _lockController;
  late AnimationController _revealController;
  late AnimationController _sparkleController;

  late Animation<double> _lockShake;
  late Animation<double> _lockScale;
  late Animation<double> _revealOpacity;
  late Animation<double> _revealScale;

  bool _showContent = false;
  late final AnimationStatusListener _lockStatusListener;
  late final AnimationStatusListener _revealStatusListener;

  @override
  void initState() {
    super.initState();

    // Lock shake and scale animation
    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _lockShake = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _lockController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _lockScale = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _lockController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInBack),
      ),
    );

    // Content reveal animation
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _revealOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _revealScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutBack),
      ),
    );

    // Sparkle animation
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _lockStatusListener = (status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _showContent = true;
        });
        _revealController.forward();
        _sparkleController.forward();
        _lockController.removeStatusListener(_lockStatusListener);
      }
    };
    _revealStatusListener = (status) {
      if (status == AnimationStatus.completed) {
        _revealController.removeStatusListener(_revealStatusListener);
        widget.onComplete();
      }
    };

    _startAnimation();
  }

  void _startAnimation() async {
    // Trigger haptic
    await HapticService.onCapsuleUnlocked();

    // Wait a beat, then start
    await Future.delayed(const Duration(milliseconds: 200));

    // Shake the lock
    _lockController.forward();

    // When lock animation completes, reveal content
    _lockController.addStatusListener(_lockStatusListener);

    // When reveal completes, call onComplete
    _revealController.addStatusListener(_revealStatusListener);
  }

  @override
  void dispose() {
    _lockController.removeStatusListener(_lockStatusListener);
    _revealController.removeStatusListener(_revealStatusListener);
    _lockController.dispose();
    _revealController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark
        ? SeedlingColors.themeGratitudeDark
        : SeedlingColors.themeGratitude;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Revealed content
        if (_showContent)
          AnimatedBuilder(
            animation: _revealController,
            builder: (context, child) {
              return Opacity(
                opacity: _revealOpacity.value,
                child: Transform.scale(
                  scale: _revealScale.value,
                  child: widget.child,
                ),
              );
            },
          ),

        // Lock animation (on top during animation)
        if (!_showContent)
          AnimatedBuilder(
            animation: _lockController,
            builder: (context, child) {
              // Shake effect
              final shakeOffset =
                  _lockShake.value *
                  8 *
                  ((_lockController.value * 10).floor() % 2 == 0 ? 1 : -1);

              return Transform.translate(
                offset: Offset(shakeOffset * (1 - _lockController.value), 0),
                child: Transform.scale(
                  scale: _lockScale.value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_open, size: 48, color: accentColor),
                  ),
                ),
              );
            },
          ),

        // Sparkles
        if (_showContent)
          ...List.generate(8, (index) {
            return AnimatedBuilder(
              animation: _sparkleController,
              builder: (context, child) {
                final progress = _sparkleController.value;
                final distance = 80 * progress;
                final opacity = (1 - progress).clamp(0.0, 1.0);

                return Transform.translate(
                  offset: Offset(
                    distance *
                        (index.isEven ? 1 : -1) *
                        (index % 3 == 0 ? 0.5 : 1),
                    distance *
                        (index < 4 ? -1 : 1) *
                        (index % 2 == 0 ? 0.7 : 1),
                  ),
                  child: Opacity(
                    opacity: opacity,
                    child: Icon(
                      [
                        Icons.auto_awesome,
                        Icons.star_outline,
                        Icons.auto_awesome_motion,
                        Icons.star_rounded,
                      ][index % 4],
                      size: 16 + (index % 3) * 4.0,
                      color: accentColor,
                    ),
                  ),
                );
              },
            );
          }),
      ],
    );
  }
}

/// Show the unlock animation in a dialog
Future<void> showCapsuleUnlockAnimation(
  BuildContext context, {
  required Widget content,
}) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: CapsuleUnlockAnimation(
        onComplete: () {
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? SeedlingColors.cardDark
                : SeedlingColors.warmWhite,
            borderRadius: BorderRadius.circular(20),
          ),
          child: content,
        ),
      ),
    ),
  );
}
