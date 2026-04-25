/// SharedPreferences key constants.
///
/// Centralizes all preference keys to prevent typos and make
/// it easy to audit what is stored locally.
class PrefsKeys {
  PrefsKeys._(); // Prevent instantiation

  // Onboarding
  static const String onboardingCompleted = 'onboarding_completed';

  // App lock
  static const String appLockEnabled = 'app_lock_enabled';

  // Master cloud sync opt-in (off by default — gates any network upload).
  static const String cloudSyncEnabled = 'cloud_sync_enabled';

  // Widget memory previews
  static const String widgetMemoryPreviewsEnabled =
      'widget_memory_previews_enabled';

  // Home feed
  static const String homeFeedScope = 'home_feed_scope';

  // Sync provider (iOS)
  static const String syncProviderIOS = 'sync_provider_ios';

  // Sync metadata (namespaced — use via SyncMetadata._key())
  static const String syncEnabled = 'sync_enabled';
  static const String syncChangeToken = 'sync_change_token';
  static const String syncLastSync = 'sync_last_sync';
  static const String syncPendingQueue = 'sync_pending_queue';
  static const String syncDeviceId = 'sync_device_id';
  static const String syncLastError = 'sync_last_error';
  static const String syncLastErrorAt = 'sync_last_error_at';

  // Google Drive sync
  static const String syncGDriveLockedAccount = 'sync_gdrive_locked_account';

  // Prompts
  static const String promptsEnabled = 'prompts_enabled';
  static const String lastPromptShown = 'last_prompt_shown';
  static const String lastPromptText = 'last_prompt_text';

  // Gentle reminders
  static const String gentleRemindersEnabled = 'gentle_reminders_enabled';
  static const String gentleRemindersCadence = 'gentle_reminders_cadence';
  static const String gentleRemindersHour = 'gentle_reminders_hour';
  static const String gentleRemindersMinute = 'gentle_reminders_minute';
  static const String gentleRemindersQuietStart =
      'gentle_reminders_quiet_start';
  static const String gentleRemindersQuietEnd = 'gentle_reminders_quiet_end';
  static const String ritualLastNotificationMs = 'ritual_last_notification_ms';

  // Entry type usage
  static const String entryTypeUsageData = 'entry_type_usage_data';

  // Feature flags
  static const String flagMoodVisualization = 'flag_mood_visualization';
  static const String flagCollageView = 'flag_collage_view';

  // Backup reminders
  static const String lastBackupDate = 'last_backup_date';
  static const String backupReminderDismissedAt =
      'backup_reminder_dismissed_at';

  // Memories screen
  static const String memoriesGridView = 'memories_grid_view';
}
