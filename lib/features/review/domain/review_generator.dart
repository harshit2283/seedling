import 'dart:math';

import '../../../data/models/entry.dart';
import '../../../data/models/tree.dart';
import '../../../core/services/ai/models/memory_theme.dart';
import '../../../core/services/ai/theme_detector_service.dart';

/// Data for a single year-in-review experience.
class YearReviewData {
  /// The year being reviewed.
  final int year;

  /// Total number of non-deleted entries for this year.
  final int totalEntries;

  /// Season-level summaries keyed by 'spring', 'summer', 'autumn', 'winter'.
  final Map<String, SeasonData> seasons;

  /// How many entries were classified under each theme.
  final Map<MemoryTheme, int> themeDistribution;

  /// The most common theme (excluding moments), or null when no entries.
  final MemoryTheme? dominantTheme;

  /// A handful of entries to highlight, photos first. Never includes
  /// released memories (the person chose to let those go) or sealed
  /// capsules.
  final List<Entry> memorableMoments;

  /// Human-readable tree growth stage label (e.g. "Sapling",
  /// "Young tree"), sentence case.
  final String treeStateLabel;

  /// Number of entries that have at least one connection.
  final int connectionCount;

  const YearReviewData({
    required this.year,
    required this.totalEntries,
    required this.seasons,
    required this.themeDistribution,
    this.dominantTheme,
    required this.memorableMoments,
    required this.treeStateLabel,
    required this.connectionCount,
  });

  /// Whether the user has enough entries (10+) to show a full review.
  bool get hasEnoughEntries => totalEntries >= 10;

  /// The growth stage this year's memories add up to.
  TreeState get treeState => treeStateForCount(totalEntries);

  /// Progress (0..1) from [treeState] towards the next stage.
  double get treeProgress => treeProgressForCount(totalEntries);

  /// Whether [year] is over relative to [now] (a finished year is told in
  /// the past tense; the current one is still taking shape).
  bool isFinished(DateTime now) => year < now.year;
}

/// Growth stage for [count] memories, using the thresholds in [Tree].
TreeState treeStateForCount(int count) {
  var state = TreeState.seed;
  for (final s in TreeState.values) {
    if (count >= Tree.thresholds[s]!) state = s;
  }
  return state;
}

/// Progress (0..1) towards the stage after the one [count] reaches.
double treeProgressForCount(int count) {
  final state = treeStateForCount(count);
  if (state == TreeState.ancientTree) return 1;
  final from = Tree.thresholds[state]!;
  final to = Tree.thresholds[TreeState.values[state.index + 1]]!;
  return ((count - from) / (to - from)).clamp(0.0, 1.0);
}

/// Sentence-case stage name ("Young tree"), the app's shared vocabulary.
String treeStageLabel(TreeState state) => switch (state) {
  TreeState.seed => 'Seed',
  TreeState.sprout => 'Sprout',
  TreeState.sapling => 'Sapling',
  TreeState.youngTree => 'Young tree',
  TreeState.matureTree => 'Mature tree',
  TreeState.ancientTree => 'Ancient tree',
};

/// Whether [entry] may be shown back to the person in a review: released
/// memories were let go on purpose, and sealed capsules stay sealed.
bool isReviewable(Entry entry) =>
    !entry.isReleased &&
    entry.type != EntryType.release &&
    !entry.isLocked &&
    !entry.isDeleted;

/// Whether [entry] carries a picture worth showing (photo or object).
bool hasPicture(Entry entry) =>
    entry.hasMedia &&
    (entry.type == EntryType.photo || entry.type == EntryType.object);

/// Summary of entries that fall within a single season.
class SeasonData {
  /// Display name (e.g. "Spring").
  final String name;

  /// Number of entries in this season.
  final int entryCount;

  /// First 50 characters of one of the season's memories, or null.
  final String? sampleSnippet;

  /// Up to four photo or object memories from this season, for a mosaic.
  final List<Entry> photos;

  const SeasonData({
    required this.name,
    required this.entryCount,
    this.sampleSnippet,
    this.photos = const [],
  });
}

/// Generates [YearReviewData] from a flat list of entries.
class ReviewGenerator {
  final ThemeDetectorService _themeDetector;

  ReviewGenerator({required ThemeDetectorService themeDetector})
    : _themeDetector = themeDetector;

  /// Build the review for [year] from [allEntries].
  ///
  /// [allEntries] may contain entries from any year, deleted entries or
  /// locked capsules; only non-deleted entries matching [year] are used, and
  /// locked capsules stay sealed (their content must not surface early).
  YearReviewData generate(int year, List<Entry> allEntries) {
    // Filter to only this year's active, readable entries.
    final entries = allEntries
        .where((e) => !e.isDeleted && !e.isLocked && e.createdAt.year == year)
        .toList();

    final seasons = _buildSeasons(entries);
    final themeDistribution = _buildThemeDistribution(entries);
    final dominantTheme = _findDominantTheme(themeDistribution);
    final memorableMoments = _pickMemorableMoments(entries);
    final treeStateLabel = _treeStateLabelForCount(entries.length);
    final connectionCount = _countConnections(entries);

    return YearReviewData(
      year: year,
      totalEntries: entries.length,
      seasons: seasons,
      themeDistribution: themeDistribution,
      dominantTheme: dominantTheme,
      memorableMoments: memorableMoments,
      treeStateLabel: treeStateLabel,
      connectionCount: connectionCount,
    );
  }

  // ---------------------------------------------------------------------------
  // Seasons
  // ---------------------------------------------------------------------------

  /// Groups entries into four seasons. Season boundaries follow the app's
  /// existing convention: spring = Mar-May, summer = Jun-Aug,
  /// autumn = Sep-Nov, winter = Dec, Jan, Feb.
  Map<String, SeasonData> _buildSeasons(List<Entry> entries) {
    final buckets = <String, List<Entry>>{
      'spring': [],
      'summer': [],
      'autumn': [],
      'winter': [],
    };

    for (final entry in entries) {
      final key = _seasonKey(entry.createdAt.month);
      buckets[key]!.add(entry);
    }

    return buckets.map((key, list) {
      final displayName = _seasonDisplayName(key);
      final shown = list.where(isReviewable).toList();
      final snippet = _sampleSnippet(shown, salt: key.codeUnitAt(0));
      final photos = _pick(
        shown.where(hasPicture).toList(),
        4,
        salt: key.length,
      )..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return MapEntry(
        key,
        SeasonData(
          name: displayName,
          entryCount: list.length,
          sampleSnippet: snippet,
          photos: photos,
        ),
      );
    });
  }

  String _seasonKey(int month) {
    return switch (month) {
      3 || 4 || 5 => 'spring',
      6 || 7 || 8 => 'summer',
      9 || 10 || 11 => 'autumn',
      _ => 'winter', // 12, 1, 2
    };
  }

  String _seasonDisplayName(String key) {
    return switch (key) {
      'spring' => 'Spring',
      'summer' => 'Summer',
      'autumn' => 'Autumn',
      'winter' => 'Winter',
      _ => key,
    };
  }

  /// Pick an entry with text and return the first 50 characters.
  String? _sampleSnippet(List<Entry> entries, {required int salt}) {
    final withText = entries.where((e) => e.hasText).toList();
    if (withText.isEmpty) return null;
    final pick = _pick(withText, 1, salt: salt).first;
    final content = pick.displayContent;
    if (content.length <= 50) return content;
    return '${content.substring(0, 50)}...';
  }

  // ---------------------------------------------------------------------------
  // Theme distribution
  // ---------------------------------------------------------------------------

  Map<MemoryTheme, int> _buildThemeDistribution(List<Entry> entries) {
    return _themeDetector.analyzeDistribution(entries);
  }

  MemoryTheme? _findDominantTheme(Map<MemoryTheme, int> distribution) {
    MemoryTheme? dominant;
    var maxCount = 0;

    for (final entry in distribution.entries) {
      // Skip the generic "moments" bucket for dominance.
      if (entry.key == MemoryTheme.moments) continue;
      if (entry.value > maxCount) {
        maxCount = entry.value;
        dominant = entry.key;
      }
    }

    return dominant;
  }

  // ---------------------------------------------------------------------------
  // Memorable moments
  // ---------------------------------------------------------------------------

  /// Picks up to five moments: up to three pictures first (they carry a
  /// year best), then memories with words. Released memories and sealed
  /// capsules are never picked. The pick is stable for a given year, so
  /// the review does not reshuffle every time it rebuilds.
  List<Entry> _pickMemorableMoments(List<Entry> entries) {
    final pool = entries.where(isReviewable).toList();
    if (pool.isEmpty) return [];

    final pictures = _pick(pool.where(hasPicture).toList(), 3, salt: 7);
    final words = _pick(
      pool.where((e) => !hasPicture(e) && e.hasText).toList(),
      5 - pictures.length,
      salt: 11,
    );
    final picked = [...pictures, ...words];
    if (picked.isEmpty) return _pick(pool, 3, salt: 13);
    picked.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return picked;
  }

  /// [count] entries from [from], chosen deterministically.
  List<Entry> _pick(List<Entry> from, int count, {required int salt}) {
    if (from.isEmpty || count <= 0) return [];
    final sorted = List.of(from)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final year = sorted.first.createdAt.year;
    sorted.shuffle(Random(year * 101 + salt));
    return sorted.take(count).toList();
  }

  // ---------------------------------------------------------------------------
  // Tree state label
  // ---------------------------------------------------------------------------

  /// Derives the tree state label purely from entry count, matching the
  /// thresholds defined in [Tree].
  String _treeStateLabelForCount(int count) =>
      treeStageLabel(treeStateForCount(count));

  // ---------------------------------------------------------------------------
  // Connections
  // ---------------------------------------------------------------------------

  /// Count entries that have at least one connection recorded.
  int _countConnections(List<Entry> entries) {
    return entries.where((e) => e.hasConnections).length;
  }
}
