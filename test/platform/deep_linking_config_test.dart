import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Flutter's built-in deep linking forwards any `seedling://host/<path>` URI
/// straight into go_router, letting other apps open arbitrary screens.
/// Seedling handles its few widget URIs via an allowlist in app.dart instead,
/// so the platform flag must stay off on both platforms.
void main() {
  test('Android manifest disables Flutter deep linking', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      RegExp(
        r'android:name="flutter_deeplinking_enabled"\s+android:value="false"',
      ).hasMatch(manifest),
      isTrue,
    );
  });

  test('iOS Info.plist disables Flutter deep linking', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      RegExp(
        r'<key>FlutterDeepLinkingEnabled</key>\s*<false/>',
      ).hasMatch(plist),
      isTrue,
    );
  });
}
