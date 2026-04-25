import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/models/entry.dart';

void main() {
  group('Entry capsule locking', () {
    test('entry without capsuleUnlockDate is not a capsule', () {
      final entry = Entry.line(text: 'Regular entry');

      expect(entry.isCapsule, isFalse);
      expect(entry.isLocked, isFalse);
      expect(entry.isUnlocked, isFalse);
    });

    test('entry with future capsuleUnlockDate is locked', () {
      final entry = Entry.line(text: 'Future capsule');
      entry.capsuleUnlockDate = DateTime.now().add(const Duration(days: 30));

      expect(entry.isCapsule, isTrue);
      expect(entry.isLocked, isTrue);
      expect(entry.isUnlocked, isFalse);
    });

    test('entry with past capsuleUnlockDate is unlocked', () {
      final entry = Entry.line(text: 'Unlocked capsule');
      entry.capsuleUnlockDate = DateTime.now().subtract(
        const Duration(days: 1),
      );

      expect(entry.isCapsule, isTrue);
      expect(entry.isLocked, isFalse);
      expect(entry.isUnlocked, isTrue);
    });

    test('capsule factory creates locked entry with future date', () {
      final unlockDate = DateTime.now().add(const Duration(days: 365));
      final entry = Entry.capsule(text: 'Time capsule', unlockDate: unlockDate);

      expect(entry.type, EntryType.line);
      expect(entry.isCapsule, isTrue);
      expect(entry.isLocked, isTrue);
      // Capsule unlock dates are stored in UTC for clock-rollback safety.
      expect(entry.capsuleUnlockDate, unlockDate.toUtc());
      expect(entry.capsuleUnlockDate!.isUtc, isTrue);
    });

    test(
      'isLocked depends only on capsuleUnlockDate, not on encrypted fields',
      () {
        // This test validates that the query optimization is safe:
        // isLocked checks capsuleUnlockDate (not encrypted) so we can
        // filter at the query level without decrypting entries.
        final entry = Entry.fragment(); // fragment allows null text
        entry.capsuleUnlockDate = DateTime.now().add(const Duration(days: 10));

        // isLocked should still work even with no text/title
        expect(entry.isLocked, isTrue);

        entry.capsuleUnlockDate = DateTime.now().subtract(
          const Duration(days: 1),
        );
        expect(entry.isLocked, isFalse);
      },
    );

    test('daysUntilUnlock returns positive for future capsules', () {
      final entry = Entry.capsule(
        text: 'test',
        unlockDate: DateTime.now().add(const Duration(days: 10)),
      );

      expect(entry.daysUntilUnlock, greaterThanOrEqualTo(9));
      expect(entry.daysUntilUnlock, lessThanOrEqualTo(10));
    });

    test('filtering locked capsules works correctly on a list', () {
      final now = DateTime.now();
      final entries = [
        Entry.line(text: 'Regular 1')..id = 1,
        Entry.line(text: 'Regular 2')..id = 2,
        Entry.capsule(
          text: 'Locked capsule',
          unlockDate: now.add(const Duration(days: 30)),
        )..id = 3,
        Entry.capsule(
          text: 'Unlocked capsule',
          unlockDate: now.subtract(const Duration(days: 1)),
        )..id = 4,
      ];

      // This is what the optimized query does at the DB level:
      // Exclude entries where capsuleUnlockDate is in the future
      final visibleEntries = entries.where((e) => !e.isLocked).toList();

      expect(visibleEntries.length, 3);
      expect(visibleEntries.map((e) => e.id), containsAll([1, 2, 4]));
      expect(visibleEntries.map((e) => e.id), isNot(contains(3)));
    });

    test('capsuleUnlockDate stored as milliseconds round-trips correctly', () {
      final originalDate = DateTime(2027, 6, 15, 10, 30, 0);
      final entry = Entry();
      entry.capsuleUnlockDate = originalDate;

      // Simulate ObjectBox storage: PropertyType.date stores as milliseconds
      final millis = entry.capsuleUnlockDate!.millisecondsSinceEpoch;
      final restored = DateTime.fromMillisecondsSinceEpoch(millis);

      expect(restored, originalDate);
    });
  });
}
