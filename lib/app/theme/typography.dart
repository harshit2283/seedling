import 'package:flutter/material.dart';
import '../../core/platform/platform_utils.dart';
import 'colors.dart';

/// Seedling typography - warm, readable, and organic.
///
/// Platform-correct families: on iOS everything uses the system font
/// (SF Pro), matching Apple's design language; on Android headlines use
/// Georgia (a warm, classic serif) and body copy uses the system sans
/// (Roboto). A `null` family means "the platform default".
class SeedlingTypography {
  SeedlingTypography._();

  /// Headline family: Georgia on Android, the system font (SF) on iOS.
  static String? get serifFamily => PlatformUtils.isIOS ? null : 'Georgia';

  /// Body family: always the platform's system font.
  static String? get sansFamily => null;

  static TextTheme get textTheme => TextTheme(
    // Display - Large titles, rarely used
    displayLarge: TextStyle(
      fontFamily: serifFamily,
      fontSize: 56,
      fontWeight: FontWeight.w300,
      letterSpacing: -1.0,
      height: 1.05,
      color: SeedlingColors.textPrimary,
    ),
    displayMedium: TextStyle(
      fontFamily: serifFamily,
      fontSize: 32,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      height: 1.15,
      color: SeedlingColors.textPrimary,
    ),
    displaySmall: TextStyle(
      fontFamily: serifFamily,
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimary,
    ),

    // Headlines - Section headers
    headlineLarge: TextStyle(
      fontFamily: serifFamily,
      fontSize: 24,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: serifFamily,
      fontSize: 20,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: serifFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimary,
    ),

    // Titles - Card titles, list headers
    titleLarge: TextStyle(
      fontFamily: sansFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.4,
      color: SeedlingColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: sansFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      height: 1.5,
      color: SeedlingColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.5,
      color: SeedlingColors.textPrimary,
    ),

    // Body - Primary reading text
    bodyLarge: TextStyle(
      fontFamily: sansFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
      height: 1.6,
      color: SeedlingColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.6,
      color: SeedlingColors.textPrimary,
    ),
    bodySmall: TextStyle(
      fontFamily: sansFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.5,
      color: SeedlingColors.textSecondary,
    ),

    // Labels - Buttons, tags, metadata
    labelLarge: TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
      color: SeedlingColors.textPrimary,
    ),
    labelMedium: TextStyle(
      fontFamily: sansFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.4,
      color: SeedlingColors.textSecondary,
    ),
    labelSmall: TextStyle(
      fontFamily: sansFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1.4,
      color: SeedlingColors.textSecondary,
    ),
  );

  /// Dark mode text theme - same typography, adjusted colors
  static TextTheme get textThemeDark => TextTheme(
    // Display - Large titles
    displayLarge: TextStyle(
      fontFamily: serifFamily,
      fontSize: 56,
      fontWeight: FontWeight.w300,
      letterSpacing: -1.0,
      height: 1.05,
      color: SeedlingColors.textPrimaryDark,
    ),
    displayMedium: TextStyle(
      fontFamily: serifFamily,
      fontSize: 32,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      height: 1.15,
      color: SeedlingColors.textPrimaryDark,
    ),
    displaySmall: TextStyle(
      fontFamily: serifFamily,
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimaryDark,
    ),

    // Headlines - Section headers
    headlineLarge: TextStyle(
      fontFamily: serifFamily,
      fontSize: 24,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimaryDark,
    ),
    headlineMedium: TextStyle(
      fontFamily: serifFamily,
      fontSize: 20,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimaryDark,
    ),
    headlineSmall: TextStyle(
      fontFamily: serifFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimaryDark,
    ),

    // Titles - Card titles, list headers
    titleLarge: TextStyle(
      fontFamily: sansFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.4,
      color: SeedlingColors.textPrimaryDark,
    ),
    titleMedium: TextStyle(
      fontFamily: sansFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      height: 1.5,
      color: SeedlingColors.textPrimaryDark,
    ),
    titleSmall: TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.5,
      color: SeedlingColors.textPrimaryDark,
    ),

    // Body - Primary reading text
    bodyLarge: TextStyle(
      fontFamily: sansFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
      height: 1.6,
      color: SeedlingColors.textPrimaryDark,
    ),
    bodyMedium: TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.6,
      color: SeedlingColors.textPrimaryDark,
    ),
    bodySmall: TextStyle(
      fontFamily: sansFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.5,
      color: SeedlingColors.textSecondaryDark,
    ),

    // Labels - Buttons, tags, metadata
    labelLarge: TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
      color: SeedlingColors.textPrimaryDark,
    ),
    labelMedium: TextStyle(
      fontFamily: sansFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.4,
      color: SeedlingColors.textSecondaryDark,
    ),
    labelSmall: TextStyle(
      fontFamily: sansFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1.4,
      color: SeedlingColors.textSecondaryDark,
    ),
  );

  /// Serif accent title — italic Georgia, used for entry titles or accents.
  /// Not applied globally; opt-in per widget.
  static TextStyle get serifTitle => TextStyle(
    fontFamily: serifFamily,
    fontStyle: FontStyle.italic,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.2,
  );
}
