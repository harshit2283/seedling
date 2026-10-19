import 'dart:async';

import '../../constants/prefs_keys.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../backup/backup_reminder_service.dart';
import '../error_reporter.dart';
import '../export/export_service.dart';
import '../haptic_service.dart';
import '../storage/storage_usage_service.dart';
import '../security/app_lock_service.dart';
import '../notifications/gentle_reminder_service.dart';
import '../share/share_receiver_service.dart';
import '../widget/widget_data_service.dart';
import 'database_providers.dart';

// ============================================================================
// App Lock Providers
// ============================================================================

/// Notifier for app lock preference.
class AppLockEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(PrefsKeys.appLockEnabled) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(PrefsKeys.appLockEnabled, enabled);
  }
}

/// Provider for app lock enabled setting.
final appLockEnabledProvider = NotifierProvider<AppLockEnabledNotifier, bool>(
  AppLockEnabledNotifier.new,
);

/// Master opt-in for any cloud sync. Defaults to false.
///
/// This is the user-facing privacy gate: when false, no Google Drive /
/// CloudKit code path may upload, download, or authenticate. Existing
/// per-backend toggles still apply on top of this.
class CloudSyncEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(PrefsKeys.cloudSyncEnabled) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(PrefsKeys.cloudSyncEnabled, enabled);
  }
}

final cloudSyncEnabledProvider =
    NotifierProvider<CloudSyncEnabledNotifier, bool>(
      CloudSyncEnabledNotifier.new,
    );

/// Provider for app lock biometric authentication service.
final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

// ============================================================================
// Reminder Providers
// ============================================================================

/// Provider for gentle reminder scheduling service.
/// Must be overridden at app startup after initialization.
final gentleReminderServiceProvider = Provider<GentleReminderService>((ref) {
  throw UnimplementedError(
    'gentleReminderServiceProvider must be overridden with the initialized service',
  );
});

/// Notifier for gentle reminder settings.
class ReminderSettingsNotifier extends Notifier<ReminderSettings> {
  @override
  ReminderSettings build() {
    final service = ref.watch(gentleReminderServiceProvider);
    return service.settings;
  }

  Future<void> setEnabled(bool enabled) async {
    final service = ref.read(gentleReminderServiceProvider);
    final next = state.copyWith(enabled: enabled);
    await service.saveSettings(next);
    state = next;
    await service.reschedule(ref.read(allEntriesProvider));
  }

  Future<void> setCadence(ReminderCadence cadence) async {
    final service = ref.read(gentleReminderServiceProvider);
    final next = state.copyWith(cadence: cadence);
    await service.saveSettings(next);
    state = next;
    await service.reschedule(ref.read(allEntriesProvider));
  }

  Future<void> setTime({required int hour, required int minute}) async {
    final service = ref.read(gentleReminderServiceProvider);
    final next = state.copyWith(hour: hour, minute: minute);
    await service.saveSettings(next);
    state = next;
    await service.reschedule(ref.read(allEntriesProvider));
  }
}

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
      ReminderSettingsNotifier.new,
    );

/// Provider that keeps reminder schedule updated as entries change.
///
/// Checks the (off-by-default) setting before watching entries, so with
/// reminders off it does not keep the all-entries stream alive and re-run on
/// every save.
final reminderAutoRescheduleProvider = Provider<void>((ref) {
  final reminderSettings = ref.watch(reminderSettingsProvider);
  if (!reminderSettings.enabled) return;
  final entries = ref.watch(allEntriesProvider);
  final reminderService = ref.watch(gentleReminderServiceProvider);
  unawaited(reminderService.reschedule(entries));
});

// ============================================================================
// Widget Providers
// ============================================================================

/// Notifier for whether widgets may include memory preview text.
class WidgetMemoryPreviewsNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(PrefsKeys.widgetMemoryPreviewsEnabled) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(PrefsKeys.widgetMemoryPreviewsEnabled, enabled);
  }
}

/// Provider for widget memory preview preference.
final widgetMemoryPreviewsEnabledProvider =
    NotifierProvider<WidgetMemoryPreviewsNotifier, bool>(
      WidgetMemoryPreviewsNotifier.new,
    );

/// Effective widget preview policy after applying privacy constraints.
final effectiveWidgetMemoryPreviewsProvider = Provider<bool>((ref) {
  final previewsEnabled = ref.watch(widgetMemoryPreviewsEnabledProvider);
  final appLockEnabled = ref.watch(appLockEnabledProvider);
  return previewsEnabled && !appLockEnabled;
});

// ============================================================================
// Calm mode
// ============================================================================

/// Calm mode hides entry counts, the progress-to-next-stage bar and stage
/// labels on the tree screen and home widgets. The tree still grows; it just
/// stops keeping score. Off by default.
class CalmModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(PrefsKeys.calmModeEnabled) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(PrefsKeys.calmModeEnabled, enabled);
  }
}

final calmModeProvider = NotifierProvider<CalmModeNotifier, bool>(
  CalmModeNotifier.new,
);

/// Provider for the widget data service (must be overridden at startup)
final widgetDataServiceProvider = Provider<WidgetDataService>((ref) {
  throw UnimplementedError(
    'widgetDataServiceProvider must be overridden with the initialized service',
  );
});

/// Provider that automatically updates widgets when tree or entries change.
///
/// Debounced (~1s) and deduplicated in [WidgetDataService.scheduleUpdate]:
/// an import or sync merge emits entries many times, and each update is
/// eight platform-channel writes plus a widget reload.
final widgetAutoUpdateProvider = Provider<void>((ref) {
  final tree = ref.watch(currentTreeProvider);
  final entries = ref.watch(entriesProvider);
  final widgetService = ref.watch(widgetDataServiceProvider);
  final showMemoryPreviews = ref.watch(effectiveWidgetMemoryPreviewsProvider);
  final calmMode = ref.watch(calmModeProvider);

  widgetService.scheduleUpdate(
    tree: tree,
    recentEntries: entries.take(3).toList(),
    showMemoryPreviews: showMemoryPreviews,
    calmMode: calmMode,
  );
});

// ============================================================================
// Share Receiver Provider (Phase 4.5)
// ============================================================================

/// Provider for the share receiver service (must be overridden at startup)
final shareReceiverServiceProvider = Provider<ShareReceiverService>((ref) {
  throw UnimplementedError(
    'shareReceiverServiceProvider must be overridden with the initialized service',
  );
});

// ============================================================================
// Export & Storage Providers
// ============================================================================

/// Provider for the export service
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(errorReporter: ref.watch(errorReporterProvider));
});

/// Provider exposing the haptic service. Override in tests to assert
/// or suppress haptic calls without touching real platform channels.
final hapticServiceProvider = Provider<HapticServiceInterface>(
  (ref) => defaultHapticService,
);

/// Provider for the storage usage service
final storageUsageServiceProvider = Provider<StorageUsageService>((ref) {
  return StorageUsageService();
});

/// Future provider for storage usage (requires async calculation)
final storageUsageProvider = FutureProvider<StorageUsage>((ref) async {
  final service = ref.watch(storageUsageServiceProvider);
  return service.calculateUsage();
});

// ============================================================================
// Feature Flag Providers
// ============================================================================

final collageViewEnabledProvider =
    NotifierProvider<_CollageViewFlagNotifier, bool>(
      _CollageViewFlagNotifier.new,
    );

class _CollageViewFlagNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(PrefsKeys.flagCollageView) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(PrefsKeys.flagCollageView, state);
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(PrefsKeys.flagCollageView, value);
  }
}

// ============================================================================
// Backup Reminder Providers
// ============================================================================

/// Provider for the backup reminder service.
final backupReminderServiceProvider = Provider<BackupReminderService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BackupReminderService(prefs);
});

/// Provider that checks whether the backup reminder should be shown.
final shouldShowBackupReminderProvider = Provider<bool>((ref) {
  final service = ref.watch(backupReminderServiceProvider);
  // Every memory counts, across all years (the yearly tree resets).
  final entryCount = ref.watch(allEntriesProvider).length;
  return service.shouldShowReminder(entryCount: entryCount);
});
