import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'typography.dart';

/// Complete Seedling theme - organic, paper-like feel
/// Emphasizes warmth, comfort, and natural aesthetics
class SeedlingTheme {
  SeedlingTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Colors
    colorScheme: ColorScheme.light(
      primary: SeedlingColors.forestGreen,
      onPrimary: SeedlingColors.warmWhite,
      primaryContainer: SeedlingColors.paleGreen,
      onPrimaryContainer: SeedlingColors.forestGreen,
      secondary: SeedlingColors.warmBrown,
      onSecondary: SeedlingColors.warmWhite,
      secondaryContainer: SeedlingColors.lightBark,
      onSecondaryContainer: SeedlingColors.barkBrown,
      surface: SeedlingColors.creamPaper,
      onSurface: SeedlingColors.textPrimary,
      surfaceContainerHighest: SeedlingColors.softCream,
      error: SeedlingColors.error,
      onError: SeedlingColors.warmWhite,
    ),

    // Scaffold
    scaffoldBackgroundColor: SeedlingColors.creamPaper,

    // Typography
    textTheme: SeedlingTypography.textTheme,

    // AppBar - subtle, blends with background
    appBarTheme: AppBarTheme(
      backgroundColor: SeedlingColors.creamPaper,
      foregroundColor: SeedlingColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: SeedlingTypography.textTheme.headlineMedium,
    ),

    // Cards - paper-like, subtle shadows
    cardTheme: CardThemeData(
      color: SeedlingColors.warmWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: SeedlingColors.softCream, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SeedlingColors.forestGreen,
        foregroundColor: SeedlingColors.warmWhite,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: SeedlingTypography.textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SeedlingColors.forestGreen,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: SeedlingTypography.textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SeedlingColors.forestGreen,
        side: const BorderSide(color: SeedlingColors.forestGreen),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: SeedlingTypography.textTheme.labelLarge,
      ),
    ),

    // Floating Action Button - main capture button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: SeedlingColors.forestGreen,
      foregroundColor: SeedlingColors.warmWhite,
      elevation: 2,
      shape: CircleBorder(),
    ),

    // Input fields - subtle, organic borders
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SeedlingColors.warmWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: SeedlingColors.softCream),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: SeedlingColors.softCream),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SeedlingColors.leafGreen, width: 2),
      ),
      hintStyle: SeedlingTypography.textTheme.bodyLarge?.copyWith(
        color: SeedlingColors.textMuted,
      ),
    ),

    // Bottom sheet - capture sheet styling
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: SeedlingColors.warmWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      dragHandleColor: SeedlingColors.lightBark,
    ),

    // Dividers
    dividerTheme: const DividerThemeData(
      color: SeedlingColors.softCream,
      thickness: 1,
      space: 1,
    ),

    // Icons
    iconTheme: const IconThemeData(
      color: SeedlingColors.textSecondary,
      size: 24,
    ),

    // List tiles
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SeedlingColors.barkBrown,
      contentTextStyle: SeedlingTypography.textTheme.bodyMedium?.copyWith(
        color: SeedlingColors.warmWhite,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: SeedlingColors.warmWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: SeedlingTypography.textTheme.headlineSmall,
      contentTextStyle: SeedlingTypography.textTheme.bodyMedium,
    ),
  );

  /// Dark theme - warm twilight forest feel
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Colors
    colorScheme: ColorScheme.dark(
      primary: SeedlingColors.forestGreenDark,
      onPrimary: SeedlingColors.textPrimaryDark,
      primaryContainer: SeedlingColors.paleGreenDark,
      onPrimaryContainer: SeedlingColors.leafGreenDark,
      secondary: SeedlingColors.warmBrownDark,
      onSecondary: SeedlingColors.textPrimaryDark,
      secondaryContainer: SeedlingColors.lightBarkDark,
      onSecondaryContainer: SeedlingColors.warmBrownDark,
      surface: SeedlingColors.backgroundDark,
      onSurface: SeedlingColors.textPrimaryDark,
      surfaceContainerHighest: SeedlingColors.surfaceContainerDark,
      error: SeedlingColors.errorDark,
      onError: SeedlingColors.textPrimaryDark,
    ),

    // Scaffold
    scaffoldBackgroundColor: SeedlingColors.backgroundDark,

    // Typography with dark colors
    textTheme: SeedlingTypography.textThemeDark,

    // AppBar - blends with dark background
    appBarTheme: AppBarTheme(
      backgroundColor: SeedlingColors.backgroundDark,
      foregroundColor: SeedlingColors.textPrimaryDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: SeedlingTypography.textThemeDark.headlineMedium,
    ),

    // Cards - elevated dark surfaces
    cardTheme: CardThemeData(
      color: SeedlingColors.cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: SeedlingColors.dividerDark, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SeedlingColors.forestGreenDark,
        foregroundColor: SeedlingColors.textPrimaryDark,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: SeedlingTypography.textThemeDark.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SeedlingColors.forestGreenDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: SeedlingTypography.textThemeDark.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SeedlingColors.forestGreenDark,
        side: const BorderSide(color: SeedlingColors.forestGreenDark),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: SeedlingTypography.textThemeDark.labelLarge,
      ),
    ),

    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: SeedlingColors.forestGreenDark,
      foregroundColor: SeedlingColors.textPrimaryDark,
      elevation: 2,
      shape: CircleBorder(),
    ),

    // Input fields - dark surfaces with visible borders
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SeedlingColors.surfaceDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: SeedlingColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: SeedlingColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: SeedlingColors.leafGreenDark,
          width: 2,
        ),
      ),
      hintStyle: SeedlingTypography.textThemeDark.bodyLarge?.copyWith(
        color: SeedlingColors.textMutedDark,
      ),
    ),

    // Bottom sheet - dark elevated surface
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: SeedlingColors.surfaceDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      dragHandleColor: SeedlingColors.textMutedDark,
    ),

    // Dividers
    dividerTheme: const DividerThemeData(
      color: SeedlingColors.dividerDark,
      thickness: 1,
      space: 1,
    ),

    // Icons
    iconTheme: const IconThemeData(
      color: SeedlingColors.textSecondaryDark,
      size: 24,
    ),

    // List tiles
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SeedlingColors.cardDark,
      contentTextStyle: SeedlingTypography.textThemeDark.bodyMedium?.copyWith(
        color: SeedlingColors.textPrimaryDark,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: SeedlingColors.surfaceDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: SeedlingTypography.textThemeDark.headlineSmall,
      contentTextStyle: SeedlingTypography.textThemeDark.bodyMedium,
    ),
  );
}
