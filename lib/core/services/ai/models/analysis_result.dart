import 'memory_theme.dart';
import 'memory_connection.dart';

/// Result of analyzing a single entry
class EntryAnalysisResult {
  /// The detected primary theme
  final MemoryTheme theme;

  /// Confidence in theme detection (0.0 to 1.0)
  final double themeConfidence;

  /// Sentiment score (-1.0 to 1.0)
  final double sentimentScore;

  /// Found connections to other entries
  final List<MemoryConnection> connections;

  /// Extracted keywords from the entry
  final List<String> keywords;

  const EntryAnalysisResult({
    required this.theme,
    required this.themeConfidence,
    required this.sentimentScore,
    required this.connections,
    required this.keywords,
  });

  /// Whether the theme detection is confident
  bool get isThemeConfident => themeConfidence >= 0.5;

  /// Human-readable sentiment label
  String get sentimentLabel {
    if (sentimentScore >= 0.3) return 'Positive';
    if (sentimentScore <= -0.3) return 'Reflective';
    return 'Neutral';
  }
}

/// Summary statistics about the user's memory collection
class MemoryCollectionStats {
  /// Total number of entries analyzed
  final int totalEntries;

  /// Distribution of themes (theme -> count)
  final Map<MemoryTheme, int> themeDistribution;

  /// Average sentiment score
  final double averageSentiment;

  /// Most common theme
  final MemoryTheme? dominantTheme;

  /// Themes with few or no entries
  final List<MemoryTheme> underrepresentedThemes;

  /// Average entries per week
  final double entriesPerWeek;

  const MemoryCollectionStats({
    required this.totalEntries,
    required this.themeDistribution,
    required this.averageSentiment,
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
