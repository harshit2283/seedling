import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPreferences {
  static const String _completedKey = 'onboarding_completed';
  final SharedPreferences _prefs;

  OnboardingPreferences(this._prefs);

  bool get isCompleted => _prefs.getBool(_completedKey) ?? false;

  Future<void> setCompleted() async {
    await _prefs.setBool(_completedKey, true);
  }

  Future<void> reset() async {
    await _prefs.remove(_completedKey);
  }
}
