import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform detection utilities for adaptive UI
class PlatformUtils {
  PlatformUtils._();

  /// Returns true if running on iOS (not web)
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Returns true if running on Android (not web)
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Returns true if running on a mobile platform
  static bool get isMobile => isIOS || isAndroid;
}
