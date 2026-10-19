import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/memories/presentation/memories_filter_state.dart';

void main() {
  group('filteredEntriesProvider', () {
    test('excludes capsule entries from default memories feed', () {
      final normal = Entry.line(text: 'A regular memory');
      final capsule = Entry.line(text: 'Future memory')
        ..capsuleUnlockDate = DateTime.now().add(const Duration(days: 30));

      final container = ProviderContainer(
        overrides: [
          pagedEntriesProvider.overrideWith((ref) => [normal, capsule]),
          entriesProvider.overrideWith((ref) => [normal, capsule]),
        ],
      );
      addTearDown(container.dispose);

      final filtered = container.read(filteredEntriesProvider);
      expect(filtered.length, 1);
      expect(filtered.first.text, 'A regular memory');
      expect(filtered.first.isCapsule, false);
    });

    test('keeps capsule entries hidden even when filters are active', () {
      final normal = Entry.line(text: 'Garden walk');
      final capsule = Entry.line(text: 'Capsule about garden')
        ..capsuleUnlockDate = DateTime.now().add(const Duration(days: 5));

      final container = ProviderContainer(
        overrides: [
          pagedEntriesProvider.overrideWith((ref) => [normal, capsule]),
          entriesProvider.overrideWith((ref) => [normal, capsule]),
        ],
      );
      addTearDown(container.dispose);

      container.read(memoriesFilterProvider.notifier).setSearchQuery('garden');

      final filtered = container.read(filteredEntriesProvider);
      expect(filtered.length, 1);
      expect(filtered.first.isCapsule, false);
      expect(filtered.first.text, 'Garden walk');
    });

    test('the Line filter also matches fragments; no Fragment chip', () {
      final line = Entry.line(text: 'A long walk by the river at dusk');
      final fragment = Entry.fragment(text: 'rain');
      final photo = Entry.photo(mediaPath: '/p.jpg');

      final container = ProviderContainer(
        overrides: [
          pagedEntriesProvider.overrideWith((ref) => [line, fragment, photo]),
          entriesProvider.overrideWith((ref) => [line, fragment, photo]),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(memoriesFilterProvider.notifier)
          .toggleTypeFilter(EntryType.line);

      final filtered = container.read(filteredEntriesProvider);
      expect(filtered, containsAll([line, fragment]));
      expect(filtered, isNot(contains(photo)));
      expect(filterableEntryTypes, isNot(contains(EntryType.fragment)));
      expect(filterableEntryTypes, contains(EntryType.line));
    });
  });
}
