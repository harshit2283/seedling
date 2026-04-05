import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seedling/core/constants/prefs_keys.dart';
import 'package:seedling/core/services/backup/backup_reminder_service.dart';

void main() {
  group('BackupReminderService', () {
    late SharedPreferences prefs;
    late BackupReminderService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = BackupReminderService(prefs);
    });

    test('no reminder when no entries exist', () {
      expect(service.shouldShowReminder(entryCount: 0), false);
    });

    test('reminder shows when user has entries but never backed up', () {
      expect(service.shouldShowReminder(entryCount: 5), true);
    });

    test('no reminder when backup was recent (< 30 days)', () async {
      // Record a backup right now
      await service.recordBackup();

      expect(service.shouldShowReminder(entryCount: 10), false);
    });

    test('reminder shows after 30 days since last backup', () async {
      // Simulate a backup that happened 31 days ago
      final oldDate = DateTime.now().subtract(const Duration(days: 31));
      await prefs.setString(
        PrefsKeys.lastBackupDate,
        oldDate.toIso8601String(),
      );

      expect(service.shouldShowReminder(entryCount: 10), true);
    });

    test('no reminder at exactly 29 days since backup', () async {
      final date = DateTime.now().subtract(const Duration(days: 29));
      await prefs.setString(PrefsKeys.lastBackupDate, date.toIso8601String());

      expect(service.shouldShowReminder(entryCount: 10), false);
    });

    test('dismiss silences reminder for 30 days', () async {
      // User has never backed up and has entries — reminder would show.
      expect(service.shouldShowReminder(entryCount: 5), true);

      // Dismiss the reminder.
      await service.dismissReminder();

      // Now it should not show.
      expect(service.shouldShowReminder(entryCount: 5), false);
    });

    test('reminder reappears after dismiss expires (30+ days)', () async {
      // Simulate a dismissal that happened 31 days ago.
      final oldDismiss = DateTime.now().subtract(const Duration(days: 31));
      await prefs.setString(
        PrefsKeys.backupReminderDismissedAt,
        oldDismiss.toIso8601String(),
      );

      // Never backed up, has entries — should show again.
      expect(service.shouldShowReminder(entryCount: 5), true);
    });

    test('recordBackup resets the timer and clears dismissal', () async {
      // Dismiss first
      await service.dismissReminder();
      expect(service.shouldShowReminder(entryCount: 5), false);

      // Record a backup — this should clear the dismissal.
      await service.recordBackup();

      // Backup just happened, so no reminder.
      expect(service.shouldShowReminder(entryCount: 5), false);

      // Verify the backup date is set.
      expect(service.getLastBackupDate(), isNotNull);

      // Verify dismissal was cleared.
      expect(prefs.getString(PrefsKeys.backupReminderDismissedAt), isNull);
    });

    test('getLastBackupDate returns null when never backed up', () {
      expect(service.getLastBackupDate(), isNull);
    });

    test('getLastBackupDate returns date after recordBackup', () async {
      final before = DateTime.now();
      await service.recordBackup();
      final after = DateTime.now();

      final lastBackup = service.getLastBackupDate();
      expect(lastBackup, isNotNull);
      expect(
        lastBackup!.isAfter(before.subtract(const Duration(seconds: 1))),
        true,
      );
      expect(lastBackup.isBefore(after.add(const Duration(seconds: 1))), true);
    });

    test('reminder shows at exactly 30 days (boundary)', () async {
      final date = DateTime.now().subtract(const Duration(days: 30));
      await prefs.setString(PrefsKeys.lastBackupDate, date.toIso8601String());

      // >= 30 days triggers the reminder
      expect(service.shouldShowReminder(entryCount: 10), true);
    });

    test('multiple recordBackup calls keep latest date', () async {
      await service.recordBackup();
      final first = service.getLastBackupDate();

      // Small delay to ensure different timestamps
      await Future.delayed(const Duration(milliseconds: 10));
      await service.recordBackup();
      final second = service.getLastBackupDate();

      expect(second, isNotNull);
      expect(first, isNotNull);
      expect(second!.isAfter(first!) || second.isAtSameMomentAs(first), true);
    });

    test('dismiss after backup still silences reminder', () async {
      await service.recordBackup();
      // Simulate backup being old
      final oldDate = DateTime.now().subtract(const Duration(days: 31));
      await prefs.setString(
        PrefsKeys.lastBackupDate,
        oldDate.toIso8601String(),
      );

      // Would normally show
      expect(service.shouldShowReminder(entryCount: 5), true);

      // Dismiss
      await service.dismissReminder();
      expect(service.shouldShowReminder(entryCount: 5), false);
    });

    test('entry count of 1 is sufficient to trigger reminder', () {
      expect(service.shouldShowReminder(entryCount: 1), true);
    });

    test('handles corrupted date string in prefs gracefully', () async {
      await prefs.setString(PrefsKeys.lastBackupDate, 'not-a-date');

      // Should not crash — treats as never backed up
      final lastBackup = service.getLastBackupDate();
      expect(lastBackup, isNull);
    });
  });
}
