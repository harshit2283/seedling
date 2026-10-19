import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/prefs_keys.dart';

/// Decides when to gently suggest keeping a copy of the user's memories.
///
/// Never on day one: the suggestion waits until the tree has at least
/// [minMemories] memories *and* [minDaysSinceFirstMemory] days have passed
/// since Seedling first saw one. After a backup or a dismissal it stays
/// quiet for [reminderThresholdDays] days, so it appears at most monthly.
class BackupReminderService {
  BackupReminderService(this._prefs, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  /// Days of quiet after a backup or dismissal.
  static const int reminderThresholdDays = 30;

  /// Memories needed before a backup is worth suggesting.
  static const int minMemories = 10;

  /// Days since the first memory before a backup is suggested.
  static const int minDaysSinceFirstMemory = 14;

  /// Records the current time as the last backup date.
  Future<void> recordBackup() async {
    await _prefs.setString(PrefsKeys.lastBackupDate, _now().toIso8601String());
    // Clear any previous dismissal so the 30-day cycle resets from the backup.
    await _prefs.remove(PrefsKeys.backupReminderDismissedAt);
  }

  /// Returns the date/time of the last backup, or `null` if the user
  /// has never backed up.
  DateTime? getLastBackupDate() => _readDate(PrefsKeys.lastBackupDate);

  /// When Seedling first saw a memory, or null before the first one.
  DateTime? getFirstMemorySeenAt() => _readDate(PrefsKeys.firstMemorySeenAt);

  /// Dismisses the reminder for another [reminderThresholdDays] days.
  Future<void> dismissReminder() async {
    await _prefs.setString(
      PrefsKeys.backupReminderDismissedAt,
      _now().toIso8601String(),
    );
  }

  /// Whether the backup suggestion should be displayed.
  bool shouldShowReminder({required int entryCount}) {
    if (entryCount <= 0) return false;
    final now = _now();

    // Remember the first time we saw a memory (SharedPreferences caches
    // writes synchronously, so this is visible to the next call at once).
    var firstSeen = getFirstMemorySeenAt();
    if (firstSeen == null) {
      firstSeen = now;
      _prefs.setString(PrefsKeys.firstMemorySeenAt, now.toIso8601String());
    }

    if (entryCount < minMemories) return false;
    if (now.difference(firstSeen).inDays < minDaysSinceFirstMemory) {
      return false;
    }

    final dismissedAt = _readDate(PrefsKeys.backupReminderDismissedAt);
    if (dismissedAt != null &&
        now.difference(dismissedAt).inDays < reminderThresholdDays) {
      return false;
    }

    final lastBackup = getLastBackupDate();
    if (lastBackup == null) return true;
    return now.difference(lastBackup).inDays >= reminderThresholdDays;
  }

  DateTime? _readDate(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
