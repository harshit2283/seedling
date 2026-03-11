import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/core/services/ai/models/memory_theme.dart';
import 'package:seedling/core/services/ai/theme_detector_service.dart';
import 'package:seedling/features/review/domain/review_generator.dart';

void main() {
  late ReviewGenerator generator;

  setUp(() {
    generator = ReviewGenerator(themeDetector: ThemeDetectorService());
  });

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Create an entry at the given [month] and [day] in [year].
  Entry makeEntry({
    int year = 2025,
    int month = 6,
    int day = 15,
    String? text,
    double? sentimentScore,
    String? connectionIds,
    String? detectedTheme,
  }) {
    final entry = Entry.line(text: text ?? 'Memory at $month/$day/$year');
    entry.createdAt = DateTime(year, month, day);
    entry.sentimentScore = sentimentScore;
    entry.connectionIds = connectionIds;
    entry.detectedTheme = detectedTheme;
    return entry;
  }

  /// Build N generic entries across the year.
  List<Entry> makeEntries(int count, {int year = 2025}) {
    return List.generate(count, (i) {
      final month = (i % 12) + 1;
      final day = (i % 28) + 1;
      return makeEntry(year: year, month: month, day: day, text: 'Entry $i');
    });
  }

  // -------------------------------------------------------------------------
  // Tests
  // -------------------------------------------------------------------------

  group('ReviewGenerator', () {
    test('empty year returns zero totals and empty collections', () {
      final data = generator.generate(2025, []);

      expect(data.year, 2025);
      expect(data.totalEntries, 0);
      expect(data.memorableMoments, isEmpty);
      expect(data.connectionCount, 0);
      expect(data.treeStateLabel, 'Seed');
      expect(data.dominantTheme, isNull);
    });

    test('filters out entries from other years', () {
      final entries = [
        makeEntry(year: 2024, month: 5, text: 'old'),
        makeEntry(year: 2025, month: 5, text: 'current'),
        makeEntry(year: 2026, month: 5, text: 'future'),
      ];

      final data = generator.generate(2025, entries);

      expect(data.totalEntries, 1);
    });

    test('filters out deleted entries', () {
      final deleted = makeEntry(year: 2025, month: 3, text: 'gone');
      deleted.isDeleted = true;
      deleted.deletedAt = DateTime(2025, 3, 20);

      final entries = [
        deleted,
        makeEntry(year: 2025, month: 4, text: 'active'),
      ];

      final data = generator.generate(2025, entries);

      expect(data.totalEntries, 1);
    });

    test('hasEnoughEntries is false below 10', () {
      final entries = makeEntries(9);
      final data = generator.generate(2025, entries);

      expect(data.hasEnoughEntries, false);
    });

    test('hasEnoughEntries is true at 10', () {
      final entries = makeEntries(10);
      final data = generator.generate(2025, entries);

      expect(data.hasEnoughEntries, true);
    });

    // -- Season grouping --

    group('season grouping', () {
      test('spring entries (Mar-May) land in spring', () {
        final entries = [
          makeEntry(month: 3),
          makeEntry(month: 4),
          makeEntry(month: 5),
        ];
        final data = generator.generate(2025, entries);

        expect(data.seasons['spring']!.entryCount, 3);
        expect(data.seasons['summer']!.entryCount, 0);
        expect(data.seasons['autumn']!.entryCount, 0);
        expect(data.seasons['winter']!.entryCount, 0);
      });

      test('summer entries (Jun-Aug) land in summer', () {
        final entries = [
          makeEntry(month: 6),
          makeEntry(month: 7),
          makeEntry(month: 8),
        ];
        final data = generator.generate(2025, entries);

        expect(data.seasons['summer']!.entryCount, 3);
      });

      test('autumn entries (Sep-Nov) land in autumn', () {
        final entries = [
          makeEntry(month: 9),
          makeEntry(month: 10),
          makeEntry(month: 11),
        ];
        final data = generator.generate(2025, entries);

        expect(data.seasons['autumn']!.entryCount, 3);
      });

      test('winter entries (Dec, Jan, Feb) land in winter', () {
        final entries = [
          makeEntry(month: 12),
          makeEntry(month: 1),
          makeEntry(month: 2),
        ];
        final data = generator.generate(2025, entries);

        expect(data.seasons['winter']!.entryCount, 3);
      });
    });

    // -- Theme distribution --

    test('theme distribution counts entries per theme', () {
      // Use entries with pre-set detectedTheme to avoid keyword-matching variance.
      final entries = [
        makeEntry(text: 'family time', detectedTheme: 'family'),
        makeEntry(text: 'gym workout', detectedTheme: 'health'),
        makeEntry(text: 'another workout', detectedTheme: 'health'),
      ];
      final data = generator.generate(2025, entries);

      final familyCount = data.themeDistribution[MemoryTheme.family] ?? 0;
      final healthCount = data.themeDistribution[MemoryTheme.health] ?? 0;
      expect(familyCount, greaterThanOrEqualTo(1));
      expect(healthCount, greaterThanOrEqualTo(2));
    });

    test('dominant theme excludes moments', () {
      // All entries explicitly tagged moments.
      final entries = List.generate(
        12,
        (i) => makeEntry(month: i + 1, text: 'today morning moment'),
      );
      final data = generator.generate(2025, entries);

      // If every entry maps to 'moments', dominantTheme should be null
      // (or whatever the detector picks). In either case, it should never
      // be moments itself.
      if (data.dominantTheme != null) {
        expect(data.dominantTheme, isNot(MemoryTheme.moments));
      }
    });

    // -- Sentiment arc --

    test('sentiment arc has 12 months', () {
      final data = generator.generate(2025, makeEntries(20));

      expect(data.sentimentArc.length, 12);
      expect(data.sentimentArc.first.month, 1);
      expect(data.sentimentArc.last.month, 12);
    });

    test('sentiment arc averages scores per month', () {
      final entries = [
        makeEntry(month: 3, day: 1, sentimentScore: 0.8),
        makeEntry(month: 3, day: 10, sentimentScore: 0.2),
      ];
      final data = generator.generate(2025, entries);

      final march = data.sentimentArc.firstWhere((m) => m.month == 3);
      expect(march.averageSentiment, closeTo(0.5, 0.001));
      expect(march.entryCount, 2);
    });

    test('months with no sentiment data default to 0.0', () {
      final entries = [makeEntry(month: 7, sentimentScore: null)];
      final data = generator.generate(2025, entries);

      final july = data.sentimentArc.firstWhere((m) => m.month == 7);
      expect(july.averageSentiment, 0.0);
      expect(july.entryCount, 1);
    });

    // -- Memorable moments --

    test('memorable moments returns 0 for empty year', () {
      final data = generator.generate(2025, []);
      expect(data.memorableMoments, isEmpty);
    });

    test('memorable moments returns at most 5 entries', () {
      final entries = makeEntries(50);
      final data = generator.generate(2025, entries);

      expect(data.memorableMoments.length, lessThanOrEqualTo(5));
    });

    test('memorable moments returns all entries when fewer than 5', () {
      final entries = makeEntries(3);
      final data = generator.generate(2025, entries);

      expect(data.memorableMoments.length, 3);
    });

    // -- Connection count --

    test('connection count reflects entries with connectionIds', () {
      final entries = [
        makeEntry(month: 1, connectionIds: '2,3'),
        makeEntry(month: 2, connectionIds: '1'),
        makeEntry(month: 3),
      ];
      final data = generator.generate(2025, entries);

      expect(data.connectionCount, 2);
    });

    // -- Tree state label --

    group('tree state label', () {
      test('0 entries -> Seed', () {
        final data = generator.generate(2025, []);
        expect(data.treeStateLabel, 'Seed');
      });

      test('10 entries -> Seed', () {
        final data = generator.generate(2025, makeEntries(10));
        expect(data.treeStateLabel, 'Seed');
      });

      test('11 entries -> Sprout', () {
        final data = generator.generate(2025, makeEntries(11));
        expect(data.treeStateLabel, 'Sprout');
      });

      test('31 entries -> Sapling', () {
        final data = generator.generate(2025, makeEntries(31));
        expect(data.treeStateLabel, 'Sapling');
      });

      test('101 entries -> Young Tree', () {
        final data = generator.generate(2025, makeEntries(101));
        expect(data.treeStateLabel, 'Young Tree');
      });

      test('251 entries -> Mature Tree', () {
        final data = generator.generate(2025, makeEntries(251));
        expect(data.treeStateLabel, 'Mature Tree');
      });

      test('501 entries -> Ancient Tree', () {
        final data = generator.generate(2025, makeEntries(501));
        expect(data.treeStateLabel, 'Ancient Tree');
      });
    });
  });
}
