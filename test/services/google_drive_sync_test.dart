import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/sync/sync_models.dart';

void main() {
  group('AccountMismatchException', () {
    test('has correct fields', () {
      final exception = AccountMismatchException(
        lockedAccount: 'alice@example.com',
        attemptedAccount: 'bob@example.com',
      );

      expect(exception.lockedAccount, 'alice@example.com');
      expect(exception.attemptedAccount, 'bob@example.com');
    });

    test('toString includes both accounts', () {
      final exception = AccountMismatchException(
        lockedAccount: 'locked@test.com',
        attemptedAccount: 'other@test.com',
      );

      final str = exception.toString();
      expect(str, contains('locked@test.com'));
      expect(str, contains('other@test.com'));
      expect(str, contains('AccountMismatchException'));
    });
  });

  group('SyncChange', () {
    test('toJson and fromJson round-trip', () {
      final original = SyncChange(
        syncUUID: 'uuid-123',
        changeType: SyncChangeType.create,
        timestamp: DateTime(2024, 6, 15, 10, 30),
      );

      final json = original.toJson();
      final restored = SyncChange.fromJson(json);

      expect(restored.syncUUID, original.syncUUID);
      expect(restored.changeType, original.changeType);
      expect(
        restored.timestamp.millisecondsSinceEpoch,
        original.timestamp.millisecondsSinceEpoch,
      );
    });

    test('fromJson handles all change types', () {
      for (final type in SyncChangeType.values) {
        final json = {
          'syncUUID': 'test',
          'changeType': type.name,
          'timestamp': 1000000,
        };
        final change = SyncChange.fromJson(json);
        expect(change.changeType, type);
      }
    });
  });

  group('SyncResult', () {
    test('success factory creates successful result', () {
      final result = SyncResult.success(pushed: 3, pulled: 5, conflicts: 1);

      expect(result.success, true);
      expect(result.pushedCount, 3);
      expect(result.pulledCount, 5);
      expect(result.conflictsResolved, 1);
      expect(result.errorMessage, isNull);
    });

    test('error factory creates failed result', () {
      final result = SyncResult.error('Network timeout');

      expect(result.success, false);
      expect(result.errorMessage, 'Network timeout');
      expect(result.pushedCount, 0);
      expect(result.pulledCount, 0);
    });
  });
}
