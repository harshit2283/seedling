import 'package:flutter/material.dart';

/// Small branded symbol used in place of large emoji on hero surfaces.
class SeedlingSymbol extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconScale;
  final List<Color> gradientColors;
  final Color iconColor;

  const SeedlingSymbol({
    super.key,
    required this.icon,
    this.size = 72,
    this.iconScale = 0.46,
    required this.gradientColors,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final shadowColor = gradientColors.isNotEmpty
        ? gradientColors.last.withValues(alpha: 0.18)
        : iconColor.withValues(alpha: 0.18);
    final colors = gradientColors.isNotEmpty
        ? gradientColors
        : [iconColor.withValues(alpha: 0.12), iconColor.withValues(alpha: 0.2)];

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Icon(icon, size: size * iconScale, color: iconColor),
        ),
      ),
    );
  }
}
