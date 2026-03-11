import 'package:flutter/services.dart';
import 'models/memory_theme.dart';

/// Platform-agnostic interface for ML-based text analysis
///
/// Uses CoreML on iOS and ML Kit on Android for on-device NLP processing.
/// Falls back to keyword-based analysis if native ML is unavailable.
abstract class MLTextAnalyzer {
  /// Analyze text and return detected theme
  Future<MemoryTheme> detectTheme(String text);

  /// Calculate sentiment score (-1.0 to 1.0)
  Future<double> analyzeSentiment(String text);

  /// Calculate semantic similarity between two texts (0.0 to 1.0)
  Future<double> calculateSimilarity(String textA, String textB);

  /// Extract key entities/keywords from text
  Future<List<String>> extractKeywords(String text);

  /// Check if ML services are available on this device
  Future<bool> isAvailable();
}

/// Platform channel implementation that bridges to native CoreML/ML Kit
class PlatformMLTextAnalyzer implements MLTextAnalyzer {
  static const _channel = MethodChannel('com.seedling.app/ml_text_analyzer');

  bool? _isAvailableCached;

  @override
  Future<bool> isAvailable() async {
    if (_isAvailableCached != null) return _isAvailableCached!;

    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      _isAvailableCached = result ?? false;
      return _isAvailableCached!;
    } on PlatformException {
      _isAvailableCached = false;
      return false;
    } on MissingPluginException {
      _isAvailableCached = false;
      return false;
    }
  }

  @override
  Future<MemoryTheme> detectTheme(String text) async {
    if (text.isEmpty) return MemoryTheme.moments;

    try {
      final result = await _channel.invokeMethod<String>('detectTheme', {
        'text': text,
      });
      return MemoryThemeExtension.fromString(result) ?? MemoryTheme.moments;
    } on PlatformException {
      return MemoryTheme.moments;
    }
  }

  @override
  Future<double> analyzeSentiment(String text) async {
    if (text.isEmpty) return 0.0;

    try {
      final result = await _channel.invokeMethod<double>('analyzeSentiment', {
        'text': text,
      });
      return result ?? 0.0;
    } on PlatformException {
      return 0.0;
    }
  }

  @override
  Future<double> calculateSimilarity(String textA, String textB) async {
    if (textA.isEmpty || textB.isEmpty) return 0.0;

    try {
      final result = await _channel.invokeMethod<double>(
        'calculateSimilarity',
        {'textA': textA, 'textB': textB},
      );
      return result ?? 0.0;
    } on PlatformException {
      return 0.0;
    }
  }

  @override
  Future<List<String>> extractKeywords(String text) async {
    if (text.isEmpty) return [];

    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'extractKeywords',
        {'text': text},
      );
      return result?.cast<String>() ?? [];
    } on PlatformException {
      return [];
    }
  }
}

/// Hybrid analyzer that uses ML when available, falls back to keyword-based
class HybridMLTextAnalyzer implements MLTextAnalyzer {
  final PlatformMLTextAnalyzer _platformAnalyzer;
  final FallbackTextAnalyzer _fallbackAnalyzer;

  HybridMLTextAnalyzer({
    PlatformMLTextAnalyzer? platformAnalyzer,
    FallbackTextAnalyzer? fallbackAnalyzer,
  }) : _platformAnalyzer = platformAnalyzer ?? PlatformMLTextAnalyzer(),
       _fallbackAnalyzer = fallbackAnalyzer ?? FallbackTextAnalyzer();

  @override
  Future<bool> isAvailable() => _platformAnalyzer.isAvailable();

  @override
  Future<MemoryTheme> detectTheme(String text) async {
    if (await _platformAnalyzer.isAvailable()) {
      return _platformAnalyzer.detectTheme(text);
    }
    return _fallbackAnalyzer.detectTheme(text);
  }

  @override
  Future<double> analyzeSentiment(String text) async {
    if (await _platformAnalyzer.isAvailable()) {
      return _platformAnalyzer.analyzeSentiment(text);
    }
    return _fallbackAnalyzer.analyzeSentiment(text);
  }

  @override
  Future<double> calculateSimilarity(String textA, String textB) async {
    if (await _platformAnalyzer.isAvailable()) {
      return _platformAnalyzer.calculateSimilarity(textA, textB);
    }
    return _fallbackAnalyzer.calculateSimilarity(textA, textB);
  }

  @override
  Future<List<String>> extractKeywords(String text) async {
    if (await _platformAnalyzer.isAvailable()) {
      return _platformAnalyzer.extractKeywords(text);
    }
    return _fallbackAnalyzer.extractKeywords(text);
  }
}

/// Fallback analyzer using keyword matching when ML is unavailable
///
/// This is used when native ML services aren't available or fail.
class FallbackTextAnalyzer implements MLTextAnalyzer {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<MemoryTheme> detectTheme(String text) async {
    // Use keyword-based detection from ThemeDetectorService
    // This is a simplified version - the full implementation is in theme_detector_service.dart
    final content = text.toLowerCase();

    final themeScores = <MemoryTheme, int>{};
    for (final theme in MemoryTheme.values) {
      themeScores[theme] = _countKeywordMatches(content, theme);
    }

    var maxTheme = MemoryTheme.moments;
    var maxScore = 0;
    for (final entry in themeScores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        maxTheme = entry.key;
      }
    }

    return maxTheme;
  }

  int _countKeywordMatches(String content, MemoryTheme theme) {
    const keywords = {
      MemoryTheme.family: [
        'mom',
        'dad',
        'family',
        'sister',
        'brother',
        'parent',
        'child',
        'kids',
      ],
      MemoryTheme.friends: [
        'friend',
        'friends',
        'hangout',
        'party',
        'fun',
        'laughed',
      ],
      MemoryTheme.work: [
        'work',
        'job',
        'meeting',
        'project',
        'office',
        'career',
      ],
      MemoryTheme.nature: [
        'nature',
        'outside',
        'sun',
        'rain',
        'tree',
        'flower',
        'walk',
        'hike',
      ],
      MemoryTheme.gratitude: [
        'grateful',
        'thankful',
        'appreciate',
        'blessed',
        'lucky',
      ],
      MemoryTheme.reflection: [
        'think',
        'feel',
        'realize',
        'learn',
        'wonder',
        'remember',
      ],
      MemoryTheme.travel: [
        'travel',
        'trip',
        'vacation',
        'flight',
        'visit',
        'explore',
      ],
      MemoryTheme.creativity: [
        'create',
        'art',
        'write',
        'music',
        'make',
        'design',
      ],
      MemoryTheme.health: [
        'health',
        'exercise',
        'workout',
        'run',
        'yoga',
        'sleep',
      ],
      MemoryTheme.food: [
        'food',
        'eat',
        'cook',
        'meal',
        'dinner',
        'lunch',
        'breakfast',
      ],
      MemoryTheme.moments: ['today', 'day', 'moment'],
    };

    final themeKeywords = keywords[theme] ?? [];
    var count = 0;
    for (final keyword in themeKeywords) {
      if (content.contains(keyword)) count++;
    }
    return count;
  }

  @override
  Future<double> analyzeSentiment(String text) async {
    // Simple keyword-based sentiment analysis
    final tokens = _tokenize(text);

    const positiveWords = {
      'happy',
      'joy',
      'love',
      'great',
      'wonderful',
      'amazing',
      'beautiful',
      'grateful',
      'thankful',
      'excited',
      'fun',
      'good',
      'best',
      'awesome',
    };
    const negativeWords = {
      'sad',
      'angry',
      'hate',
      'bad',
      'terrible',
      'awful',
      'worst',
      'worried',
      'anxious',
      'stressed',
      'frustrated',
      'disappointed',
      'upset',
    };

    var score = 0.0;
    score += tokens.intersection(positiveWords).length * 0.1;
    score -= tokens.intersection(negativeWords).length * 0.1;

    return score.clamp(-1.0, 1.0);
  }

  @override
  Future<double> calculateSimilarity(String textA, String textB) async {
    // Simple Jaccard similarity
    final wordsA = _tokenize(textA);
    final wordsB = _tokenize(textB);

    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;

    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;

    return union > 0 ? intersection / union : 0.0;
  }

  Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .toSet();
  }

  @override
  Future<List<String>> extractKeywords(String text) async {
    // Extract nouns and significant words
    final words = _tokenize(text);

    // Filter out common stop words
    final stopWords = {
      'the',
      'and',
      'for',
      'are',
      'but',
      'not',
      'you',
      'all',
      'can',
      'had',
      'her',
      'was',
      'one',
      'our',
      'out',
      'get',
      'has',
      'him',
      'his',
      'how',
      'its',
      'may',
      'now',
      'old',
      'see',
      'way',
      'who',
      'did',
      'got',
      'let',
      'put',
      'say',
      'she',
      'too',
      'use',
      'been',
      'call',
      'come',
      'each',
      'find',
      'from',
      'have',
      'into',
      'know',
      'like',
      'look',
      'made',
      'make',
      'many',
      'more',
      'most',
      'much',
      'must',
      'need',
      'only',
      'over',
      'said',
      'some',
      'such',
      'take',
      'than',
      'that',
      'them',
      'then',
      'there',
      'these',
      'they',
      'this',
      'time',
      'very',
      'want',
      'well',
      'went',
      'what',
      'when',
      'will',
      'with',
      'would',
      'your',
      'about',
      'after',
      'also',
      'back',
      'being',
      'both',
      'could',
      'down',
      'even',
      'going',
      'here',
    };

    return words.difference(stopWords).take(10).toList();
  }
}
