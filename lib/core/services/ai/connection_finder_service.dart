import '../../../data/models/entry.dart';
import 'models/memory_connection.dart';
import 'models/memory_theme.dart';
import 'stop_words.dart';

/// Service for finding connections between memory entries
///
/// Uses text similarity (Jaccard index), temporal proximity,
/// and shared themes to identify related memories.
class ConnectionFinderService {
  /// Minimum similarity score to consider a connection meaningful
  static const double _minimumThreshold = 0.3;

  /// Maximum number of connections to return per entry
  static const int _maxConnections = 5;

  /// Days within which temporal proximity bonus applies
  static const int _temporalWindowDays = 7;

  /// Find connections for a specific entry
  ///
  /// Returns a list of related entries sorted by similarity score.
  List<MemoryConnection> findConnections(Entry entry, List<Entry> allEntries) {
    if (entry.searchableContent.isEmpty) return [];

    final connections = <MemoryConnection>[];

    // Pre-calculate tokens for the source entry to avoid re-tokenizing in the loop
    final sourceWords = _tokenize(entry.searchableContent);
    final sourceFiltered = _removeStopWords(sourceWords);

    for (final candidate in allEntries) {
      // Skip self and deleted entries
      if (candidate.id == entry.id || candidate.isDeleted) continue;

      // Calculate similarity
      final factors = _calculateConnectionFactors(
        entry,
        candidate,
        precalculatedWordsA: sourceWords,
        precalculatedFilteredA: sourceFiltered,
      );
      final score = factors.total;

      // Only include meaningful connections
      if (score >= _minimumThreshold) {
        connections.add(
          MemoryConnection(
            relatedEntry: candidate,
            similarityScore: score,
            factors: factors,
          ),
        );
      }
    }

    // Sort by similarity score (highest first)
    connections.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));

    // Return top connections
    return connections.take(_maxConnections).toList();
  }

  /// Calculate all connection factors between two entries
  ConnectionFactors _calculateConnectionFactors(
    Entry a,
    Entry b, {
    Set<String>? precalculatedWordsA,
    Set<String>? precalculatedFilteredA,
  }) {
    return ConnectionFactors(
      textSimilarity: _calculateTextSimilarity(
        a,
        b,
        precalculatedWordsA: precalculatedWordsA,
        precalculatedFilteredA: precalculatedFilteredA,
      ),
      temporalBonus: _calculateTemporalBonus(a, b),
      themeBonus: _calculateThemeBonus(a, b),
    );
  }

  /// Calculate text similarity using Jaccard index
  ///
  /// Jaccard index = |A ∩ B| / |A ∪ B|
  /// where A and B are sets of words
  double _calculateTextSimilarity(
    Entry a,
    Entry b, {
    Set<String>? precalculatedWordsA,
    Set<String>? precalculatedFilteredA,
  }) {
    final wordsA = precalculatedWordsA ?? _tokenize(a.searchableContent);
    final wordsB = _tokenize(b.searchableContent);

    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;

    // Remove common stop words for better signal
    final filteredA = precalculatedFilteredA ?? _removeStopWords(wordsA);
    final filteredB = _removeStopWords(wordsB);

    if (filteredA.isEmpty || filteredB.isEmpty) {
      // Fall back to unfiltered if stop word removal empties the sets
      return _jaccardIndex(wordsA, wordsB);
    }

    return _jaccardIndex(filteredA, filteredB);
  }

  /// Calculate Jaccard index between two sets
  double _jaccardIndex(Set<String> a, Set<String> b) {
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;

    if (union == 0) return 0.0;
    return intersection / union;
  }

  /// Calculate temporal proximity bonus
  ///
  /// Entries within the same week get a bonus.
  double _calculateTemporalBonus(Entry a, Entry b) {
    final daysDifference = a.createdAt.difference(b.createdAt).inDays.abs();

    if (daysDifference <= 1) return 1.0; // Same day or adjacent
    if (daysDifference <= _temporalWindowDays) {
      // Linear decay over the window
      return 1.0 - (daysDifference / _temporalWindowDays);
    }
    return 0.0;
  }

  /// Calculate shared theme bonus
  ///
  /// Entries with the same theme get a bonus.
  double _calculateThemeBonus(Entry a, Entry b) {
    if (!a.hasTheme || !b.hasTheme) return 0.0;

    final themeA = MemoryThemeExtension.fromString(a.detectedTheme);
    final themeB = MemoryThemeExtension.fromString(b.detectedTheme);

    if (themeA == null || themeB == null) return 0.0;
    if (themeA == themeB) return 1.0;

    // Partial bonus for related themes
    if (_areThemesRelated(themeA, themeB)) return 0.5;

    return 0.0;
  }

  /// Check if two themes are related
  bool _areThemesRelated(MemoryTheme a, MemoryTheme b) {
    final relatedGroups = [
      {MemoryTheme.family, MemoryTheme.friends},
      {MemoryTheme.nature, MemoryTheme.travel, MemoryTheme.health},
      {MemoryTheme.reflection, MemoryTheme.gratitude},
      {MemoryTheme.creativity, MemoryTheme.work},
      {MemoryTheme.food, MemoryTheme.friends},
    ];

    for (final group in relatedGroups) {
      if (group.contains(a) && group.contains(b)) return true;
    }

    return false;
  }

  /// Tokenize content into lowercase words
  Set<String> _tokenize(String content) {
    return content
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .toSet();
  }

  /// Remove common stop words
  Set<String> _removeStopWords(Set<String> words) {
    return words.difference(commonStopWords);
  }

  /// Get IDs of connected entries as comma-separated string
  String getConnectionIdsString(List<MemoryConnection> connections) {
    return connections.map((c) => c.relatedEntry.id.toString()).join(',');
  }

  /// Calculate overall similarity between two entries (0.0 to 1.0)
  double calculateSimilarity(Entry a, Entry b) {
    final factors = _calculateConnectionFactors(a, b);
    return factors.total;
  }
}
