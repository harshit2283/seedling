/// SharedPreferences key constants.
///
/// Centralizes all preference keys to prevent typos and make
/// it easy to audit what is stored locally.
class PrefsKeys {
  PrefsKeys._(); // Prevent instantiation

  // Onboarding
  static const String onboardingCompleted = 'onboarding_completed';

  // Implementation intention ("When I make my morning coffee"), optional.
  // Shown softly as the capture field's hint.
  static const String captureIntention = 'capture_intention';

  // App lock
  static const String appLockEnabled = 'app_lock_enabled';

  // Master cloud sync opt-in (off by default — gates any network upload).
  static const String cloudSyncEnabled = 'cloud_sync_enabled';

  // Widget memory previews
  static const String widgetMemoryPreviewsEnabled =
      'widget_memory_previews_enabled';

  // Home feed
  static const String homeFeedScope = 'home_feed_scope';

  // Calm mode: hide counts, stages and progress (the tree still grows).
  static const String calmModeEnabled = 'calm_mode_enabled';

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
  // Remote layout version this device has fully uploaded for (re-push all
  // local entries when it is behind SyncEngine.currentFormatVersion).
  static const String syncFormatVersion = 'sync_format_version';
  // Records that failed to decrypt/authenticate, kept for a retry.
  static const String syncQuarantine = 'sync_quarantine';
  // Fingerprint of the key the last full upload was done with.
  static const String syncKeyFingerprint = 'sync_key_fingerprint';

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

  // Entry type usage
  static const String entryTypeUsageData = 'entry_type_usage_data';

  // Feature flags
  static const String flagCollageView = 'flag_collage_view';

  // Backup reminders
  static const String lastBackupDate = 'last_backup_date';
  static const String backupReminderDismissedAt =
      'backup_reminder_dismissed_at';

  // Memories screen
  static const String memoriesGridView = 'memories_grid_view';

  // On This Day card (day-keyed dismissal)
  static const String onThisDayDismissedDate = 'on_this_day_dismissed_date';

  // "From your tree" resurfacing card (day-keyed dismissal) and its
  // opt-in weekly notification.
  static const String resurfaceDismissedDate = 'resurface_dismissed_date';
  static const String resurfaceNotificationsEnabled =
      'resurface_notifications_enabled';

  // Support invitation (shown at most once, ever)
  static const String supportInvitationShown = 'support_invitation_shown';

  // One-time background pass that persists detected themes on entries saved
  // before themes were stored at capture. Holds the completed pass version.
  static const String themeBackfillVersion = 'theme_backfill_version';
}
