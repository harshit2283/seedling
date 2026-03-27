import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/models/entry.dart';

/// Mirrors the filtering logic from ObjectBoxDatabase.getEntriesOnThisDay()
/// so we can unit-test without a live ObjectBox store.
List<Entry> filterOnThisDay(List<Entry> allEntries, DateTime today) {
  final currentYear = today.year;
  return allEntries.where((entry) {
    if (entry.isDeleted) return false;
    if (entry.createdAt.year == currentYear) return false;
    if (entry.isLocked) return false;
    return entry.createdAt.month == today.month &&
        entry.createdAt.day == today.day;
  }).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

void main() {
  group('On This Day filtering', () {
    final today = DateTime(2026, 3, 27);

    test('includes entries matching today month/day from previous years', () {
      final entries = [
        Entry.line(text: 'Last year')
          ..createdAt = DateTime(2025, 3, 27),
        Entry.line(text: 'Two years ago')
          ..createdAt = DateTime(2024, 3, 27),
      ];

      final result = filterOnThisDay(entries, today);

      expect(result, hasLength(2));
      expect(result[0].text, 'Last year');
      expect(result[1].text, 'Two years ago');
    });

    test('excludes current year entries', () {
      final entries = [
        Entry.line(text: 'Today this year')
          ..createdAt = DateTime(2026, 3, 27),
        Entry.line(text: 'Last year')
          ..createdAt = DateTime(2025, 3, 27),
      ];

      final result = filterOnThisDay(entries, today);

      expect(result, hasLength(1));
      expect(result[0].text, 'Last year');
    });

    test('excludes deleted entries', () {
      final entries = [
        Entry.line(text: 'Deleted memory')
          ..createdAt = DateTime(2025, 3, 27)
          ..isDeleted = true
          ..deletedAt = DateTime(2026, 3, 20),
        Entry.line(text: 'Visible memory')
          ..createdAt = DateTime(2024, 3, 27),
      ];

      final result = filterOnThisDay(entries, today);

      expect(result, hasLength(1));
      expect(result[0].text, 'Visible memory');
    });

    test('excludes locked capsules', () {
      final entries = [
        Entry(
          typeIndex: EntryType.line.index,
          text: 'Locked capsule',
          createdAt: DateTime(2025, 3, 27),
          capsuleUnlockDate: DateTime(2027, 1, 1), // future = locked
        ),
        Entry.line(text: 'Regular entry')
          ..createdAt = DateTime(2025, 3, 27),
      ];

      final result = filterOnThisDay(entries, today);

      expect(result, hasLength(1));
      expect(result[0].text, 'Regular entry');
    });

    test('returns empty when no entries match', () {
      final entries = [
        Entry.line(text: 'Wrong day')
          ..createdAt = DateTime(2025, 3, 28),
        Entry.line(text: 'Wrong month')
          ..createdAt = DateTime(2025, 4, 27),
        Entry.line(text: 'Current year')
          ..createdAt = DateTime(2026, 3, 27),
      ];

      final result = filterOnThisDay(entries, today);

      expect(result, isEmpty);
    });

    test('returns entries sorted by year descending', () {
      final entries = [
        Entry.line(text: 'Oldest')
          ..createdAt = DateTime(2022, 3, 27),
        Entry.line(text: 'Newest')
          ..createdAt = DateTime(2025, 3, 27),
        Entry.line(text: 'Middle')
          ..createdAt = DateTime(2024, 3, 27),
      ];

      final result = filterOnThisDay(entries, today);

      expect(result, hasLength(3));
      expect(result[0].text, 'Newest');
      expect(result[1].text, 'Middle');
      expect(result[2].text, 'Oldest');
    });

    test('includes unlocked capsules from previous years', () {
      final entries = [
        Entry(
          typeIndex: EntryType.line.index,
          text: 'Unlocked capsule',
          createdAt: DateTime(2025, 3, 27),
          capsuleUnlockDate: DateTime(2026, 1, 1), // past = unlocked
        ),
      ];

      final result = filterOnThisDay(entries, today);

      expect(result, hasLength(1));
      expect(result[0].text, 'Unlocked capsule');
    });
  });
}
