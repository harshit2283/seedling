import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/review/presentation/year_in_review_screen.dart';

class _MockDb extends Mock implements ObjectBoxDatabase {}

void main() {
  late _MockDb db;

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

  Widget host() => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      theme: SeedlingTheme.dark,
      home: const YearInReviewScreen(year: 2026),
    ),
  );

  setUp(() => db = _MockDb());

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
}
