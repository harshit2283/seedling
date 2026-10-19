import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/review/presentation/year_in_review_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDb extends Mock implements ObjectBoxDatabase {}

void main() {
  late _MockDb db;
  late SharedPreferences prefs;

  void stubEntries(List<Entry> entries) {
    when(() => db.watchAllEntries()).thenAnswer((_) => Stream.value(entries));
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

  Widget host({int year = 2026, DateTime? now}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      theme: SeedlingTheme.dark,
      home: YearInReviewScreen(year: year, now: now ?? DateTime(2026, 10, 19)),
    ),
  );

  setUp(() async {
    db = _MockDb();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('with a few memories shows what exists, not a locked gate', (
    tester,
  ) async {
    final entries = [
      for (var i = 1; i <= 3; i++) Entry.line(text: 'Morning walk $i')..id = i,
    ];
    stubEntries(entries);
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('Your year is still taking shape'), findsOneWidget);
    expect(find.textContaining('3 memories planted in 2026'), findsOneWidget);
    expect(find.text('Morning walk 1'), findsOneWidget);
    expect(find.textContaining('unlock'), findsNothing);
    expect(find.textContaining('You need'), findsNothing);
  });

  testWidgets('with no memories invites, gently', (tester) async {
    stubEntries(const []);
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('Your year is still taking shape'), findsOneWidget);
    expect(find.textContaining('Nothing planted in 2026 yet'), findsOneWidget);
  });

  group('a finished year', () {
    final now = DateTime(2026, 10, 19);

    testWidgets('a quiet past year is told in the past tense', (tester) async {
      stubEntries([
        Entry.line(text: 'Roof in Porto')
          ..id = 1
          ..createdAt = DateTime(2025, 8, 14),
        Entry.release(text: 'Being angry at Jordan')
          ..id = 2
          ..createdAt = DateTime(2025, 6, 20),
      ]);
      await tester.pumpWidget(host(year: 2025, now: now));
      await tester.pump();

      expect(find.text('Your 2025'), findsOneWidget);
      expect(find.textContaining('taking shape'), findsNothing);
      expect(find.textContaining('so far'), findsNothing);
      expect(find.text('So far'), findsNothing);
      expect(find.text('From 2025'), findsOneWidget);
      expect(find.text('Roof in Porto'), findsOneWidget);
      // Released memories were let go on purpose: never shown back.
      expect(find.textContaining('Jordan'), findsNothing);
    });

    testWidgets('a full past year reads as finished', (tester) async {
      tester.view.physicalSize = const Size(1800, 9000);
      addTearDown(tester.view.reset);
      stubEntries([
        for (var i = 1; i <= 12; i++)
          Entry.line(text: 'Walk by the river $i')
            ..id = i
            ..createdAt = DateTime(2025, i, 3),
        Entry.release(text: 'Being angry at Jordan')
          ..id = 99
          ..createdAt = DateTime(2025, 6, 20),
      ]);
      await tester.pumpWidget(host(year: 2025, now: now));
      await tester.pump();

      expect(find.text('Your 2025'), findsOneWidget);
      expect(find.text('You planted 13 memories'), findsOneWidget);
      expect(find.textContaining('By December'), findsOneWidget);
      expect(find.textContaining('taking shape'), findsNothing);
      expect(find.textContaining('so far'), findsNothing);
      expect(find.textContaining('Jordan'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Thank you for keeping 2025.'),
        400,
      );
      expect(find.text('Thank you for keeping 2025.'), findsOneWidget);
    });

    testWidgets('the current year still says it is taking shape', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1800, 9000);
      addTearDown(tester.view.reset);
      stubEntries([
        for (var i = 1; i <= 12; i++)
          Entry.line(text: 'Morning $i')
            ..id = i
            ..createdAt = DateTime(2026, (i % 9) + 1, 3),
      ]);
      await tester.pumpWidget(host(year: 2026, now: now));
      await tester.pump();

      expect(find.text('Your 2026, so far'), findsOneWidget);
      expect(find.textContaining('still taking shape'), findsOneWidget);
      expect(find.textContaining('By December'), findsNothing);
    });
  });
}
