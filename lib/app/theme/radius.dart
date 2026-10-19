import 'package:flutter/widgets.dart';

import '../../core/platform/platform_utils.dart';

/// Corner radii that follow each platform's language: 20pt on iOS (matches
/// system sheets and cards), 12dp on Android (Material 3 medium shape).
class SeedlingRadius {
  SeedlingRadius._();

  /// Raw value for cards, sheets and primary buttons.
  static double get value => PlatformUtils.isIOS ? 20 : 12;

  /// Smaller radius for chips, badges and thumbnails.
  static double get smallValue => PlatformUtils.isIOS ? 12 : 8;

  static BorderRadius get card => BorderRadius.circular(value);
  static BorderRadius get button => BorderRadius.circular(value);
  static BorderRadius get small => BorderRadius.circular(smallValue);
  static BorderRadius get sheet =>
      BorderRadius.vertical(top: Radius.circular(value));
}
