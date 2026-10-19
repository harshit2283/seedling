import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/features/capture/presentation/widgets/release_ceremony.dart';

void main() {
  Widget host({
    required Future<void> Function() onLetGo,
    bool reduceMotion = false,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showReleaseCeremony(
                  Navigator.of(context),
                  text: 'Old resentment',
                  onLetGo: onLetGo,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the words, then the choice', (tester) async {
    await tester.pumpWidget(host(onLetGo: () async {}));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('“Old resentment”'), findsOneWidget);
    // The choice waits for the leaves to drift.
    expect(find.text('Keep it in the tree'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Keep it in the tree'), findsOneWidget);
    expect(find.textContaining('no trash and no undo'), findsOneWidget);
  });

  testWidgets('keeping closes without deleting', (tester) async {
    var deleted = 0;
    await tester.pumpWidget(host(onLetGo: () async => deleted++));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep it in the tree'));
    await tester.pumpAndSettle();

    expect(deleted, 0);
    expect(find.byType(ReleaseCeremony), findsNothing);
  });

  testWidgets('letting go deletes only after the words drift away', (
    tester,
  ) async {
    var deleted = 0;
    await tester.pumpWidget(host(onLetGo: () async => deleted++));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Let it go completely'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(deleted, 0, reason: 'still drifting');

    await tester.pump(const Duration(milliseconds: 1400));
    expect(deleted, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("It's gone."), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseCeremony), findsNothing);
    expect(deleted, 1);
  });

  testWidgets('reduced motion still lets go, with a plain fade', (
    tester,
  ) async {
    var deleted = 0;
    await tester.pumpWidget(
      host(onLetGo: () async => deleted++, reduceMotion: true),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Let it go completely'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseCeremony), findsNothing);
  });
}
