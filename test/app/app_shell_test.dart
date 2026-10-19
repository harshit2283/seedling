import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/app/app_lock_gate.dart';
import 'package:seedling/core/widgets/feedback/seedling_toast.dart';

void main() {
  Widget gate({required bool locked, VoidCallback? onSecretTap}) {
    return CupertinoApp(
      home: AppLockGate(
        locked: locked,
        isUnlocking: false,
        onUnlock: () {},
        child: Center(
          child: GestureDetector(
            onTap: onSecretTap,
            child: const Text('a private memory'),
          ),
        ),
      ),
    );
  }

  testWidgets('locked content is hidden from screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(gate(locked: true));

    expect(find.bySemanticsLabel('a private memory'), findsNothing);
    expect(find.text('Seedling is locked'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('locked content cannot be tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      gate(locked: true, onSecretTap: () => tapped = true),
    );
    await tester.tapAt(tester.getCenter(find.byType(AppLockGate)));
    expect(tapped, isFalse);
  });

  testWidgets('unlocked content is visible and keeps its state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(gate(locked: false));
    expect(find.bySemanticsLabel('a private memory'), findsOneWidget);
    expect(find.text('Seedling is locked'), findsNothing);
    semantics.dispose();
  });

  testWidgets('messages show without a Scaffold (iOS shell)', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => showSeedlingMessage(context, 'Mic denied'),
            child: const Text('trigger'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Mic denied'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Mic denied'), findsNothing);
  });
}
