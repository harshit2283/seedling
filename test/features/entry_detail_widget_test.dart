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
import 'package:seedling/features/memories/presentation/entry_detail_screen.dart';

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
    registerFallbackValue(Entry.line(text: ''));
    registerFallbackValue(EntryType.line);
  });

  setUp(() async {
    mockDb = MockObjectBoxDatabase();
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
      () => mockRitualService.updateAfterEntry(any()),
    ).thenAnswer((_) async {});
  });

  /// Helper to create an entry with a given ID using factory constructors.
  Entry createTestEntry({
    int id = 1,
    EntryType type = EntryType.line,
    String? text,
    String? title,
  }) {
    final Entry entry;
    switch (type) {
      case EntryType.line:
        entry = Entry.line(text: text);
      case EntryType.photo:
        entry = Entry.photo(mediaPath: '', text: text);
      case EntryType.voice:
        entry = Entry.voice(mediaPath: '', text: text);
      case EntryType.object:
        entry = Entry.object(title: title ?? '', text: text);
      case EntryType.fragment:
        entry = Entry.fragment(text: text);
      case EntryType.ritual:
        entry = Entry.ritual(title: title ?? '', text: text);
      case EntryType.release:
        entry = Entry.release(text: text);
    }
    entry.id = id;
    if (title != null && type != EntryType.object && type != EntryType.ritual) {
      entry.title = title;
    }
    return entry;
  }

  /// Build a testable widget that provides the entry via the entries stream.
  Widget buildTestWidget(Entry entry) {
    // Override the entries stream so the detail screen can find the entry
    when(() => mockDb.watchEntries()).thenAnswer((_) => Stream.value([entry]));

    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        sharedPreferencesProvider.overrideWithValue(prefs),
        ritualServiceProvider.overrideWithValue(mockRitualService),
        syncEngineProvider.overrideWithValue(mockSyncEngine),
      ],
      child: MaterialApp(home: EntryDetailScreen(entryId: entry.id)),
    );
  }

  group('EntryDetailScreen', () {
    testWidgets('renders entry text content', (tester) async {
      final entry = createTestEntry(text: 'The sunset was remarkable today');

      await tester.pumpWidget(buildTestWidget(entry));
      await tester.pumpAndSettle();

      expect(find.text('The sunset was remarkable today'), findsOneWidget);
    });

    testWidgets('renders entry type name in app bar', (tester) async {
      final entry = createTestEntry(
        type: EntryType.line,
        text: 'A quiet thought',
      );

      await tester.pumpWidget(buildTestWidget(entry));
      await tester.pumpAndSettle();

      // The type name appears in both the AppBar title and the type badge
      expect(find.text('Line'), findsAtLeast(1));
    });

    testWidgets('shows not found state for missing entry', (tester) async {
      // Don't provide the entry in the stream
      when(
        () => mockDb.watchEntries(),
      ).thenAnswer((_) => Stream.value(<Entry>[]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(mockDb),
            sharedPreferencesProvider.overrideWithValue(prefs),
            ritualServiceProvider.overrideWithValue(mockRitualService),
            syncEngineProvider.overrideWithValue(mockSyncEngine),
          ],
          child: const MaterialApp(home: EntryDetailScreen(entryId: 999)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Memory not found'), findsOneWidget);
    });

    testWidgets('edit mode toggles on pencil tap', (tester) async {
      final entry = createTestEntry(text: 'Editable memory');

      await tester.pumpWidget(buildTestWidget(entry));
      await tester.pumpAndSettle();

      // On Android (test environment), the edit button is an IconButton
      // with Icons.edit_outlined
      final editButton = find.byIcon(Icons.edit_outlined);
      expect(editButton, findsOneWidget);

      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // After tapping edit, the app bar title should change to "Edit Line"
      expect(find.text('Edit Line'), findsOneWidget);

      // A TextField should appear for editing
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('delete triggers confirmation dialog', (tester) async {
      final entry = createTestEntry(text: 'Memory to delete');

      await tester.pumpWidget(buildTestWidget(entry));
      await tester.pumpAndSettle();

      // Find and tap the delete button (Icons.delete_outline on Android)
      final deleteButton = find.byIcon(Icons.delete_outline);
      expect(deleteButton, findsOneWidget);

      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // A confirmation dialog should appear with the expected text
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete Memory?'), findsOneWidget);
      expect(
        find.text(
          'This memory will be moved to trash and can be recovered within 30 days.',
        ),
        findsOneWidget,
      );
    });
  });
}
