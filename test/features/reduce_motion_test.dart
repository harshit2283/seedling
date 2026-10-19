import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/data/models/tree.dart';
import 'package:seedling/features/capsules/presentation/widgets/capsule_unlock_animation.dart';
import 'package:seedling/features/tree/presentation/animated_tree_visualization.dart';

Widget _host(Widget child, {required bool reduceMotion}) {
  return MaterialApp(
    theme: SeedlingTheme.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  group('AnimatedTreeVisualization', () {
    testWidgets('sways continuously by default', (tester) async {
      await tester.pumpWidget(
        _host(
          const AnimatedTreeVisualization(
            state: TreeState.sapling,
            progress: 0.4,
          ),
          reduceMotion: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('Reduce Motion stops the sway controller', (tester) async {
      await tester.pumpWidget(
        _host(
          const AnimatedTreeVisualization(
            state: TreeState.sapling,
            progress: 0.4,
          ),
          reduceMotion: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // No ticker is running, so nothing asks for another frame.
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('Reduce Motion growth and celebration settle immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const AnimatedTreeVisualization(
            state: TreeState.sprout,
            progress: 0.9,
          ),
          reduceMotion: true,
        ),
      );
      await tester.pumpWidget(
        _host(
          const AnimatedTreeVisualization(
            state: TreeState.sapling,
            progress: 0.0,
            celebrateGrowth: true,
          ),
          reduceMotion: true,
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('CapsuleUnlockAnimation', () {
    testWidgets('Reduce Motion crossfades without shake or sparkles', (
      tester,
    ) async {
      var completed = false;
      await tester.pumpWidget(
        _host(
          CapsuleUnlockAnimation(
            onComplete: () => completed = true,
            child: const Text('A note from last spring'),
          ),
          reduceMotion: true,
        ),
      );
      // Haptic pattern (~220ms) + a 200ms beat before the reveal starts.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('A note from last spring'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      expect(find.byIcon(Icons.lock_open), findsNothing);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(completed, isTrue);
    });
  });
}
