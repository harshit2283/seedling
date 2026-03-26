import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/core/services/ritual/ritual_service.dart';
import 'package:seedling/core/services/sync/sync_engine.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/memories/presentation/memories_screen.dart';
import 'package:seedling/features/memories/presentation/memory_card.dart';

class MockObjectBoxDatabase extends Mock implements ObjectBoxDatabase {}

class MockSyncEngine extends Mock implements SyncEngine {}

class MockRitualService extends Mock implements RitualService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockObjectBoxDatabase mockDb;
  late MockSyncEngine mockSyncEngine;
  late MockRitualService mockRitualService;
  late SharedPreferences prefs;

  setUpAll(() {
    registerFallbackValue(Entry());
    registerFallbackValue(EntryType.line);
  });

  setUp(() async {
    mockDb = MockObjectBoxDatabase();
    mockSyncEngine = MockSyncEngine();
    mockRitualService = MockRitualService();

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    // Default stubs
    when(() => mockDb.watchEntries()).thenAnswer(
      (_) => Stream.value(<Entry>[]),
    );
    when(() => mockDb.watchCurrentTree()).thenAnswer(
      (_) => Stream.value(null),
    );
    when(() => mockDb.watchRituals()).thenAnswer(
      (_) => Stream.value([]),
    );
    when(() => mockDb.getAllEntries()).thenReturn([]);
    when(() => mockDb.getEntriesPage(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          year: any(named: 'year'),
          includeDeleted: any(named: 'includeDeleted'),
          descending: any(named: 'descending'),
          includeLockedCapsules: any(named: 'includeLockedCapsules'),
        )).thenReturn([]);
    when(() => mockDb.getEntriesCount(
          year: any(named: 'year'),
          includeDeleted: any(named: 'includeDeleted'),
          includeLockedCapsules: any(named: 'includeLockedCapsules'),
        )).thenReturn(0);
    when(() => mockDb.getAllCapsules()).thenReturn([]);
    when(() => mockDb.getDeletedEntries()).thenReturn([]);
    when(() => mockDb.getCapsulesToUnlockToday()).thenReturn([]);
    when(() => mockDb.getAllTrees()).thenReturn([]);
    when(() => mockRitualService.updateAfterEntry(any()))
        .thenAnswer((_) async {});
  });

  /// Helper to create test entries with proper IDs.
  List<Entry> createTestEntries() {
    final entries = <Entry>[];
    for (var i = 1; i <= 3; i++) {
      final entry = Entry.line(text: 'Memory number $i');
      entry.id = i;
      entries.add(entry);
    }
    return entries;
  }

  /// Build a testable widget with provider overrides and test entries.
  Widget buildTestWidget({List<Entry> entries = const []}) {
    when(() => mockDb.watchEntries()).thenAnswer(
      (_) => Stream.value(entries),
    );
    when(() => mockDb.getEntriesPage(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          year: any(named: 'year'),
          includeDeleted: any(named: 'includeDeleted'),
          descending: any(named: 'descending'),
          includeLockedCapsules: any(named: 'includeLockedCapsules'),
        )).thenReturn(entries);
    when(() => mockDb.getEntriesCount(
          year: any(named: 'year'),
          includeDeleted: any(named: 'includeDeleted'),
          includeLockedCapsules: any(named: 'includeLockedCapsules'),
        )).thenReturn(entries.length);

    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        sharedPreferencesProvider.overrideWithValue(prefs),
        ritualServiceProvider.overrideWithValue(mockRitualService),
        syncEngineProvider.overrideWithValue(mockSyncEngine),
      ],
      child: const MaterialApp(
        home: MemoriesScreen(),
      ),
    );
  }

  group('MemoriesScreen', () {
    testWidgets('renders entries list', (tester) async {
      final entries = createTestEntries();
      await tester.pumpWidget(buildTestWidget(entries: entries));
      await tester.pumpAndSettle();

      // Verify each entry's text content is displayed
      expect(find.text('Memory number 1'), findsOneWidget);
      expect(find.text('Memory number 2'), findsOneWidget);
      expect(find.text('Memory number 3'), findsOneWidget);

      // Verify MemoryCard widgets are used
      expect(find.byType(MemoryCard), findsNWidgets(3));
    });

    testWidgets('search bar is displayed', (tester) async {
      final entries = createTestEntries();
      await tester.pumpWidget(buildTestWidget(entries: entries));
      await tester.pumpAndSettle();

      // The search bar should show the hint text (TextField on Android)
      expect(find.text('Search memories...'), findsOneWidget);
    });

    testWidgets('empty state shows when no entries', (tester) async {
      await tester.pumpWidget(buildTestWidget(entries: []));
      await tester.pumpAndSettle();

      expect(find.text('No memories yet'), findsOneWidget);
      expect(
        find.text('Your memories will appear here\nas you capture them.'),
        findsOneWidget,
      );
    });

    testWidgets('filter chips are displayed', (tester) async {
      final entries = createTestEntries();
      await tester.pumpWidget(buildTestWidget(entries: entries));
      await tester.pumpAndSettle();

      // EntryType filter chips should be visible — they use the type names
      // from EntryType.values. Check for a few of the main types.
      expect(find.text('Line'), findsWidgets);
      expect(find.text('Photo'), findsWidgets);
      expect(find.text('Voice'), findsWidgets);
    });
  });
}
