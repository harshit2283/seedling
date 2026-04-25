import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/entry.dart';
import '../../../features/prompts/data/prompt_repository.dart';
import '../../../features/prompts/data/prompt_preferences.dart';
import '../../../features/prompts/domain/prompt_selector.dart';
import '../entry_type_usage_service.dart';
import '../../../features/onboarding/data/onboarding_preferences.dart';
import '../sync/sync_models.dart';
import 'database_providers.dart';
import 'ai_providers.dart';
import 'sync_providers.dart';

// ============================================================================
// Entry Creator
// ============================================================================

/// Notifier for creating entries
class EntryCreatorNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Ensure sync UUID is set on entry before saving, so the UUID gets persisted
  /// in the same DB write. Then queue a sync push after save.
  Future<Entry> _saveAndSync(Entry entry) async {
    final db = ref.read(databaseProvider);
    final syncEngine = ref.read(syncEngineProvider);
    syncEngine.ensureSyncUUID(entry);
    final saved = await db.saveEntry(entry);
    // Record entry type usage for smart button ordering
    await ref
        .read(entryTypeUsageServiceProvider)
        .recordUsage(saved.type, isCapsule: saved.isCapsule);
    syncEngine.queuePush(saved, SyncChangeType.create);
    // Flag the freshly-inserted entry so the memories list can animate it in.
    ref.read(recentlyInsertedEntryIdProvider.notifier).state = saved.id;
    return saved;
  }

  /// Create a LINE entry from text
  Future<Entry> createLineEntry(
    String text, {
    DateTime? capsuleUnlockDate,
  }) async {
    final entry = Entry.line(text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    final saved = await _saveAndSync(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }

  /// Create a RELEASE entry (let go)
  Future<Entry> createReleaseEntry(
    String? text, {
    DateTime? capsuleUnlockDate,
  }) async {
    final entry = Entry.release(text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    final saved = await _saveAndSync(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }

  /// Create a FRAGMENT entry
  Future<Entry> createFragmentEntry(
    String? text, {
    DateTime? capsuleUnlockDate,
  }) async {
    final entry = Entry.fragment(text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    final saved = await _saveAndSync(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }

  /// Create a RITUAL entry from shared text.
  Future<Entry> createRitualEntry(
    String text, {
    DateTime? capsuleUnlockDate,
  }) async {
    final entry = Entry.ritual(title: text, text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    final saved = await _saveAndSync(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }

  /// Create a PHOTO entry
  Future<Entry> createPhotoEntry(
    String mediaPath, {
    String? text,
    DateTime? capsuleUnlockDate,
  }) async {
    final entry = Entry.photo(mediaPath: mediaPath, text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    final saved = await _saveAndSync(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }

  /// Create a VOICE entry
  Future<Entry> createVoiceEntry(
    String mediaPath, {
    String? text,
    DateTime? capsuleUnlockDate,
  }) async {
    final entry = Entry.voice(mediaPath: mediaPath, text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    final saved = await _saveAndSync(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }

  /// Create an OBJECT entry
  Future<Entry> createObjectEntry(
    String title, {
    String? mediaPath,
    String? text,
    DateTime? capsuleUnlockDate,
  }) async {
    final entry = Entry.object(title: title, mediaPath: mediaPath, text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    final saved = await _saveAndSync(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }

  /// Soft delete an entry (recoverable for 30 days)
  Future<bool> deleteEntry(int id) async {
    final db = ref.read(databaseProvider);
    final result = await db.softDeleteEntry(id);
    if (result) {
      // Re-fetch the tombstoned record so sync payload has isDeleted/deletedAt
      final updatedEntry = db.getEntry(id);
      if (updatedEntry != null) {
        ref
            .read(syncEngineProvider)
            .queuePush(updatedEntry, SyncChangeType.update);
      }
    }
    return result;
  }

  /// Permanently delete an entry
  Future<bool> permanentlyDeleteEntry(int id) async {
    final db = ref.read(databaseProvider);
    final entry = db.getEntry(id);
    final result = await db.deleteEntry(id);
    if (result && entry != null && entry.syncUUID != null) {
      ref.read(syncEngineProvider).queuePush(entry, SyncChangeType.delete);
    }
    return result;
  }

  /// Restore a soft-deleted entry
  Future<bool> restoreEntry(int id) async {
    final db = ref.read(databaseProvider);
    final result = await db.restoreEntry(id);
    if (result) {
      final entry = db.getEntry(id);
      if (entry != null) {
        ref.read(syncEngineProvider).queuePush(entry, SyncChangeType.update);
      }
    }
    return result;
  }

  /// Update entry text/title
  Future<void> updateEntryText(int id, {String? text, String? title}) async {
    final db = ref.read(databaseProvider);
    final entry = db.getEntry(id);
    if (entry == null) return;

    if (text != null) entry.text = text;
    if (title != null) entry.title = title;
    db.updateEntry(entry);
    ref.read(syncEngineProvider).queuePush(entry, SyncChangeType.update);
  }

  /// Create a CAPSULE entry (time capsule)
  Future<Entry> createCapsuleEntry(String? text, DateTime unlockDate) async {
    final entry = Entry.capsule(text: text, unlockDate: unlockDate);
    final saved = await _saveAndSync(entry);
    await ref.read(ritualServiceProvider).updateAfterEntry(saved);
    return saved;
  }
}

/// Provider for entry creation operations
final entryCreatorProvider = NotifierProvider<EntryCreatorNotifier, void>(
  EntryCreatorNotifier.new,
);

// ============================================================================
// Prompt System Providers
// ============================================================================

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

/// Holds the id of the most recently inserted entry so the memories list can
/// animate it into view. Cleared automatically after a short window so the
/// animation only plays once per save.
final recentlyInsertedEntryIdProvider = StateProvider<int?>((ref) {
  Timer? timer;
  ref.listenSelf((_, next) {
    timer?.cancel();
    if (next != null) {
      timer = Timer(const Duration(milliseconds: 1500), () {
        if (ref.read(recentlyInsertedEntryIdProvider) == next) {
          ref.read(recentlyInsertedEntryIdProvider.notifier).state = null;
        }
      });
    }
  });
  ref.onDispose(() => timer?.cancel());
  return null;
});
