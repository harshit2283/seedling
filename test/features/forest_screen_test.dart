import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/models/tree.dart';
import 'package:seedling/features/tree/presentation/forest_screen.dart';
import 'package:seedling/features/tree/presentation/still_tree.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 10, 19);

  Tree tree(int year, int count) =>
      Tree(year: year, entryCount: count)..updateVisualState();

  Future<void> pump(WidgetTester tester, List<Tree> trees) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allTreesProvider.overrideWithValue(trees),
        ],
        child: MaterialApp(home: ForestScreen(now: now)),
      ),
    );
    await tester.pump();
  }

  void notchedPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
    tester.view.viewPadding = const FakeViewPadding(top: 141, bottom: 102);
    addTearDown(tester.view.reset);
  }

  setUp(StillTree.debugClearCache);

  testWidgets('the back button and title clear the status bar', (tester) async {
    notchedPhone(tester);
    await pump(tester, [tree(2026, 42), tree(2025, 120)]);

    // 141 physical px at 3x = 47pt of status bar / notch.
    final back = tester.getRect(find.byTooltip('Back'));
    expect(back.top, greaterThanOrEqualTo(47));
    final title = tester.getRect(find.text('Your forest'));
    expect(title.top, greaterThanOrEqualTo(47));
  });

  testWidgets('the list ends above the home indicator', (tester) async {
    notchedPhone(tester);
    await pump(tester, [
      tree(2026, 42),
      for (var y = 2025; y >= 2016; y--) tree(y, 40 + y % 7 * 30),
    ]);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
    await tester.pumpAndSettle();

    final lastTile = tester.getRect(find.text('2016 · Sapling'));
    // 102 physical px at 3x = 34pt of home indicator.
    expect(lastTile.bottom, lessThanOrEqualTo(844 - 34));
  });

  testWidgets('each year is its own tree, labelled and tappable', (
    tester,
  ) async {
    notchedPhone(tester);
    await pump(tester, [tree(2026, 42), tree(2025, 300), tree(2024, 5)]);

    expect(find.byType(StillTree), findsNWidgets(3));
    expect(find.text('2025 · Mature tree'), findsOneWidget);
    expect(find.text('2024 · Seed'), findsOneWidget);
    expect(find.text('This year'), findsOneWidget);
    expect(find.text('347 memories across 3 years'), findsOneWidget);
    expect(find.textContaining('leaves'), findsNothing);
    expect(find.textContaining('Archive'), findsNothing);
  });

  testWidgets('trees are painted once and reused across rebuilds', (
    tester,
  ) async {
    notchedPhone(tester);
    final trees = [tree(2026, 42), tree(2025, 300)];
    await pump(tester, trees);
    final first = StillTree.debugRenderCount;
    expect(first, 2);
    await pump(tester, trees);
    await tester.pump();
    expect(StillTree.debugRenderCount, first);
  });

  testWidgets('a first year gets a calm word, not an empty grid', (
    tester,
  ) async {
    notchedPhone(tester);
    await pump(tester, [tree(2026, 12)]);

    expect(find.text('Your forest starts here.'), findsOneWidget);
    expect(find.textContaining('When 2026 closes'), findsOneWidget);
    expect(find.text('Past years'), findsNothing);
  });
}
