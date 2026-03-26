import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/prefs_keys.dart';

class OnboardingPreferences {
  final SharedPreferences _prefs;

  OnboardingPreferences(this._prefs);

  bool get isCompleted =>
      _prefs.getBool(PrefsKeys.onboardingCompleted) ?? false;

  Future<void> setCompleted() async {
    await _prefs.setBool(PrefsKeys.onboardingCompleted, true);
  }

  Future<void> reset() async {
    await _prefs.remove(PrefsKeys.onboardingCompleted);
  }
}
