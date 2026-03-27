import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/ritual.dart';
import '../../../features/tree/domain/tree_personality.dart';
import '../ai/theme_detector_service.dart';
import '../ai/connection_finder_service.dart';
import '../ai/ritual_detection_service.dart';
import '../ai/suggestion_engine.dart';
import '../ai/ml_text_analyzer.dart';
import '../ai/models/memory_connection.dart';
import '../ai/models/memory_theme.dart';
import '../ai/models/ritual_candidate.dart';
import '../ai/models/smart_suggestion.dart';
import '../ai/models/analysis_result.dart';
import '../search/semantic_search_service.dart';
import '../transcription/speech_transcription_service.dart';
import '../ritual/ritual_service.dart';
import '../../../features/review/domain/review_generator.dart';
import 'database_providers.dart';

// ============================================================================
// AI Services Providers (Phase 4)
// ============================================================================

/// Provider for the ML text analyzer (CoreML on iOS, ML Kit on Android)
final mlTextAnalyzerProvider = Provider<MLTextAnalyzer>((ref) {
  return HybridMLTextAnalyzer();
});

/// Provider for the theme detector service
final themeDetectorProvider = Provider<ThemeDetectorService>((ref) {
  return ThemeDetectorService();
});

/// Provider for the connection finder service
final connectionFinderProvider = Provider<ConnectionFinderService>((ref) {
  return ConnectionFinderService();
});

/// Provider for the suggestion engine
final suggestionEngineProvider = Provider<SuggestionEngine>((ref) {
  final themeDetector = ref.watch(themeDetectorProvider);
  return SuggestionEngine(themeDetector: themeDetector);
});

/// Provider for the ritual detection service.
final ritualDetectionServiceProvider = Provider<RitualDetectionService>((ref) {
  return RitualDetectionService();
});

/// Provider for finding connections for a specific entry.
///
/// Uses ref.read (not ref.watch) for the entries list intentionally:
/// connection finding is expensive and should only compute once per entry
/// detail screen visit, not re-run whenever ANY entry in the list changes.
final entryConnectionsProvider = Provider.family<List<MemoryConnection>, int>((
  ref,
  entryId,
) {
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

/// Provider for smart suggestion (uses suggestion engine)
final smartSuggestionProvider = Provider<SmartSuggestion?>((ref) {
  final entries = ref.watch(entriesProvider);
  final suggestionEngine = ref.watch(suggestionEngineProvider);
  return suggestionEngine.getNextSuggestion(entries);
});

/// Provider for recurring ritual candidates in recent entries.
final ritualCandidatesProvider = Provider<List<RitualCandidate>>((ref) {
  final entries = ref.watch(allEntriesProvider);
  final detector = ref.watch(ritualDetectionServiceProvider);
  return detector.detectCandidates(entries);
});

/// Theme counts used by memories filtering UI.
final memoryThemeCountsProvider = Provider<Map<MemoryTheme, int>>((ref) {
  final entries = ref.watch(entriesProvider);
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
      averageSentiment: 0.0,
      dominantTheme: null,
      underrepresentedThemes: [],
      entriesPerWeek: 0.0,
    );
  }

  // Calculate average sentiment
  final entriesWithSentiment = entries.where((e) => e.sentimentScore != null);
  final avgSentiment = entriesWithSentiment.isEmpty
      ? 0.0
      : entriesWithSentiment
                .map((e) => e.sentimentScore!)
                .reduce((a, b) => a + b) /
            entriesWithSentiment.length;

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
    averageSentiment: avgSentiment,
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
// Semantic Search Providers (Phase 5)
// ============================================================================

/// Provider for the semantic search service
final semanticSearchServiceProvider = Provider<SemanticSearchService>((ref) {
  return SemanticSearchService(
    mlAnalyzer: ref.watch(mlTextAnalyzerProvider),
    themeDetector: ref.watch(themeDetectorProvider),
  );
});

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

final activeRitualsProvider = Provider<List<Ritual>>((ref) {
  final rituals = ref.watch(ritualsStreamProvider).value ?? [];
  return rituals
      .where((r) => r.statusIndex == RitualStatus.active.index)
      .toList();
});

final dueRitualsProvider = Provider<List<Ritual>>((ref) {
  final active = ref.watch(activeRitualsProvider);
  return active.where((r) => r.isDue).toList();
});

// ============================================================================
// Year-in-Review Providers (Phase 5)
// ============================================================================

/// Provider for year review data, keyed by year
final reviewDataProvider = Provider.family<YearReviewData?, int>((ref, year) {
  final db = ref.watch(databaseProvider);
  // Watch all-years stream since review can be for any year
  ref.watch(allEntriesStreamProvider);

  // Page through all entries for the year
  final allEntries = <Entry>[];
  const pageSize = 500;
  var offset = 0;
  while (true) {
    final page = db.getEntriesPage(
      limit: pageSize,
      offset: offset,
      year: year,
      includeLockedCapsules: true,
    );
    allEntries.addAll(page);
    if (page.length < pageSize) break;
    offset += pageSize;
  }

  if (allEntries.length < 10) return null;
  final themeDetector = ref.watch(themeDetectorProvider);
  final generator = ReviewGenerator(themeDetector: themeDetector);
  return generator.generate(year, allEntries);
});
