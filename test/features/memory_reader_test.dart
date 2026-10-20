import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/memories/presentation/memory_reader_screen.dart';

final _longText = List.filled(
  14,
  'The kettle ticked as it cooled and the light came in sideways across the '
  'table, catching the steam, and for a minute nobody said anything.',
).join(' ');

Widget _reader(List<Entry> entries, {int initial = 0, bool reduce = false}) {
  return MaterialApp(
    theme: SeedlingTheme.light,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        disableAnimations: reduce,
      ),
      child: MemoryReaderScreen(
        args: MemoryReaderArgs(entries: entries, initialIndex: initial),
      ),
    ),
  );
}

void main() {
  testWidgets('long text scrolls within its page and hints at more', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final entries = [
      Entry.line(text: 'First light')..id = 1,
      Entry.line(text: _longText)..id = 2,
    ];
    await tester.pumpWidget(_reader(entries, initial: 1));
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(ReaderPageScroll),
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(find.bySemanticsLabel('More of this memory below'), findsOneWidget);

    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));

    // Reaching the end clears the "more" hint.
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final hint = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('reader-more-hint')),
    );
    expect(hint.opacity, 0);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('shows position as "2 of 3" and edge hints both ways', (
    tester,
  ) async {
    final entries = [
      Entry.line(text: 'One')..id = 1,
      Entry.line(text: 'Two')..id = 2,
      Entry.line(text: 'Three')..id = 3,
    ];
    await tester.pumpWidget(_reader(entries, initial: 1));
    await tester.pump();

    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.byType(ReaderProgressLine), findsOneWidget);
    expect(find.bySemanticsLabel('Previous memory'), findsOneWidget);
    expect(find.bySemanticsLabel('Next memory'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Next memory'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Next memory'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('with Reduce Motion, turning a page is instant', (tester) async {
    final entries = [
      Entry.line(text: 'One')..id = 1,
      Entry.line(text: 'Two')..id = 2,
    ];
    await tester.pumpWidget(_reader(entries, reduce: true));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Next memory'));
    await tester.pump();
    expect(find.text('2 of 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
