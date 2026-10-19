import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

/// Loads Roboto from the Flutter SDK's cache, next to the test runner.
Future<void> _loadRoboto() async {
  final engineDir = File(Platform.resolvedExecutable).parent;
  final fonts = Directory('${engineDir.parent.parent.path}/material_fonts');
  // Android's system font, also standing in for the Cupertino family that
  // falls back to it on Android.
  for (final family in ['Roboto', 'CupertinoSystemText']) {
    final loader = FontLoader(family);
    for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      final file = File('${fonts.path}/$name');
      if (!file.existsSync()) continue;
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    await loader.load();
  }
}

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
      // Deliberate modes stay reachable, one tap away under "More".
      expect(find.text('Let go'), findsNothing);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
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

      expect(find.text('Save memory'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Something I noticed');
      await tester.pump();

      expect(find.text('Ready to save'), findsOneWidget);
    });

    testWidgets('at 320pt wide every control fits and the hint is one line', (
      tester,
    ) async {
      // Measure with the real Roboto from the Flutter SDK (the default test
      // font draws every glyph a full em wide).
      await tester.runAsync(_loadRoboto);
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      const screen = Rect.fromLTWH(0, 0, 320, 568);
      for (final label in [
        'Photo',
        'Voice',
        'Title',
        'More',
        'Let go',
        'Ritual',
        'Capsule',
      ]) {
        final rect = tester.getRect(find.text(label));
        expect(
          screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
          isTrue,
          reason: '$label at $rect',
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(100) - 0.5),
          reason: '$label is cut off',
        );
      }
      final hint = tester.getSize(find.text('Swipe down to save'));
      expect(hint.height, lessThan(24), reason: 'one line');
      final hintParagraph = tester.renderObject<RenderParagraph>(
        find.text('Swipe down to save'),
      );
      expect(
        hintParagraph.size.width,
        greaterThanOrEqualTo(hintParagraph.getMaxIntrinsicWidth(100) - 0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long intention never cuts the hint mid-word', (
      tester,
    ) async {
      await prefs.setString(
        'capture_intention',
        'When I sit down on the train home after a long day at the office',
      );
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('capture-text')),
      );
      final hint = field.decoration!.hintText!;
      expect(
        hint,
        anyOf(
          'When I sit down on the train home after a long day at the office…',
          'What stayed with you?',
        ),
      );
    });

    testWidgets('the when line backdates the saved memory', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('capture-text')),
        'The first frost on the car',
      );
      await tester.pump();
      expect(find.textContaining('Today, '), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('capture-when')));
      await tester.pumpAndSettle();
      // Go back a month and pick its 1st, then keep the suggested time.
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').first);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final expected = DateTime(now.year, now.month - 1, 1);
      expect(find.textContaining('Today, '), findsNothing);

      await tester.tap(find.text('Save memory'));
      await tester.pumpAndSettle();
      final saved = savedEntries().single;
      expect(saved.createdAt.year, expected.year);
      expect(saved.createdAt.month, expected.month);
      expect(saved.createdAt.day, 1);
      expect(saved.text, 'The first frost on the car');
    });

    testWidgets('a full sentence saves as a line', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'The light on the kitchen table this morning',
      );
      await tester.pump();
      await tester.tap(find.text('Save memory'));
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
      await tester.tap(find.text('Save memory'));
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

      await tester.tap(find.text('Save memory'));
      await tester.pumpAndSettle();

      final entry = savedEntries().single;
      expect(entry.type, EntryType.object);
      expect(entry.title, "Grandma's ring");
      expect(entry.text, 'She wore it every Sunday');
    });

    testWidgets('Let go changes the hint and saves a release', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('More'));
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
      await tester.tap(find.text('Save memory'));
      await tester.pumpAndSettle();

      expect(savedEntries().single.type, EntryType.release);
    });

    testWidgets('Ritual needs a name and saves a ritual', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ritual'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('capture-title')), findsOneWidget);
      expect(find.text('Name the ritual'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('capture-title')),
        'Sunday pancakes',
      );
      await tester.pump();
      await tester.tap(find.text('Save memory'));
      await tester.pumpAndSettle();

      final entry = savedEntries().single;
      expect(entry.type, EntryType.ritual);
      expect(entry.title, 'Sunday pancakes');
    });

    Widget launcher() => buildTestWidget(
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
    );

    Future<void> saveRelease(WidgetTester tester) async {
      await tester.pumpWidget(launcher());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Let go'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('capture-text')),
        'The grudge I carried all summer',
      );
      await tester.pump();
      await tester.tap(find.text('Save memory'));
      await tester.pumpAndSettle();
    }

    testWidgets('a saved release offers the ceremony; keeping is default', (
      tester,
    ) async {
      await saveRelease(tester);

      expect(find.byType(QuickCaptureSheet), findsNothing);
      expect(find.text('Keep it in the tree'), findsOneWidget);
      expect(find.text('Let it go completely'), findsOneWidget);

      await tester.tap(find.text('Keep it in the tree'));
      await tester.pumpAndSettle();

      expect(find.text('Keep it in the tree'), findsNothing);
      verifyNever(() => mockDb.deleteEntry(any()));
    });

    testWidgets('letting go completely hard-deletes the entry', (tester) async {
      final stored = <int, Entry>{};
      when(() => mockDb.saveEntry(any())).thenAnswer((invocation) async {
        final entry = invocation.positionalArguments[0] as Entry;
        entry.id = 41;
        stored[entry.id] = entry;
        return entry;
      });
      when(
        () => mockDb.getEntry(any()),
      ).thenAnswer((inv) => stored[inv.positionalArguments.first as int]);
      when(() => mockDb.deleteEntry(any())).thenAnswer((inv) async {
        return stored.remove(inv.positionalArguments.first as int) != null;
      });

      await saveRelease(tester);
      await tester.tap(find.text('Let it go completely'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      verify(() => mockDb.deleteEntry(41)).called(1);
      verifyNever(() => mockDb.softDeleteEntry(any()));
      expect(stored, isEmpty);
      // The ceremony closes on its own after a quiet beat.
      expect(find.text("It's gone."), findsNothing);
      expect(find.text('Let it go completely'), findsNothing);
    });

    Future<void> openWith(
      WidgetTester tester,
      void Function(BuildContext) open,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a real swipe down on the sheet saves the draft exactly once', (
      tester,
    ) async {
      await openWith(tester, (context) => showQuickCaptureSheet(context));
      await tester.enterText(
        find.byKey(const ValueKey('capture-text')),
        'Dismissing should keep this',
      );
      await tester.pump();

      await tester.fling(
        find.byType(QuickCaptureSheet),
        const Offset(0, 500),
        2000,
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureSheet), findsNothing);
      final saved = savedEntries();
      expect(saved, hasLength(1));
      expect(saved.single.text, 'Dismissing should keep this');
    });

    testWidgets('a swipe down from the drag handle saves too', (tester) async {
      await openWith(tester, (context) => showQuickCaptureSheet(context));
      await tester.enterText(
        find.byKey(const ValueKey('capture-text')),
        'Grabbed by the handle',
      );
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('capture-drag-handle')),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureSheet), findsNothing);
      expect(savedEntries().single.text, 'Grabbed by the handle');
    });

    testWidgets('a swipe down on the iOS popup route saves too', (
      tester,
    ) async {
      await openWith(
        tester,
        (context) => showCupertinoModalPopup<void>(
          context: context,
          // The host is not iOS, so the sheet builds Material fields.
          builder: (_) => const Material(child: QuickCaptureSheet()),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('capture-text')),
        'Kept on the other platform',
      );
      await tester.pump();

      await tester.fling(
        find.byType(QuickCaptureSheet),
        const Offset(0, 500),
        2000,
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureSheet), findsNothing);
      expect(savedEntries().single.text, 'Kept on the other platform');
    });

    testWidgets('a small drag springs back and saves nothing', (tester) async {
      await openWith(tester, (context) => showQuickCaptureSheet(context));
      await tester.enterText(
        find.byKey(const ValueKey('capture-text')),
        'Still writing this one',
      );
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('capture-drag-handle')),
        const Offset(0, 30),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureSheet), findsOneWidget);
      verifyNever(() => mockDb.saveEntry(any()));
    });

    testWidgets('swiping an empty sheet away saves nothing', (tester) async {
      await openWith(tester, (context) => showQuickCaptureSheet(context));

      await tester.fling(
        find.byType(QuickCaptureSheet),
        const Offset(0, 500),
        2000,
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureSheet), findsNothing);
      verifyNever(() => mockDb.saveEntry(any()));
    });

    testWidgets('back / barrier dismiss saves the draft exactly once', (
      tester,
    ) async {
      await openWith(tester, (context) => showQuickCaptureSheet(context));
      await tester.enterText(
        find.byKey(const ValueKey('capture-text')),
        'Closed with the back button',
      );
      await tester.pump();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.maybePop();
      await tester.pump();
      navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureSheet), findsNothing);
      expect(savedEntries(), hasLength(1));
    });

    testWidgets('a failure after the entry is written does not duplicate it', (
      tester,
    ) async {
      when(
        () => mockRitualService.updateAfterEntry(any()),
      ).thenThrow(StateError('ritual db'));
      await openWith(tester, (context) => showQuickCaptureSheet(context));
      await tester.enterText(
        find.byKey(const ValueKey('capture-text')),
        'A long enough sentence here',
      );
      await tester.pump();

      await tester.tap(find.text('Save memory'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not save'), findsNothing);
      expect(find.byType(QuickCaptureSheet), findsNothing);
      expect(savedEntries(), hasLength(1));
    });
  });
}
