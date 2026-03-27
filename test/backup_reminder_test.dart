import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      await prefs.setString('last_backup_date', oldDate.toIso8601String());

      expect(service.shouldShowReminder(entryCount: 10), true);
    });

    test('no reminder at exactly 29 days since backup', () async {
      final date = DateTime.now().subtract(const Duration(days: 29));
      await prefs.setString('last_backup_date', date.toIso8601String());

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
        'backup_reminder_dismissed_at',
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
      expect(prefs.getString('backup_reminder_dismissed_at'), isNull);
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
      expect(
        lastBackup.isBefore(after.add(const Duration(seconds: 1))),
        true,
      );
    });
  });
}
