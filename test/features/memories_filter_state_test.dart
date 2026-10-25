import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/datasources/local/seedling_database.dart';
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
          // No index: fall back to matching in memory.
          memorySearchMatchesProvider.overrideWith((ref, query) => null),
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

    test('search uses the full-text index of the database', () async {
      final db = await SeedlingDatabase.openForTesting();
      addTearDown(db.close);
      final cafe = await db.saveEntry(
        Entry.line(text: 'Breakfast at the Café'),
      );
      final other = await db.saveEntry(Entry.line(text: 'A walk at dusk'));
      final voice = await db.saveEntry(
        Entry.voice(mediaPath: 'voices/v.m4a')
          ..transcription = 'the cafe on the corner',
      );
      final entries = [cafe, other, voice];

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pagedEntriesProvider.overrideWith((ref) => entries),
          entriesProvider.overrideWith((ref) => entries),
        ],
      );
      addTearDown(container.dispose);

      // Accent-insensitive, and transcriptions count.
      container.read(memoriesFilterProvider.notifier).setSearchQuery('CAFE');
      expect(container.read(filteredEntriesProvider), [cafe, voice]);

      // Under three characters the in-memory match takes over.
      container.read(memoriesFilterProvider.notifier).setSearchQuery('du');
      expect(container.read(filteredEntriesProvider), [other]);
    });
  });
}
