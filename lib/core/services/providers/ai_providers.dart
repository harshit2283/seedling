import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/ritual.dart';
import '../../../features/tree/domain/tree_personality.dart';
import '../ai/theme_detector_service.dart';
import '../ai/connection_finder_service.dart';
import '../ai/ritual_detection_service.dart';
import '../ai/models/memory_connection.dart';
import '../ai/models/memory_theme.dart';
import '../ai/models/ritual_candidate.dart';
import '../ai/models/analysis_result.dart';
import '../transcription/speech_transcription_service.dart';
import '../ritual/ritual_service.dart';
import '../../../features/review/domain/review_generator.dart';
import 'database_providers.dart';

// ============================================================================
// AI Services Providers (Phase 4)
// ============================================================================

/// Provider for the theme detector service
final themeDetectorProvider = Provider<ThemeDetectorService>((ref) {
  return ThemeDetectorService();
});

/// Provider for the connection finder service
final connectionFinderProvider = Provider<ConnectionFinderService>((ref) {
  return ConnectionFinderService();
});

/// Provider for the ritual detection service.
final ritualDetectionServiceProvider = Provider<RitualDetectionService>((ref) {
  return RitualDetectionService();
});

/// Provider for finding connections for a specific entry.
///
/// Auto-disposed: one instance per visited entry would otherwise live for the
/// whole session. Token sets survive in the ConnectionFinderService cache
/// (keyed by entry id, invalidated when the text changes), so revisits and
/// neighbouring entries skip re-tokenising the collection.
///
/// Uses ref.read (not ref.watch) for the entries list intentionally:
/// connection finding is expensive and should only compute once per entry
/// detail screen visit, not re-run whenever ANY entry in the list changes.
final entryConnectionsProvider = Provider.autoDispose
    .family<List<MemoryConnection>, int>((ref, entryId) {
      // Read entries once instead of watching — avoids re-computing connections
      // every time the entries list changes (e.g. when a new entry is created).
      final entries = ref.read(entriesProvider);
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

/// Memoised tree personality derived from the theme distribution.
final treePersonalityProvider = Provider<TreePersonality>((ref) {
  final distribution = ref.watch(themeDistributionProvider);
  return TreePersonality.fromDistribution(distribution);
});

/// Provider for underrepresented themes
final underrepresentedThemesProvider = Provider<List<MemoryTheme>>((ref) {
  final distribution = ref.watch(themeDistributionProvider);
  final themeDetector = ref.watch(themeDetectorProvider);
  return themeDetector.getUnderrepresentedThemes(distribution);
});

/// Recurring patterns that *could* become rituals. Suggestions only: nothing
/// here is persisted or scheduled until the user confirms a candidate
/// (RitualService.createFromCandidate). Auto-disposed so detection does not
/// keep re-running over every entry after the patterns sheet closes.
final ritualCandidatesProvider = Provider.autoDispose<List<RitualCandidate>>((
  ref,
) {
  final entries = ref.watch(allEntriesProvider);
  final detector = ref.watch(ritualDetectionServiceProvider);
  return detector.detectCandidates(entries);
});

/// Theme counts used by memories filtering UI.
///
/// Auto-disposed so it gets garbage-collected when no UI is watching, and the
/// underlying entries dependency is taken via `select(length)` so transient
/// stream emissions that don't change the entry count don't re-tally.
final memoryThemeCountsProvider = Provider.autoDispose<Map<MemoryTheme, int>>((
  ref,
) {
  ref.watch(entriesProvider.select((entries) => entries.length));
  final entries = ref.read(entriesProvider);
  final distribution = <MemoryTheme, int>{};
  for (final entry in entries) {
    if (entry.isCapsule || !entry.hasTheme) continue;
    final theme = MemoryThemeExtension.fromString(entry.detectedTheme);
    if (theme == null) continue;
    distribution[theme] = (distribution[theme] ?? 0) + 1;
  }
  return distribution;
});

/// Provider for collection statistics
final collectionStatsProvider = Provider<MemoryCollectionStats>((ref) {
  final entries = ref.watch(entriesProvider);
  final distribution = ref.watch(themeDistributionProvider);
  final underrepresented = ref.watch(underrepresentedThemesProvider);

  if (entries.isEmpty) {
    return MemoryCollectionStats(
      totalEntries: 0,
      themeDistribution: {},
      dominantTheme: null,
      underrepresentedThemes: [],
      entriesPerWeek: 0.0,
    );
  }

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
    dominantTheme: dominant,
    underrepresentedThemes: underrepresented,
    entriesPerWeek: entriesPerWeek,
  );
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

// ============================================================================
// Year-in-Review Providers (Phase 5)
// ============================================================================

/// Provider for year review data, keyed by year. Auto-disposed so a year's
/// entries are released once the review screen closes.
final reviewDataProvider = Provider.autoDispose.family<YearReviewData?, int>((
  ref,
  year,
) {
  final db = ref.watch(databaseProvider);
  // Watch all-years stream since review can be for any year
  ref.watch(allEntriesStreamProvider);

  // Page through all entries for the year
  final allEntries = <Entry>[];
  const pageSize = 500;
  var offset = 0;
  while (true) {
    final page = db.getEntriesPage(limit: pageSize, offset: offset, year: year);
    allEntries.addAll(page);
    if (page.length < pageSize) break;
    offset += pageSize;
  }

  if (allEntries.length < 10) return null;
  final themeDetector = ref.watch(themeDetectorProvider);
  final generator = ReviewGenerator(themeDetector: themeDetector);
  return generator.generate(year, allEntries);
});
