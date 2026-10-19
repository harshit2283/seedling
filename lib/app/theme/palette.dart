import 'package:flutter/material.dart';

import 'colors.dart';

/// Semantic colors that adapt to light and dark mode.
///
/// Widgets in `lib/features` read colors through `context.palette` instead of
/// the raw [SeedlingColors] constants, so every surface and every piece of
/// text picks the right variant for the current brightness. The palette is
/// registered on both [ThemeData]s in `SeedlingTheme`, which the iOS
/// Cupertino shell also wraps its content in, so it is reachable everywhere.
///
/// Text colors are chosen so that [textPrimary] and [textSecondary] meet
/// WCAG AA (4.5:1) on [background], [surface] and [card]. [textMuted] is for
/// hints and decorative captions only (≥3:1).
@immutable
class SeedlingPalette extends ThemeExtension<SeedlingPalette> {
  const SeedlingPalette({
    required this.brightness,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primaryFill,
    required this.onPrimaryFill,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.bark,
    required this.background,
    required this.backgroundGradientStart,
    required this.backgroundGradientEnd,
    required this.surface,
    required this.card,
    required this.surfaceMuted,
    required this.divider,
    required this.border,
    required this.glassTint,
    required this.shadow,
    required this.scrim,
    required this.onMedia,
    required this.mediaScrim,
    required this.error,
    required this.success,
    required this.warning,
    required this.accentLine,
    required this.accentPhoto,
    required this.accentVoice,
    required this.accentObject,
    required this.accentFragment,
    required this.accentRitual,
    required this.accentRelease,
    required this.accentGold,
  });

  final Brightness brightness;

  /// Body copy, titles and primary icons.
  final Color textPrimary;

  /// Supporting copy, dates and secondary icons. AA on every surface.
  final Color textSecondary;

  /// Hints, placeholders and decorative captions only.
  final Color textMuted;

  /// Brand green for text, icons and outlines.
  final Color primary;

  /// Brand green used as a filled background (buttons, FAB, selected chips).
  final Color primaryFill;

  /// Text and icons placed on [primaryFill].
  final Color onPrimaryFill;

  /// Soft green container (badges, icon wells).
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Warm bark brown accent.
  final Color secondary;

  /// Deep bark brown for small labels on warm chips (AA on [surfaceMuted]).
  final Color bark;

  final Color background;
  final Color backgroundGradientStart;
  final Color backgroundGradientEnd;

  /// Sheets, dialogs and elevated panels.
  final Color surface;

  /// Memory cards and list rows.
  final Color card;

  /// Subtle fills: inputs, inactive chips, wells.
  final Color surfaceMuted;

  final Color divider;
  final Color border;

  /// Translucent fill drawn over a blur (iOS glass).
  final Color glassTint;

  /// Drop shadow color (already includes alpha).
  final Color shadow;

  /// Modal barrier / dimming color (already includes alpha).
  final Color scrim;

  /// Text and icons placed directly on photos or dark media overlays.
  final Color onMedia;

  /// Darkening gradient stop used behind [onMedia] content.
  final Color mediaScrim;

  final Color error;
  final Color success;
  final Color warning;

  final Color accentLine;
  final Color accentPhoto;
  final Color accentVoice;
  final Color accentObject;
  final Color accentFragment;
  final Color accentRitual;
  final Color accentRelease;

  /// Warm gold used for capsules and gratitude highlights.
  final Color accentGold;

  bool get isDark => brightness == Brightness.dark;

  /// A readable text color derived from an [accent] (type or theme color).
  ///
  /// Accents are tuned for icons and tints; as small text they can fall
  /// below AA. This pulls the accent toward [textPrimary] so badge labels
  /// keep their hue but reach 4.5:1 on cards and tinted badges.
  Color inkFor(Color accent) =>
      Color.lerp(accent, textPrimary, isDark ? 0.25 : 0.5)!;

  /// The accent color for a memory theme, adjusted for brightness.
  Color themeColor(String themeName) {
    final c = isDark ? _themeDark[themeName] : _themeLight[themeName];
    return c ??
        (isDark
            ? SeedlingColors.themeMomentsDark
            : SeedlingColors.themeMoments);
  }

  static const Map<String, Color> _themeLight = {
    'family': SeedlingColors.themeFamily,
    'friends': SeedlingColors.themeFriends,
    'work': SeedlingColors.themeWork,
    'nature': SeedlingColors.themeNature,
    'gratitude': SeedlingColors.themeGratitude,
    'reflection': SeedlingColors.themeReflection,
    'travel': SeedlingColors.themeTravel,
    'creativity': SeedlingColors.themeCreativity,
    'health': SeedlingColors.themeHealth,
    'food': SeedlingColors.themeFood,
    'moments': SeedlingColors.themeMoments,
  };

  static const Map<String, Color> _themeDark = {
    'family': SeedlingColors.themeFamilyDark,
    'friends': SeedlingColors.themeFriendsDark,
    'work': SeedlingColors.themeWorkDark,
    'nature': SeedlingColors.themeNatureDark,
    'gratitude': SeedlingColors.themeGratitudeDark,
    'reflection': SeedlingColors.themeReflectionDark,
    'travel': SeedlingColors.themeTravelDark,
    'creativity': SeedlingColors.themeCreativityDark,
    'health': SeedlingColors.themeHealthDark,
    'food': SeedlingColors.themeFoodDark,
    'moments': SeedlingColors.themeMomentsDark,
  };

  static const SeedlingPalette light = SeedlingPalette(
    brightness: Brightness.light,
    textPrimary: SeedlingColors.textPrimary,
    textSecondary: SeedlingColors.textSecondary,
    textMuted: Color(0xFF8A8A87),
    primary: SeedlingColors.forestGreen,
    primaryFill: SeedlingColors.forestGreen,
    onPrimaryFill: SeedlingColors.warmWhite,
    primaryContainer: SeedlingColors.paleGreen,
    onPrimaryContainer: SeedlingColors.forestGreen,
    secondary: SeedlingColors.warmBrown,
    bark: SeedlingColors.barkBrown,
    background: SeedlingColors.creamPaper,
    backgroundGradientStart: SeedlingColors.backgroundGradientStart,
    backgroundGradientEnd: SeedlingColors.backgroundGradientEnd,
    surface: SeedlingColors.warmWhite,
    card: SeedlingColors.warmWhite,
    surfaceMuted: SeedlingColors.softCream,
    divider: SeedlingColors.softCream,
    border: Color(0xFFE6DFD3),
    glassTint: Color(0xBFFAF8F5),
    shadow: Color(0x0F000000),
    scrim: Color(0x66000000),
    onMedia: Color(0xFFFFFFFF),
    mediaScrim: Color(0x99000000),
    error: SeedlingColors.error,
    success: SeedlingColors.success,
    warning: SeedlingColors.warning,
    accentLine: SeedlingColors.accentLine,
    accentPhoto: SeedlingColors.accentPhoto,
    accentVoice: SeedlingColors.accentVoice,
    accentObject: SeedlingColors.accentObject,
    accentFragment: SeedlingColors.accentFragment,
    accentRitual: SeedlingColors.accentRitual,
    accentRelease: SeedlingColors.accentRelease,
    accentGold: SeedlingColors.themeGratitude,
  );

  static const SeedlingPalette dark = SeedlingPalette(
    brightness: Brightness.dark,
    textPrimary: SeedlingColors.textPrimaryDark,
    textSecondary: SeedlingColors.textSecondaryDark,
    textMuted: Color(0xFF8E8E8B),
    primary: SeedlingColors.leafGreenDark,
    primaryFill: Color(0xFF3F7A52),
    onPrimaryFill: SeedlingColors.textPrimaryDark,
    primaryContainer: SeedlingColors.paleGreenDark,
    onPrimaryContainer: Color(0xFFCFE6D5),
    secondary: SeedlingColors.warmBrownDark,
    bark: Color(0xFFC9B79A),
    background: SeedlingColors.backgroundDark,
    backgroundGradientStart: Color(0xFF1C1F1C),
    backgroundGradientEnd: Color(0xFF151715),
    surface: SeedlingColors.surfaceDark,
    card: SeedlingColors.cardDark,
    surfaceMuted: SeedlingColors.surfaceContainerDark,
    divider: SeedlingColors.dividerDark,
    border: SeedlingColors.borderDark,
    glassTint: Color(0xB3242624),
    shadow: Color(0x4D000000),
    scrim: Color(0x99000000),
    onMedia: Color(0xFFFFFFFF),
    mediaScrim: Color(0xB3000000),
    error: SeedlingColors.errorDark,
    success: SeedlingColors.successDark,
    warning: SeedlingColors.warningDark,
    accentLine: SeedlingColors.accentLineDark,
    accentPhoto: SeedlingColors.accentPhotoDark,
    accentVoice: SeedlingColors.accentVoiceDark,
    accentObject: SeedlingColors.accentObjectDark,
    accentFragment: SeedlingColors.accentFragmentDark,
    accentRitual: SeedlingColors.accentRitualDark,
    accentRelease: SeedlingColors.accentReleaseDark,
    accentGold: SeedlingColors.themeGratitudeDark,
  );

  /// The palette for [brightness], without needing a [BuildContext].
  static SeedlingPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  SeedlingPalette copyWith({Brightness? brightness}) =>
      brightness == null ? this : of(brightness);

  @override
  SeedlingPalette lerp(ThemeExtension<SeedlingPalette>? other, double t) {
    if (other is! SeedlingPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SeedlingPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      primary: l(primary, other.primary),
      primaryFill: l(primaryFill, other.primaryFill),
      onPrimaryFill: l(onPrimaryFill, other.onPrimaryFill),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      secondary: l(secondary, other.secondary),
      bark: l(bark, other.bark),
      background: l(background, other.background),
      backgroundGradientStart: l(
        backgroundGradientStart,
        other.backgroundGradientStart,
      ),
      backgroundGradientEnd: l(
        backgroundGradientEnd,
        other.backgroundGradientEnd,
      ),
      surface: l(surface, other.surface),
      card: l(card, other.card),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      divider: l(divider, other.divider),
      border: l(border, other.border),
      glassTint: l(glassTint, other.glassTint),
      shadow: l(shadow, other.shadow),
      scrim: l(scrim, other.scrim),
      onMedia: l(onMedia, other.onMedia),
      mediaScrim: l(mediaScrim, other.mediaScrim),
      error: l(error, other.error),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      accentLine: l(accentLine, other.accentLine),
      accentPhoto: l(accentPhoto, other.accentPhoto),
      accentVoice: l(accentVoice, other.accentVoice),
      accentObject: l(accentObject, other.accentObject),
      accentFragment: l(accentFragment, other.accentFragment),
      accentRitual: l(accentRitual, other.accentRitual),
      accentRelease: l(accentRelease, other.accentRelease),
      accentGold: l(accentGold, other.accentGold),
    );
  }
}

/// `theme.palette` - the [SeedlingPalette] registered on this [ThemeData].
extension SeedlingPaletteTheme on ThemeData {
  SeedlingPalette get palette =>
      extension<SeedlingPalette>() ?? SeedlingPalette.of(brightness);
}

/// `context.palette` - the [SeedlingPalette] for the current theme.
extension SeedlingPaletteContext on BuildContext {
  SeedlingPalette get palette {
    final theme = Theme.of(this);
    return theme.extension<SeedlingPalette>() ??
        SeedlingPalette.of(theme.brightness);
  }
}
