import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/models/entry.dart';

/// Mirrors the filtering logic from ObjectBoxDatabase.getObjectEntries()
/// so we can unit-test without a live ObjectBox store.
List<Entry> filterObjectEntries(List<Entry> allEntries) {
  return allEntries
      .where((e) => e.type == EntryType.object && !e.isDeleted)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

void main() {
  group('Object Gallery filtering', () {
    test('only object entries are returned', () {
      final entries = [
        Entry.object(title: 'Grandma ring', mediaPath: '/path/ring.jpg'),
        Entry.line(text: 'A thought'),
        Entry.photo(mediaPath: '/path/photo.jpg'),
        Entry.object(title: 'Old watch', mediaPath: '/path/watch.jpg'),
        Entry.voice(mediaPath: '/path/voice.m4a'),
        Entry.fragment(text: 'half idea'),
      ];

      final result = filterObjectEntries(entries);

      expect(result, hasLength(2));
      expect(result[0].title, 'Old watch');
      expect(result[1].title, 'Grandma ring');
    });

    test('deleted object entries are excluded', () {
      final entries = [
        Entry.object(title: 'Visible object', mediaPath: '/path/a.jpg'),
        Entry.object(title: 'Deleted object', mediaPath: '/path/b.jpg')
          ..isDeleted = true
          ..deletedAt = DateTime(2026, 3, 1),
      ];

      final result = filterObjectEntries(entries);

      expect(result, hasLength(1));
      expect(result[0].title, 'Visible object');
    });

    test('entries sorted by date descending (newest first)', () {
      final entries = [
        Entry.object(title: 'Oldest', mediaPath: '/path/1.jpg')
          ..createdAt = DateTime(2024, 1, 1),
        Entry.object(title: 'Newest', mediaPath: '/path/3.jpg')
          ..createdAt = DateTime(2026, 3, 15),
        Entry.object(title: 'Middle', mediaPath: '/path/2.jpg')
          ..createdAt = DateTime(2025, 6, 10),
      ];

      final result = filterObjectEntries(entries);

      expect(result, hasLength(3));
      expect(result[0].title, 'Newest');
      expect(result[1].title, 'Middle');
      expect(result[2].title, 'Oldest');
    });

    test('returns empty when no object entries exist', () {
      final entries = [
        Entry.line(text: 'A thought'),
        Entry.photo(mediaPath: '/path/photo.jpg'),
        Entry.voice(mediaPath: '/path/voice.m4a'),
      ];

      final result = filterObjectEntries(entries);

      expect(result, isEmpty);
    });

    test('returns empty when all object entries are deleted', () {
      final entries = [
        Entry.object(title: 'Deleted 1', mediaPath: '/path/a.jpg')
          ..isDeleted = true,
        Entry.object(title: 'Deleted 2', mediaPath: '/path/b.jpg')
          ..isDeleted = true,
      ];

      final result = filterObjectEntries(entries);

      expect(result, isEmpty);
    });

    test('object entries without media are still included', () {
      final entries = [Entry.object(title: 'No photo object')];

      final result = filterObjectEntries(entries);

      expect(result, hasLength(1));
      expect(result[0].title, 'No photo object');
      expect(result[0].hasMedia, false);
    });

    test('object entries with text story are included', () {
      final entries = [
        Entry.object(
          title: 'Family heirloom',
          mediaPath: '/path/heirloom.jpg',
          text: 'This ring has been in the family for three generations.',
        ),
      ];

      final result = filterObjectEntries(entries);

      expect(result, hasLength(1));
      expect(result[0].title, 'Family heirloom');
      expect(result[0].hasText, true);
      expect(result[0].text, contains('three generations'));
    });
  });
}
