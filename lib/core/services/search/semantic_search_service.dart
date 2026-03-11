import 'dart:math';
import 'package:flutter/foundation.dart';

import '../../../data/models/entry.dart';
import '../ai/ml_text_analyzer.dart';
import '../ai/theme_detector_service.dart';

/// A search result with relevance scoring
class SearchResult {
  final Entry entry;
  final double score;
  final SearchMatchType matchType;

  const SearchResult({
    required this.entry,
    required this.score,
    required this.matchType,
  });
}

enum SearchMatchType { exact, keyword, theme, semantic }

/// Blended search combining keyword, theme, and semantic matching.
///
/// For queries < 3 chars, uses simple substring matching.
/// For longer queries, blends keyword (0.5 weight), theme (0.2 weight),
/// and ML semantic similarity (0.3 weight) for richer results.
class SemanticSearchService {
  final MLTextAnalyzer _mlAnalyzer;
  final ThemeDetectorService _themeDetector;

  SemanticSearchService({
    required MLTextAnalyzer mlAnalyzer,
    required ThemeDetectorService themeDetector,
  }) : _mlAnalyzer = mlAnalyzer,
       _themeDetector = themeDetector;

  /// Search entries with blended relevance scoring.
  ///
  /// Returns entries sorted by relevance score (highest first).
  /// [minScore] filters out low-relevance results (default 0.1).
  Future<List<SearchResult>> search(
    String query,
    List<Entry> entries, {
    double minScore = 0.1,
  }) async {
    if (query.isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();

    // Short queries: simple substring match only
    if (normalizedQuery.length < 3) {
      return _substringSearch(normalizedQuery, entries);
    }

    // Full blended search
    final results = <SearchResult>[];
    final queryTheme = _themeDetector.detectTheme(
      Entry.line(text: normalizedQuery),
    );
    final queryThemeName = queryTheme.name;
    final queryWords = _tokenize(normalizedQuery);

    for (final entry in entries) {
      final content = entry.searchableContent;
      if (content.isEmpty) continue;

      // 1. Keyword score (weight: 0.5)
      final keywordScore = _keywordScore(normalizedQuery, queryWords, content);

      // 2. Theme score (weight: 0.2)
      final themeScore = _themeScore(queryThemeName, entry.detectedTheme);

      // 3. Semantic score via ML (weight: 0.3)
      double semanticScore = 0.0;
      try {
        semanticScore = await _mlAnalyzer.calculateSimilarity(
          normalizedQuery,
          content.length > 200 ? content.substring(0, 200) : content,
        );
      } catch (e) {
        debugPrint(
          'SemanticSearchService.search semantic scoring failed for entry ${entry.id}: $e',
        );
        // ML unavailable, skip semantic scoring
      }

      final totalScore =
          (keywordScore * 0.5) + (themeScore * 0.2) + (semanticScore * 0.3);

      if (totalScore >= minScore) {
        final matchType = keywordScore > 0.5
            ? (content.contains(normalizedQuery)
                  ? SearchMatchType.exact
                  : SearchMatchType.keyword)
            : (semanticScore > themeScore
                  ? SearchMatchType.semantic
                  : SearchMatchType.theme);

        results.add(
          SearchResult(entry: entry, score: totalScore, matchType: matchType),
        );
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  List<SearchResult> _substringSearch(String query, List<Entry> entries) {
    final results = <SearchResult>[];
    for (final entry in entries) {
      final content = entry.searchableContent;
      if (content.contains(query)) {
        results.add(
          SearchResult(
            entry: entry,
            score: 1.0,
            matchType: SearchMatchType.exact,
          ),
        );
      }
    }
    return results;
  }

  double _keywordScore(String query, Set<String> queryWords, String content) {
    // Exact substring match is highest
    if (content.contains(query)) return 1.0;

    // Word overlap (Jaccard-like)
    final contentWords = _tokenize(content);
    if (queryWords.isEmpty || contentWords.isEmpty) return 0.0;

    final intersection = queryWords.intersection(contentWords).length;
    final union = queryWords.union(contentWords).length;

    if (union == 0) return 0.0;

    // Boost for matching all query words
    final queryMatchRatio = intersection / queryWords.length;
    final jaccardScore = intersection / union;

    return min(1.0, (queryMatchRatio * 0.7) + (jaccardScore * 0.3));
  }

  double _themeScore(String queryThemeName, String? entryTheme) {
    if (entryTheme == null || entryTheme.isEmpty) return 0.0;
    return queryThemeName == entryTheme ? 1.0 : 0.0;
  }

  Set<String> _tokenize(String text) {
    return text
        .split(RegExp(r'[\s\p{P}]+', unicode: true))
        .where((w) => w.length > 1)
        .toSet();
  }
}
