import '../../../data/models/entry.dart';
import 'models/memory_theme.dart';

/// Service for detecting themes in memory entries
///
/// Uses keyword-based scoring to classify entries into themes.
/// Each theme has a set of associated keywords, and the entry
/// is assigned the theme with the highest keyword match score.
class ThemeDetectorService {
  /// Keyword mappings for each theme
  /// More specific keywords score higher
  static const Map<MemoryTheme, List<String>> _themeKeywords = {
    MemoryTheme.family: [
      'mom',
      'dad',
      'mother',
      'father',
      'parent',
      'parents',
      'sister',
      'brother',
      'sibling',
      'siblings',
      'grandma',
      'grandpa',
      'grandmother',
      'grandfather',
      'grandparent',
      'aunt',
      'uncle',
      'cousin',
      'niece',
      'nephew',
      'son',
      'daughter',
      'child',
      'children',
      'kids',
      'baby',
      'wife',
      'husband',
      'spouse',
      'partner',
      'family',
      'home',
      'childhood',
      'grew up',
      'raised',
      'holiday',
      'thanksgiving',
      'christmas',
      'birthday',
      'reunion',
      'gathering',
      'together',
      'love',
    ],
    MemoryTheme.friends: [
      'friend',
      'friends',
      'buddy',
      'pal',
      'hangout',
      'hang out',
      'hung out',
      'hanging',
      'party',
      'celebration',
      'gathering',
      'group',
      'crew',
      'gang',
      'squad',
      'coffee',
      'drinks',
      'dinner',
      'lunch',
      'brunch',
      'laughed',
      'laughing',
      'fun',
      'funny',
      'chat',
      'chatted',
      'talking',
      'talked',
      'met up',
      'meet up',
      'meeting',
      'catch up',
    ],
    MemoryTheme.work: [
      'work',
      'working',
      'worked',
      'job',
      'career',
      'office',
      'meeting',
      'meetings',
      'conference',
      'project',
      'deadline',
      'task',
      'tasks',
      'colleague',
      'coworker',
      'boss',
      'manager',
      'team',
      'presentation',
      'email',
      'emails',
      'call',
      'calls',
      'promotion',
      'raise',
      'achievement',
      'accomplished',
      'client',
      'customer',
      'business',
      'company',
      'productive',
      'success',
      'successful',
      'goal',
      'goals',
    ],
    MemoryTheme.nature: [
      'nature',
      'natural',
      'outside',
      'outdoors',
      'outdoor',
      'sun',
      'sunny',
      'sunset',
      'sunrise',
      'sky',
      'rain',
      'raining',
      'snow',
      'snowing',
      'weather',
      'tree',
      'trees',
      'flower',
      'flowers',
      'plant',
      'plants',
      'garden',
      'gardening',
      'park',
      'forest',
      'woods',
      'mountain',
      'mountains',
      'beach',
      'ocean',
      'sea',
      'lake',
      'river',
      'bird',
      'birds',
      'animal',
      'animals',
      'dog',
      'cat',
      'pet',
      'walk',
      'walking',
      'hike',
      'hiking',
      'fresh air',
      'spring',
      'summer',
      'autumn',
      'fall',
      'winter',
      'season',
    ],
    MemoryTheme.gratitude: [
      'grateful',
      'gratitude',
      'thankful',
      'thanks',
      'thank',
      'appreciate',
      'appreciation',
      'blessed',
      'blessing',
      'lucky',
      'fortunate',
      'gift',
      'gifted',
      'kind',
      'kindness',
      'generous',
      'generosity',
      'help',
      'helped',
      'helping',
      'support',
      'supported',
      'beautiful',
      'wonderful',
      'amazing',
      'awesome',
      'love',
      'loved',
      'loving',
      'caring',
      'care',
    ],
    MemoryTheme.reflection: [
      'think',
      'thinking',
      'thought',
      'thoughts',
      'feel',
      'feeling',
      'felt',
      'feelings',
      'emotion',
      'realize',
      'realized',
      'realization',
      'understand',
      'learn',
      'learned',
      'learning',
      'lesson',
      'grow',
      'growing',
      'growth',
      'change',
      'changing',
      'changed',
      'self',
      'myself',
      'personal',
      'journey',
      'wonder',
      'wondering',
      'curious',
      'question',
      'remember',
      'remembering',
      'memory',
      'memories',
      'hope',
      'hoping',
      'dream',
      'dreaming',
      'future',
      'past',
      'present',
      'life',
      'living',
      'moment',
    ],
    MemoryTheme.travel: [
      'travel',
      'traveling',
      'travelled',
      'trip',
      'trips',
      'vacation',
      'holiday',
      'getaway',
      'flight',
      'flew',
      'flying',
      'plane',
      'airport',
      'train',
      'bus',
      'car',
      'road trip',
      'drive',
      'driving',
      'hotel',
      'stay',
      'stayed',
      'staying',
      'visit',
      'visited',
      'visiting',
      'explore',
      'exploring',
      'city',
      'town',
      'country',
      'place',
      'destination',
      'adventure',
      'adventurous',
      'journey',
      'tourist',
      'sightseeing',
      'landmark',
      'view',
      'views',
    ],
    MemoryTheme.creativity: [
      'create',
      'created',
      'creating',
      'creative',
      'creativity',
      'art',
      'artist',
      'artistic',
      'draw',
      'drawing',
      'paint',
      'painting',
      'write',
      'writing',
      'wrote',
      'writer',
      'story',
      'poem',
      'music',
      'musical',
      'song',
      'sing',
      'singing',
      'play',
      'playing',
      'instrument',
      'guitar',
      'piano',
      'drum',
      'dance',
      'dancing',
      'danced',
      'craft',
      'crafting',
      'make',
      'making',
      'made',
      'build',
      'building',
      'design',
      'designing',
      'photo',
      'photography',
      'imagine',
      'imagination',
      'idea',
      'ideas',
      'inspire',
      'inspired',
    ],
    MemoryTheme.health: [
      'health',
      'healthy',
      'wellness',
      'wellbeing',
      'exercise',
      'exercising',
      'workout',
      'gym',
      'fitness',
      'run',
      'running',
      'ran',
      'jog',
      'jogging',
      'yoga',
      'meditation',
      'meditate',
      'mindful',
      'mindfulness',
      'sleep',
      'sleeping',
      'slept',
      'rest',
      'resting',
      'energy',
      'energetic',
      'tired',
      'exhausted',
      'doctor',
      'appointment',
      'checkup',
      'body',
      'physical',
      'mental',
      'strength',
      'strong',
      'heal',
      'healing',
      'recover',
      'recovery',
    ],
    MemoryTheme.food: [
      'food',
      'eat',
      'eating',
      'ate',
      'meal',
      'meals',
      'breakfast',
      'lunch',
      'dinner',
      'brunch',
      'snack',
      'cook',
      'cooking',
      'cooked',
      'bake',
      'baking',
      'baked',
      'recipe',
      'kitchen',
      'restaurant',
      'cafe',
      'delicious',
      'tasty',
      'yummy',
      'flavor',
      'taste',
      'coffee',
      'tea',
      'drink',
      'drinks',
      'wine',
      'beer',
      'dessert',
      'cake',
      'chocolate',
      'ice cream',
      'vegetable',
      'fruit',
      'meat',
      'fish',
      'pasta',
      'pizza',
      'hungry',
      'full',
      'satisfied',
    ],
    MemoryTheme.moments: [
      // This is the default theme with general keywords
      'today', 'day', 'morning', 'evening', 'night', 'afternoon',
      'just', 'now', 'moment', 'time',
    ],
  };

  /// Detect the theme of an entry
  ///
  /// Returns the theme with the highest keyword match score.
  /// If no meaningful keywords are found, defaults to 'moments'.
  MemoryTheme detectTheme(Entry entry) {
    final content = entry.searchableContent;
    if (content.isEmpty) return MemoryTheme.moments;

    final scores = <MemoryTheme, double>{};
    final contentWords = _tokenize(content);

    for (final theme in MemoryTheme.values) {
      scores[theme] = _calculateThemeScore(content, contentWords, theme);
    }

    // Find highest scoring theme
    var maxScore = 0.0;
    var detectedTheme = MemoryTheme.moments;

    for (final entry in scores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        detectedTheme = entry.key;
      }
    }

    // If the score is too low, default to moments
    if (maxScore < 0.1) {
      return MemoryTheme.moments;
    }

    return detectedTheme;
  }

  /// Calculate theme score for content
  double _calculateThemeScore(
    String content,
    Set<String> contentWords,
    MemoryTheme theme,
  ) {
    final keywords = _themeKeywords[theme] ?? [];
    if (keywords.isEmpty) return 0.0;

    var matchCount = 0;

    for (final keyword in keywords) {
      // Check for exact word match or phrase match
      if (keyword.contains(' ')) {
        // Phrase match
        if (content.contains(keyword)) {
          matchCount += 2; // Phrases score higher
        }
      } else {
        // Single word match
        if (contentWords.contains(keyword)) {
          matchCount++;
        }
      }
    }

    // Normalize by keyword count to avoid bias toward themes with more keywords
    return matchCount / keywords.length;
  }

  /// Get confidence score for detected theme
  double getConfidence(Entry entry, MemoryTheme theme) {
    final content = entry.searchableContent;
    if (content.isEmpty) return 0.0;

    final contentWords = _tokenize(content);
    final score = _calculateThemeScore(content, contentWords, theme);

    // Calculate scores for other themes to determine relative confidence
    var totalScore = 0.0;
    for (final t in MemoryTheme.values) {
      totalScore += _calculateThemeScore(content, contentWords, t);
    }

    if (totalScore == 0) return 0.0;
    return score / totalScore;
  }

  /// Analyze multiple entries and return theme distribution
  Map<MemoryTheme, int> analyzeDistribution(List<Entry> entries) {
    final distribution = <MemoryTheme, int>{};

    for (final theme in MemoryTheme.values) {
      distribution[theme] = 0;
    }

    for (final entry in entries) {
      final theme = entry.hasTheme
          ? MemoryThemeExtension.fromString(entry.detectedTheme) ??
                detectTheme(entry)
          : detectTheme(entry);
      distribution[theme] = (distribution[theme] ?? 0) + 1;
    }

    return distribution;
  }

  /// Get underrepresented themes (less than 5% of entries)
  List<MemoryTheme> getUnderrepresentedThemes(
    Map<MemoryTheme, int> distribution,
  ) {
    final total = distribution.values.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) return [];

    return distribution.entries
        .where((e) => e.value / total < 0.05 && e.key != MemoryTheme.moments)
        .map((e) => e.key)
        .toList();
  }

  /// Tokenize content into lowercase words
  Set<String> _tokenize(String content) {
    return content
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 1)
        .toSet();
  }
}
