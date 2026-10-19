// Manual benchmark: Dart-side cost of idle tree frames (paint + layer
// recording). Raster cost (e.g. blur glows) is not visible in flutter_test.
// Run with: flutter test test/benchmarks/tree_paint_benchmark.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/models/tree.dart';
import 'package:seedling/features/tree/presentation/animated_tree_visualization.dart';

void main() {
  for (final state in [TreeState.sapling, TreeState.ancientTree]) {
    testWidgets('idle frames: ${state.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              child: AnimatedTreeVisualization(state: state, progress: 0.5),
            ),
          ),
        ),
      );
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      const frames = 600;
      final sw = Stopwatch()..start();
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      sw.stop();
      debugPrint(
        '${state.name}: ${(sw.elapsedMicroseconds / frames).toStringAsFixed(0)}'
        'us per idle frame (pump incl. build/layout/paint)',
      );
    });
  }
}
