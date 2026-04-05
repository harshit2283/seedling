import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/prefs_keys.dart';

/// Service that tracks when the user last backed up and determines
/// whether a gentle reminder should be shown.
///
/// Uses [SharedPreferences] to persist dates across sessions.
class BackupReminderService {
  BackupReminderService(this._prefs);

  final SharedPreferences _prefs;

  /// Number of days after which a reminder is shown.
  static const int reminderThresholdDays = 30;

  /// Records the current time as the last backup date.
  Future<void> recordBackup() async {
    await _prefs.setString(
      PrefsKeys.lastBackupDate,
      DateTime.now().toIso8601String(),
    );
    // Clear any previous dismissal so the 30-day cycle resets from the backup.
    await _prefs.remove(PrefsKeys.backupReminderDismissedAt);
  }

  /// Returns the date/time of the last backup, or `null` if the user
  /// has never backed up.
  DateTime? getLastBackupDate() {
    final raw = _prefs.getString(PrefsKeys.lastBackupDate);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Dismisses the reminder for another [reminderThresholdDays] days.
  Future<void> dismissReminder() async {
    await _prefs.setString(
      PrefsKeys.backupReminderDismissedAt,
      DateTime.now().toIso8601String(),
    );
  }

  /// Whether the backup reminder card should be displayed.
  bool shouldShowReminder({required int entryCount}) {
    if (entryCount <= 0) return false;

    final dismissedRaw = _prefs.getString(PrefsKeys.backupReminderDismissedAt);
    if (dismissedRaw != null) {
      final dismissedAt = DateTime.tryParse(dismissedRaw);
      if (dismissedAt != null) {
        final daysSinceDismiss = DateTime.now().difference(dismissedAt).inDays;
        if (daysSinceDismiss < reminderThresholdDays) {
          return false;
        }
      }
    }

    final lastBackup = getLastBackupDate();
    if (lastBackup == null) return true;

    final daysSinceBackup = DateTime.now().difference(lastBackup).inDays;
    return daysSinceBackup >= reminderThresholdDays;
  }
}
