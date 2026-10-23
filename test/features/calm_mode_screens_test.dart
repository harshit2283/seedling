import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/constants/prefs_keys.dart';
import 'package:seedling/core/services/ai/models/memory_theme.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/data/models/tree.dart';
import 'package:seedling/features/memories/presentation/memories_screen.dart';
import 'package:seedling/features/review/domain/review_generator.dart';
import 'package:seedling/features/review/presentation/year_in_review_screen.dart';
import 'package:seedling/features/tree/presentation/forest_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDb extends Mock implements ObjectBoxDatabase {}

/// Calm mode: the tree still grows, it just stops keeping score. Every
/// screen that shows counts or growth stages has to respect it.
void main() {
  late _MockDb db;

  setUpAll(() {
    registerFallbackValue(Entry.line(text: ''));
  });

  Future<SharedPreferences> prefsWith({required bool calm}) async {
    SharedPreferences.setMockInitialValues({PrefsKeys.calmModeEnabled: calm});
    return SharedPreferences.getInstance();
  }

  void stubEntries(List<Entry> entries) {
    when(() => db.watchEntries()).thenAnswer((_) => Stream.value(entries));
    when(() => db.watchAllEntries()).thenAnswer((_) => Stream.value(entries));
    when(() => db.watchCurrentTree()).thenAnswer((_) => Stream.value(null));
    when(() => db.watchRituals()).thenAnswer((_) => Stream.value([]));
    when(() => db.getAllEntries()).thenReturn(entries);
    when(() => db.getAllCapsules()).thenReturn([]);
    when(() => db.getDeletedEntries()).thenReturn([]);
    when(() => db.getCapsulesToUnlockToday()).thenReturn([]);
    when(() => db.getAllTrees()).thenReturn([]);
    when(
      () => db.getEntriesPage(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        year: any(named: 'year'),
        includeDeleted: any(named: 'includeDeleted'),
        descending: any(named: 'descending'),
        includeLockedCapsules: any(named: 'includeLockedCapsules'),
      ),
    ).thenReturn(entries);
    when(
      () => db.getEntriesCount(
        year: any(named: 'year'),
        includeDeleted: any(named: 'includeDeleted'),
        includeLockedCapsules: any(named: 'includeLockedCapsules'),
      ),
    ).thenReturn(entries.length);
  }

  setUp(() {
    db = _MockDb();
    stubEntries(const []);
  });

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4800);
    addTearDown(tester.view.reset);
  }

  group('Forest', () {
    final trees = [
      Tree(year: 2026, entryCount: 42)..state = TreeState.sapling,
      Tree(year: 2025, entryCount: 7)..state = TreeState.seed,
    ];

    Future<void> pumpForest(WidgetTester tester, {required bool calm}) async {
      final prefs = await prefsWith(calm: calm);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            allTreesProvider.overrideWithValue(trees),
          ],
          child: MaterialApp(home: ForestScreen(now: DateTime(2026, 10, 19))),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows totals and stages normally', (tester) async {
      await pumpForest(tester, calm: false);
      expect(find.text('49 memories across 2 years'), findsOneWidget);
      expect(find.text('2026 \u00b7 Sapling'), findsOneWidget);
      expect(find.text('42 memories'), findsOneWidget);
    });

    testWidgets('hides totals, stages and counts in calm mode', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpForest(tester, calm: true);

      expect(find.textContaining('memories'), findsNothing);
      expect(find.textContaining('Sapling'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('memories')), findsNothing);
      expect(find.text('2026'), findsWidgets);
      semantics.dispose();
    });
  });

  group('Year in review', () {
    final full = YearReviewData(
      year: 2026,
      totalEntries: 42,
      seasons: const {
        'spring': SeasonData(name: 'Spring', entryCount: 12),
        'summer': SeasonData(name: 'Summer', entryCount: 30),
      },
      themeDistribution: const {MemoryTheme.nature: 17},
      dominantTheme: MemoryTheme.nature,
      memorableMoments: const [],
      treeStateLabel: 'Sapling',
    );

    Future<void> pumpReview(
      WidgetTester tester, {
      required bool calm,
      YearReviewData? data,
    }) async {
      final prefs = await prefsWith(calm: calm);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
            reviewDataProvider(2026).overrideWithValue(data),
          ],
          child: const MaterialApp(home: YearInReviewScreen(year: 2026)),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows counts and the stage normally', (tester) async {
      tallScreen(tester);
      await pumpReview(tester, calm: false, data: full);
      expect(find.text('You planted 42 memories'), findsOneWidget);
      expect(find.textContaining('Sapling'), findsWidgets);
      expect(find.text('30 memories'), findsOneWidget);
    });

    testWidgets('keeps no score in calm mode', (tester) async {
      tallScreen(tester);
      await pumpReview(tester, calm: true, data: full);

      expect(find.textContaining('42'), findsNothing);
      expect(find.textContaining('Sapling'), findsNothing);
      expect(find.textContaining(RegExp(r'\d+ memor')), findsNothing);
      expect(find.text('17'), findsNothing);
      // The year itself is still told.
      expect(find.text('Your seasons'), findsOneWidget);
    });

    testWidgets('a young year shows no count in calm mode', (tester) async {
      stubEntries([
        for (var i = 1; i <= 3; i++) Entry.line(text: 'Walk number $i')..id = i,
      ]);
      await pumpReview(tester, calm: true);

      expect(find.text('Your year is still taking shape'), findsOneWidget);
      expect(find.textContaining('3 memories'), findsNothing);
      expect(find.text('Walk number 1'), findsOneWidget);
    });
  });

  group('Memories theme filters', () {
    Future<void> pumpMemories(WidgetTester tester, {required bool calm}) async {
      final prefs = await prefsWith(calm: calm);
      final entries = [
        for (var i = 1; i <= 3; i++)
          Entry.line(text: 'A walk in the forest among the trees $i')
            ..id = i
            ..detectedTheme = MemoryTheme.nature.name,
      ];
      stubEntries(entries);
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(home: MemoriesScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('theme chips show counts normally', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpMemories(tester, calm: false);
      expect(
        find.bySemanticsLabel(RegExp(r'Nature filter, \d+ memories')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('theme chips hide counts in calm mode', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpMemories(tester, calm: true);
      expect(find.bySemanticsLabel(RegExp(r'^Nature filter')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'Nature filter, \d+ memories')),
        findsNothing,
      );
      semantics.dispose();
    });
  });
}
