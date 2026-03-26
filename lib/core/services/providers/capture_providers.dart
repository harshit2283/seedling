import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/entry.dart';
import '../../../features/prompts/data/prompt_repository.dart';
import '../../../features/prompts/data/prompt_preferences.dart';
import '../../../features/prompts/domain/prompt_selector.dart';
import '../entry_type_usage_service.dart';
import '../../../features/onboarding/data/onboarding_preferences.dart';
import 'database_providers.dart';
import 'ai_providers.dart';

// ============================================================================
// Entry Creator
// ============================================================================

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
