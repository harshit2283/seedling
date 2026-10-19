import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/models/tree.dart';
import 'package:seedling/features/tree/presentation/animated_tree_visualization.dart';

Widget _tree(TreeState state) => MaterialApp(
  home: Scaffold(
    body: Center(child: AnimatedTreeVisualization(state: state, progress: 0.5)),
  ),
);

/// Idle sway must replay cached layers: recording the tree (paths, blur
/// glows) once per state, not once per frame.
void main() {
  setUp(debugClearTreeLayerCache);

  for (final state in TreeState.values) {
    testWidgets('${state.name}: 120 idle frames record the tree once', (
      tester,
    ) async {
      await tester.pumpWidget(_tree(state));
      final before = debugTreeLayerBuilds;
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(debugTreeLayerBuilds - before, 0, reason: 'cache reused');
      expect(debugTreeLayerBuilds, greaterThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('growth draws live, then settles on one new cached layer', (
    tester,
  ) async {
    await tester.pumpWidget(_tree(TreeState.sapling));
    await tester.pump(const Duration(milliseconds: 16));
    final settled = debugTreeLayerBuilds;

    await tester.pumpWidget(_tree(TreeState.youngTree));
    // Mid-transition frames draw directly (state value changes each frame).
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Let the growth animation and celebration finish, then idle.
    await tester.pump(const Duration(seconds: 3));
    final afterGrowth = debugTreeLayerBuilds;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(afterGrowth - settled, 1, reason: 'one build for the new state');
    expect(debugTreeLayerBuilds, afterGrowth);
    expect(tester.takeException(), isNull);
  });
}
