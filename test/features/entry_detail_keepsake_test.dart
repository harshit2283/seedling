import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/app/router.dart';
import 'package:seedling/core/constants/prefs_keys.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/core/services/sync/sync_engine.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/memories/presentation/entry_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDb extends Mock implements ObjectBoxDatabase {}

class _MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockDb db;
  late SharedPreferences prefs;

  setUpAll(() {
    registerFallbackValue(Entry.line(text: ''));
  });

  /// [current] is this year's list; [all] is every year.
  void stubEntries({required List<Entry> current, required List<Entry> all}) {
    when(() => db.watchEntries()).thenAnswer((_) => Stream.value(current));
    when(() => db.watchAllEntries()).thenAnswer((_) => Stream.value(all));
    when(() => db.getEntry(any())).thenAnswer((inv) {
      final id = inv.positionalArguments.first as int;
      return all.where((e) => e.id == id).firstOrNull;
    });
  }

  setUp(() async {
    db = _MockDb();
    SharedPreferences.setMockInitialValues({
      PrefsKeys.onboardingCompleted: true,
    });
    prefs = await SharedPreferences.getInstance();
    when(() => db.watchCurrentTree()).thenAnswer((_) => Stream.value(null));
    when(() => db.getEntriesBySyncUUIDs(any())).thenReturn([]);
    when(
      () => db.getEntriesPage(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        year: any(named: 'year'),
        includeDeleted: any(named: 'includeDeleted'),
        descending: any(named: 'descending'),
        includeLockedCapsules: any(named: 'includeLockedCapsules'),
      ),
    ).thenReturn([]);
    when(
      () => db.getEntriesCount(
        year: any(named: 'year'),
        includeDeleted: any(named: 'includeDeleted'),
        includeLockedCapsules: any(named: 'includeLockedCapsules'),
      ),
    ).thenReturn(0);
    stubEntries(current: [], all: []);
  });

  List<Override> overrides() => [
    databaseProvider.overrideWithValue(db),
    sharedPreferencesProvider.overrideWithValue(prefs),
    syncEngineProvider.overrideWithValue(_MockSyncEngine()),
  ];

  Future<void> pumpDetail(WidgetTester tester, int id) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(home: EntryDetailScreen(entryId: id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Entry pastYearMemory() {
    final now = DateTime.now();
    return Entry.line(text: 'We got the keys and ate pizza on the floor.')
      ..id = 41
      ..createdAt = DateTime(now.year - 2, now.month, now.day, 19);
  }

  group('past-year memories', () {
    testWidgets('open through the router instead of "Memory not found"', (
      tester,
    ) async {
      final past = pastYearMemory();
      final thisYear = Entry.line(text: 'Something from this year')
        ..id = 7
        ..createdAt = DateTime.now();
      // The past memory is not in the current-year list.
      stubEntries(current: [thisYear], all: [thisYear, past]);

      final router = createAppRouter(prefs);
      addTearDown(router.dispose);
      router.go(AppRoutes.entryRoute(past.id));

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Memory not found'), findsNothing);
      expect(
        find.text('We got the keys and ate pizza on the floor.'),
        findsOneWidget,
      );
      expect(find.textContaining('2 years ago'), findsOneWidget);
    });

    testWidgets('on-this-day link shows a soft "years ago today" header', (
      tester,
    ) async {
      final past = pastYearMemory();
      stubEntries(current: [], all: [past]);

      final router = createAppRouter(prefs);
      addTearDown(router.dispose);
      router.go(AppRoutes.onThisDayEntryRoute(past.id));

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 years ago today'), findsOneWidget);
    });

    testWidgets('a trashed memory is still "not found"', (tester) async {
      final past = pastYearMemory()..isDeleted = true;
      stubEntries(current: [], all: [past]);

      await pumpDetail(tester, past.id);

      expect(find.text('Memory not found'), findsOneWidget);
    });
  });

  group('no empty sections', () {
    testWidgets('an unlinked memory shows no "Linked" or "Related" header', (
      tester,
    ) async {
      final entry = Entry.line(text: 'Quiet morning, tea, the window.')
        ..id = 3
        ..createdAt = DateTime(2026, 4, 26, 7);
      stubEntries(current: [entry], all: [entry]);

      await pumpDetail(tester, entry.id);

      expect(find.textContaining('Linked'), findsNothing);
      expect(find.text('Related memories'), findsNothing);
      // Linking stays possible as a quiet action at the end.
      expect(find.text('Link a memory'), findsOneWidget);
      // The page never titles itself with the type.
      expect(find.text('Line'), findsNothing);
    });

    testWidgets('linked memories appear only when there are links', (
      tester,
    ) async {
      final other = Entry.line(text: 'The night on the roof in Porto.')
        ..id = 9
        ..syncUUID = 'b'
        ..createdAt = DateTime(2025, 8, 14, 23);
      final entry = Entry.line(text: 'Back in Porto again.')
        ..id = 8
        ..syncUUID = 'a'
        ..manualLinkIds = 'b'
        ..createdAt = DateTime(2026, 6, 1, 20);
      stubEntries(current: [entry], all: [entry, other]);
      when(() => db.getEntriesBySyncUUIDs(['b'])).thenReturn([other]);

      await pumpDetail(tester, entry.id);

      expect(find.text('Linked memories'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('The night on the roof in Porto')),
        findsOneWidget,
      );
    });
  });

  group('date helpers', () {
    test('yearsAgoLabel needs a full year', () {
      final now = DateTime(2026, 10, 19);
      expect(yearsAgoLabel(DateTime(2026, 1, 1), now), isNull);
      expect(yearsAgoLabel(DateTime(2025, 10, 20), now), isNull);
      expect(yearsAgoLabel(DateTime(2025, 10, 19), now), 'A year ago');
      expect(yearsAgoLabel(DateTime(2024, 10, 12), now), '2 years ago');
    });

    test('keepsakeDateLine keeps the date together', () {
      expect(
        keepsakeDateLine(DateTime(2024, 10, 12)),
        'Saturday, 12 October 2024',
      );
    });
  });
}
