import 'package:flutter/cupertino.dart';

import 'palette.dart';

/// Page and navigation-bar fills for the iOS (Cupertino) screens.
///
/// `CupertinoColors.systemGroupedBackground.withValues(...)` silently drops
/// the dark variant (a dynamic color's `withValues` keeps only its light
/// value), which is how scrolled bars on Settings and Support turned light
/// grey under a white title in dark mode. Read these instead.
extension SeedlingBarSurfaces on BuildContext {
  /// Background for grouped, Settings-style iOS lists: the system grouped
  /// grey in light mode, the warm palette background in dark mode.
  Color get groupedBackground {
    final palette = this.palette;
    if (palette.isDark) return palette.background;
    return CupertinoDynamicColor.resolve(
      CupertinoColors.systemGroupedBackground,
      this,
    );
  }

  /// Translucent fill for a [CupertinoNavigationBar] over a page of color
  /// [under] (defaults to the palette background). Dynamic colors are
  /// resolved for the current brightness before the opacity is applied.
  Color barBackground({Color? under, double opacity = 0.9}) {
    final base = under == null
        ? palette.background
        : CupertinoDynamicColor.resolve(under, this);
    return base.withValues(alpha: opacity);
  }
}
