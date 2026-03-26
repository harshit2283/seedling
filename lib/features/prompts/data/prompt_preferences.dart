import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/prefs_keys.dart';

/// Manages prompt preferences and state using SharedPreferences
class PromptPreferences {

  /// Default cooldown between prompts (8 hours)
  static const promptCooldownHours = 8;

  final SharedPreferences _prefs;

  PromptPreferences(this._prefs);

  /// Whether prompts are enabled
  bool get isEnabled => _prefs.getBool(PrefsKeys.promptsEnabled) ?? true;

  /// Set whether prompts are enabled
  Future<void> setEnabled(bool enabled) async {
    await _prefs.setBool(PrefsKeys.promptsEnabled, enabled);
  }

  /// When the last prompt was shown
  DateTime? get lastPromptShown {
    final millis = _prefs.getInt(PrefsKeys.lastPromptShown);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// The text of the last prompt shown
  String? get lastPromptText => _prefs.getString(PrefsKeys.lastPromptText);

  /// Record that a prompt was shown
  Future<void> recordPromptShown(String promptText) async {
    await _prefs.setInt(
      PrefsKeys.lastPromptShown,
      DateTime.now().millisecondsSinceEpoch,
    );
    await _prefs.setString(PrefsKeys.lastPromptText, promptText);
  }

  /// Check if enough time has passed since last prompt
  bool canShowPrompt() {
    if (!isEnabled) return false;

    final lastShown = lastPromptShown;
    if (lastShown == null) return true;

    final hoursSinceLastPrompt = DateTime.now().difference(lastShown).inHours;
    return hoursSinceLastPrompt >= promptCooldownHours;
  }

  /// Dismiss the current prompt (resets cooldown)
  Future<void> dismissPrompt() async {
    await _prefs.setInt(
      PrefsKeys.lastPromptShown,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
