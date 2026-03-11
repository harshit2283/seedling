import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/ml_text_analyzer.dart';
import 'package:seedling/core/services/ai/models/memory_theme.dart';
import 'package:seedling/core/services/ai/theme_detector_service.dart';
import 'package:seedling/core/services/search/semantic_search_service.dart';
import 'package:seedling/data/models/entry.dart';

class _FakeMLAnalyzer implements MLTextAnalyzer {
  final Map<String, double> similarityByContent;
  int similarityCalls = 0;

  _FakeMLAnalyzer(this.similarityByContent);

  @override
  Future<double> calculateSimilarity(String textA, String textB) async {
    similarityCalls++;
    return similarityByContent[textB] ?? 0.0;
  }

  @override
  Future<double> analyzeSentiment(String text) async => 0.0;

  @override
  Future<MemoryTheme> detectTheme(String text) async => MemoryTheme.moments;

  @override
  Future<List<String>> extractKeywords(String text) async => const [];

  @override
  Future<bool> isAvailable() async => true;
}

class _ThrowingMLAnalyzer extends _FakeMLAnalyzer {
  _ThrowingMLAnalyzer() : super(const {});

  @override
  Future<double> calculateSimilarity(String textA, String textB) async {
    throw StateError('model unavailable');
  }
}

void main() {
  group('SemanticSearchService', () {
    test('returns empty results for empty query', () async {
      final service = SemanticSearchService(
        mlAnalyzer: _FakeMLAnalyzer({}),
        themeDetector: ThemeDetectorService(),
      );

      final results = await service.search('', <Entry>[]);
      expect(results, isEmpty);
    });

    test('uses substring search for short queries and skips ML', () async {
      final analyzer = _FakeMLAnalyzer({});
      final service = SemanticSearchService(
        mlAnalyzer: analyzer,
        themeDetector: ThemeDetectorService(),
      );

      final entries = <Entry>[
        Entry.line(text: 'Garden coffee with mom'),
        Entry.line(text: 'Team meeting in office'),
      ];

      final results = await service.search('ga', entries);

      expect(results.length, 1);
      expect(results.first.entry.text, 'Garden coffee with mom');
      expect(results.first.matchType, SearchMatchType.exact);
      expect(analyzer.similarityCalls, 0);
    });

    test('ranks results by blended score for long queries', () async {
      final query = 'mom dinner';
      final detector = ThemeDetectorService();
      final queryTheme = detector.detectTheme(Entry.line(text: query));

      final exact = Entry.line(text: 'mom dinner memory')
        ..detectedTheme = queryTheme.name;
      final semantic = Entry.line(text: 'quiet evening tea')
        ..detectedTheme = MemoryTheme.moments.name;
      final themeOnly = Entry.line(text: 'shared meal')
        ..detectedTheme = queryTheme.name;

      final analyzer = _FakeMLAnalyzer({
        exact.searchableContent:
            0.3, // exact keyword should still dominate from keyword score
        semantic.searchableContent: 0.95,
        themeOnly.searchableContent: 0.0,
      });

      final service = SemanticSearchService(
        mlAnalyzer: analyzer,
        themeDetector: detector,
      );

      final results = await service.search(query, <Entry>[
        themeOnly,
        semantic,
        exact,
      ]);

      expect(results.length, 3);
      expect(results.first.entry, exact);
      expect(results.first.matchType, SearchMatchType.exact);
      expect(results[1].entry, semantic);
      expect(results[2].entry, themeOnly);
      expect(analyzer.similarityCalls, 3);
    });

    test('respects minScore threshold', () async {
      final low = Entry.line(text: 'random words with no relation');
      final high = Entry.line(text: 'sunset walk in nature park')
        ..detectedTheme = MemoryTheme.nature.name;

      final analyzer = _FakeMLAnalyzer({
        low.searchableContent: 0.0,
        high.searchableContent: 0.9,
      });

      final service = SemanticSearchService(
        mlAnalyzer: analyzer,
        themeDetector: ThemeDetectorService(),
      );

      final results = await service.search('nature walk', <Entry>[
        low,
        high,
      ], minScore: 0.4);

      expect(results.length, 1);
      expect(results.first.entry, high);
      expect(results.first.score, greaterThanOrEqualTo(0.4));
    });

    test('continues search when semantic scoring throws', () async {
      final entry = Entry.line(text: 'nature walk with family');
      final service = SemanticSearchService(
        mlAnalyzer: _ThrowingMLAnalyzer(),
        themeDetector: ThemeDetectorService(),
      );

      final results = await service.search('nature walk', <Entry>[entry]);

      expect(results, isNotEmpty);
      expect(results.first.entry, entry);
    });
  });
}
