import 'package:shared_preferences/shared_preferences.dart';

/// Service that tracks when the user last backed up and determines
/// whether a gentle reminder should be shown.
///
/// Uses [SharedPreferences] to persist dates across sessions.
class BackupReminderService {
  BackupReminderService(this._prefs);

  final SharedPreferences _prefs;

  static const String _lastBackupDateKey = 'last_backup_date';
  static const String _reminderDismissedAtKey = 'backup_reminder_dismissed_at';

  /// Number of days after which a reminder is shown.
  static const int reminderThresholdDays = 30;

  /// Records the current time as the last backup date.
  Future<void> recordBackup() async {
    await _prefs.setString(
      _lastBackupDateKey,
      DateTime.now().toIso8601String(),
    );
    // Clear any previous dismissal so the 30-day cycle resets from the backup.
    await _prefs.remove(_reminderDismissedAtKey);
  }

  /// Returns the date/time of the last backup, or `null` if the user
  /// has never backed up.
  DateTime? getLastBackupDate() {
    final raw = _prefs.getString(_lastBackupDateKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Dismisses the reminder for another [reminderThresholdDays] days.
  Future<void> dismissReminder() async {
    await _prefs.setString(
      _reminderDismissedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Whether the backup reminder card should be displayed.
  ///
  /// Returns `true` when ALL of the following are true:
  /// 1. The user has at least one entry (indicated by [entryCount] > 0).
  /// 2. Either the user has never backed up, or the last backup was more
  ///    than [reminderThresholdDays] days ago.
  /// 3. The reminder has not been dismissed within the last
  ///    [reminderThresholdDays] days.
  bool shouldShowReminder({required int entryCount}) {
    if (entryCount <= 0) return false;

    // Check if the reminder was recently dismissed.
    final dismissedRaw = _prefs.getString(_reminderDismissedAtKey);
    if (dismissedRaw != null) {
      final dismissedAt = DateTime.tryParse(dismissedRaw);
      if (dismissedAt != null) {
        final daysSinceDismiss =
            DateTime.now().difference(dismissedAt).inDays;
        if (daysSinceDismiss < reminderThresholdDays) {
          return false;
        }
      }
    }

    // Check if the user has ever backed up.
    final lastBackup = getLastBackupDate();
    if (lastBackup == null) return true;

    final daysSinceBackup = DateTime.now().difference(lastBackup).inDays;
    return daysSinceBackup >= reminderThresholdDays;
  }
}
