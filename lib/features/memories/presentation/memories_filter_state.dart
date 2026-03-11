import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/entry.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/ai/models/memory_theme.dart';
import '../../../core/services/search/semantic_search_service.dart';

/// Sort order for entries
enum SortOrder { newestFirst, oldestFirst }

/// State class for memories filtering and sorting
class MemoriesFilterState {
  final Set<EntryType> typeFilters;
  final Set<MemoryTheme> themeFilters;
  final String searchQuery;
  final SortOrder sortOrder;

  const MemoriesFilterState({
    this.typeFilters = const {},
    this.themeFilters = const {},
    this.searchQuery = '',
    this.sortOrder = SortOrder.newestFirst,
  });

  /// Whether any filters are active
  bool get hasActiveFilters =>
      typeFilters.isNotEmpty ||
      themeFilters.isNotEmpty ||
      searchQuery.isNotEmpty;

  /// Create a copy with updated values
  MemoriesFilterState copyWith({
    Set<EntryType>? typeFilters,
    Set<MemoryTheme>? themeFilters,
    String? searchQuery,
    SortOrder? sortOrder,
  }) {
    return MemoriesFilterState(
      typeFilters: typeFilters ?? this.typeFilters,
      themeFilters: themeFilters ?? this.themeFilters,
      searchQuery: searchQuery ?? this.searchQuery,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// Notifier for managing filter state
class MemoriesFilterNotifier extends Notifier<MemoriesFilterState> {
  @override
  MemoriesFilterState build() => const MemoriesFilterState();

  /// Toggle a type filter on/off
  void toggleTypeFilter(EntryType type) {
    final newFilters = Set<EntryType>.from(state.typeFilters);
    if (newFilters.contains(type)) {
      newFilters.remove(type);
    } else {
      newFilters.add(type);
    }
    state = state.copyWith(typeFilters: newFilters);
  }

  /// Toggle a theme filter on/off
  void toggleThemeFilter(MemoryTheme theme) {
    final newFilters = Set<MemoryTheme>.from(state.themeFilters);
    if (newFilters.contains(theme)) {
      newFilters.remove(theme);
    } else {
      newFilters.add(theme);
    }
    state = state.copyWith(themeFilters: newFilters);
  }

  /// Set the search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clear search query
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  /// Toggle sort order
  void toggleSortOrder() {
    state = state.copyWith(
      sortOrder: state.sortOrder == SortOrder.newestFirst
          ? SortOrder.oldestFirst
          : SortOrder.newestFirst,
    );
  }

  /// Clear all filters
  void clearAllFilters() {
    state = const MemoriesFilterState();
  }

  /// Clear only theme filters
  void clearThemeFilters() {
    state = state.copyWith(themeFilters: {});
  }
}

/// Provider for filter state
final memoriesFilterProvider =
    NotifierProvider<MemoriesFilterNotifier, MemoriesFilterState>(
      MemoriesFilterNotifier.new,
    );

/// Provider for filtered and sorted entries
final filteredEntriesProvider = Provider<List<Entry>>((ref) {
  final filterState = ref.watch(memoriesFilterProvider);
  final baseEntries = filterState.hasActiveFilters
      ? ref.watch(entriesProvider)
      : ref.watch(pagedEntriesProvider);

  // Memory feed excludes capsule entries; capsules have a dedicated screen.
  var filtered = baseEntries.where((e) => !e.isCapsule).toList();

  // Apply type filters (if any selected, show only those types)
  if (filterState.typeFilters.isNotEmpty) {
    filtered = filtered
        .where((e) => filterState.typeFilters.contains(e.type))
        .toList();
  }

  // Apply theme filters (if any selected, show only those themes)
  if (filterState.themeFilters.isNotEmpty) {
    filtered = filtered.where((e) {
      if (!e.hasTheme) return false;
      final theme = MemoryThemeExtension.fromString(e.detectedTheme);
      return theme != null && filterState.themeFilters.contains(theme);
    }).toList();
  }

  // Apply search query — use semantic search for queries >= 3 chars
  if (filterState.searchQuery.isNotEmpty) {
    final query = filterState.searchQuery.toLowerCase();
    // Include transcription and searchableContent in basic search
    filtered = filtered.where((e) {
      if (e.searchableContent.contains(query)) return true;
      if (e.typeName.toLowerCase().contains(query)) return true;
      if (e.hasTheme) {
        final theme = MemoryThemeExtension.fromString(e.detectedTheme);
        if (theme != null && theme.displayName.toLowerCase().contains(query)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  // Apply sort order
  if (filterState.sortOrder == SortOrder.oldestFirst) {
    filtered = filtered.reversed.toList();
  }

  return filtered;
});

/// Async provider for semantic search results (queries >= 3 chars).
/// Returns null when not active, or the search results when ready.
final semanticSearchResultsProvider = FutureProvider<List<SearchResult>?>((
  ref,
) async {
  final filterState = ref.watch(memoriesFilterProvider);
  final query = filterState.searchQuery;

  // Only use semantic search for meaningful queries
  if (query.length < 3) return null;

  final entries = ref.watch(entriesProvider);
  final searchService = ref.watch(semanticSearchServiceProvider);
  final nonCapsules = entries.where((e) => !e.isCapsule).toList();

  return searchService.search(query, nonCapsules);
});
