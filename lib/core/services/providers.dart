import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/objectbox_database.dart';
import '../../data/models/entry.dart';
import '../../data/models/tree.dart';
import 'media/audio_playback_service.dart';
import 'media/file_storage_service.dart';
import 'media/media_compression_service.dart';
import 'media/permission_service.dart';
import 'media/photo_capture_service.dart';
import 'media/voice_recording_service.dart';
import 'export/export_service.dart';
import 'storage/storage_usage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/prompts/data/prompt_repository.dart';
import '../../features/prompts/data/prompt_preferences.dart';
import '../../features/prompts/domain/prompt_selector.dart';
import 'ai/theme_detector_service.dart';
import 'ai/connection_finder_service.dart';
import 'ai/ritual_detection_service.dart';
import 'ai/suggestion_engine.dart';
import 'ai/ml_text_analyzer.dart';
import 'ai/models/memory_connection.dart';
import 'ai/models/memory_theme.dart';
import 'ai/models/ritual_candidate.dart';
import 'ai/models/smart_suggestion.dart';
import 'ai/models/analysis_result.dart';
import 'share/share_receiver_service.dart';
import 'widget/widget_data_service.dart';
import 'entry_type_usage_service.dart';
import 'security/app_lock_service.dart';
import 'transcription/speech_transcription_service.dart';
import 'search/semantic_search_service.dart';
import 'notifications/gentle_reminder_service.dart';
import 'sync/cloudkit_sync_service.dart';
import 'sync/google_drive_sync_service.dart';
import 'sync/sync_backend.dart';
import 'sync/sync_crypto_service.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_metadata.dart';
import 'sync/sync_models.dart';
import '../../features/review/domain/review_generator.dart';
import '../../features/onboarding/data/onboarding_preferences.dart';
import 'ritual/ritual_service.dart';
import '../../data/models/ritual.dart';

/// Scope used for home screen memory previews.
enum HomeFeedScope { currentYear, allYears }

/// iOS sync provider preference (Android always uses Google Drive).
class SyncProviderNotifier extends Notifier<SyncProviderType> {
  static const String _iosSyncProviderKey = 'sync_provider_ios';

  @override
  SyncProviderType build() {
    if (!Platform.isIOS) return SyncProviderType.googleDrive;
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_iosSyncProviderKey);
    if (raw == SyncProviderType.googleDrive.name) {
      return SyncProviderType.googleDrive;
    }
    return SyncProviderType.cloudKit;
  }

  Future<void> setProvider(SyncProviderType provider) async {
    if (!Platform.isIOS) return;
    state = provider;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_iosSyncProviderKey, provider.name);
  }
}

final syncProviderTypeProvider =
    NotifierProvider<SyncProviderNotifier, SyncProviderType>(
      SyncProviderNotifier.new,
    );

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

/// Notifier for app lock preference.
class AppLockEnabledNotifier extends Notifier<bool> {
  static const String _key = 'app_lock_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);
  }
}

/// Provider for app lock enabled setting.
final appLockEnabledProvider = NotifierProvider<AppLockEnabledNotifier, bool>(
  AppLockEnabledNotifier.new,
);

/// Notifier for whether widgets may include memory preview text.
class WidgetMemoryPreviewsNotifier extends Notifier<bool> {
  static const String _key = 'widget_memory_previews_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);
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

/// Provider for the ObjectBox database singleton
/// Must be overridden at app startup after initialization
final databaseProvider = Provider<ObjectBoxDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider must be overridden with the initialized database',
  );
});

/// Stream provider for the current year's tree
final currentTreeStreamProvider = StreamProvider<Tree?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchCurrentTree();
});

/// Simple provider for getting the current tree (non-stream)
final currentTreeProvider = Provider<Tree?>((ref) {
  final treeAsync = ref.watch(currentTreeStreamProvider);
  return treeAsync.value;
});

/// Stream provider for current year's entries
final entriesStreamProvider = StreamProvider<List<Entry>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchEntries();
});

/// Provider for the entries list (non-stream)
final entriesProvider = Provider<List<Entry>>((ref) {
  final entriesAsync = ref.watch(entriesStreamProvider);
  return entriesAsync.value ?? [];
});

/// Provider for all entries across all years (includes locked capsules).
final allEntriesProvider = Provider<List<Entry>>((ref) {
  final db = ref.watch(databaseProvider);
  ref.watch(entriesStreamProvider);
  return db.getAllEntries();
});

const int _memoriesPageSize = 50;

/// Tracks how many pages are loaded on the memories screen.
class MemoriesPaginationNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void loadMore() {
    state = state + 1;
  }

  void reset() {
    state = 1;
  }
}

/// Provider controlling page count for memories list.
final memoriesPageProvider = NotifierProvider<MemoriesPaginationNotifier, int>(
  MemoriesPaginationNotifier.new,
);

/// Provider returning current page of entries for memories screen.
final pagedEntriesProvider = Provider<List<Entry>>((ref) {
  final db = ref.watch(databaseProvider);
  final pages = ref.watch(memoriesPageProvider);
  ref.watch(entriesStreamProvider);
  return db.getEntriesPage(
    limit: pages * _memoriesPageSize,
    offset: 0,
    year: DateTime.now().year,
  );
});

/// Whether there are more entries to load in current year memories.
final hasMorePagedEntriesProvider = Provider<bool>((ref) {
  final db = ref.watch(databaseProvider);
  final loadedCount = ref.watch(pagedEntriesProvider).length;
  final totalCount = db.getEntriesCount(year: DateTime.now().year);
  return loadedCount < totalCount;
});

/// Provider for recent entries (limited)
final recentEntriesProvider = Provider<List<Entry>>((ref) {
  final entries = ref.watch(entriesProvider);
  return entries.take(5).toList();
});

/// Notifier for the home screen feed scope setting.
class HomeFeedScopeNotifier extends Notifier<HomeFeedScope> {
  static const String _scopeKey = 'home_feed_scope';

  @override
  HomeFeedScope build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_scopeKey);
    return raw == HomeFeedScope.allYears.name
        ? HomeFeedScope.allYears
        : HomeFeedScope.currentYear;
  }

  Future<void> setScope(HomeFeedScope scope) async {
    state = scope;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_scopeKey, scope.name);
  }
}

/// Provider for home feed scope setting.
final homeFeedScopeProvider =
    NotifierProvider<HomeFeedScopeNotifier, HomeFeedScope>(
      HomeFeedScopeNotifier.new,
    );

/// Provider for home screen entries based on selected feed scope.
final homeEntriesProvider = Provider<List<Entry>>((ref) {
  final scope = ref.watch(homeFeedScopeProvider);
  final db = ref.watch(databaseProvider);
  // Recompute on entry mutations.
  ref.watch(entriesStreamProvider);
  return db.getEntriesPage(
    limit: 200,
    offset: 0,
    year: scope == HomeFeedScope.allYears ? null : DateTime.now().year,
  );
});

/// Provider for home screen recent entries (limited).
final homeRecentEntriesProvider = Provider<List<Entry>>((ref) {
  final scope = ref.watch(homeFeedScopeProvider);
  final db = ref.watch(databaseProvider);
  // Recompute on entry mutations.
  ref.watch(entriesStreamProvider);
  return db.getEntriesPage(
    limit: 5,
    offset: 0,
    year: scope == HomeFeedScope.allYears ? null : DateTime.now().year,
  );
});

/// Provider for the tree's visual state
final treeStateProvider = Provider<TreeState>((ref) {
  final tree = ref.watch(currentTreeProvider);
  return tree?.state ?? TreeState.seed;
});

/// Provider for all trees in the user's forest.
final allTreesProvider = Provider<List<Tree>>((ref) {
  final db = ref.watch(databaseProvider);
  // Recompute whenever entry/tree data changes.
  ref.watch(entriesStreamProvider);
  final trees = db.getAllTrees()..sort((a, b) => b.year.compareTo(a.year));
  return trees;
});

/// Provider for tree growth progress (0.0 - 1.0)
final treeProgressProvider = Provider<double>((ref) {
  final tree = ref.watch(currentTreeProvider);
  return tree?.progressToNextStage ?? 0.0;
});

/// Notifier for tree growth celebration state
class TreeGrowthNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void triggerCelebration() {
    state = true;
    // Auto-reset after celebration animation completes
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        state = false;
      }
    });
  }

  bool get mounted {
    try {
      // Check if notifier is still mounted by accessing state
      final _ = state;
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Provider that tracks if tree just grew to a new state (for celebration animation)
/// Resets automatically after 2 seconds
final treeGrowthEventProvider = NotifierProvider<TreeGrowthNotifier, bool>(
  TreeGrowthNotifier.new,
);

/// Provider that detects tree growth and triggers celebration events
/// Must be watched somewhere in the widget tree to work
final treeGrowthDetectorProvider = Provider<void>((ref) {
  // Listen to tree state changes
  ref.listen<TreeState>(treeStateProvider, (previous, current) {
    // Check if tree grew (higher state index = more growth)
    if (previous != null && current.index > previous.index) {
      // Tree grew! Trigger celebration
      ref.read(treeGrowthEventProvider.notifier).triggerCelebration();
    }
  });
});

/// Notifier for creating entries
class EntryCreatorNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Create a LINE entry from text
  Future<Entry> createLineEntry(
    String text, {
    DateTime? capsuleUnlockDate,
  }) async {
    final db = ref.read(databaseProvider);
    final entry = Entry.line(text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    final saved = await db.saveEntry(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }

  /// Create a RELEASE entry (let go)
  Future<Entry> createReleaseEntry(
    String? text, {
    DateTime? capsuleUnlockDate,
  }) async {
    final db = ref.read(databaseProvider);
    final entry = Entry.release(text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    final saved = await db.saveEntry(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }

  /// Create a FRAGMENT entry
  Future<Entry> createFragmentEntry(
    String? text, {
    DateTime? capsuleUnlockDate,
  }) async {
    final db = ref.read(databaseProvider);
    final entry = Entry.fragment(text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    final saved = await db.saveEntry(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }

  /// Create a PHOTO entry (placeholder for Phase 2)
  Future<Entry> createPhotoEntry(
    String mediaPath, {
    String? text,
    DateTime? capsuleUnlockDate,
  }) async {
    final db = ref.read(databaseProvider);
    final entry = Entry.photo(mediaPath: mediaPath, text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    final saved = await db.saveEntry(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }

  /// Create a VOICE entry (placeholder for Phase 2)
  Future<Entry> createVoiceEntry(
    String mediaPath, {
    String? text,
    DateTime? capsuleUnlockDate,
  }) async {
    final db = ref.read(databaseProvider);
    final entry = Entry.voice(mediaPath: mediaPath, text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    final saved = await db.saveEntry(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }

  /// Create an OBJECT entry (placeholder for Phase 2)
  Future<Entry> createObjectEntry(
    String title, {
    String? mediaPath,
    String? text,
    DateTime? capsuleUnlockDate,
  }) async {
    final db = ref.read(databaseProvider);
    final entry = Entry.object(title: title, mediaPath: mediaPath, text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    final saved = await db.saveEntry(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }

  /// Soft delete an entry (recoverable for 30 days)
  Future<bool> deleteEntry(int id) async {
    final db = ref.read(databaseProvider);
    return db.softDeleteEntry(id);
  }

  /// Permanently delete an entry
  Future<bool> permanentlyDeleteEntry(int id) async {
    final db = ref.read(databaseProvider);
    return db.deleteEntry(id);
  }

  /// Restore a soft-deleted entry
  Future<bool> restoreEntry(int id) async {
    final db = ref.read(databaseProvider);
    return db.restoreEntry(id);
  }

  /// Update entry text/title
  Future<void> updateEntryText(int id, {String? text, String? title}) async {
    final db = ref.read(databaseProvider);
    final entry = db.getEntry(id);
    if (entry == null) return;

    if (text != null) entry.text = text;
    if (title != null) entry.title = title;
    db.updateEntry(entry);
  }

  /// Create a CAPSULE entry (time capsule)
  Future<Entry> createCapsuleEntry(String? text, DateTime unlockDate) async {
    final db = ref.read(databaseProvider);
    final entry = Entry.capsule(text: text, unlockDate: unlockDate);
    final saved = await db.saveEntry(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }
}

/// Provider for entry creation operations
final entryCreatorProvider = NotifierProvider<EntryCreatorNotifier, void>(
  EntryCreatorNotifier.new,
);

/// Notifier for database maintenance operations.
class DatabaseMaintenanceNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Recompute tree counts/states from entries to repair inconsistencies.
  Future<void> recountTrees({int? year}) async {
    final db = ref.read(databaseProvider);
    await db.recountTrees(year: year);
  }
}

/// Provider for database maintenance operations.
final databaseMaintenanceProvider =
    NotifierProvider<DatabaseMaintenanceNotifier, void>(
      DatabaseMaintenanceNotifier.new,
    );

/// Provider for entry count display
final entryCountProvider = Provider<int>((ref) {
  final tree = ref.watch(currentTreeProvider);
  return tree?.entryCount ?? 0;
});

/// Whether the memories browser has any non-capsule entries to show.
final hasNonCapsuleEntriesProvider = Provider<bool>((ref) {
  final entries = ref.watch(entriesProvider);
  return entries.any((entry) => !entry.isCapsule);
});

/// Theme counts used by memories filtering UI.
final memoryThemeCountsProvider = Provider<Map<MemoryTheme, int>>((ref) {
  final entries = ref.watch(entriesProvider);
  final distribution = <MemoryTheme, int>{};
  for (final entry in entries) {
    if (entry.isCapsule || !entry.hasTheme) continue;
    final theme = MemoryThemeExtension.fromString(entry.detectedTheme);
    if (theme == null) continue;
    distribution[theme] = (distribution[theme] ?? 0) + 1;
  }
  return distribution;
});

/// Provider for soft-deleted entries (for recovery screen)
final deletedEntriesProvider = Provider<List<Entry>>((ref) {
  final db = ref.watch(databaseProvider);
  // Re-fetch when entries change
  ref.watch(entriesStreamProvider);
  return db.getDeletedEntries();
});

/// Provider for tree state description
final treeDescriptionProvider = Provider<String>((ref) {
  final tree = ref.watch(currentTreeProvider);
  return tree?.stateDescription ?? 'Plant your first memory';
});

// ============================================================================
// Media Services Providers
// ============================================================================

/// Provider for the permission service
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

/// Provider for the file storage service
/// Must be overridden at app startup after initialization
final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  throw UnimplementedError(
    'fileStorageServiceProvider must be overridden with the initialized service',
  );
});

/// Provider for the media compression service
final compressionServiceProvider = Provider<MediaCompressionService>((ref) {
  return MediaCompressionService();
});

/// Provider for the photo capture service
final photoCaptureServiceProvider = Provider<PhotoCaptureService>((ref) {
  return PhotoCaptureService(
    permissionService: ref.watch(permissionServiceProvider),
    storageService: ref.watch(fileStorageServiceProvider),
    compressionService: ref.watch(compressionServiceProvider),
  );
});

/// Provider for the voice recording service
final voiceRecordingServiceProvider = Provider<VoiceRecordingService>((ref) {
  return VoiceRecordingService(
    permissionService: ref.watch(permissionServiceProvider),
    storageService: ref.watch(fileStorageServiceProvider),
  );
});

/// Provider for the audio playback service
final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  final service = AudioPlaybackService();
  ref.onDispose(() => service.dispose());
  return service;
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

/// Provider for gentle reminder scheduling service.
/// Must be overridden at app startup after initialization.
final gentleReminderServiceProvider = Provider<GentleReminderService>((ref) {
  throw UnimplementedError(
    'gentleReminderServiceProvider must be overridden with the initialized service',
  );
});

/// Future provider for storage usage (requires async calculation)
final storageUsageProvider = FutureProvider<StorageUsage>((ref) async {
  final service = ref.watch(storageUsageServiceProvider);
  return service.calculateUsage();
});

/// Provider for app lock biometric authentication service.
final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

// ============================================================================
// Prompt System Providers
// ============================================================================

/// Provider for SharedPreferences (must be overridden at startup)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with the initialized SharedPreferences',
  );
});

/// Provider for the prompt repository
final promptRepositoryProvider = Provider<PromptRepository>((ref) {
  return PromptRepository();
});

/// Provider for prompt preferences
final promptPreferencesProvider = Provider<PromptPreferences>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PromptPreferences(prefs);
});

/// Provider for prompt selector
final promptSelectorProvider = Provider<PromptSelector>((ref) {
  return PromptSelector(
    repository: ref.watch(promptRepositoryProvider),
    preferences: ref.watch(promptPreferencesProvider),
  );
});

/// Provider for whether prompts are enabled
final promptsEnabledProvider = Provider<bool>((ref) {
  final selector = ref.watch(promptSelectorProvider);
  return selector.isEnabled;
});

/// Provider for the current prompt to show (or null)
final currentPromptProvider = Provider<GentlePrompt?>((ref) {
  // Check if we already have an entry today
  final entries = ref.watch(entriesProvider);
  final now = DateTime.now();
  final hasEntryToday = entries.any(
    (e) =>
        e.createdAt.year == now.year &&
        e.createdAt.month == now.month &&
        e.createdAt.day == now.day,
  );

  if (hasEntryToday) {
    return null;
  }

  final selector = ref.watch(promptSelectorProvider);
  return selector.getPromptToShow();
});

/// Provider for onboarding preferences
final onboardingPreferencesProvider = Provider<OnboardingPreferences>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingPreferences(prefs);
});

/// Provider for entry type usage tracking (smart button ordering)
final entryTypeUsageServiceProvider = Provider<EntryTypeUsageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return EntryTypeUsageService(prefs);
});

/// Provider for ordered entry types based on usage
final orderedEntryTypesProvider = Provider<List<String>>((ref) {
  final usageService = ref.watch(entryTypeUsageServiceProvider);
  return usageService.getOrderedTypes();
});

// ============================================================================
// AI Services Providers (Phase 4)
// ============================================================================

/// Provider for the ML text analyzer (CoreML on iOS, ML Kit on Android)
final mlTextAnalyzerProvider = Provider<MLTextAnalyzer>((ref) {
  return HybridMLTextAnalyzer();
});

/// Provider for the theme detector service
final themeDetectorProvider = Provider<ThemeDetectorService>((ref) {
  return ThemeDetectorService();
});

/// Provider for the connection finder service
final connectionFinderProvider = Provider<ConnectionFinderService>((ref) {
  return ConnectionFinderService();
});

/// Provider for the suggestion engine
final suggestionEngineProvider = Provider<SuggestionEngine>((ref) {
  final themeDetector = ref.watch(themeDetectorProvider);
  return SuggestionEngine(themeDetector: themeDetector);
});

/// Provider for the ritual detection service.
final ritualDetectionServiceProvider = Provider<RitualDetectionService>((ref) {
  return RitualDetectionService();
});

/// Provider for finding connections for a specific entry
final entryConnectionsProvider = Provider.family<List<MemoryConnection>, int>((
  ref,
  entryId,
) {
  final entries = ref.watch(entriesProvider);
  final entry = entries.where((e) => e.id == entryId).firstOrNull;
  if (entry == null) return [];

  final connectionFinder = ref.watch(connectionFinderProvider);
  return connectionFinder.findConnections(entry, entries);
});

/// Provider for theme distribution across all entries
final themeDistributionProvider = Provider<Map<MemoryTheme, int>>((ref) {
  final entries = ref.watch(entriesProvider);
  final themeDetector = ref.watch(themeDetectorProvider);
  return themeDetector.analyzeDistribution(entries);
});

/// Provider for underrepresented themes
final underrepresentedThemesProvider = Provider<List<MemoryTheme>>((ref) {
  final distribution = ref.watch(themeDistributionProvider);
  final themeDetector = ref.watch(themeDetectorProvider);
  return themeDetector.getUnderrepresentedThemes(distribution);
});

/// Provider for smart suggestion (uses suggestion engine)
final smartSuggestionProvider = Provider<SmartSuggestion?>((ref) {
  final entries = ref.watch(entriesProvider);
  final suggestionEngine = ref.watch(suggestionEngineProvider);
  return suggestionEngine.getNextSuggestion(entries);
});

/// Provider for recurring ritual candidates in recent entries.
final ritualCandidatesProvider = Provider<List<RitualCandidate>>((ref) {
  final entries = ref.watch(allEntriesProvider);
  final detector = ref.watch(ritualDetectionServiceProvider);
  return detector.detectCandidates(entries);
});

// ============================================================================
// Capsule Providers (Phase 4.5)
// ============================================================================

/// Provider for all capsules (locked and unlocked)
final capsulesProvider = Provider<List<Entry>>((ref) {
  final db = ref.watch(databaseProvider);
  // Re-fetch when entries change
  ref.watch(entriesStreamProvider);
  return db.getAllCapsules();
});

/// Provider for locked capsules only
final lockedCapsulesProvider = Provider<List<Entry>>((ref) {
  final capsules = ref.watch(capsulesProvider);
  return capsules.where((c) => c.isLocked).toList();
});

/// Provider for unlocked capsules only
final unlockedCapsulesProvider = Provider<List<Entry>>((ref) {
  final capsules = ref.watch(capsulesProvider);
  return capsules.where((c) => c.isUnlocked).toList();
});

/// Provider for capsules that unlock today
final capsulesToUnlockTodayProvider = Provider<List<Entry>>((ref) {
  final db = ref.watch(databaseProvider);
  ref.watch(entriesStreamProvider);
  return db.getCapsulesToUnlockToday();
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
// Widget Data Provider (Phase 4.5)
// ============================================================================

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

/// Provider that keeps reminder schedule updated as entries change.
final reminderAutoRescheduleProvider = Provider<void>((ref) {
  final entries = ref.watch(allEntriesProvider);
  final reminderSettings = ref.watch(reminderSettingsProvider);
  if (!reminderSettings.enabled) return;
  final reminderService = ref.watch(gentleReminderServiceProvider);
  unawaited(reminderService.reschedule(entries));
});

// ============================================================================
// Voice Transcription Providers (Phase 5)
// ============================================================================

/// Provider for the speech transcription service
final speechTranscriptionServiceProvider = Provider<SpeechTranscriptionService>(
  (ref) {
    return SpeechTranscriptionService();
  },
);

// ============================================================================
// Semantic Search Providers (Phase 5)
// ============================================================================

/// Provider for the semantic search service
final semanticSearchServiceProvider = Provider<SemanticSearchService>((ref) {
  return SemanticSearchService(
    mlAnalyzer: ref.watch(mlTextAnalyzerProvider),
    themeDetector: ref.watch(themeDetectorProvider),
  );
});

// ============================================================================
// Cloud Sync Providers (Phase 5)
// ============================================================================

/// Provider for the CloudKit sync service (native bridge).
final cloudKitSyncServiceProvider = Provider<CloudKitSyncService>((ref) {
  return CloudKitSyncService();
});

/// Provider for secure storage used by sync cryptography.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// Provider for sync payload encryption/decryption.
final syncCryptoServiceProvider = Provider<SyncCryptoService>((ref) {
  return SyncCryptoService(secureStorage: ref.watch(secureStorageProvider));
});

/// Whether a sync passphrase-derived key is configured.
final syncPassphraseConfiguredProvider = FutureProvider<bool>((ref) async {
  return ref.watch(syncCryptoServiceProvider).hasPassphrase();
});

/// Provider for the Google Drive sync service (cross-platform).
final googleDriveSyncServiceProvider = Provider<GoogleDriveSyncService>((ref) {
  return GoogleDriveSyncService();
});

/// Provider for the selected sync backend.
final syncBackendProvider = Provider<SyncBackend>((ref) {
  final providerType = ref.watch(syncProviderTypeProvider);
  if (!Platform.isIOS) {
    return ref.watch(googleDriveSyncServiceProvider);
  }
  return providerType == SyncProviderType.cloudKit
      ? ref.watch(cloudKitSyncServiceProvider)
      : ref.watch(googleDriveSyncServiceProvider);
});

/// Provider for sync metadata (change tokens, pending queue), namespaced by provider.
final syncMetadataProvider = Provider<SyncMetadata>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final providerType = ref.watch(syncProviderTypeProvider);
  return SyncMetadata(prefs, namespace: providerType.name);
});

/// Provider for current sync backend account status text.
final syncAccountStatusProvider = FutureProvider<String>((ref) async {
  final backend = ref.watch(syncBackendProvider);
  return backend.getAccountStatus();
});

/// Provider for whether backend account/session is currently available.
final syncAccountConnectedProvider = FutureProvider<bool>((ref) async {
  final backend = ref.watch(syncBackendProvider);
  return backend.isAvailable();
});

/// Provider for the sync engine.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final fileStorage = ref.watch(fileStorageServiceProvider);
  final engine = SyncEngine(
    database: ref.watch(databaseProvider),
    backend: ref.watch(syncBackendProvider),
    metadata: ref.watch(syncMetadataProvider),
    cryptoService: ref.watch(syncCryptoServiceProvider),
    mediaBasePath: fileStorage.basePath,
  );
  ref.onDispose(() => engine.dispose());
  return engine;
});

/// Provider for current sync state
final syncStateProvider = StreamProvider<SyncState>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.stateStream;
});

/// Provider for whether sync is enabled
final syncEnabledProvider = Provider<bool>((ref) {
  final metadata = ref.watch(syncMetadataProvider);
  return metadata.isEnabled;
});

// ============================================================================
// Year-in-Review Providers (Phase 5)
// ============================================================================

/// Provider for year review data, keyed by year
final reviewDataProvider = Provider.family<YearReviewData?, int>((ref, year) {
  final db = ref.watch(databaseProvider);
  ref.watch(entriesStreamProvider);
  final allEntries = db.getEntriesPage(
    limit: 10000,
    offset: 0,
    year: year,
    includeLockedCapsules: true,
  );
  if (allEntries.length < 10) return null;

  final themeDetector = ref.watch(themeDetectorProvider);
  final generator = ReviewGenerator(themeDetector: themeDetector);
  return generator.generate(year, allEntries);
});

// ============================================================================
// Ritual Providers
// ============================================================================

final ritualServiceProvider = Provider<RitualService>((ref) {
  final db = ref.read(databaseProvider);
  final detector = ref.read(ritualDetectionServiceProvider);
  return RitualService(db, detector);
});

final ritualsStreamProvider = StreamProvider<List<Ritual>>((ref) {
  final db = ref.read(databaseProvider);
  return db.watchRituals();
});

final activeRitualsProvider = Provider<List<Ritual>>((ref) {
  final rituals = ref.watch(ritualsStreamProvider).value ?? [];
  return rituals
      .where((r) => r.statusIndex == RitualStatus.active.index)
      .toList();
});

final dueRitualsProvider = Provider<List<Ritual>>((ref) {
  final active = ref.watch(activeRitualsProvider);
  return active.where((r) => r.isDue).toList();
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
  static const String _key = 'flag_mood_visualization';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, state);
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, value);
  }
}

class _CollageViewFlagNotifier extends Notifier<bool> {
  static const String _key = 'flag_collage_view';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, state);
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, value);
  }
}

/// Provider for collection statistics
final collectionStatsProvider = Provider<MemoryCollectionStats>((ref) {
  final entries = ref.watch(entriesProvider);
  final distribution = ref.watch(themeDistributionProvider);
  final underrepresented = ref.watch(underrepresentedThemesProvider);

  if (entries.isEmpty) {
    return MemoryCollectionStats(
      totalEntries: 0,
      themeDistribution: {},
      averageSentiment: 0.0,
      dominantTheme: null,
      underrepresentedThemes: [],
      entriesPerWeek: 0.0,
    );
  }

  // Calculate average sentiment
  final entriesWithSentiment = entries.where((e) => e.sentimentScore != null);
  final avgSentiment = entriesWithSentiment.isEmpty
      ? 0.0
      : entriesWithSentiment
                .map((e) => e.sentimentScore!)
                .reduce((a, b) => a + b) /
            entriesWithSentiment.length;

  // Find dominant theme
  MemoryTheme? dominant;
  var maxCount = 0;
  for (final entry in distribution.entries) {
    if (entry.value > maxCount && entry.key != MemoryTheme.moments) {
      maxCount = entry.value;
      dominant = entry.key;
    }
  }

  // Calculate entries per week
  final oldestEntry = entries.reduce(
    (a, b) => a.createdAt.isBefore(b.createdAt) ? a : b,
  );
  final weeks = DateTime.now().difference(oldestEntry.createdAt).inDays / 7;
  final entriesPerWeek = weeks > 0
      ? entries.length / weeks
      : entries.length.toDouble();

  return MemoryCollectionStats(
    totalEntries: entries.length,
    themeDistribution: distribution,
    averageSentiment: avgSentiment,
    dominantTheme: dominant,
    underrepresentedThemes: underrepresented,
    entriesPerWeek: entriesPerWeek,
  );
});
