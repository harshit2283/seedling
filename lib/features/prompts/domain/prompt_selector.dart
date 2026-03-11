import 'dart:math';
import '../data/prompt_repository.dart';
import '../data/prompt_preferences.dart';

/// Selects appropriate prompts based on context and preferences
class PromptSelector {
  final PromptRepository _repository;
  final PromptPreferences _preferences;
  final Random _random;

  PromptSelector({
    required PromptRepository repository,
    required PromptPreferences preferences,
    Random? random,
  }) : _repository = repository,
       _preferences = preferences,
       _random = random ?? Random();

  /// Get a prompt to show, or null if no prompt should be shown
  GentlePrompt? getPromptToShow() {
    // Check if prompts are enabled and cooldown has passed
    if (!_preferences.canShowPrompt()) {
      return null;
    }

    // Get all available prompts for current context
    final prompts = _repository.getAllCurrentPrompts();
    if (prompts.isEmpty) return null;

    // Avoid showing the same prompt twice in a row
    final lastPromptText = _preferences.lastPromptText;
    final availablePrompts = prompts
        .where((p) => p.text != lastPromptText)
        .toList();

    if (availablePrompts.isEmpty) {
      // If all prompts are the same as last (unlikely), just pick any
      return prompts[_random.nextInt(prompts.length)];
    }

    // Randomly select a prompt
    return availablePrompts[_random.nextInt(availablePrompts.length)];
  }

  /// Record that a prompt was shown
  Future<void> markPromptShown(GentlePrompt prompt) async {
    await _preferences.recordPromptShown(prompt.text);
  }

  /// Dismiss the current prompt
  Future<void> dismissPrompt() async {
    await _preferences.dismissPrompt();
  }

  /// Check if prompts are enabled
  bool get isEnabled => _preferences.isEnabled;

  /// Enable or disable prompts
  Future<void> setEnabled(bool enabled) async {
    await _preferences.setEnabled(enabled);
  }
}
