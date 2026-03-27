import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/prefs_keys.dart';
import '../../../data/datasources/local/objectbox_database.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/tree.dart';

// ============================================================================
// Shared Preferences (core dependency used across many provider files)
// ============================================================================

/// Provider for SharedPreferences (must be overridden at startup)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with the initialized SharedPreferences',
  );
});

// ============================================================================
// Database & Entry Providers
// ============================================================================

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

/// Stream provider for all entries across all years (includes locked capsules).
final allEntriesStreamProvider = StreamProvider<List<Entry>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllEntries();
});

/// Provider for all entries across all years (includes locked capsules).
final allEntriesProvider = Provider<List<Entry>>((ref) {
  final allEntriesAsync = ref.watch(allEntriesStreamProvider);
  return allEntriesAsync.value ?? [];
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

/// Scope used for home screen memory previews.
enum HomeFeedScope { currentYear, allYears }

/// Notifier for the home screen feed scope setting.
class HomeFeedScopeNotifier extends Notifier<HomeFeedScope> {
  @override
  HomeFeedScope build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(PrefsKeys.homeFeedScope);
    return raw == HomeFeedScope.allYears.name
        ? HomeFeedScope.allYears
        : HomeFeedScope.currentYear;
  }

  Future<void> setScope(HomeFeedScope scope) async {
    state = scope;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(PrefsKeys.homeFeedScope, scope.name);
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
  // Watch the appropriate stream based on scope.
  if (scope == HomeFeedScope.allYears) {
    ref.watch(allEntriesStreamProvider);
  } else {
    ref.watch(entriesStreamProvider);
  }
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
  // Watch the appropriate stream based on scope.
  if (scope == HomeFeedScope.allYears) {
    ref.watch(allEntriesStreamProvider);
  } else {
    ref.watch(entriesStreamProvider);
  }
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
  bool _disposed = false;

  @override
  bool build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return false;
  }

  void triggerCelebration() {
    state = true;
    // Auto-reset after celebration animation completes
    Future.delayed(const Duration(seconds: 2), () {
      if (!_disposed) {
        state = false;
      }
    });
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

/// Provider for tree state description
final treeDescriptionProvider = Provider<String>((ref) {
  final tree = ref.watch(currentTreeProvider);
  return tree?.stateDescription ?? 'Plant your first memory';
});

/// Provider for object-type entries (for Object Collection Gallery)
final objectEntriesProvider = Provider<List<Entry>>((ref) {
  final db = ref.watch(databaseProvider);
  // Re-evaluate when entries change (objects may span years)
  ref.watch(allEntriesStreamProvider);
  return db.getObjectEntries();
});

/// Provider for soft-deleted entries (for recovery screen)
final deletedEntriesProvider = Provider<List<Entry>>((ref) {
  final db = ref.watch(databaseProvider);
  // Re-fetch when entries change (cross-year data, so watch all entries)
  ref.watch(allEntriesStreamProvider);
  return db.getDeletedEntries();
});

// ============================================================================
// Capsule Providers (Phase 4.5)
// ============================================================================

/// Provider for all capsules (locked and unlocked)
final capsulesProvider = Provider<List<Entry>>((ref) {
  final db = ref.watch(databaseProvider);
  // Re-fetch when entries change (cross-year data, so watch all entries)
  ref.watch(allEntriesStreamProvider);
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

/// Provider for "On This Day" entries from previous years matching today's month/day
final onThisDayProvider = Provider<List<Entry>>((ref) {
  final db = ref.watch(databaseProvider);
  // Watch all entries so we re-evaluate when data changes
  ref.watch(allEntriesStreamProvider);
  return db.getEntriesOnThisDay();
});

/// Provider for capsules that unlock today
final capsulesToUnlockTodayProvider = Provider<List<Entry>>((ref) {
  final db = ref.watch(databaseProvider);
  // Cross-year data, so watch all entries
  ref.watch(allEntriesStreamProvider);
  return db.getCapsulesToUnlockToday();
});

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

/// Provider that reactively resolves linked entries for a given entry.
/// Watches the entries stream so it updates when linked entries change.
final linkedEntriesProvider = Provider.family<List<Entry>, List<String>>((
  ref,
  syncUUIDs,
) {
  final db = ref.watch(databaseProvider);
  // Re-evaluate when entries change (linked entries may span years)
  ref.watch(allEntriesStreamProvider);
  if (syncUUIDs.isEmpty) return [];
  return db.getEntriesBySyncUUIDs(syncUUIDs);
});
