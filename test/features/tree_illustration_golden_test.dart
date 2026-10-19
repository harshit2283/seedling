// Golden regressions for the tree illustration. Inputs are pinned (seed,
// season, Reduce Motion) so renders are deterministic.
// Update with: flutter test --update-goldens test/features/tree_illustration_golden_test.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/core/models/season.dart';
import 'package:seedling/data/models/tree.dart';
import 'package:seedling/features/tree/presentation/animated_tree_visualization.dart';
import 'package:seedling/features/tree/presentation/painting/tree_blueprint.dart';

/// Tolerates tiny anti-aliasing differences between machines.
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  static const double _tolerance = 0.005;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

const _key = ValueKey('tree');

Widget _tree(TreeState state, Season season, {required bool dark}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? SeedlingTheme.dark : SeedlingTheme.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: _key,
              child: AnimatedTreeVisualization(
                state: state,
                progress: 0.5,
                season: season,
                seed: 2026,
                memoryLights: 3,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    final previous = goldenFileComparator;
    if (previous is LocalFileComparator) {
      goldenFileComparator = _TolerantComparator(
        Uri.parse('${previous.basedir}tree_illustration_golden_test.dart'),
      );
    }
  });
  setUp(debugClearTreeLayerCache);

  const cases = [
    (TreeState.sprout, Season.spring, false),
    (TreeState.youngTree, Season.winter, false),
    (TreeState.matureTree, Season.summer, false),
    (TreeState.ancientTree, Season.autumn, true),
  ];
  for (final (state, season, dark) in cases) {
    final name = '${state.name}_${season.name}_${dark ? 'dark' : 'light'}';
    testWidgets('tree illustration: $name', (tester) async {
      await tester.pumpWidget(_tree(state, season, dark: dark));
      await tester.pump();
      await expectLater(
        find.byKey(_key),
        matchesGoldenFile('goldens/tree_$name.png'),
      );
    });
  }

  test('the same seed always grows the same tree', () {
    final a = TreeBlueprint.forSeed(2031);
    final b = TreeBlueprint.forSeed(2031);
    expect(identical(a, b), isTrue);
    final poseA = a.pose(
      g: 4.5,
      base: const Offset(100, 180),
      maxHeight: 170,
      maxHalfWidth: 94,
    );
    final poseB = a.pose(
      g: 4.5,
      base: const Offset(100, 180),
      maxHeight: 170,
      maxHalfWidth: 94,
    );
    expect(poseA.foliageBounds, poseB.foliageBounds);
    expect(
      TreeBlueprint.forSeed(2032).limbs.length == a.limbs.length &&
          TreeBlueprint.forSeed(2032).limbs.first.angle == a.limbs.first.angle,
      isFalse,
      reason: 'different years grow different trees',
    );
  });

  test('growth adds to the tree: branches and leaves only accumulate', () {
    final blueprint = TreeBlueprint.forSeed(2026);
    var lastBranches = 0;
    var lastClusters = 0;
    for (var g = 2.0; g <= 6.0; g += 0.25) {
      final pose = blueprint.pose(
        g: g,
        base: const Offset(110, 190),
        maxHeight: 400,
        maxHalfWidth: 400,
      );
      expect(pose.branches.length, greaterThanOrEqualTo(lastBranches));
      expect(pose.clusters.length, greaterThanOrEqualTo(lastClusters));
      lastBranches = pose.branches.length;
      lastClusters = pose.clusters.length;
    }
  });

  test('every stage fits its canvas', () {
    const sizes = {2: 160.0, 3: 180.0, 4: 200.0, 5: 220.0};
    for (final seed in [2024, 2025, 2026, 2027, 2028]) {
      final blueprint = TreeBlueprint.forSeed(seed);
      for (final entry in sizes.entries) {
        for (final p in [0.0, 0.5, 0.999]) {
          final side = entry.value;
          final groundY = side * 0.87;
          final pose = blueprint.pose(
            g: entry.key + p,
            base: Offset(side / 2, groundY),
            maxHeight: groundY - 6,
            maxHalfWidth: side / 2 - 6,
          );
          final b = pose.foliageBounds;
          expect(b.top, greaterThanOrEqualTo(0), reason: 'seed $seed');
          expect(b.left, greaterThanOrEqualTo(0), reason: 'seed $seed');
          expect(b.right, lessThanOrEqualTo(side), reason: 'seed $seed');
        }
      }
    }
  });
}
