import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/providers.dart';

void main() {
  group('RecentlyInsertedEntryIdNotifier', () {
    test('initial state is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(recentlyInsertedEntryIdProvider), isNull);
    });

    test('mark() sets the id and exposes it via watch', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(recentlyInsertedEntryIdProvider.notifier).mark(42);

      expect(container.read(recentlyInsertedEntryIdProvider), 42);
    });

    test('mark() auto-clears after 1500ms', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(recentlyInsertedEntryIdProvider.notifier).mark(7);
        expect(container.read(recentlyInsertedEntryIdProvider), 7);

        async.elapse(const Duration(milliseconds: 1499));
        expect(container.read(recentlyInsertedEntryIdProvider), 7);

        async.elapse(const Duration(milliseconds: 2));
        expect(container.read(recentlyInsertedEntryIdProvider), isNull);
      });
    });

    test('a second mark() resets the timer and replaces the id', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(
          recentlyInsertedEntryIdProvider.notifier,
        );

        notifier.mark(1);
        async.elapse(const Duration(milliseconds: 1000));
        notifier.mark(2);
        // Old timer for id=1 should be cancelled.
        async.elapse(const Duration(milliseconds: 1000));
        expect(container.read(recentlyInsertedEntryIdProvider), 2);

        async.elapse(const Duration(milliseconds: 600));
        expect(container.read(recentlyInsertedEntryIdProvider), isNull);
      });
    });

    test('disposing the provider cancels the pending timer', () {
      fakeAsync((async) {
        final container = ProviderContainer();

        container.read(recentlyInsertedEntryIdProvider.notifier).mark(99);
        container.dispose();

        // No exception means the cancelled timer never fired into a disposed
        // notifier.
        async.elapse(const Duration(seconds: 5));
      });
    });
  });
}
