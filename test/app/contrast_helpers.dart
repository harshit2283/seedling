import 'dart:math' as math;
import 'dart:ui';

/// WCAG 2.1 relative luminance of an opaque [color].
double relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Composites a translucent [foreground] over an opaque [background].
Color composite(Color foreground, Color background) {
  final a = foreground.a;
  return Color.from(
    alpha: 1,
    red: foreground.r * a + background.r * (1 - a),
    green: foreground.g * a + background.g * (1 - a),
    blue: foreground.b * a + background.b * (1 - a),
  );
}

/// WCAG contrast ratio between [foreground] (may be translucent) and an
/// opaque [background].
double contrastRatio(Color foreground, Color background) {
  final fg = composite(foreground, background);
  final l1 = relativeLuminance(fg);
  final l2 = relativeLuminance(background);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}
