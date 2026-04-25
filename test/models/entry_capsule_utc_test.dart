import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/models/entry.dart';

void main() {
  group('Entry.capsule UTC normalization', () {
    test('capsule factory stores unlockDate as UTC', () {
      final localDate = DateTime(2030, 6, 15, 10, 30, 0);
      final entry = Entry.capsule(text: 'future me', unlockDate: localDate);

      expect(entry.capsuleUnlockDate!.isUtc, isTrue);
      expect(
        entry.capsuleUnlockDate!.millisecondsSinceEpoch,
        localDate.toUtc().millisecondsSinceEpoch,
      );
    });

    test(
      'isLocked is consistent across local and UTC inputs for the same moment',
      () {
        final futureLocal = DateTime.now().add(const Duration(days: 30));
        final futureUtc = futureLocal.toUtc();

        final entryLocal = Entry.line(text: 'a')
          ..capsuleUnlockDate = futureLocal;
        final entryUtc = Entry.line(text: 'b')..capsuleUnlockDate = futureUtc;

        // Both should be locked because they describe the same future moment.
        expect(entryLocal.isLocked, isTrue);
        expect(entryUtc.isLocked, isTrue);
      },
    );

    test(
      'isLocked correctly identifies past UTC dates as unlocked',
      () {
        final pastUtc = DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 1));
        final entry = Entry.line(text: 'a')..capsuleUnlockDate = pastUtc;

        expect(entry.isUnlocked, isTrue);
        expect(entry.isLocked, isFalse);
      },
    );

    test('daysUntilUnlock yields a stable count regardless of input tz', () {
      final futureLocal = DateTime.now().add(const Duration(days: 10));
      final entry = Entry.capsule(text: 'a', unlockDate: futureLocal);

      expect(entry.daysUntilUnlock, greaterThanOrEqualTo(9));
      expect(entry.daysUntilUnlock, lessThanOrEqualTo(10));
    });
  });
}
