import '../../../../data/models/entry.dart';

/// Represents a connection between two memory entries
///
/// Connections are discovered through text similarity, temporal proximity,
/// and shared themes. The similarity score determines how strongly
/// related two memories are.
class MemoryConnection {
  /// The related entry
  final Entry relatedEntry;

  /// Similarity score (0.0 to 1.0)
  /// - 0.3+ is considered a meaningful connection
  /// - 0.5+ is a strong connection
  /// - 0.7+ is a very strong connection
  final double similarityScore;

  /// Breakdown of similarity components
  final ConnectionFactors factors;

  const MemoryConnection({
    required this.relatedEntry,
    required this.similarityScore,
    required this.factors,
  });

  /// Whether this is a meaningful connection (above threshold)
  bool get isMeaningful => similarityScore >= 0.3;

  /// Whether this is a strong connection
  bool get isStrong => similarityScore >= 0.5;

  /// Human-readable connection strength
  String get strengthLabel {
    if (similarityScore >= 0.7) return 'Very related';
    if (similarityScore >= 0.5) return 'Related';
    if (similarityScore >= 0.3) return 'Similar';
    return 'Weak';
  }
}

/// Breakdown of factors contributing to connection strength
class ConnectionFactors {
  /// Text content similarity (TF-IDF cosine over the collection)
  final double textSimilarity;

  /// Temporal proximity bonus (same week = higher)
  final double temporalBonus;

  /// Shared theme bonus
  final double themeBonus;

  /// Shared people and places (names, relationship words)
  final double entityBonus;

  const ConnectionFactors({
    required this.textSimilarity,
    required this.temporalBonus,
    required this.themeBonus,
    this.entityBonus = 0.0,
  });

  // Calibrated on test/fixtures/connection_eval.json (train split) so the
  // 0.3 "meaningful" cut-off sits where precision and coverage balance.
  // TF-IDF cosine between short texts is small (one shared rare word is
  // ~0.15), hence a text weight above 0.5. The sum is clamped to 1.
  static const double textWeight = 0.85;
  static const double entityWeight = 0.45;
  static const double themeWeight = 0.25;
  static const double temporalWeight = 0.15;

  /// Total weighted score (0..1)
  double get total {
    final sum =
        textSimilarity * textWeight +
        entityBonus * entityWeight +
        themeBonus * themeWeight +
        temporalBonus * temporalWeight;
    return sum > 1.0 ? 1.0 : sum;
  }

  /// Primary reason for connection: the factor contributing most.
  String get primaryReason {
    final text = textSimilarity * textWeight;
    final people = entityBonus * entityWeight;
    final theme = themeBonus * themeWeight;
    final time = temporalBonus * temporalWeight;
    if (people > text && people >= theme && people >= time) {
      return 'People & places';
    }
    if (text >= theme && text >= time) return 'Similar content';
    if (theme >= time) return 'Same theme';
    return 'Close in time';
  }
}
