import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/models/tree.dart';

void main() {
  group('Tree model', () {
    group('Factory constructor', () {
      test('Tree.currentYear creates tree for current year', () {
        final tree = Tree.currentYear();
        expect(tree.year, DateTime.now().year);
        expect(tree.entryCount, 0);
        expect(tree.state, TreeState.seed);
      });

      test('Tree defaults have correct initial state', () {
        final tree = Tree.currentYear();
        expect(tree.id, 0);
        expect(tree.stateIndex, TreeState.seed.index);
      });
    });

    group('State transitions', () {
      test('starts at seed state with 0 entries', () {
        final tree = Tree.currentYear();
        expect(tree.state, TreeState.seed);
        expect(tree.entryCount, 0);
      });

      test('remains seed at 10 entries', () {
        final tree = Tree.currentYear();
        tree.entryCount = 10;
        tree.updateVisualState();
        expect(tree.state, TreeState.seed);
      });

      test('transitions to sprout at 11 entries', () {
        final tree = Tree.currentYear();
        tree.entryCount = 10;
        tree.updateVisualState();
        expect(tree.state, TreeState.seed);

        tree.addEntry(); // 11th entry
        expect(tree.state, TreeState.sprout);
      });

      test('remains sprout at 30 entries', () {
        final tree = Tree.currentYear();
        tree.entryCount = 30;
        tree.updateVisualState();
        expect(tree.state, TreeState.sprout);
      });

      test('transitions to sapling at 31 entries', () {
        final tree = Tree.currentYear();
        tree.entryCount = 30;
        tree.updateVisualState();
        expect(tree.state, TreeState.sprout);

        tree.addEntry(); // 31st entry
        expect(tree.state, TreeState.sapling);
      });

      test('remains sapling at 100 entries', () {
        final tree = Tree.currentYear();
        tree.entryCount = 100;
        tree.updateVisualState();
        expect(tree.state, TreeState.sapling);
      });

      test('transitions to youngTree at 101 entries', () {
        final tree = Tree.currentYear();
        tree.entryCount = 100;
        tree.updateVisualState();
        expect(tree.state, TreeState.sapling);

        tree.addEntry(); // 101st entry
        expect(tree.state, TreeState.youngTree);
      });

      test('remains youngTree at 250 entries', () {
        final tree = Tree.currentYear();
        tree.entryCount = 250;
        tree.updateVisualState();
        expect(tree.state, TreeState.youngTree);
      });

      test('transitions to matureTree at 251 entries', () {
        final tree = Tree.currentYear();
        tree.entryCount = 250;
        tree.updateVisualState();
        expect(tree.state, TreeState.youngTree);

        tree.addEntry(); // 251st entry
        expect(tree.state, TreeState.matureTree);
      });

      test('remains matureTree at 500 entries', () {
        final tree = Tree.currentYear();
        tree.entryCount = 500;
        tree.updateVisualState();
        expect(tree.state, TreeState.matureTree);
      });

      test('transitions to ancientTree at 501 entries', () {
        final tree = Tree.currentYear();
        tree.entryCount = 500;
        tree.updateVisualState();
        expect(tree.state, TreeState.matureTree);

        tree.addEntry(); // 501st entry
        expect(tree.state, TreeState.ancientTree);
      });

      test('remains ancientTree above 501 entries', () {
        final tree = Tree.currentYear();
        tree.entryCount = 1000;
        tree.updateVisualState();
        expect(tree.state, TreeState.ancientTree);
      });
    });

    group('Progress calculation', () {
      test('progress is 0 at start of stage', () {
        final tree = Tree.currentYear();
        tree.entryCount = 0;
        tree.updateVisualState();
        expect(tree.progressToNextStage, closeTo(0.0, 0.01));
      });

      test('progress at 5/11 for seed stage', () {
        final tree = Tree.currentYear();
        tree.entryCount = 5;
        tree.updateVisualState();
        // 5 / 11 ≈ 0.45
        expect(tree.progressToNextStage, closeTo(0.45, 0.05));
      });

      test('progress resets at stage boundary', () {
        final tree = Tree.currentYear();
        tree.entryCount = 11;
        tree.updateVisualState();
        // Now in sprout, progress toward sapling (31)
        // 0 / 20 = 0.0
        expect(tree.progressToNextStage, closeTo(0.0, 0.01));
      });

      test('progress at ancient tree is 1.0 (maxed)', () {
        final tree = Tree.currentYear();
        tree.entryCount = 600;
        tree.updateVisualState();
        // Ancient tree has no next stage, progress should be 1.0
        expect(tree.progressToNextStage, closeTo(1.0, 0.01));
      });

      test('progress mid-way through sprout stage', () {
        final tree = Tree.currentYear();
        tree.entryCount = 21; // 10 into sprout (11-31 range, 20 total)
        tree.updateVisualState();
        // 10 / 20 = 0.5
        expect(tree.progressToNextStage, closeTo(0.5, 0.05));
      });
    });

    group('addEntry', () {
      test('increments entry count', () {
        final tree = Tree.currentYear();
        expect(tree.entryCount, 0);

        tree.addEntry();
        expect(tree.entryCount, 1);

        tree.addEntry();
        expect(tree.entryCount, 2);
      });

      test('updates visual state after adding entry', () {
        final tree = Tree.currentYear();
        tree.entryCount = 10;
        tree.updateVisualState();
        expect(tree.state, TreeState.seed);

        tree.addEntry();
        expect(tree.state, TreeState.sprout);
      });
    });

    group('state getter and setter', () {
      test('state getter returns correct enum', () {
        final tree = Tree.currentYear();
        tree.stateIndex = TreeState.sapling.index;
        expect(tree.state, TreeState.sapling);
      });

      test('state setter updates stateIndex', () {
        final tree = Tree.currentYear();
        tree.state = TreeState.matureTree;
        expect(tree.stateIndex, TreeState.matureTree.index);
      });
    });

    group('stateDescription', () {
      test('returns non-empty description for each state', () {
        final tree = Tree.currentYear();

        for (final state in TreeState.values) {
          tree.state = state;
          expect(tree.stateDescription.isNotEmpty, true);
          expect(tree.stateDescription.length, greaterThan(5));
        }
      });

      test('returns unique description for each state', () {
        final tree = Tree.currentYear();
        final descriptions = <String>{};

        for (final state in TreeState.values) {
          tree.state = state;
          descriptions.add(tree.stateDescription);
        }

        expect(descriptions.length, TreeState.values.length);
      });

      test('seed description mentions seed', () {
        final tree = Tree.currentYear();
        tree.state = TreeState.seed;
        expect(tree.stateDescription.toLowerCase(), contains('seed'));
      });

      test('ancient tree description mentions roots or stories', () {
        final tree = Tree.currentYear();
        tree.state = TreeState.ancientTree;
        final desc = tree.stateDescription.toLowerCase();
        expect(desc.contains('root') || desc.contains('stori'), true);
      });
    });

    group('TreeState enum', () {
      test('all tree states have unique indices', () {
        final indices = TreeState.values.map((e) => e.index).toSet();
        expect(indices.length, TreeState.values.length);
      });

      test('tree states are in expected order', () {
        expect(TreeState.seed.index, 0);
        expect(TreeState.sprout.index, 1);
        expect(TreeState.sapling.index, 2);
        expect(TreeState.youngTree.index, 3);
        expect(TreeState.matureTree.index, 4);
        expect(TreeState.ancientTree.index, 5);
      });
    });

    group('Boundary conditions', () {
      test('exact boundary at seed/sprout (10/11)', () {
        final tree = Tree.currentYear();

        tree.entryCount = 10;
        tree.updateVisualState();
        expect(tree.state, TreeState.seed);

        tree.entryCount = 11;
        tree.updateVisualState();
        expect(tree.state, TreeState.sprout);
      });

      test('exact boundary at sprout/sapling (30/31)', () {
        final tree = Tree.currentYear();

        tree.entryCount = 30;
        tree.updateVisualState();
        expect(tree.state, TreeState.sprout);

        tree.entryCount = 31;
        tree.updateVisualState();
        expect(tree.state, TreeState.sapling);
      });

      test('exact boundary at sapling/youngTree (100/101)', () {
        final tree = Tree.currentYear();

        tree.entryCount = 100;
        tree.updateVisualState();
        expect(tree.state, TreeState.sapling);

        tree.entryCount = 101;
        tree.updateVisualState();
        expect(tree.state, TreeState.youngTree);
      });

      test('exact boundary at youngTree/matureTree (250/251)', () {
        final tree = Tree.currentYear();

        tree.entryCount = 250;
        tree.updateVisualState();
        expect(tree.state, TreeState.youngTree);

        tree.entryCount = 251;
        tree.updateVisualState();
        expect(tree.state, TreeState.matureTree);
      });

      test('exact boundary at matureTree/ancientTree (500/501)', () {
        final tree = Tree.currentYear();

        tree.entryCount = 500;
        tree.updateVisualState();
        expect(tree.state, TreeState.matureTree);

        tree.entryCount = 501;
        tree.updateVisualState();
        expect(tree.state, TreeState.ancientTree);
      });
    });
  });
}
