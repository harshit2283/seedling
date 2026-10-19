import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/entry.dart';
import '../../../features/capture/domain/capture_intent.dart';
import '../../../features/prompts/data/prompt_repository.dart';
import '../../../features/prompts/data/prompt_preferences.dart';
import '../../../features/prompts/domain/prompt_selector.dart';
import '../entry_type_usage_service.dart';
import '../../../features/onboarding/data/onboarding_preferences.dart';
import '../sync/sync_models.dart';
import '../error_reporter.dart';
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
  ///
  /// Once `db.saveEntry` returns, the memory is saved: every
  /// later step (usage ordering, sync queue, the insert animation, ritual
  /// streaks) is best-effort. A failure there is reported and swallowed,
  /// never rethrown — otherwise the sheet would say "Could not save" about
  /// a saved memory, a retry would duplicate it, and closing would delete
  /// its media.
  Future<Entry> _saveAndSync(Entry entry) async {
    final db = ref.read(databaseProvider);
    final syncEngine = ref.read(syncEngineProvider);
    syncEngine.ensureSyncUUID(entry);
    // Persist the theme in the same write so theme counts, badges and
    // filters never have to re-run keyword detection over the collection.
    ref.read(themeDetectorProvider).assignTheme(entry);
    final saved = await db.saveEntry(entry);

    final reporter = ref.read(errorReporterProvider);
    Future<void> bestEffort(String step, FutureOr<void> Function() run) async {
      try {
        await run();
      } catch (e, st) {
        reporter.report(e, stack: st, context: 'EntryCreator.$step');
      }
    }

    // Record entry type usage for smart button ordering
    await bestEffort(
      'recordUsage',
      () => ref
          .read(entryTypeUsageServiceProvider)
          .recordUsage(saved.type, isCapsule: saved.isCapsule),
    );
    await bestEffort(
      'queuePush',
      () => syncEngine.queuePush(saved, SyncChangeType.create),
    );
    // Flag the freshly-inserted entry so the memories list can animate it in.
    await bestEffort(
      'markInserted',
      () => ref.read(recentlyInsertedEntryIdProvider.notifier).mark(saved.id),
    );
    await bestEffort(
      'ritualUpdate',
      () => ref.read(ritualServiceProvider).updateAfterEntry(saved),
    );
    return saved;
  }

  /// Create a LINE entry from text
  Future<Entry> createLineEntry(
    String text, {
    DateTime? capsuleUnlockDate,
  }) async {
    final entry = Entry.line(text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    return _saveAndSync(entry);
  }

  /// Create a RELEASE entry (let go)
  Future<Entry> createReleaseEntry(
    String? text, {
    DateTime? capsuleUnlockDate,
  }) async {
    final entry = Entry.release(text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    return _saveAndSync(entry);
  }

  /// Create a FRAGMENT entry
  Future<Entry> createFragmentEntry(
    String? text, {
    DateTime? capsuleUnlockDate,
  }) async {
    final entry = Entry.fragment(text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    return _saveAndSync(entry);
  }

  /// Create a RITUAL entry. [title] names the ritual; [text] defaults to
  /// the title (shared text arrives as a single string).
  Future<Entry> createRitualEntry(
    String title, {
    String? text,
    DateTime? capsuleUnlockDate,
  }) async {
    final entry = Entry.ritual(title: title, text: text ?? title);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    return _saveAndSync(entry);
  }

  /// Create a PHOTO entry
  Future<Entry> createPhotoEntry(
    String mediaPath, {
    String? text,
    DateTime? capsuleUnlockDate,
  }) async {
    final entry = Entry.photo(mediaPath: mediaPath, text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    return _saveAndSync(entry);
  }

  /// Create a VOICE entry
  Future<Entry> createVoiceEntry(
    String mediaPath, {
    String? text,
    DateTime? capsuleUnlockDate,
  }) async {
    final entry = Entry.voice(mediaPath: mediaPath, text: text);
    entry.capsuleUnlockDate = capsuleUnlockDate;
    return _saveAndSync(entry);
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
    return _saveAndSync(entry);
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
    entry.invalidateSearchCache();
    ref.read(themeDetectorProvider).assignTheme(entry);
    db.updateEntry(entry);
    ref.read(syncEngineProvider).queuePush(entry, SyncChangeType.update);
  }

  /// Persist an edit made outside the text fields (manual links, a voice
  /// transcription) and queue it for sync, so it reaches other devices.
  void saveEdit(Entry entry) {
    // A transcription can change the text, so keep the persisted theme true.
    entry.invalidateSearchCache();
    ref.read(themeDetectorProvider).assignTheme(entry);
    ref.read(databaseProvider).updateEntry(entry);
    ref.read(syncEngineProvider).queuePush(entry, SyncChangeType.update);
  }

  /// Create a CAPSULE entry (time capsule)
  Future<Entry> createCapsuleEntry(String? text, DateTime unlockDate) async {
    final entry = Entry.capsule(text: text, unlockDate: unlockDate);
    return _saveAndSync(entry);
  }

  /// Single entry point: build the right entry kind for a [CaptureIntent].
  /// The typed `create*Entry` methods above remain for backwards compat.
  Future<Entry> create(CaptureIntent intent) {
    return switch (intent) {
      LineCapture(:final text, :final capsuleUnlockDate) => createLineEntry(
        text,
        capsuleUnlockDate: capsuleUnlockDate,
      ),
      FragmentCapture(:final text, :final capsuleUnlockDate) =>
        createFragmentEntry(text, capsuleUnlockDate: capsuleUnlockDate),
      ReleaseCapture(:final text, :final capsuleUnlockDate) =>
        createReleaseEntry(text, capsuleUnlockDate: capsuleUnlockDate),
      PhotoCapture(:final mediaPath, :final text, :final capsuleUnlockDate) =>
        createPhotoEntry(
          mediaPath,
          text: text,
          capsuleUnlockDate: capsuleUnlockDate,
        ),
      VoiceCapture(:final mediaPath, :final text, :final capsuleUnlockDate) =>
        createVoiceEntry(
          mediaPath,
          text: text,
          capsuleUnlockDate: capsuleUnlockDate,
        ),
      ObjectCapture(
        :final title,
        :final mediaPath,
        :final text,
        :final capsuleUnlockDate,
      ) =>
        createObjectEntry(
          title,
          mediaPath: mediaPath,
          text: text,
          capsuleUnlockDate: capsuleUnlockDate,
        ),
      RitualCapture(:final title, :final text, :final capsuleUnlockDate) =>
        createRitualEntry(
          title,
          text: text,
          capsuleUnlockDate: capsuleUnlockDate,
        ),
      CapsuleCapture(:final text, :final unlockDate) => createCapsuleEntry(
        text,
        unlockDate,
      ),
    };
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

/// The person's optional capture cue ("When I make my morning coffee").
class CaptureIntentionNotifier extends Notifier<String?> {
  @override
  String? build() => ref.watch(onboardingPreferencesProvider).captureIntention;

  Future<void> set(String? intention) async {
    await ref
        .read(onboardingPreferencesProvider)
        .setCaptureIntention(intention);
    state = ref.read(onboardingPreferencesProvider).captureIntention;
  }
}

final captureIntentionProvider =
    NotifierProvider<CaptureIntentionNotifier, String?>(
      CaptureIntentionNotifier.new,
    );

/// The capture field's hint for a given cue: the person's own words, then a
/// gentle question. Falls back to the default question without a cue.
String captureHintFor(String? intention) {
  const fallback = 'What stayed with you?';
  final cue = intention?.trim().replaceAll(RegExp(r'[\s.,;:!?…—-]+$'), '');
  if (cue == null || cue.isEmpty) return fallback;
  return '$cue… what stayed with you?';
}

/// Set when onboarding ends with "Add your first memory": the home screen
/// opens the capture sheet once it has appeared, then clears this.
class PendingFirstCaptureNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  /// Returns whether a capture was pending, and clears it.
  bool consume() {
    final pending = state;
    if (pending) state = false;
    return pending;
  }
}

final pendingFirstCaptureProvider =
    NotifierProvider<PendingFirstCaptureNotifier, bool>(
      PendingFirstCaptureNotifier.new,
    );

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
class RecentlyInsertedEntryIdNotifier extends Notifier<int?> {
  Timer? _clearTimer;

  @override
  int? build() {
    ref.onDispose(() => _clearTimer?.cancel());
    return null;
  }

  void mark(int id) {
    _clearTimer?.cancel();
    state = id;
    _clearTimer = Timer(const Duration(milliseconds: 1500), () {
      if (state == id) state = null;
    });
  }
}

final recentlyInsertedEntryIdProvider =
    NotifierProvider<RecentlyInsertedEntryIdNotifier, int?>(
      RecentlyInsertedEntryIdNotifier.new,
    );
