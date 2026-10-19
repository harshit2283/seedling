import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/constants/prefs_keys.dart';
import 'package:seedling/core/platform/platform_utils.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/data/models/tree.dart';
import 'package:seedling/features/tree/presentation/tree_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDb extends Mock implements ObjectBoxDatabase {}

/// The home's add button floats over the page. Whatever the page holds,
/// scrolled to the end, its last item must sit fully above the button.
void main() {
  setUpAll(() => registerFallbackValue(Entry.line(text: '')));

  final now = DateTime.now();
  List<Entry> populated() => [
    for (var i = 0; i < 12; i++)
      Entry.line(text: 'A small thing worth keeping, number $i')
        ..id = i + 1
        ..createdAt = now.subtract(Duration(days: i, hours: 1)),
    // Old enough to be resurfaced.
    Entry.line(text: 'The flat with the yellow door')
      ..id = 99
      ..createdAt = DateTime(now.year - 1, now.month, now.day, 9),
  ];

  _MockDb dbWith(List<Entry> entries) {
    final db = _MockDb();
    final tree = Tree(year: now.year, entryCount: entries.length);
    when(() => db.watchEntries()).thenAnswer((_) => Stream.value(entries));
    when(() => db.watchAllEntries()).thenAnswer((_) => Stream.value(entries));
    when(
      () => db.watchCurrentTree(),
    ).thenAnswer((_) => Stream.value(entries.isEmpty ? null : tree));
    when(() => db.watchRituals()).thenAnswer((_) => Stream.value([]));
    when(() => db.getAllEntries()).thenReturn(entries);
    when(() => db.getAllCapsules()).thenReturn([]);
    when(() => db.getDeletedEntries()).thenReturn([]);
    when(() => db.getCapsulesToUnlockToday()).thenReturn([]);
    when(() => db.getAllTrees()).thenReturn([]);
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
    return db;
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    required List<Entry> entries,
    required bool calm,
    required Size size,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
    tester.view.viewPadding = const FakeViewPadding(top: 141, bottom: 102);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      PrefsKeys.calmModeEnabled: calm,
      PrefsKeys.onboardingCompleted: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const TreeScreen())],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(dbWith(entries)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final ios in [false, true]) {
    for (final size in const [Size(390, 844), Size(320, 568)]) {
      for (final scenario in ['first run', 'populated', 'calm']) {
        final name =
            '${ios ? 'iOS' : 'Android'} ${size.width.toInt()}w $scenario';
        testWidgets('$name: the add button never covers the last item', (
          tester,
        ) async {
          PlatformUtils.debugIsIOSOverride = ios;
          addTearDown(() => PlatformUtils.debugIsIOSOverride = null);
          await pumpHome(
            tester,
            entries: scenario == 'first run' ? const [] : populated(),
            calm: scenario == 'calm',
            size: size,
          );

          final position = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pump();

          final last = tester.getRect(
            find.byKey(const ValueKey('home-last-item')),
          );
          final button = tester.getRect(
            find.byKey(const ValueKey('home-add-memory')),
          );
          expect(
            last.bottom,
            lessThanOrEqualTo(button.top),
            reason: 'last item $last vs button $button',
          );
          expect(tester.takeException(), isNull);
          // Let the tree's ambient timers finish.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
  }

  testWidgets('the stage is said once, and calm mode drops it', (tester) async {
    await pumpHome(
      tester,
      entries: populated(),
      calm: false,
      size: const Size(390, 844),
    );
    expect(find.textContaining('Seed'), findsOneWidget);
    expect(find.text('Gentle prompt'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));

    await pumpHome(
      tester,
      entries: populated(),
      calm: true,
      size: const Size(390, 844),
    );
    expect(find.textContaining('Seed'), findsNothing);
    expect(find.textContaining('memories'), findsOneWidget); // "All memories"
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
