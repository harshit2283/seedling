import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/suggestion_engine.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/core/services/ai/models/memory_theme.dart';

void main() {
  group('SuggestionEngine', () {
    late SuggestionEngine engine;

    setUp(() {
      engine = SuggestionEngine();
    });

    test(
      'identifyGaps correctly identifies gaps and calculates days since',
      () {
        final now = DateTime.now();
        final entries = [
          Entry(
            createdAt: now.subtract(const Duration(days: 1)),
            detectedTheme: 'family',
          ),
          Entry(
            createdAt: now.subtract(const Duration(days: 5)),
            detectedTheme: 'work',
          ),
          // No 'nature' entries
        ];

        // Mock distribution to avoid dependency on ThemeDetectorService logic
        // We populate it with themes we care about for this test
        final distribution = <MemoryTheme, int>{
          MemoryTheme.family: 1,
          MemoryTheme.work: 1,
          MemoryTheme.nature: 0,
        };
        // Fill others with 0
        for (final theme in MemoryTheme.values) {
          distribution.putIfAbsent(theme, () => 0);
        }

        final gaps = engine.identifyGaps(entries, distribution);

        // Check family gap
        final familyGap = gaps.firstWhere((g) => g.theme == MemoryTheme.family);
        expect(familyGap.daysSinceLastEntry, 1);

        // Check work gap
        final workGap = gaps.firstWhere((g) => g.theme == MemoryTheme.work);
        expect(workGap.daysSinceLastEntry, 5);

        // Check nature gap (never entered)
        final natureGap = gaps.firstWhere((g) => g.theme == MemoryTheme.nature);
        expect(natureGap.daysSinceLastEntry, 999);
      },
    );

    test('identifyGaps handles empty entries', () {
      final gaps = engine.identifyGaps([], {});
      expect(gaps, isEmpty);
    });

    test('identifyGaps finds the latest entry among duplicates', () {
      final now = DateTime.now();
      final entries = [
        Entry(
          createdAt: now.subtract(const Duration(days: 10)),
          detectedTheme: 'family',
        ),
        Entry(
          createdAt: now.subtract(const Duration(days: 2)),
          detectedTheme: 'family',
        ), // Newer
        Entry(
          createdAt: now.subtract(const Duration(days: 5)),
          detectedTheme: 'family',
        ),
      ];

      final distribution = <MemoryTheme, int>{MemoryTheme.family: 3};
      for (final theme in MemoryTheme.values) {
        distribution.putIfAbsent(theme, () => 0);
      }

      final gaps = engine.identifyGaps(entries, distribution);
      final familyGap = gaps.firstWhere((g) => g.theme == MemoryTheme.family);

      // Should be 2 days ago
      expect(familyGap.daysSinceLastEntry, 2);
    });
  });
}
