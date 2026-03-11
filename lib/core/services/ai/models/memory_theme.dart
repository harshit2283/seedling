/// Memory theme categories for auto-classification
///
/// Themes represent the emotional or contextual categories that
/// memories naturally fall into. The detection algorithm scores
/// each theme based on keyword matches in the entry content.
enum MemoryTheme {
  family, // Relatives, home, childhood
  friends, // Social, gatherings, shared experiences
  work, // Career, professional, accomplishments
  nature, // Outdoors, weather, seasons, animals
  gratitude, // Thankfulness, appreciation
  reflection, // Self, thoughts, personal growth
  travel, // Places, journeys, exploration
  creativity, // Art, music, making things
  health, // Body, exercise, wellbeing
  food, // Meals, cooking, tastes
  moments, // Small daily moments (default)
}

/// Extension methods for MemoryTheme
extension MemoryThemeExtension on MemoryTheme {
  /// Human-readable display name
  String get displayName {
    switch (this) {
      case MemoryTheme.family:
        return 'Family';
      case MemoryTheme.friends:
        return 'Friends';
      case MemoryTheme.work:
        return 'Work';
      case MemoryTheme.nature:
        return 'Nature';
      case MemoryTheme.gratitude:
        return 'Gratitude';
      case MemoryTheme.reflection:
        return 'Reflection';
      case MemoryTheme.travel:
        return 'Travel';
      case MemoryTheme.creativity:
        return 'Creativity';
      case MemoryTheme.health:
        return 'Health';
      case MemoryTheme.food:
        return 'Food';
      case MemoryTheme.moments:
        return 'Moments';
    }
  }

  /// Emoji icon for the theme
  String get emoji {
    switch (this) {
      case MemoryTheme.family:
        return '👨‍👩‍👧';
      case MemoryTheme.friends:
        return '👥';
      case MemoryTheme.work:
        return '💼';
      case MemoryTheme.nature:
        return '🌿';
      case MemoryTheme.gratitude:
        return '🙏';
      case MemoryTheme.reflection:
        return '💭';
      case MemoryTheme.travel:
        return '✈️';
      case MemoryTheme.creativity:
        return '🎨';
      case MemoryTheme.health:
        return '💪';
      case MemoryTheme.food:
        return '🍽️';
      case MemoryTheme.moments:
        return '✨';
    }
  }

  /// Convert to string for storage
  String get storageName => name;

  /// Parse from storage string
  static MemoryTheme? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return MemoryTheme.values.firstWhere(
        (theme) => theme.name == value,
        orElse: () => MemoryTheme.moments,
      );
    } catch (_) {
      return null;
    }
  }
}
