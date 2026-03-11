import 'dart:math';
import '../../../data/models/entry.dart';
import 'models/memory_theme.dart';
import 'models/smart_suggestion.dart';
import 'theme_detector_service.dart';

/// Engine for generating smart, personalized suggestions
///
/// Analyzes the user's entry history to identify patterns,
/// gaps in themes, and appropriate times to suggest capture.
class SuggestionEngine {
  final ThemeDetectorService _themeDetector;
  final Random _random;

  SuggestionEngine({ThemeDetectorService? themeDetector, Random? random})
    : _themeDetector = themeDetector ?? ThemeDetectorService(),
      _random = random ?? Random();

  /// Get the next smart suggestion based on entry history
  ///
  /// Returns null if no good suggestion is available.
  SmartSuggestion? getNextSuggestion(List<Entry> entries) {
    if (entries.isEmpty) {
      return _getFirstTimeSuggestion();
    }

    // Collect possible suggestions
    final suggestions = <SmartSuggestion>[];

    // Time-aware suggestions
    final timeSuggestion = _getTimeAwareSuggestion(entries);
    if (timeSuggestion != null) suggestions.add(timeSuggestion);

    // Pattern-based suggestions
    final patternSuggestion = _getPatternBasedSuggestion(entries);
    if (patternSuggestion != null) suggestions.add(patternSuggestion);

    // Gap-filling suggestions
    final gapSuggestion = _getGapFillingSuggestion(entries);
    if (gapSuggestion != null) suggestions.add(gapSuggestion);

    // Anniversary suggestions
    final anniversarySuggestion = _getAnniversarySuggestion(entries);
    if (anniversarySuggestion != null) suggestions.add(anniversarySuggestion);

    if (suggestions.isEmpty) return null;

    // Weight by confidence and return one
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Add some randomness - don't always pick the highest confidence
    if (suggestions.length > 1 && _random.nextDouble() > 0.7) {
      return suggestions[1];
    }

    return suggestions.first;
  }

  /// Get a suggestion for first-time users
  SmartSuggestion _getFirstTimeSuggestion() {
    const prompts = [
      'What made you smile today?',
      'Capture a small moment from your day.',
      'What are you grateful for right now?',
      'Share something you noticed today.',
    ];

    return SmartSuggestion(
      text: prompts[_random.nextInt(prompts.length)],
      type: SuggestionType.timeAware,
      reason: 'Start your memory collection',
      confidence: 1.0,
    );
  }

  /// Get a time-aware suggestion based on current time
  SmartSuggestion? _getTimeAwareSuggestion(List<Entry> entries) {
    final now = DateTime.now();
    final hour = now.hour;

    // Morning suggestions (6-11)
    if (hour >= 6 && hour < 11) {
      return SmartSuggestion(
        text: _getMorningSuggestion(),
        type: SuggestionType.timeAware,
        reason: 'Good morning - perfect time to reflect',
        confidence: 0.6,
      );
    }

    // Afternoon suggestions (11-17)
    if (hour >= 11 && hour < 17) {
      return SmartSuggestion(
        text: _getAfternoonSuggestion(),
        type: SuggestionType.timeAware,
        reason: 'Midday pause for reflection',
        confidence: 0.5,
      );
    }

    // Evening suggestions (17-22)
    if (hour >= 17 && hour < 22) {
      return SmartSuggestion(
        text: _getEveningSuggestion(),
        type: SuggestionType.timeAware,
        reason: 'Evening reflection time',
        confidence: 0.7,
      );
    }

    return null;
  }

  String _getMorningSuggestion() {
    const prompts = [
      'What are you looking forward to today?',
      'How did you sleep? Any dreams worth noting?',
      'What is your intention for today?',
      'Morning thoughts...',
    ];
    return prompts[_random.nextInt(prompts.length)];
  }

  String _getAfternoonSuggestion() {
    const prompts = [
      'How is your day unfolding?',
      'What has surprised you today?',
      'A midday observation...',
      'What are you working on?',
    ];
    return prompts[_random.nextInt(prompts.length)];
  }

  String _getEveningSuggestion() {
    const prompts = [
      'What was the highlight of your day?',
      'What are you grateful for today?',
      'How are you feeling this evening?',
      'What did you learn today?',
      'A moment worth remembering from today...',
    ];
    return prompts[_random.nextInt(prompts.length)];
  }

  /// Get a pattern-based suggestion based on user's entry habits
  SmartSuggestion? _getPatternBasedSuggestion(List<Entry> entries) {
    if (entries.length < 5) return null;

    // Check for day-of-week patterns
    final dayPattern = _analyzeDayPattern(entries);
    if (dayPattern != null) {
      return SmartSuggestion(
        text:
            'You often reflect on ${_getDayName(DateTime.now().weekday)}s. What is on your mind?',
        type: SuggestionType.patternBased,
        reason: 'Based on your ${_getDayName(DateTime.now().weekday)} pattern',
        confidence: dayPattern,
      );
    }

    return null;
  }

  /// Analyze day-of-week entry patterns
  double? _analyzeDayPattern(List<Entry> entries) {
    final now = DateTime.now();
    final today = now.weekday;
    final recentEntries = entries
        .where((e) => now.difference(e.createdAt).inDays < 30)
        .toList();

    if (recentEntries.length < 5) return null;

    final dayCount = <int, int>{};
    for (final entry in recentEntries) {
      final day = entry.createdAt.weekday;
      dayCount[day] = (dayCount[day] ?? 0) + 1;
    }

    final todayCount = dayCount[today] ?? 0;
    final average = recentEntries.length / 7;

    // If today has significantly more entries than average
    if (todayCount > average * 1.5) {
      return 0.6;
    }

    return null;
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

  /// Get a gap-filling suggestion for underrepresented themes
  SmartSuggestion? _getGapFillingSuggestion(List<Entry> entries) {
    if (entries.length < 10) return null;

    final distribution = _themeDetector.analyzeDistribution(entries);
    final gaps = identifyGaps(entries, distribution);

    if (gaps.isEmpty) return null;

    // Pick a significant gap
    final significantGaps = gaps.where((g) => g.isSignificant).toList();
    if (significantGaps.isEmpty) return null;

    final gap = significantGaps[_random.nextInt(significantGaps.length)];
    final prompt = _getGapPrompt(gap.theme);

    return SmartSuggestion(
      text: prompt,
      type: SuggestionType.gapFilling,
      reason:
          'It has been a while since you captured a ${gap.theme.displayName.toLowerCase()} moment',
      targetTheme: gap.theme,
      confidence: 0.5,
    );
  }

  String _getGapPrompt(MemoryTheme theme) {
    switch (theme) {
      case MemoryTheme.family:
        return 'How is your family doing? Any moments to capture?';
      case MemoryTheme.friends:
        return 'When did you last connect with a friend?';
      case MemoryTheme.work:
        return 'Any work accomplishments worth noting?';
      case MemoryTheme.nature:
        return 'Have you noticed anything in nature lately?';
      case MemoryTheme.gratitude:
        return 'What are you thankful for today?';
      case MemoryTheme.reflection:
        return 'What has been on your mind lately?';
      case MemoryTheme.travel:
        return 'Planning any adventures? Or remembering past ones?';
      case MemoryTheme.creativity:
        return 'Created anything lately? Big or small counts.';
      case MemoryTheme.health:
        return 'How are you taking care of yourself?';
      case MemoryTheme.food:
        return 'Any memorable meals or cooking experiences?';
      case MemoryTheme.moments:
        return 'What small moment stood out today?';
    }
  }

  /// Identify gaps in theme coverage
  List<ThemeGap> identifyGaps(
    List<Entry> entries,
    Map<MemoryTheme, int>? existingDistribution,
  ) {
    final distribution =
        existingDistribution ?? _themeDetector.analyzeDistribution(entries);
    final total = distribution.values.fold<int>(0, (sum, count) => sum + count);

    if (total == 0) return [];

    final gaps = <ThemeGap>[];

    // Pre-calculate last entry dates for all themes in one pass
    final lastEntryDates = <MemoryTheme, DateTime>{};
    for (final entry in entries) {
      final theme = MemoryThemeExtension.fromString(entry.detectedTheme);
      if (theme == null) continue;

      final currentLast = lastEntryDates[theme];
      if (currentLast == null || entry.createdAt.isAfter(currentLast)) {
        lastEntryDates[theme] = entry.createdAt;
      }
    }

    for (final theme in MemoryTheme.values) {
      if (theme == MemoryTheme.moments) continue; // Skip default theme

      final count = distribution[theme] ?? 0;
      final percentage = count / total;

      final lastEntryDate = lastEntryDates[theme];

      final daysSince = lastEntryDate != null
          ? DateTime.now().difference(lastEntryDate).inDays
          : 999;

      gaps.add(
        ThemeGap(
          theme: theme,
          percentage: percentage,
          daysSinceLastEntry: daysSince,
        ),
      );
    }

    return gaps;
  }

  /// Get an anniversary suggestion if applicable
  SmartSuggestion? _getAnniversarySuggestion(List<Entry> entries) {
    if (entries.length < 30) return null;

    final today = DateTime.now();
    final lastYear = DateTime(today.year - 1, today.month, today.day);

    // Look for entries from around this time last year
    for (final entry in entries) {
      final daysDiff = entry.createdAt.difference(lastYear).inDays.abs();

      if (daysDiff <= 3 && entry.hasText) {
        return SmartSuggestion(
          text:
              'A year ago you wrote: "${_truncate(entry.text!, 50)}" How have things changed?',
          type: SuggestionType.anniversary,
          reason: 'Memory from this time last year',
          relatedEntryId: entry.id,
          confidence: 0.8,
        );
      }
    }

    return null;
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }
}
