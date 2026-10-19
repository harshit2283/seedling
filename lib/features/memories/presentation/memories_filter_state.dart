import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/entry.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/ai/models/memory_theme.dart';

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

/// Entry types offered as filter chips. Fragment is folded into Line: the
/// capture sheet no longer asks people to tell them apart.
final List<EntryType> filterableEntryTypes = EntryType.values
    .where((t) => t != EntryType.fragment)
    .toList(growable: false);

/// The chip types that have at least one visible memory (across all years;
/// locked capsules and deleted memories don't count). Fragments count as
/// lines, since the Line chip covers them.
final presentEntryTypesProvider = Provider<Set<EntryType>>((ref) {
  final entries = ref.watch(allEntriesProvider);
  return {
    for (final e in entries)
      if (!e.isDeleted && !e.isLocked)
        e.type == EntryType.fragment ? EntryType.line : e.type,
  };
});

/// The type chips worth offering: types the user actually has, plus any
/// that are selected (so a filter can always be seen and cleared).
List<EntryType> visibleFilterTypes(
  Set<EntryType> present,
  Set<EntryType> selected,
) => filterableEntryTypes
    .where((t) => present.contains(t) || selected.contains(t))
    .toList(growable: false);

/// The stored types a set of chip filters matches. "Line" also matches
/// fragments (short lines), including ones saved before the merge.
Set<EntryType> expandTypeFilters(Set<EntryType> filters) => {
  ...filters,
  if (filters.contains(EntryType.line)) EntryType.fragment,
};

/// Provider for filter state
final memoriesFilterProvider =
    NotifierProvider<MemoriesFilterNotifier, MemoriesFilterState>(
      MemoriesFilterNotifier.new,
    );

/// Internal provider that applies type/theme/sort filters but NOT the text
/// query. Recomputes only when the non-text filter parts change, so typing in
/// the search box re-runs only the cheap text filter on the narrowed list.
final _typeAndThemeFilteredProvider = Provider<List<Entry>>((ref) {
  // Select on filter parts that affect this provider so search query edits do
  // not invalidate this computation.
  final typeFilters = ref.watch(
    memoriesFilterProvider.select((s) => s.typeFilters),
  );
  final themeFilters = ref.watch(
    memoriesFilterProvider.select((s) => s.themeFilters),
  );
  final sortOrder = ref.watch(
    memoriesFilterProvider.select((s) => s.sortOrder),
  );
  final hasNonTextFilters = typeFilters.isNotEmpty || themeFilters.isNotEmpty;

  // Search expands the pool to all current-year entries; non-text filters do
  // too because the user may filter older items than the current paged window.
  final searchQuery = ref.watch(
    memoriesFilterProvider.select((s) => s.searchQuery),
  );
  final baseEntries = hasNonTextFilters || searchQuery.isNotEmpty
      ? ref.watch(entriesProvider)
      : ref.watch(pagedEntriesProvider);

  var filtered = baseEntries.where((e) => !e.isCapsule).toList();

  if (typeFilters.isNotEmpty) {
    final types = expandTypeFilters(typeFilters);
    filtered = filtered.where((e) => types.contains(e.type)).toList();
  }

  if (themeFilters.isNotEmpty) {
    filtered = filtered.where((e) {
      if (!e.hasTheme) return false;
      final theme = MemoryThemeExtension.fromString(e.detectedTheme);
      return theme != null && themeFilters.contains(theme);
    }).toList();
  }

  if (sortOrder == SortOrder.oldestFirst) {
    filtered = filtered.reversed.toList();
  }

  return filtered;
});

/// Provider for filtered and sorted entries.
///
/// Composed of [_typeAndThemeFilteredProvider] (heavier, recomputed only when
/// type/theme/sort filters change) plus a cheap text filter applied on top.
final filteredEntriesProvider = Provider<List<Entry>>((ref) {
  final query = ref.watch(memoriesFilterProvider.select((s) => s.searchQuery));
  final base = ref.watch(_typeAndThemeFilteredProvider);

  if (query.isEmpty) return base;

  final lowered = query.toLowerCase();
  return base.where((e) {
    if (e.searchableLower.contains(lowered)) return true;
    if (e.typeName.toLowerCase().contains(lowered)) return true;
    if (e.hasTheme) {
      final theme = MemoryThemeExtension.fromString(e.detectedTheme);
      if (theme != null && theme.displayName.toLowerCase().contains(lowered)) {
        return true;
      }
    }
    return false;
  }).toList();
});
