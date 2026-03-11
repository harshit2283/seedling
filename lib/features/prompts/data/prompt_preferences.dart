import 'package:shared_preferences/shared_preferences.dart';

/// Manages prompt preferences and state using SharedPreferences
class PromptPreferences {
  static const _keyPromptsEnabled = 'prompts_enabled';
  static const _keyLastPromptShown = 'last_prompt_shown';
  static const _keyLastPromptText = 'last_prompt_text';

  /// Default cooldown between prompts (8 hours)
  static const promptCooldownHours = 8;

  final SharedPreferences _prefs;

  PromptPreferences(this._prefs);

  /// Whether prompts are enabled
  bool get isEnabled => _prefs.getBool(_keyPromptsEnabled) ?? true;

  /// Set whether prompts are enabled
  Future<void> setEnabled(bool enabled) async {
    await _prefs.setBool(_keyPromptsEnabled, enabled);
  }

  /// When the last prompt was shown
  DateTime? get lastPromptShown {
    final millis = _prefs.getInt(_keyLastPromptShown);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// The text of the last prompt shown
  String? get lastPromptText => _prefs.getString(_keyLastPromptText);

  /// Record that a prompt was shown
  Future<void> recordPromptShown(String promptText) async {
    await _prefs.setInt(
      _keyLastPromptShown,
      DateTime.now().millisecondsSinceEpoch,
    );
    await _prefs.setString(_keyLastPromptText, promptText);
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
      _keyLastPromptShown,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
