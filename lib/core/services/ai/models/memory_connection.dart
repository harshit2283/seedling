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
  /// Text content similarity (Jaccard index)
  final double textSimilarity;

  /// Temporal proximity bonus (same week = higher)
  final double temporalBonus;

  /// Shared theme bonus
  final double themeBonus;

  const ConnectionFactors({
    required this.textSimilarity,
    required this.temporalBonus,
    required this.themeBonus,
  });

  /// Total weighted score
  double get total {
    // Weights: text 60%, temporal 20%, theme 20%
    return (textSimilarity * 0.6) + (temporalBonus * 0.2) + (themeBonus * 0.2);
  }

  /// Primary reason for connection
  String get primaryReason {
    if (textSimilarity >= temporalBonus && textSimilarity >= themeBonus) {
      return 'Similar content';
    }
    if (themeBonus >= temporalBonus) {
      return 'Same theme';
    }
    return 'Close in time';
  }
}
