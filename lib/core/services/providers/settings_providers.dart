import 'dart:async';

import '../../constants/prefs_keys.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../export/export_service.dart';
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
final reminderAutoRescheduleProvider = Provider<void>((ref) {
  final entries = ref.watch(allEntriesProvider);
  final reminderSettings = ref.watch(reminderSettingsProvider);
  if (!reminderSettings.enabled) return;
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

/// Provider for the widget data service (must be overridden at startup)
final widgetDataServiceProvider = Provider<WidgetDataService>((ref) {
  throw UnimplementedError(
    'widgetDataServiceProvider must be overridden with the initialized service',
  );
});

/// Provider that automatically updates widgets when tree or entries change
final widgetAutoUpdateProvider = Provider<void>((ref) {
  final tree = ref.watch(currentTreeProvider);
  final entries = ref.watch(entriesProvider);
  final widgetService = ref.watch(widgetDataServiceProvider);
  final showMemoryPreviews = ref.watch(effectiveWidgetMemoryPreviewsProvider);

  // Update widget data whenever tree or entries change
  unawaited(
    widgetService.updateWidgetData(
      tree: tree,
      recentEntries: entries.take(3).toList(),
      showMemoryPreviews: showMemoryPreviews,
    ),
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
  return ExportService();
});

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

final moodVisualizationEnabledProvider =
    NotifierProvider<_MoodVisualizationFlagNotifier, bool>(
      _MoodVisualizationFlagNotifier.new,
    );

final collageViewEnabledProvider =
    NotifierProvider<_CollageViewFlagNotifier, bool>(
      _CollageViewFlagNotifier.new,
    );

class _MoodVisualizationFlagNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(PrefsKeys.flagMoodVisualization) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(PrefsKeys.flagMoodVisualization, state);
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(PrefsKeys.flagMoodVisualization, value);
  }
}

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
