import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

  testWidgets('nothing behind the lock can take focus or the keyboard', (
    tester,
  ) async {
    // A capture sheet opened behind the lock (cold start from the home
    // widget) autofocuses its text field.
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    Widget app({required bool locked}) => MaterialApp(
      home: AppLockGate(
        locked: locked,
        isUnlocking: false,
        onUnlock: () {},
        child: Scaffold(body: TextField(focusNode: focusNode, autofocus: true)),
      ),
    );

    await tester.pumpWidget(app(locked: true));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);

    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);

    await tester.pumpWidget(app(locked: false));
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
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
