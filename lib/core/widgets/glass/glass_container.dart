import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../app/theme/colors.dart';
import '../../platform/platform_utils.dart';

/// A container that applies a frosted glass effect on iOS
/// Falls back to a solid background on Android
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.backgroundColor,
    this.opacity = 0.85,
    this.blurSigma = 30.0,
    this.border,
  });

  final Widget child;
  final double borderRadius;
  final Color? backgroundColor;
  final double opacity;
  final double blurSigma;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? (Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface);
    final radius = BorderRadius.circular(borderRadius);

    if (PlatformUtils.isIOS) {
      return ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: opacity),
              borderRadius: radius,
              border: border,
            ),
            child: child,
          ),
        ),
      );
    }

    // Android: solid background
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: radius,
        border: border,
      ),
      child: child,
    );
  }
}

/// A sheet-style glass container with top-only rounded corners
/// Used for bottom sheets and modals
class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.backgroundColor,
    this.opacity = 0.85,
    this.blurSigma = 30.0,
  });

  final Widget child;
  final double borderRadius;
  final Color? backgroundColor;
  final double opacity;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? (Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface);
    final radius = BorderRadius.vertical(top: Radius.circular(borderRadius));

    if (PlatformUtils.isIOS) {
      return ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: opacity),
              borderRadius: radius,
            ),
            child: child,
          ),
        ),
      );
    }

    // Android: solid background
    return Container(
      decoration: BoxDecoration(color: bgColor, borderRadius: radius),
      child: child,
    );
  }
}
