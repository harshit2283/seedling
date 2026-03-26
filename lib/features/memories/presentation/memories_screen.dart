import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/ai/models/memory_theme.dart';
import '../../../data/models/entry.dart';
import 'entry_detail_screen.dart';
import 'memory_card.dart';
import 'memories_filter_state.dart';
import 'memory_reader_screen.dart';

/// Screen showing all memories with search, filter, and sort
class MemoriesScreen extends ConsumerStatefulWidget {
  const MemoriesScreen({super.key});

  @override
  ConsumerState<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends ConsumerState<MemoriesScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  bool _isGridView = false;
  int? _selectedEntryId;

  @override
  void initState() {
    super.initState();
    _loadGridPreference();
  }

  Future<void> _loadGridPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => _isGridView = prefs.getBool('memories_grid_view') ?? false,
      );
    }
  }

  Future<void> _toggleGridView() async {
    HapticFeedback.selectionClick();
    final next = !_isGridView;
    setState(() => _isGridView = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('memories_grid_view', next);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      if (value.isEmpty) {
        ref.read(memoriesPageProvider.notifier).reset();
      }
      ref.read(memoriesFilterProvider.notifier).setSearchQuery(value);
    });
  }

  void _cancelPendingSearch() {
    _searchDebounce?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = ref.watch(filteredEntriesProvider);
    final filterState = ref.watch(memoriesFilterProvider);
    final hasAnyEntries = ref.watch(hasNonCapsuleEntriesProvider);
    final hasMoreEntries = filterState.hasActiveFilters
        ? false
        : ref.watch(hasMorePagedEntriesProvider);
    final collageEnabled = ref.watch(collageViewEnabledProvider);

    if (PlatformUtils.isIOS) {
      return _buildIOSLayout(
        context,
        filteredEntries,
        filterState,
        hasAnyEntries,
        hasMoreEntries,
        collageEnabled,
      );
    }
    return _buildAndroidLayout(
      context,
      filteredEntries,
      filterState,
      hasAnyEntries,
      hasMoreEntries,
      collageEnabled,
    );
  }

  Widget _buildIOSLayout(
    BuildContext context,
    List<Entry> filteredEntries,
    MemoriesFilterState filterState,
    bool hasAnyEntries,
    bool hasMoreEntries,
    bool collageEnabled,
  ) {
    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(
          context,
        ).scaffoldBackgroundColor.withValues(alpha: 0.9),
        border: null,
        middle: const Text('Memories'),
        leading: CupertinoNavigationBarBackButton(
          color: SeedlingColors.forestGreen,
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (filteredEntries.isNotEmpty)
              Semantics(
                button: true,
                label: 'Open swipe reader',
                child: CupertinoButton(
                  padding: const EdgeInsets.only(right: 4),
                  onPressed: () => _openReader(context, filteredEntries),
                  child: const Icon(
                    CupertinoIcons.rectangle_stack,
                    color: SeedlingColors.forestGreen,
                    size: 22,
                  ),
                ),
              ),
            if (collageEnabled)
              Semantics(
                button: true,
                label: _isGridView
                    ? 'Switch to list view'
                    : 'Switch to grid view',
                child: CupertinoButton(
                  padding: const EdgeInsets.only(right: 4),
                  onPressed: _toggleGridView,
                  child: Icon(
                    _isGridView
                        ? CupertinoIcons.list_bullet
                        : CupertinoIcons.square_grid_2x2,
                    color: SeedlingColors.forestGreen,
                    size: 22,
                  ),
                ),
              ),
            _buildSortButton(filterState),
          ],
        ),
      ),
      child: SafeArea(
        top: true,
        child: !hasAnyEntries && !filterState.hasActiveFilters
            ? _buildEmptyState(context)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  if (isWide) {
                    return _buildTwoPaneLayout(
                      context,
                      filteredEntries,
                      filterState,
                      hasMoreEntries,
                      collageEnabled,
                    );
                  }
                  return _buildContent(
                    context,
                    filteredEntries,
                    filterState,
                    hasMoreEntries,
                    collageEnabled,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildAndroidLayout(
    BuildContext context,
    List<Entry> filteredEntries,
    MemoriesFilterState filterState,
    bool hasAnyEntries,
    bool hasMoreEntries,
    bool collageEnabled,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memories'),
        leading: IconButton(
          icon: Icon(AdaptiveIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (filteredEntries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.style_outlined),
              color: SeedlingColors.forestGreen,
              tooltip: 'Reader mode',
              onPressed: () => _openReader(context, filteredEntries),
            ),
          if (collageEnabled)
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              color: SeedlingColors.forestGreen,
              tooltip: _isGridView ? 'List view' : 'Grid view',
              onPressed: _toggleGridView,
            ),
          _buildSortButton(filterState),
        ],
      ),
      body: !hasAnyEntries && !filterState.hasActiveFilters
          ? _buildEmptyState(context)
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                if (isWide) {
                  return _buildTwoPaneLayout(
                    context,
                    filteredEntries,
                    filterState,
                    hasMoreEntries,
                    collageEnabled,
                  );
                }
                return _buildContent(
                  context,
                  filteredEntries,
                  filterState,
                  hasMoreEntries,
                  collageEnabled,
                );
              },
            ),
    );
  }

  Widget _buildSortButton(MemoriesFilterState filterState) {
    final isOldest = filterState.sortOrder == SortOrder.oldestFirst;

    if (PlatformUtils.isIOS) {
      return Semantics(
        button: true,
        label: isOldest ? 'Sort oldest first' : 'Sort newest first',
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            HapticFeedback.selectionClick();
            ref.read(memoriesFilterProvider.notifier).toggleSortOrder();
          },
          child: Icon(
            isOldest ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
            color: SeedlingColors.forestGreen,
            size: 22,
          ),
        ),
      );
    }

    return IconButton(
      icon: Icon(isOldest ? Icons.arrow_upward : Icons.arrow_downward),
      color: SeedlingColors.forestGreen,
      tooltip: isOldest ? 'Oldest first' : 'Newest first',
      onPressed: () {
        HapticFeedback.selectionClick();
        ref.read(memoriesFilterProvider.notifier).toggleSortOrder();
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Entry> entries,
    MemoriesFilterState filterState,
    bool hasMoreEntries,
    bool collageEnabled,
  ) {
    return Column(
      children: [
        // Search bar
        _buildSearchBar(context, filterState),
        // Filter chips
        _buildFilterChips(context, filterState),
        // Results
        Expanded(
          child: entries.isEmpty
              ? _buildNoResultsState(context, filterState)
              : _buildMemoriesListOrGrid(context, entries, collageEnabled),
        ),
        if (!filterState.hasActiveFilters && hasMoreEntries)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: PlatformUtils.isIOS
                ? CupertinoButton(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () =>
                        ref.read(memoriesPageProvider.notifier).loadMore(),
                    child: Text(
                      'Load more',
                      style: TextStyle(
                        color:
                            Theme.of(context).textTheme.bodyLarge?.color ??
                            SeedlingColors.textPrimary,
                      ),
                    ),
                  )
                : OutlinedButton(
                    onPressed: () =>
                        ref.read(memoriesPageProvider.notifier).loadMore(),
                    child: const Text('Load more'),
                  ),
          ),
      ],
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    MemoriesFilterState filterState,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: PlatformUtils.isIOS
          ? CupertinoSearchTextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              placeholder: 'Search memories...',
              onChanged: _handleSearchChanged,
              onSuffixTap: () {
                _cancelPendingSearch();
                _searchController.clear();
                ref.read(memoriesPageProvider.notifier).reset();
                ref.read(memoriesFilterProvider.notifier).clearSearch();
                _searchFocusNode.unfocus();
              },
            )
          : TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search memories...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: SeedlingColors.textMuted,
                ),
                suffixIcon: filterState.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: SeedlingColors.textMuted,
                        ),
                        onPressed: () {
                          _cancelPendingSearch();
                          _searchController.clear();
                          ref.read(memoriesPageProvider.notifier).reset();
                          ref
                              .read(memoriesFilterProvider.notifier)
                              .clearSearch();
                          _searchFocusNode.unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).dividerColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _handleSearchChanged,
            ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    MemoriesFilterState filterState,
  ) {
    final themeDistribution = ref.watch(memoryThemeCountsProvider);

    // Get themes that have entries (excluding moments if few entries)
    final activeThemes = themeDistribution.entries
        .where(
          (e) => e.value > 0 && (e.key != MemoryTheme.moments || e.value > 3),
        )
        .map((e) => e.key)
        .toList();

    return Column(
      children: [
        // Type filter chips row
        SizedBox(
          height: 58,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Clear filters button (only show if filters active)
              if (filterState.hasActiveFilters) ...[
                Semantics(
                  button: true,
                  label: 'Clear all filters',
                  child: _buildClearFiltersChip(context),
                ),
                const SizedBox(width: 8),
              ],
              // Type filter chips
              ...EntryType.values.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
                  child: Center(
                    child: _buildFilterChip(context, type, filterState),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Theme filter chips row (only show if there are themes)
        if (activeThemes.isNotEmpty)
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ...activeThemes.map(
                  (theme) => Padding(
                    padding: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
                    child: Center(
                      child: _buildThemeFilterChip(
                        context,
                        theme,
                        filterState,
                        themeDistribution[theme] ?? 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildThemeFilterChip(
    BuildContext context,
    MemoryTheme theme,
    MemoriesFilterState filterState,
    int count,
  ) {
    final isSelected = filterState.themeFilters.contains(theme);
    final color = _getThemeColor(theme);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _cancelPendingSearch();
        ref.read(memoriesPageProvider.notifier).reset();
        ref.read(memoriesFilterProvider.notifier).toggleThemeFilter(theme);
      },
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '${theme.displayName} filter, $count memories',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Theme.of(context).cardTheme.color ??
                      Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                theme.displayName,
                style: TextStyle(
                  color: isSelected ? color : SeedlingColors.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? color : SeedlingColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getThemeColor(MemoryTheme theme) {
    switch (theme) {
      case MemoryTheme.family:
        return SeedlingColors.themeFamily;
      case MemoryTheme.friends:
        return SeedlingColors.themeFriends;
      case MemoryTheme.work:
        return SeedlingColors.themeWork;
      case MemoryTheme.nature:
        return SeedlingColors.themeNature;
      case MemoryTheme.gratitude:
        return SeedlingColors.themeGratitude;
      case MemoryTheme.reflection:
        return SeedlingColors.themeReflection;
      case MemoryTheme.travel:
        return SeedlingColors.themeTravel;
      case MemoryTheme.creativity:
        return SeedlingColors.themeCreativity;
      case MemoryTheme.health:
        return SeedlingColors.themeHealth;
      case MemoryTheme.food:
        return SeedlingColors.themeFood;
      case MemoryTheme.moments:
        return SeedlingColors.themeMoments;
    }
  }

  Widget _buildClearFiltersChip(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _cancelPendingSearch();
        _searchController.clear();
        ref.read(memoriesPageProvider.notifier).reset();
        ref.read(memoriesFilterProvider.notifier).clearAllFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: SeedlingColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PlatformUtils.isIOS ? CupertinoIcons.xmark : Icons.close,
              size: 14,
              color: SeedlingColors.error,
            ),
            const SizedBox(width: 4),
            Text(
              'Clear',
              style: TextStyle(
                color: SeedlingColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    EntryType type,
    MemoriesFilterState filterState,
  ) {
    final isSelected = filterState.typeFilters.contains(type);
    final color = _getTypeColor(type);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _cancelPendingSearch();
        ref.read(memoriesPageProvider.notifier).reset();
        ref.read(memoriesFilterProvider.notifier).toggleTypeFilter(type);
      },
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '${_getTypeName(type)} filter',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getTypeIcon(type),
                size: 14,
                color: isSelected ? color : SeedlingColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                _getTypeName(type),
                style: TextStyle(
                  color: isSelected ? color : SeedlingColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: SeedlingColors.paleGreen.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AdaptiveIcons.leaf,
                size: 40,
                color: SeedlingColors.leafGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No memories yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Your memories will appear here\nas you capture them.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SeedlingColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(
    BuildContext context,
    MemoriesFilterState filterState,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PlatformUtils.isIOS ? CupertinoIcons.search : Icons.search_off,
              size: 48,
              color: SeedlingColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No memories found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              filterState.searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Try changing your filters',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: SeedlingColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _cancelPendingSearch();
                _searchController.clear();
                ref.read(memoriesPageProvider.notifier).reset();
                ref.read(memoriesFilterProvider.notifier).clearAllFilters();
              },
              child: Text(
                'Clear all filters',
                style: TextStyle(color: SeedlingColors.forestGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Two-pane layout for wide screens (tablets / landscape)
  // ─────────────────────────────────────────────────────────────────

  Widget _buildTwoPaneLayout(
    BuildContext context,
    List<Entry> entries,
    MemoriesFilterState filterState,
    bool hasMoreEntries,
    bool collageEnabled,
  ) {
    return Row(
      children: [
        // Left pane: memories list
        Expanded(
          flex: 2,
          child: _buildTwoPaneList(
            context,
            entries,
            filterState,
            hasMoreEntries,
            collageEnabled,
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // Right pane: detail or placeholder
        Expanded(
          flex: 3,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            ),
            child: _selectedEntryId != null
                ? EntryDetailScreen(
                    key: ValueKey(_selectedEntryId),
                    entryId: _selectedEntryId!,
                    embedded: true,
                  )
                : _buildDetailPlaceholder(context),
          ),
        ),
      ],
    );
  }

  Widget _buildTwoPaneList(
    BuildContext context,
    List<Entry> entries,
    MemoriesFilterState filterState,
    bool hasMoreEntries,
    bool collageEnabled,
  ) {
    return Column(
      children: [
        _buildSearchBar(context, filterState),
        _buildFilterChips(context, filterState),
        Expanded(
          child: entries.isEmpty
              ? _buildNoResultsState(context, filterState)
              : _buildTwoPaneMemoriesList(context, entries),
        ),
        if (!filterState.hasActiveFilters && hasMoreEntries)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: PlatformUtils.isIOS
                ? CupertinoButton(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () =>
                        ref.read(memoriesPageProvider.notifier).loadMore(),
                    child: Text(
                      'Load more',
                      style: TextStyle(
                        color:
                            Theme.of(context).textTheme.bodyLarge?.color ??
                            SeedlingColors.textPrimary,
                      ),
                    ),
                  )
                : OutlinedButton(
                    onPressed: () =>
                        ref.read(memoriesPageProvider.notifier).loadMore(),
                    child: const Text('Load more'),
                  ),
          ),
      ],
    );
  }

  Widget _buildTwoPaneMemoriesList(BuildContext context, List<Entry> entries) {
    final groupedEntries = _groupEntriesByDate(entries);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: groupedEntries.length,
      itemBuilder: (context, index) {
        final group = groupedEntries[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                group.dateLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: SeedlingColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...group.entries.map(
              (entry) => MemoryCard(
                entry: entry,
                style: MemoryCardStyle.list,
                onLongPress: () => _showDeleteDialog(context, entry),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedEntryId = entry.id);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailPlaceholder(BuildContext context) {
    return Center(
      key: const ValueKey('placeholder'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PlatformUtils.isIOS
                ? CupertinoIcons.doc_text
                : Icons.article_outlined,
            size: 48,
            color: SeedlingColors.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Select a memory',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: SeedlingColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // List vs Grid switcher
  // ─────────────────────────────────────────────────────────────────

  Widget _buildMemoriesListOrGrid(
    BuildContext context,
    List<Entry> entries,
    bool collageEnabled,
  ) {
    final showGrid = collageEnabled && _isGridView;

    final listWidget = _buildMemoriesList(context, entries);
    final gridWidget = _buildMemoriesGrid(context, entries);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
      child: showGrid
          ? KeyedSubtree(key: const ValueKey('grid'), child: gridWidget)
          : KeyedSubtree(key: const ValueKey('list'), child: listWidget),
    );
  }

  Widget _buildMemoriesList(BuildContext context, List<Entry> entries) {
    // Group entries by date
    final groupedEntries = _groupEntriesByDate(entries);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: groupedEntries.length,
      itemBuilder: (context, index) {
        final group = groupedEntries[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Semantics(
                header: true,
                child: Text(
                  group.dateLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: SeedlingColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Entries for this date
            ...group.entries.map(
              (entry) => MemoryCard(
                entry: entry,
                style: MemoryCardStyle.list,
                onLongPress: () => _showDeleteDialog(context, entry),
                onTap: () {
                  context.push(AppRoutes.entryRoute(entry.id));
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMemoriesGrid(BuildContext context, List<Entry> entries) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final crossAxisCount = isLandscape ? 3 : 2;

    return MasonryGridView.count(
      key: const ValueKey('masonry_grid'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return MemoryCard(
          entry: entry,
          style: MemoryCardStyle.grid,
          onLongPress: () => _showDeleteDialog(context, entry),
          onTap: () {
            context.push(AppRoutes.entryRoute(entry.id));
          },
        );
      },
    );
  }

  List<_DateGroup> _groupEntriesByDate(List<Entry> entries) {
    final groups = <_DateGroup>[];
    String? currentDate;
    List<Entry> currentEntries = [];

    for (final entry in entries) {
      final dateLabel = _getDateLabel(entry.createdAt);

      if (dateLabel != currentDate) {
        if (currentEntries.isNotEmpty) {
          groups.add(_DateGroup(currentDate!, currentEntries));
        }
        currentDate = dateLabel;
        currentEntries = [entry];
      } else {
        currentEntries.add(entry);
      }
    }

    if (currentEntries.isNotEmpty && currentDate != null) {
      groups.add(_DateGroup(currentDate, currentEntries));
    }

    return groups;
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(entryDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return _getDayName(date.weekday);
    } else if (date.year == now.year) {
      return '${_getMonthName(date.month)} ${date.day}';
    } else {
      return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    }
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  void _showDeleteDialog(BuildContext context, Entry entry) {
    HapticFeedback.mediumImpact();

    const title = 'Delete memory?';
    final content = entry.hasText
        ? 'This memory will be moved to trash and can be recovered within 30 days.'
        : 'This ${entry.typeName.toLowerCase()} will be moved to trash and can be recovered within 30 days.';

    if (PlatformUtils.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text(title),
          content: Text(content),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.of(context).pop();
                await ref
                    .read(entryCreatorProvider.notifier)
                    .deleteEntry(entry.id);
                HapticFeedback.lightImpact();
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await ref
                    .read(entryCreatorProvider.notifier)
                    .deleteEntry(entry.id);
                HapticFeedback.lightImpact();
              },
              style: TextButton.styleFrom(
                foregroundColor: SeedlingColors.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    }
  }

  Color _getTypeColor(EntryType type) {
    switch (type) {
      case EntryType.line:
        return SeedlingColors.accentLine;
      case EntryType.photo:
        return SeedlingColors.accentPhoto;
      case EntryType.voice:
        return SeedlingColors.accentVoice;
      case EntryType.object:
        return SeedlingColors.accentObject;
      case EntryType.fragment:
        return SeedlingColors.accentFragment;
      case EntryType.ritual:
        return SeedlingColors.accentRitual;
      case EntryType.release:
        return SeedlingColors.accentRelease;
    }
  }

  IconData _getTypeIcon(EntryType type) {
    if (PlatformUtils.isIOS) {
      switch (type) {
        case EntryType.line:
          return CupertinoIcons.text_quote;
        case EntryType.photo:
          return CupertinoIcons.photo;
        case EntryType.voice:
          return CupertinoIcons.waveform;
        case EntryType.object:
          return CupertinoIcons.cube;
        case EntryType.fragment:
          return CupertinoIcons.sparkles;
        case EntryType.ritual:
          return CupertinoIcons.arrow_2_circlepath;
        case EntryType.release:
          return CupertinoIcons.wind;
      }
    }

    switch (type) {
      case EntryType.line:
        return Icons.format_quote;
      case EntryType.photo:
        return Icons.photo_outlined;
      case EntryType.voice:
        return Icons.graphic_eq;
      case EntryType.object:
        return Icons.category_outlined;
      case EntryType.fragment:
        return Icons.auto_awesome;
      case EntryType.ritual:
        return Icons.loop;
      case EntryType.release:
        return Icons.air;
    }
  }

  String _getTypeName(EntryType type) {
    switch (type) {
      case EntryType.line:
        return 'Line';
      case EntryType.photo:
        return 'Photo';
      case EntryType.voice:
        return 'Voice';
      case EntryType.object:
        return 'Object';
      case EntryType.fragment:
        return 'Fragment';
      case EntryType.ritual:
        return 'Ritual';
      case EntryType.release:
        return 'Release';
    }
  }

  void _openReader(BuildContext context, List<Entry> entries) {
    if (entries.isEmpty) return;
    final selectedId = _selectedEntryId;
    final initialIndex = selectedId == null
        ? 0
        : entries.indexWhere((entry) => entry.id == selectedId);
    context.push(
      AppRoutes.memoryReader,
      extra: MemoryReaderArgs(
        entries: entries,
        initialIndex: initialIndex < 0 ? 0 : initialIndex,
      ),
    );
  }
}

/// Helper class for grouping entries by date
class _DateGroup {
  final String dateLabel;
  final List<Entry> entries;

  _DateGroup(this.dateLabel, this.entries);
}
