import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/providers.dart';

void main() {
  group('TreeGrowthNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is false', () {
      final state = container.read(treeGrowthEventProvider);
      expect(state, false);
    });

    test('triggerCelebration sets state to true', () {
      final notifier = container.read(treeGrowthEventProvider.notifier);

      expect(container.read(treeGrowthEventProvider), false);

      notifier.triggerCelebration();

      expect(container.read(treeGrowthEventProvider), true);
    });

    test('triggerCelebration auto-resets after delay', () async {
      final notifier = container.read(treeGrowthEventProvider.notifier);

      notifier.triggerCelebration();
      expect(container.read(treeGrowthEventProvider), true);

      // Wait for auto-reset (2 seconds + buffer)
      await Future.delayed(const Duration(milliseconds: 2200));

      expect(container.read(treeGrowthEventProvider), false);
    });

    test('multiple triggers work correctly', () async {
      final notifier = container.read(treeGrowthEventProvider.notifier);

      // First trigger
      notifier.triggerCelebration();
      expect(container.read(treeGrowthEventProvider), true);

      // Wait for reset
      await Future.delayed(const Duration(milliseconds: 2200));
      expect(container.read(treeGrowthEventProvider), false);

      // Second trigger should work
      notifier.triggerCelebration();
      expect(container.read(treeGrowthEventProvider), true);
    });
  });
}
