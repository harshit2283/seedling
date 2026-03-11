import 'package:flutter/cupertino.dart';
import 'colors.dart';

/// Cupertino theme for iOS - matches Seedling palette with iOS styling
class SeedlingCupertinoTheme {
  SeedlingCupertinoTheme._();

  static CupertinoThemeData get light => CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: SeedlingColors.forestGreen,
    primaryContrastingColor: SeedlingColors.warmWhite,
    scaffoldBackgroundColor: SeedlingColors.creamPaper,
    barBackgroundColor: SeedlingColors.creamPaper.withValues(alpha: 0.9),
    textTheme: CupertinoTextThemeData(
      primaryColor: SeedlingColors.forestGreen,
      textStyle: const TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: SeedlingColors.textPrimary,
      ),
      actionTextStyle: const TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: SeedlingColors.forestGreen,
      ),
      navTitleTextStyle: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: SeedlingColors.textPrimary,
      ),
      navLargeTitleTextStyle: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: SeedlingColors.textPrimary,
      ),
      navActionTextStyle: const TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: SeedlingColors.forestGreen,
      ),
      pickerTextStyle: const TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 21,
        fontWeight: FontWeight.w400,
        color: SeedlingColors.textPrimary,
      ),
      dateTimePickerTextStyle: const TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 21,
        fontWeight: FontWeight.w400,
        color: SeedlingColors.textPrimary,
      ),
      tabLabelTextStyle: const TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: SeedlingColors.textSecondary,
      ),
    ),
  );

  /// Dark Cupertino theme - warm twilight feel matching iOS dark mode
  static CupertinoThemeData get dark => CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: SeedlingColors.forestGreenDark,
    primaryContrastingColor: SeedlingColors.textPrimaryDark,
    scaffoldBackgroundColor: SeedlingColors.backgroundDark,
    barBackgroundColor: SeedlingColors.surfaceDark.withValues(alpha: 0.9),
    textTheme: CupertinoTextThemeData(
      primaryColor: SeedlingColors.forestGreenDark,
      textStyle: const TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: SeedlingColors.textPrimaryDark,
      ),
      actionTextStyle: const TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: SeedlingColors.forestGreenDark,
      ),
      navTitleTextStyle: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: SeedlingColors.textPrimaryDark,
      ),
      navLargeTitleTextStyle: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: SeedlingColors.textPrimaryDark,
      ),
      navActionTextStyle: const TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: SeedlingColors.forestGreenDark,
      ),
      pickerTextStyle: const TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 21,
        fontWeight: FontWeight.w400,
        color: SeedlingColors.textPrimaryDark,
      ),
      dateTimePickerTextStyle: const TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 21,
        fontWeight: FontWeight.w400,
        color: SeedlingColors.textPrimaryDark,
      ),
      tabLabelTextStyle: const TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: SeedlingColors.textSecondaryDark,
      ),
    ),
  );
}
