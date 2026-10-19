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
import 'package:seedling/features/capture/presentation/quick_capture_sheet.dart';

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
    when(() => mockDb.saveEntry(any())).thenAnswer((invocation) async {
      final entry = invocation.positionalArguments[0] as Entry;
      entry.id = 1;
      return entry;
    });
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
    when(
      () => mockRitualService.updateAfterEntry(any()),
    ).thenAnswer((_) async {});
  });

  /// Build a testable widget with all required provider overrides.
  Widget buildTestWidget({Widget? child}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        sharedPreferencesProvider.overrideWithValue(prefs),
        ritualServiceProvider.overrideWithValue(mockRitualService),
        syncEngineProvider.overrideWithValue(mockSyncEngine),
      ],
      child: MaterialApp(
        home: Scaffold(body: child ?? const QuickCaptureSheet()),
      ),
    );
  }

  List<Entry> savedEntries() =>
      verify(() => mockDb.saveEntry(captureAny())).captured.cast<Entry>();

  group('QuickCaptureSheet', () {
    testWidgets('opens straight into a focused text field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode?.hasFocus, isTrue);
      expect(field.decoration?.hintText, 'What stayed with you?');
    });

    testWidgets('type chips are secondary; Line and Fragment are merged', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Attachments infer the type.
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Voice'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      // Deliberate modes stay reachable.
      expect(find.text('Let go'), findsOneWidget);
      expect(find.text('Ritual'), findsOneWidget);
      expect(find.text('Capsule'), findsOneWidget);
      // No up-front choice between Line and Fragment.
      expect(find.text('Line'), findsNothing);
      expect(find.text('Fragment'), findsNothing);
    });

    testWidgets('text input accepts text', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'A quiet morning');
      await tester.pump();

      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.controller?.text, 'A quiet morning');
    });

    testWidgets('save button becomes active when text is entered', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('SAVE MEMORY'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Something I noticed');
      await tester.pump();

      expect(find.text('Ready to save this memory'), findsOneWidget);
    });

    testWidgets('a full sentence saves as a line', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'The light on the kitchen table this morning',
      );
      await tester.pump();
      await tester.tap(find.text('SAVE MEMORY'));
      await tester.pumpAndSettle();

      final saved = savedEntries();
      expect(saved, hasLength(1));
      expect(saved.single.type, EntryType.line);
    });

    testWidgets('a very short line saves as a fragment', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'rain, again');
      await tester.pump();
      await tester.tap(find.text('SAVE MEMORY'));
      await tester.pumpAndSettle();

      expect(savedEntries().single.type, EntryType.fragment);
    });

    testWidgets('adding a title makes it an object', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'She wore it every Sunday',
      );
      await tester.tap(find.text('Title'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('capture-title')),
        "Grandma's ring",
      );
      await tester.pump();
      expect(find.text('Saving as an object'), findsOneWidget);

      await tester.tap(find.text('SAVE MEMORY'));
      await tester.pumpAndSettle();

      final entry = savedEntries().single;
      expect(entry.type, EntryType.object);
      expect(entry.title, "Grandma's ring");
      expect(entry.text, 'She wore it every Sunday');
    });

    testWidgets('Let go changes the hint and saves a release', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Let go'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('capture-text')),
      );
      expect(field.decoration?.hintText, 'What would you like to let go of?');

      await tester.enterText(
        find.byKey(const ValueKey('capture-text')),
        'The argument',
      );
      await tester.pump();
      await tester.tap(find.text('SAVE MEMORY'));
      await tester.pumpAndSettle();

      expect(savedEntries().single.type, EntryType.release);
    });

    testWidgets('Ritual needs a name and saves a ritual', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ritual'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('capture-title')), findsOneWidget);
      expect(find.text('Give the ritual a name'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('capture-title')),
        'Sunday pancakes',
      );
      await tester.pump();
      await tester.tap(find.text('SAVE MEMORY'));
      await tester.pumpAndSettle();

      final entry = savedEntries().single;
      expect(entry.type, EntryType.ritual);
      expect(entry.title, 'Sunday pancakes');
    });

    testWidgets('swipe-down saves the draft exactly once', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const QuickCaptureSheet(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('capture-text')),
        'Dismissing should keep this',
      );
      await tester.pump();

      // Dismiss the sheet (what a swipe down does).
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureSheet), findsNothing);
      final saved = savedEntries();
      expect(saved, hasLength(1));
      expect(saved.single.text, 'Dismissing should keep this');
    });
  });
}
