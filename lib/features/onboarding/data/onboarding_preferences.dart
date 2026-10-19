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

  /// The person's own cue for capturing, e.g. "When I make my morning
  /// coffee". Optional; null when skipped or cleared.
  String? get captureIntention {
    final value = _prefs.getString(PrefsKeys.captureIntention)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Stores [intention], or clears it when null or blank.
  Future<void> setCaptureIntention(String? intention) async {
    final value = intention?.trim() ?? '';
    if (value.isEmpty) {
      await _prefs.remove(PrefsKeys.captureIntention);
    } else {
      await _prefs.setString(PrefsKeys.captureIntention, value);
    }
  }

  Future<void> reset() async {
    await _prefs.remove(PrefsKeys.onboardingCompleted);
  }
}
