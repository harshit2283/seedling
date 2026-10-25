import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seedling/core/platform/platform_utils.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/core/services/ritual/ritual_service.dart';
import 'package:seedling/core/services/sync/sync_engine.dart';
import 'package:seedling/data/datasources/local/seedling_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/memories/presentation/entry_detail_screen.dart';
import 'package:seedling/features/memories/presentation/widgets/keepsake_memory_card.dart';

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
    when(
      () => mockDb.watchAllEntries(),
    ).thenAnswer((_) => Stream.value([entry]));
    when(() => mockDb.getEntry(entry.id)).thenReturn(entry);

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

    testWidgets('leads with the date, never the type name', (tester) async {
      final entry = createTestEntry(
        type: EntryType.line,
        text: 'A quiet thought',
      )..createdAt = DateTime(2024, 10, 12, 9, 30);

      await tester.pumpWidget(buildTestWidget(entry));
      await tester.pumpAndSettle();

      expect(find.text('Saturday, 12\u00A0October\u00A02024'), findsOneWidget);
      expect(find.text('Line'), findsNothing);
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

      // After tapping edit, the bar says so
      expect(find.text('Editing'), findsOneWidget);

      // A TextField should appear for editing
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('edit and delete buttons have tooltips', (tester) async {
      final entry = createTestEntry(text: 'Labelled controls');

      await tester.pumpWidget(buildTestWidget(entry));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Edit memory'), findsOneWidget);
      expect(find.byTooltip('Delete memory'), findsOneWidget);
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

    group('top bar over scrolling words', () {
      String longText() => List.filled(
        40,
        'The light on the kitchen floor this morning was soft and long.',
      ).join(' ');

      Future<void> scrollBy(WidgetTester tester, double dy) async {
        await tester.drag(find.byType(Scrollable).first, Offset(0, -dy));
        await tester.pumpAndSettle();
      }

      testWidgets('Android: clear at rest, filled once words go under', (
        tester,
      ) async {
        final entry = createTestEntry(text: longText());
        await tester.pumpWidget(buildTestWidget(entry));
        await tester.pumpAndSettle();
        Color bar() =>
            tester.widget<AppBar>(find.byType(AppBar)).backgroundColor!;
        expect(bar().a, 0);

        // Previously the bar stayed clear for the first 72px of scroll, so
        // the share/edit/delete icons sat right on top of the text.
        await scrollBy(tester, 30);
        expect(bar().a, greaterThan(0.9));
      });

      testWidgets('iOS: translucent palette fill once words go under', (
        tester,
      ) async {
        PlatformUtils.debugIsIOSOverride = true;
        addTearDown(() => PlatformUtils.debugIsIOSOverride = null);
        final entry = createTestEntry(text: longText());
        await tester.pumpWidget(buildTestWidget(entry));
        await tester.pumpAndSettle();
        Color bar() => tester
            .widget<CupertinoNavigationBar>(find.byType(CupertinoNavigationBar))
            .backgroundColor!;
        expect(bar().a, 0);

        await scrollBy(tester, 30);
        expect(bar().a, greaterThan(0.8));
        expect(bar().a, lessThan(1.0), reason: 'blurred, not opaque');
      });
    });

    testWidgets('no overflow at 320pt with text scale 1.6', (tester) async {
      tester.view.physicalSize = const Size(640, 1688);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final entry = createTestEntry(
        type: EntryType.object,
        title: "Grandma's ring",
        text: 'She wore it every day.',
      );
      await tester.pumpWidget(buildTestWidget(entry));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Link a memory'), 200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('keepsake rows grow with large text (no bottom overflow)', (
    tester,
  ) async {
    final entries = [
      for (var i = 0; i < 3; i++)
        Entry.photo(mediaPath: '/nowhere/photos/$i.jpg', text: 'Photo $i')
          ..id = i + 1,
    ];
    for (final scale in [1.0, 1.6, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Column(
                children: [KeepsakeMemoryRow(entries: entries, onOpen: (_) {})],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'scale $scale');
    }
  });
}
