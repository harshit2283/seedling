/// Category of prompts based on context
enum PromptCategory { morning, afternoon, evening, seasonal, general }

/// A gentle prompt for memory capture
class GentlePrompt {
  final String text;
  final PromptCategory category;

  const GentlePrompt({required this.text, required this.category});
}

/// Repository of curated, non-gamified prompts
/// Philosophy: Gentle invitations, not pressure
class PromptRepository {
  static const List<GentlePrompt> _morningPrompts = [
    GentlePrompt(
      text: 'How did you wake up this morning?',
      category: PromptCategory.morning,
    ),
    GentlePrompt(
      text: 'What sounds did you hear first thing?',
      category: PromptCategory.morning,
    ),
    GentlePrompt(
      text: 'Is there something you\'re looking forward to today?',
      category: PromptCategory.morning,
    ),
    GentlePrompt(
      text: 'What does your morning routine feel like today?',
      category: PromptCategory.morning,
    ),
    GentlePrompt(
      text: 'Any dreams lingering from last night?',
      category: PromptCategory.morning,
    ),
  ];

  static const List<GentlePrompt> _afternoonPrompts = [
    GentlePrompt(
      text: 'What\'s on your mind right now?',
      category: PromptCategory.afternoon,
    ),
    GentlePrompt(
      text: 'Did anything surprise you today?',
      category: PromptCategory.afternoon,
    ),
    GentlePrompt(
      text: 'Who have you talked to today?',
      category: PromptCategory.afternoon,
    ),
    GentlePrompt(
      text: 'What did you have for lunch?',
      category: PromptCategory.afternoon,
    ),
    GentlePrompt(
      text: 'Is there a small moment you want to remember?',
      category: PromptCategory.afternoon,
    ),
  ];

  static const List<GentlePrompt> _eveningPrompts = [
    GentlePrompt(
      text: 'What stayed with you today?',
      category: PromptCategory.evening,
    ),
    GentlePrompt(
      text: 'Is there something you want to let go of?',
      category: PromptCategory.evening,
    ),
    GentlePrompt(
      text: 'What made you smile today?',
      category: PromptCategory.evening,
    ),
    GentlePrompt(
      text: 'How are you feeling right now?',
      category: PromptCategory.evening,
    ),
    GentlePrompt(
      text: 'What\'s one thing you\'re grateful for today?',
      category: PromptCategory.evening,
    ),
    GentlePrompt(
      text: 'Did anything challenge you today?',
      category: PromptCategory.evening,
    ),
  ];

  static const List<GentlePrompt> _generalPrompts = [
    GentlePrompt(
      text: 'What are you thinking about?',
      category: PromptCategory.general,
    ),
    GentlePrompt(
      text: 'Is there something you want to remember?',
      category: PromptCategory.general,
    ),
    GentlePrompt(
      text: 'What\'s one thing you noticed today?',
      category: PromptCategory.general,
    ),
    GentlePrompt(
      text: 'How does this moment feel?',
      category: PromptCategory.general,
    ),
    GentlePrompt(
      text: 'What would future you want to know about today?',
      category: PromptCategory.general,
    ),
  ];

  // Seasonal prompts - selected based on month
  static const List<GentlePrompt> _springPrompts = [
    GentlePrompt(
      text: 'What\'s blooming around you?',
      category: PromptCategory.seasonal,
    ),
    GentlePrompt(
      text: 'Is there something new beginning in your life?',
      category: PromptCategory.seasonal,
    ),
    GentlePrompt(
      text: 'How does the changing weather make you feel?',
      category: PromptCategory.seasonal,
    ),
  ];

  static const List<GentlePrompt> _summerPrompts = [
    GentlePrompt(
      text: 'What does the sunlight feel like today?',
      category: PromptCategory.seasonal,
    ),
    GentlePrompt(
      text: 'Is there a summer memory coming back to you?',
      category: PromptCategory.seasonal,
    ),
    GentlePrompt(
      text: 'What sounds of summer are around you?',
      category: PromptCategory.seasonal,
    ),
  ];

  static const List<GentlePrompt> _autumnPrompts = [
    GentlePrompt(
      text: 'What\'s changing around you this autumn?',
      category: PromptCategory.seasonal,
    ),
    GentlePrompt(
      text: 'Is there something you\'re ready to let go of?',
      category: PromptCategory.seasonal,
    ),
    GentlePrompt(
      text: 'What colors are you noticing today?',
      category: PromptCategory.seasonal,
    ),
  ];

  static const List<GentlePrompt> _winterPrompts = [
    GentlePrompt(
      text: 'How are you staying warm today?',
      category: PromptCategory.seasonal,
    ),
    GentlePrompt(
      text: 'What brings you comfort right now?',
      category: PromptCategory.seasonal,
    ),
    GentlePrompt(
      text: 'Is there something you\'re looking forward to?',
      category: PromptCategory.seasonal,
    ),
  ];

  /// Get prompts for a specific time of day
  List<GentlePrompt> getPromptsForTime(int hour) {
    if (hour >= 5 && hour < 12) {
      return _morningPrompts;
    } else if (hour >= 12 && hour < 17) {
      return _afternoonPrompts;
    } else {
      return _eveningPrompts;
    }
  }

  /// Get seasonal prompts based on month
  List<GentlePrompt> getSeasonalPrompts(int month) {
    // Northern hemisphere seasons
    if (month >= 3 && month <= 5) {
      return _springPrompts;
    } else if (month >= 6 && month <= 8) {
      return _summerPrompts;
    } else if (month >= 9 && month <= 11) {
      return _autumnPrompts;
    } else {
      return _winterPrompts;
    }
  }

  /// Get all general prompts
  List<GentlePrompt> getGeneralPrompts() => _generalPrompts;

  /// Get all available prompts for current context
  List<GentlePrompt> getAllCurrentPrompts() {
    final now = DateTime.now();
    final timePrompts = getPromptsForTime(now.hour);
    final seasonalPrompts = getSeasonalPrompts(now.month);
    final generalPrompts = getGeneralPrompts();

    return [...timePrompts, ...seasonalPrompts, ...generalPrompts];
  }
}
