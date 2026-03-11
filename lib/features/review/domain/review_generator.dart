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

  /// Monthly sentiment averages (Jan=1 .. Dec=12).
  final List<MonthSentiment> sentimentArc;

  /// A handful of randomly-picked entries to highlight.
  final List<Entry> memorableMoments;

  /// Human-readable tree growth stage label (e.g. "Sapling").
  final String treeStateLabel;

  /// Number of entries that have at least one connection.
  final int connectionCount;

  const YearReviewData({
    required this.year,
    required this.totalEntries,
    required this.seasons,
    required this.themeDistribution,
    this.dominantTheme,
    required this.sentimentArc,
    required this.memorableMoments,
    required this.treeStateLabel,
    required this.connectionCount,
  });

  /// Whether the user has enough entries (10+) to show a full review.
  bool get hasEnoughEntries => totalEntries >= 10;
}

/// Summary of entries that fall within a single season.
class SeasonData {
  /// Display name (e.g. "Spring").
  final String name;

  /// Number of entries in this season.
  final int entryCount;

  /// First 50 characters of a randomly-chosen entry, or null.
  final String? sampleSnippet;

  const SeasonData({
    required this.name,
    required this.entryCount,
    this.sampleSnippet,
  });
}

/// Average sentiment for a single month.
class MonthSentiment {
  /// 1-based month number (January = 1).
  final int month;

  /// Average of all sentimentScore values; 0.0 when no data.
  final double averageSentiment;

  /// How many entries exist in this month.
  final int entryCount;

  const MonthSentiment({
    required this.month,
    required this.averageSentiment,
    required this.entryCount,
  });
}

/// Generates [YearReviewData] from a flat list of entries.
class ReviewGenerator {
  final ThemeDetectorService _themeDetector;

  ReviewGenerator({required ThemeDetectorService themeDetector})
    : _themeDetector = themeDetector;

  /// Build the review for [year] from [allEntries].
  ///
  /// [allEntries] may contain entries from any year or deleted entries;
  /// only non-deleted entries matching [year] are used.
  YearReviewData generate(int year, List<Entry> allEntries) {
    // Filter to only this year's active entries.
    final entries = allEntries
        .where((e) => !e.isDeleted && e.createdAt.year == year)
        .toList();

    final seasons = _buildSeasons(entries);
    final themeDistribution = _buildThemeDistribution(entries);
    final dominantTheme = _findDominantTheme(themeDistribution);
    final sentimentArc = _buildSentimentArc(entries);
    final memorableMoments = _pickMemorableMoments(entries);
    final treeStateLabel = _treeStateLabelForCount(entries.length);
    final connectionCount = _countConnections(entries);

    return YearReviewData(
      year: year,
      totalEntries: entries.length,
      seasons: seasons,
      themeDistribution: themeDistribution,
      dominantTheme: dominantTheme,
      sentimentArc: sentimentArc,
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
      final snippet = _sampleSnippet(list);
      return MapEntry(
        key,
        SeasonData(
          name: displayName,
          entryCount: list.length,
          sampleSnippet: snippet,
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

  /// Pick a random entry with text and return the first 50 characters.
  String? _sampleSnippet(List<Entry> entries) {
    final withText = entries.where((e) => e.hasText).toList();
    if (withText.isEmpty) return null;
    final pick = withText[Random().nextInt(withText.length)];
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
  // Sentiment arc
  // ---------------------------------------------------------------------------

  List<MonthSentiment> _buildSentimentArc(List<Entry> entries) {
    final monthBuckets = <int, List<double>>{};

    for (final entry in entries) {
      if (entry.sentimentScore != null) {
        monthBuckets
            .putIfAbsent(entry.createdAt.month, () => [])
            .add(entry.sentimentScore!);
      }
    }

    return List.generate(12, (i) {
      final month = i + 1;
      final scores = monthBuckets[month];
      final count = entries.where((e) => e.createdAt.month == month).length;

      if (scores == null || scores.isEmpty) {
        return MonthSentiment(
          month: month,
          averageSentiment: 0.0,
          entryCount: count,
        );
      }

      final avg = scores.reduce((a, b) => a + b) / scores.length;
      return MonthSentiment(
        month: month,
        averageSentiment: avg,
        entryCount: count,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Memorable moments
  // ---------------------------------------------------------------------------

  /// Picks 3-5 random entries, preferring those with text content.
  List<Entry> _pickMemorableMoments(List<Entry> entries) {
    if (entries.isEmpty) return [];

    // Prefer entries with text for richer display.
    final candidates = entries.where((e) => e.hasText).toList();
    final pool = candidates.isNotEmpty ? candidates : entries;

    final shuffled = List.of(pool)..shuffle(Random());
    final pickCount = pool.length.clamp(0, 5);
    return shuffled.take(pickCount).toList();
  }

  // ---------------------------------------------------------------------------
  // Tree state label
  // ---------------------------------------------------------------------------

  /// Derives the tree state label purely from entry count, matching the
  /// thresholds defined in [Tree].
  String _treeStateLabelForCount(int count) {
    if (count >= Tree.thresholds[TreeState.ancientTree]!) return 'Ancient Tree';
    if (count >= Tree.thresholds[TreeState.matureTree]!) return 'Mature Tree';
    if (count >= Tree.thresholds[TreeState.youngTree]!) return 'Young Tree';
    if (count >= Tree.thresholds[TreeState.sapling]!) return 'Sapling';
    if (count >= Tree.thresholds[TreeState.sprout]!) return 'Sprout';
    return 'Seed';
  }

  // ---------------------------------------------------------------------------
  // Connections
  // ---------------------------------------------------------------------------

  /// Count entries that have at least one connection recorded.
  int _countConnections(List<Entry> entries) {
    return entries.where((e) => e.hasConnections).length;
  }
}
