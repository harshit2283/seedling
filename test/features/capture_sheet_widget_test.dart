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
    when(() => mockDb.saveEntry(any())).thenAnswer((invocation) async {
      final entry = invocation.positionalArguments[0] as Entry;
      entry.id = 1;
      return entry;
    });
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
        home: Scaffold(
          body: child ?? const QuickCaptureSheet(),
        ),
      ),
    );
  }

  group('QuickCaptureSheet', () {
    testWidgets('renders entry type buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // The default ordered types include Line, Photo, Voice, Fragment,
      // Object, Let Go, and Capsule. Verify the primary ones render.
      expect(find.text('Line'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Voice'), findsOneWidget);
      expect(find.text('Fragment'), findsOneWidget);
      expect(find.text('Object'), findsOneWidget);
      expect(find.text('Let Go'), findsOneWidget);
      expect(find.text('Capsule'), findsOneWidget);
    });

    testWidgets('text input accepts text', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // The text field should be present (TextField on non-iOS platforms)
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'A quiet morning');
      await tester.pump();

      // Verify the text was entered
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.controller?.text, 'A quiet morning');
    });

    testWidgets('save button becomes active when text is entered',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Before entering text, the save button label should exist but hint
      // should reflect the placeholder state.
      expect(find.text('SAVE MEMORY'), findsOneWidget);

      // Enter text to enable saving
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Something I noticed');
      await tester.pump();

      // After entering text, the hint should say "Ready to save this memory"
      expect(find.text('Ready to save this memory'), findsOneWidget);
    });

    testWidgets('selecting entry type changes mode', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially Line is selected — the text field should show the line hint
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      // Tap the Fragment button to switch type
      await tester.tap(find.text('Fragment'));
      await tester.pumpAndSettle();

      // The text field should still be present (Fragment uses text mode)
      // but the hint text should change
      final updatedTextField = tester.widget<TextField>(find.byType(TextField));
      expect(
        updatedTextField.decoration?.hintText,
        'A thought, incomplete is fine...',
      );
    });
  });
}
