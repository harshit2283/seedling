import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/constants/prefs_keys.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> prefsValues) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

/// Home-screen widgets must never show memory text unless the user opted in,
/// and App Lock always wins over that opt-in.
void main() {
  test('widget memory previews are off by default', () async {
    final container = await _container({});
    addTearDown(container.dispose);
    expect(container.read(effectiveWidgetMemoryPreviewsProvider), isFalse);
  });

  test('opted-in previews are shown when App Lock is off', () async {
    final container = await _container({
      PrefsKeys.widgetMemoryPreviewsEnabled: true,
    });
    addTearDown(container.dispose);
    expect(container.read(effectiveWidgetMemoryPreviewsProvider), isTrue);
  });

  test('App Lock suppresses previews even when opted in', () async {
    final container = await _container({
      PrefsKeys.widgetMemoryPreviewsEnabled: true,
      PrefsKeys.appLockEnabled: true,
    });
    addTearDown(container.dispose);
    expect(container.read(effectiveWidgetMemoryPreviewsProvider), isFalse);
  });
}
