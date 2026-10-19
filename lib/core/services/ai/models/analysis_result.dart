import 'memory_theme.dart';

/// Summary statistics about the user's memory collection
class MemoryCollectionStats {
  /// Total number of entries analyzed
  final int totalEntries;

  /// Distribution of themes (theme -> count)
  final Map<MemoryTheme, int> themeDistribution;

  /// Most common theme
  final MemoryTheme? dominantTheme;

  /// Themes with few or no entries
  final List<MemoryTheme> underrepresentedThemes;

  /// Average entries per week
  final double entriesPerWeek;

  const MemoryCollectionStats({
    required this.totalEntries,
    required this.themeDistribution,
    this.dominantTheme,
    required this.underrepresentedThemes,
    required this.entriesPerWeek,
  });

  /// Get percentage for a theme
  double themePercentage(MemoryTheme theme) {
    if (totalEntries == 0) return 0.0;
    return (themeDistribution[theme] ?? 0) / totalEntries;
  }

  /// Check if a theme is underrepresented
  bool isUnderrepresented(MemoryTheme theme) {
    return underrepresentedThemes.contains(theme);
  }
}
