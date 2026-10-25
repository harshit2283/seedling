import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/core/services/ritual/ritual_service.dart';
import 'package:seedling/core/services/sync/sync_engine.dart';
import 'package:seedling/data/datasources/local/seedling_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/memories/presentation/entry_detail_screen.dart';
import 'package:seedling/features/memories/presentation/widgets/season_sprig.dart';

class MockSeedlingDatabase extends Mock implements SeedlingDatabase {}

class MockSyncEngine extends Mock implements SyncEngine {}

class MockRitualService extends Mock implements RitualService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSeedlingDatabase mockDb;
  late MockSyncEngine mockSyncEngine;
  late MockRitualService mockRitualService;
  late SharedPreferences prefs;

  setUpAll(() {
    registerFallbackValue(Entry.line(text: ''));
    registerFallbackValue(EntryType.line);
  });

  setUp(() async {
    mockDb = MockSeedlingDatabase();
    mockSyncEngine = MockSyncEngine();
    mockRitualService = MockRitualService();

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    // Default stubs
    when(
      () => mockDb.watchEntries(),
    ).thenAnswer((_) => Stream.value(<Entry>[]));
    when(() => mockDb.watchCurrentTree()).thenAnswer((_) => Stream.value(null));
    when(() => mockDb.watchRituals()).thenAnswer((_) => Stream.value([]));
    when(() => mockDb.getAllEntries()).thenReturn([]);
    when(
      () => mockDb.getEntriesPage(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        year: any(named: 'year'),
        includeDeleted: any(named: 'includeDeleted'),
        descending: any(named: 'descending'),
        includeLockedCapsules: any(named: 'includeLockedCapsules'),
      ),
    ).thenReturn([]);
    when(
      () => mockDb.getEntriesCount(
        year: any(named: 'year'),
        includeDeleted: any(named: 'includeDeleted'),
        includeLockedCapsules: any(named: 'includeLockedCapsules'),
      ),
    ).thenReturn(0);
    when(() => mockDb.getAllCapsules()).thenReturn([]);
    when(() => mockDb.getDeletedEntries()).thenReturn([]);
    when(() => mockDb.getCapsulesToUnlockToday()).thenReturn([]);
    when(() => mockDb.getAllTrees()).thenReturn([]);
    when(() => mockDb.getEntriesBySyncUUIDs(any())).thenReturn([]);
    when(
      () => mockDb.watchAllEntries(),
    ).thenAnswer((_) => Stream.value(<Entry>[]));
    when(() => mockDb.getEntry(any())).thenReturn(null);
    when(
      () => mockRitualService.updateAfterEntry(any()),
    ).thenAnswer((_) async {});
  });

  Widget host(List<Entry> entries, int id) {
    when(() => mockDb.watchEntries()).thenAnswer((_) => Stream.value(entries));
    when(
      () => mockDb.watchAllEntries(),
    ).thenAnswer((_) => Stream.value(entries));
    for (final e in entries) {
      when(() => mockDb.getEntry(e.id)).thenReturn(e);
    }
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        sharedPreferencesProvider.overrideWithValue(prefs),
        ritualServiceProvider.overrideWithValue(mockRitualService),
        syncEngineProvider.overrideWithValue(mockSyncEngine),
      ],
      child: MaterialApp(home: EntryDetailScreen(entryId: id)),
    );
  }

  Entry line(int id, String text, DateTime at) => Entry.line(text: text)
    ..id = id
    ..createdAt = at;

  test('season line names the season and part of day', () {
    expect(seasonMomentLine(DateTime(2026, 10, 4, 19)), 'An autumn evening');
    expect(seasonMomentLine(DateTime(2026, 4, 4, 8)), 'A spring morning');
    expect(seasonMomentLine(DateTime(2026, 7, 4, 14)), 'A summer afternoon');
    expect(seasonMomentLine(DateTime(2026, 1, 4, 23)), 'A winter night');
  });

  testWidgets('a line memory without a photo shows its season sprig', (
    tester,
  ) async {
    final entry = line(
      1,
      'Morning coffee on the balcony',
      DateTime(2026, 10, 4, 8),
    );
    await tester.pumpWidget(host([entry], 1));
    await tester.pumpAndSettle();

    expect(find.byType(SeasonSprigHeader), findsOneWidget);
    expect(find.text('An autumn morning'), findsOneWidget);
  });

  testWidgets('a short line still offers related memories', (tester) async {
    final now = DateTime.now();
    final entries = [
      line(1, 'Morning coffee on the balcony', now),
      line(
        2,
        'Coffee with Sam at the corner place',
        now.subtract(const Duration(days: 20)),
      ),
      line(3, 'Rain all afternoon', now.subtract(const Duration(days: 40))),
    ];
    await tester.pumpWidget(host(entries, 1));
    await tester.pumpAndSettle();

    expect(find.text('Related memories'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
