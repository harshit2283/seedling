import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/providers.dart';

void main() {
  group('TreeGrowthNotifier disposal lifecycle', () {
    test('disposing container before reset delay does not throw', () async {
      final container = ProviderContainer();

      final notifier = container.read(treeGrowthEventProvider.notifier);
      notifier.triggerCelebration();
      expect(container.read(treeGrowthEventProvider), true);

      // Dispose immediately — the 2-second delayed future is still pending
      container.dispose();

      // Wait for the delayed future to fire (it should be a no-op)
      await Future.delayed(const Duration(milliseconds: 2500));

      // If we get here without an exception, the _disposed flag worked
    });

    test('rapid trigger then dispose does not throw', () async {
      final container = ProviderContainer();

      final notifier = container.read(treeGrowthEventProvider.notifier);

      // Trigger multiple times rapidly
      notifier.triggerCelebration();
      notifier.triggerCelebration();
      notifier.triggerCelebration();

      // Dispose while multiple delayed futures are pending
      container.dispose();

      // Wait for all delayed futures to fire
      await Future.delayed(const Duration(milliseconds: 2500));

      // No exception means the _disposed guard is working
    });

    test('rebuild after invalidation resets _disposed flag', () async {
      final container = ProviderContainer();

      final notifier = container.read(treeGrowthEventProvider.notifier);
      notifier.triggerCelebration();
      expect(container.read(treeGrowthEventProvider), true);

      // Invalidate the provider — triggers rebuild, which resets _disposed
      container.invalidate(treeGrowthEventProvider);

      // State should be reset to false (initial value from build())
      expect(container.read(treeGrowthEventProvider), false);

      // Trigger again — should work normally
      container.read(treeGrowthEventProvider.notifier).triggerCelebration();
      expect(container.read(treeGrowthEventProvider), true);

      // Wait for auto-reset
      await Future.delayed(const Duration(milliseconds: 2200));
      expect(container.read(treeGrowthEventProvider), false);

      container.dispose();
    });
  });
}
