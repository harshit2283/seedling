import 'package:flutter/material.dart';
import 'colors.dart';

/// Seedling typography - warm, readable, and organic
/// Uses Georgia for headers (classic, warm serif) and system sans for body
class SeedlingTypography {
  SeedlingTypography._();

  // Font families
  static const String serifFamily = 'Georgia';
  static const String sansFamily = '.AppleSystemUIFont'; // System font

  static TextTheme get textTheme => TextTheme(
    // Display - Large titles, rarely used
    displayLarge: const TextStyle(
      fontFamily: serifFamily,
      fontSize: 56,
      fontWeight: FontWeight.w300,
      letterSpacing: -1.0,
      height: 1.05,
      color: SeedlingColors.textPrimary,
    ),
    displayMedium: const TextStyle(
      fontFamily: serifFamily,
      fontSize: 32,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      height: 1.15,
      color: SeedlingColors.textPrimary,
    ),
    displaySmall: const TextStyle(
      fontFamily: serifFamily,
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimary,
    ),

    // Headlines - Section headers
    headlineLarge: const TextStyle(
      fontFamily: serifFamily,
      fontSize: 24,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimary,
    ),
    headlineMedium: const TextStyle(
      fontFamily: serifFamily,
      fontSize: 20,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimary,
    ),
    headlineSmall: const TextStyle(
      fontFamily: serifFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimary,
    ),

    // Titles - Card titles, list headers
    titleLarge: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.4,
      color: SeedlingColors.textPrimary,
    ),
    titleMedium: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      height: 1.5,
      color: SeedlingColors.textPrimary,
    ),
    titleSmall: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.5,
      color: SeedlingColors.textPrimary,
    ),

    // Body - Primary reading text
    bodyLarge: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
      height: 1.6,
      color: SeedlingColors.textPrimary,
    ),
    bodyMedium: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.6,
      color: SeedlingColors.textPrimary,
    ),
    bodySmall: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.5,
      color: SeedlingColors.textSecondary,
    ),

    // Labels - Buttons, tags, metadata
    labelLarge: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
      color: SeedlingColors.textPrimary,
    ),
    labelMedium: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.4,
      color: SeedlingColors.textSecondary,
    ),
    labelSmall: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.4,
      color: SeedlingColors.textMuted,
    ),
  );

  /// Dark mode text theme - same typography, adjusted colors
  static TextTheme get textThemeDark => TextTheme(
    // Display - Large titles
    displayLarge: const TextStyle(
      fontFamily: serifFamily,
      fontSize: 56,
      fontWeight: FontWeight.w300,
      letterSpacing: -1.0,
      height: 1.05,
      color: SeedlingColors.textPrimaryDark,
    ),
    displayMedium: const TextStyle(
      fontFamily: serifFamily,
      fontSize: 32,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      height: 1.15,
      color: SeedlingColors.textPrimaryDark,
    ),
    displaySmall: const TextStyle(
      fontFamily: serifFamily,
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimaryDark,
    ),

    // Headlines - Section headers
    headlineLarge: const TextStyle(
      fontFamily: serifFamily,
      fontSize: 24,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimaryDark,
    ),
    headlineMedium: const TextStyle(
      fontFamily: serifFamily,
      fontSize: 20,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimaryDark,
    ),
    headlineSmall: const TextStyle(
      fontFamily: serifFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.15,
      color: SeedlingColors.textPrimaryDark,
    ),

    // Titles - Card titles, list headers
    titleLarge: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.4,
      color: SeedlingColors.textPrimaryDark,
    ),
    titleMedium: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      height: 1.5,
      color: SeedlingColors.textPrimaryDark,
    ),
    titleSmall: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.5,
      color: SeedlingColors.textPrimaryDark,
    ),

    // Body - Primary reading text
    bodyLarge: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
      height: 1.6,
      color: SeedlingColors.textPrimaryDark,
    ),
    bodyMedium: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.6,
      color: SeedlingColors.textPrimaryDark,
    ),
    bodySmall: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.5,
      color: SeedlingColors.textSecondaryDark,
    ),

    // Labels - Buttons, tags, metadata
    labelLarge: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
      color: SeedlingColors.textPrimaryDark,
    ),
    labelMedium: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.4,
      color: SeedlingColors.textSecondaryDark,
    ),
    labelSmall: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.4,
      color: SeedlingColors.textMutedDark,
    ),
  );

  /// Serif accent title — italic Georgia, used for entry titles or accents.
  /// Not applied globally; opt-in per widget.
  static const TextStyle serifTitle = TextStyle(
    fontFamily: serifFamily,
    fontStyle: FontStyle.italic,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.2,
  );
}
