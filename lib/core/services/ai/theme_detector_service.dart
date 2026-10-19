import 'dart:typed_data';

import '../../../data/models/entry.dart';
import 'models/memory_theme.dart';
import 'stop_words.dart';
import 'theme_lexicon.dart';

/// The text fields of an entry that theme detection reads, as plain data so
/// they can cross into a background isolate (see ThemeBackfillService).
class ThemeInput {
  const ThemeInput({
    this.text,
    this.title,
    this.context,
    this.mood,
    this.transcription,
    this.isRelease = false,
  });

  factory ThemeInput.fromEntry(Entry entry) => ThemeInput(
    text: entry.text,
    title: entry.title,
    context: entry.context,
    mood: entry.mood,
    transcription: entry.transcription,
    isRelease: entry.type == EntryType.release,
  );

  final String? text;
  final String? title;
  final String? context;
  final String? mood;
  final String? transcription;

  /// Letting-go entries lean towards reflection when nothing else is said.
  final bool isRelease;

  bool get isEmpty =>
      _blank(text) &&
      _blank(title) &&
      _blank(context) &&
      _blank(mood) &&
      _blank(transcription);

  static bool _blank(String? s) => s == null || s.trim().isEmpty;
}

/// Result of classifying one entry.
class ThemeAnalysis {
  const ThemeAnalysis({
    required this.primary,
    required this.secondary,
    required this.confidence,
    required this.scores,
  });

  /// The theme to persist and display.
  final MemoryTheme primary;

  /// A second theme with substantial support, or null.
  final MemoryTheme? secondary;

  /// 0..1. For a detected theme: how clearly it beats the alternatives and
  /// how much evidence there is. For a 'moments' fallback: how little
  /// evidence any other theme had.
  final double confidence;

  /// Raw evidence per theme, indexed by [MemoryTheme.index].
  final Float64List scores;

  double scoreOf(MemoryTheme theme) => scores[theme.index];
}

/// Service for detecting themes in memory entries.
///
/// Weighted-lexicon classifier tuned for short, personal memory texts
/// ("coffee with mum on the porch", "first frost on the car"):
///
/// * curated lexicons per theme with weights (theme_lexicon.dart), expanded
///   to common inflections and folded across British/American spelling;
/// * phrase patterns ("letting go", "couch to 5k") and blockers
///   ("running late");
/// * relationship words across languages (mum, nan, abuela, appa, oma…);
/// * emoji, a small destination gazetteer, and capitalised names after
///   "with" (people) or "in"/"to" (places);
/// * typo tolerance (a typo table plus single-edit matches at low weight);
/// * negation damping ("didn't run" still counts, at half weight);
/// * field weights: title > text/transcription > context > mood.
///
/// A theme needs [minimumScore] of evidence; otherwise the entry is
/// 'moments', which therefore means "nothing else applies" rather than
/// "the detector gave up". Inference is a few microseconds per entry.
/// Evaluation: docs/engineering/themes.md.
class ThemeDetectorService {
  /// Evidence a theme needs before it is chosen over 'moments'. A single
  /// defining word (weight >= 1) is enough; weak hints need company.
  static const double minimumScore = 1.0;

  /// A secondary theme needs this share of the primary's score.
  static const double secondaryRatio = 0.5;

  static const double _negatedFactor = 0.5;
  static const double _fuzzyFactor = 0.4;
  static const double _releasePrior = 0.75;

  /// "painted with my daughter" is about painting: a person word right
  /// after "with" is company, not the topic, so it counts a little less.
  static const double _companionFactor = 0.75;
  static const double _placeWeight = 1.25;
  static const double _nameWithWeight = 1.75;
  static const double _nameInWeight = 0.75;

  static const Map<String, double> _fieldWeights = {
    'title': 1.5,
    'text': 1.0,
    'transcription': 1.0,
    'context': 0.75,
    'mood': 0.5,
  };

  /// Tie-break order: the more specific theme wins an exact tie.
  static const List<MemoryTheme> _tieOrder = [
    MemoryTheme.family,
    MemoryTheme.health,
    MemoryTheme.work,
    MemoryTheme.travel,
    MemoryTheme.food,
    MemoryTheme.creativity,
    MemoryTheme.friends,
    MemoryTheme.nature,
    MemoryTheme.gratitude,
    MemoryTheme.reflection,
    MemoryTheme.moments,
  ];

  /// Detect the theme of an entry.
  MemoryTheme detectTheme(Entry entry) =>
      analyze(ThemeInput.fromEntry(entry)).primary;

  /// [detectTheme] over a plain string (treated as the entry's text). Works
  /// on plain data so it can run in a background isolate.
  MemoryTheme detectThemeForContent(String content) =>
      analyze(ThemeInput(text: content)).primary;

  /// Full classification: primary, optional secondary, confidence, scores.
  ThemeAnalysis analyze(ThemeInput input) {
    final scores = Float64List(MemoryTheme.values.length);
    if (input.isEmpty) {
      return ThemeAnalysis(
        primary: MemoryTheme.moments,
        secondary: null,
        confidence: 0,
        scores: scores,
      );
    }
    final lexicon = _CompiledLexicon.instance;
    void field(String? value, String name) {
      if (value == null || value.isEmpty) return;
      lexicon.score(value, _fieldWeights[name]!, scores);
    }

    field(input.title, 'title');
    field(input.text, 'text');
    field(input.transcription, 'transcription');
    field(input.context, 'context');
    field(input.mood, 'mood');
    if (input.isRelease) {
      scores[MemoryTheme.reflection.index] += _releasePrior;
    }
    return _decide(scores);
  }

  ThemeAnalysis _decide(Float64List scores) {
    MemoryTheme? best;
    MemoryTheme? runnerUp;
    for (final theme in _tieOrder) {
      final s = scores[theme.index];
      if (best == null || s > scores[best.index]) {
        runnerUp = best;
        best = theme;
      } else if (runnerUp == null || s > scores[runnerUp.index]) {
        runnerUp = theme;
      }
    }
    final top = scores[best!.index];
    final second = scores[runnerUp!.index];

    if (top < minimumScore) {
      return ThemeAnalysis(
        primary: MemoryTheme.moments,
        secondary: null,
        confidence: 1 - 0.5 * (top / minimumScore),
        scores: scores,
      );
    }

    MemoryTheme? secondary;
    if (runnerUp != MemoryTheme.moments &&
        best != MemoryTheme.moments &&
        second >= minimumScore &&
        second >= top * secondaryRatio) {
      secondary = runnerUp;
    }
    // Margin over the runner-up, discounted when evidence is thin.
    final margin = (top - second) / top;
    final evidence = top / (top + 1.5);
    return ThemeAnalysis(
      primary: best,
      secondary: secondary,
      confidence: (0.5 * margin + 0.5) * evidence,
      scores: scores,
    );
  }

  /// Get confidence score for [theme] on [entry] (0..1).
  double getConfidence(Entry entry, MemoryTheme theme) {
    final analysis = analyze(ThemeInput.fromEntry(entry));
    if (analysis.primary == theme) return analysis.confidence;
    var total = 0.0;
    for (final s in analysis.scores) {
      total += s;
    }
    if (total == 0) return 0.0;
    return analysis.scoreOf(theme) / (total + 1);
  }

  /// The theme name to persist on [entry], or null when it has no text to
  /// classify (an empty fragment, a photo without a note).
  String? themeNameFor(Entry entry) {
    if (entry.searchableContent.isEmpty) return null;
    return detectTheme(entry).name;
  }

  /// Detect and store the theme on [entry]. Call whenever an entry is created
  /// or its text changes, so readers can count persisted themes instead of
  /// re-running detection over the whole collection.
  /// Returns true when the stored value changed.
  bool assignTheme(Entry entry) {
    final name = themeNameFor(entry);
    if (entry.detectedTheme == name) return false;
    entry.detectedTheme = name;
    return true;
  }

  /// The theme of [entry]: the persisted one when present, otherwise
  /// detected on the fly (entries not yet backfilled).
  MemoryTheme themeOf(Entry entry) {
    if (entry.hasTheme) {
      final stored = MemoryThemeExtension.fromString(entry.detectedTheme);
      if (stored != null) return stored;
    }
    return detectTheme(entry);
  }

  /// Analyze multiple entries and return theme distribution.
  ///
  /// Persisted themes make this a plain count; only entries that have not
  /// been themed yet fall back to detection.
  Map<MemoryTheme, int> analyzeDistribution(List<Entry> entries) {
    final distribution = <MemoryTheme, int>{
      for (final theme in MemoryTheme.values) theme: 0,
    };

    for (final entry in entries) {
      final theme = themeOf(entry);
      distribution[theme] = distribution[theme]! + 1;
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
}

/// Text normalisation shared by the lexicon compiler and the scorer, so both
/// sides agree on what a token looks like.
abstract final class ThemeText {
  static final RegExp _token = RegExp(r'[\p{L}\p{N}]+', unicode: true);
  static final RegExp _possessive = RegExp(
    r"['’]s(?![\p{L}\p{N}])",
    unicode: true,
  );
  static final RegExp _apostrophe = RegExp(r"['’]");
  // "I'll" must not become "ill", nor "we'll" "well".
  static final RegExp _willContraction = RegExp(
    r"['’]ll(?![\p{L}\p{N}])",
    unicode: true,
  );
  static final RegExp _ourSuffix = RegExp(
    r'([^aeiou])our(s|ed|ing|ite|ites|able|ful|hood|less)?$',
  );

  static const Map<String, String> _spelling = {
    'grey': 'gray',
    'pyjamas': 'pajamas',
    'aeroplane': 'airplane',
    'practise': 'practice',
    'mould': 'mold',
    'doughnut': 'donut',
    'jewellery': 'jewelry',
    'tyre': 'tire',
    'cosy': 'cozy',
    'mum': 'mum',
    'programme': 'program',
    'cheque': 'check',
    'omelette': 'omelet',
  };

  static final Map<int, int> _fold = () {
    const groups = {
      'a': 'àáâãäåāăą',
      'c': 'çćč',
      'd': 'ďđ',
      'e': 'èéêëēėęě',
      'g': 'ğ',
      'i': 'ìíîïīįı',
      'l': 'łľ',
      'n': 'ñńň',
      'o': 'òóôõöøō',
      'r': 'ř',
      's': 'śšş',
      't': 'ťţ',
      'u': 'ùúûüūůű',
      'y': 'ýÿ',
      'z': 'źżž',
    };
    final map = <int, int>{};
    groups.forEach((plain, accented) {
      for (final r in accented.runes) {
        map[r] = plain.codeUnitAt(0);
      }
    });
    return map;
  }();

  /// Lowercase, strip accents, drop possessive 's and apostrophes.
  static String clean(String raw) {
    final lower = raw.toLowerCase();
    final buffer = StringBuffer();
    var changed = false;
    for (final r in lower.runes) {
      final f = _fold[r];
      if (f != null) changed = true;
      buffer.writeCharCode(f ?? r);
    }
    final folded = changed ? buffer.toString() : lower;
    return folded
        .replaceAll(_willContraction, ' will')
        .replaceAll(_possessive, '')
        .replaceAll(_apostrophe, '');
  }

  /// Raw word tokens of already-[clean]ed text.
  static Iterable<String> words(String cleaned) =>
      _token.allMatches(cleaned).map((m) => m[0]!);

  /// Canonical form of one cleaned token: typo fix, irregular form, then
  /// British -> American spelling.
  static String normalize(String token) {
    var t = commonTypos[token] ?? token;
    t = irregularForms[t] ?? t;
    return spelling(t);
  }

  static String spelling(String t) {
    final mapped = _spelling[t];
    if (mapped != null) return mapped;
    if (t.length <= 4) return t;
    if (t.contains('our')) {
      // colour, flavoured, neighbourhood; not journal, mourning or four.
      t = t.replaceFirstMapped(_ourSuffix, (m) => '${m[1]}or${m[2] ?? ''}');
    }
    for (final suffix in const ['ise', 'ised', 'ises', 'ising', 'isation']) {
      if (t.endsWith(suffix) && t.length > suffix.length + 1) {
        return '${t.substring(0, t.length - suffix.length)}iz'
            '${suffix.substring(2)}';
      }
    }
    for (final suffix in const ['yse', 'ysed', 'ysing']) {
      if (t.endsWith(suffix)) {
        return '${t.substring(0, t.length - suffix.length)}yz'
            '${suffix.substring(2)}';
      }
    }
    if (t.endsWith('tre') && !_isVowel(t.codeUnitAt(t.length - 4))) {
      return '${t.substring(0, t.length - 3)}ter';
    }
    for (final suffix in const ['lled', 'lling', 'ller']) {
      if (t.endsWith(suffix) && t.length > suffix.length + 2) {
        return '${t.substring(0, t.length - suffix.length)}'
            '${suffix.substring(1)}';
      }
    }
    return t;
  }

  static bool _isVowel(int c) =>
      c == 0x61 || c == 0x65 || c == 0x69 || c == 0x6f || c == 0x75;

  static bool _isConsonant(int c) =>
      c >= 0x61 && c <= 0x7a && !_isVowel(c) && c != 0x79;

  /// Common inflections of a base word. Over-generation is harmless: the
  /// extra forms are rarely real words with another meaning.
  static Set<String> inflect(String w) {
    final out = {w};
    if (w.length < 3 || w.codeUnits.any((c) => c < 0x61 || c > 0x7a)) {
      return out;
    }
    final last = w.codeUnitAt(w.length - 1);
    final prev = w.codeUnitAt(w.length - 2);
    final consonantY = last == 0x79 && _isConsonant(prev);
    // Plural / third person.
    if (w.endsWith('s') ||
        w.endsWith('x') ||
        w.endsWith('z') ||
        w.endsWith('ch') ||
        w.endsWith('sh') ||
        w.endsWith('o')) {
      out.add('${w}es');
    }
    if (consonantY) {
      final stem = w.substring(0, w.length - 1);
      out
        ..add('${stem}ies')
        ..add('${stem}ied')
        ..add('${stem}ier')
        ..add('${w}ing');
      return out;
    }
    out.add('${w}s');
    if (last == 0x65) {
      final stem = w.substring(0, w.length - 1);
      out
        ..add('${w}d')
        ..add('${w}r')
        ..add('${stem}ing');
      return out;
    }
    out
      ..add('${w}ed')
      ..add('${w}ing')
      ..add('${w}er');
    final cvc =
        _isConsonant(last) &&
        last != 0x77 &&
        last != 0x78 &&
        _isVowel(prev) &&
        (w.length < 3 || _isConsonant(w.codeUnitAt(w.length - 3)));
    if (cvc) {
      final doubled = w + String.fromCharCode(last);
      out
        ..add('${doubled}ed')
        ..add('${doubled}ing')
        ..add('${doubled}er');
    }
    return out;
  }
}

class _Phrase {
  const _Phrase(this.tokens, this.weights);
  final List<String> tokens;

  /// Null for a blocker phrase.
  final Float64List? weights;
}

/// The lexicon expanded into lookup tables, built once per isolate.
class _CompiledLexicon {
  _CompiledLexicon._() {
    themeLexicon.forEach((theme, terms) {
      terms.forEach((term, weight) => _addTerm(term, theme, weight));
    });
    for (final place in travelPlaces) {
      _addTerm(place, MemoryTheme.travel, ThemeDetectorService._placeWeight);
    }
    for (final blocker in themeBlockerPhrases) {
      final tokens = _termTokens(blocker);
      for (final variant in _phraseVariants(tokens)) {
        _addPhrase(variant, null);
      }
    }
    for (final list in _phrases.values) {
      list.sort((a, b) => b.tokens.length.compareTo(a.tokens.length));
    }
    for (final form in _words.keys) {
      if (form.length < 6) continue;
      for (var i = 0; i < form.length; i++) {
        final deletion = form.substring(0, i) + form.substring(i + 1);
        // Ambiguous deletions map to '' and are ignored.
        final existing = _deletions[deletion];
        _deletions[deletion] = existing == null || existing == form ? form : '';
      }
    }
  }

  static final _CompiledLexicon instance = _CompiledLexicon._();

  final Map<String, Float64List> _words = {};
  final Map<String, List<_Phrase>> _phrases = {};
  final Map<String, String> _deletions = {};

  static const Set<String> _negators = {
    'not',
    'no',
    'never',
    'didnt',
    'dont',
    'doesnt',
    'wasnt',
    'isnt',
    'arent',
    'werent',
    'cant',
    'couldnt',
    'wont',
    'wouldnt',
    'without',
    'hardly',
    'nor',
  };

  static const Set<String> _nonNames = {
    'i',
    'im',
    'ive',
    'id',
    'ill',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
    'god',
    'ok',
    'okay',
    'tv',
    'uk',
    'us',
    'usa',
  };

  static List<String> _termTokens(String term) => [
    for (final w in ThemeText.words(ThemeText.clean(term)))
      ThemeText.normalize(w),
  ];

  static Iterable<List<String>> _phraseVariants(List<String> tokens) sync* {
    final firsts = ThemeText.inflect(tokens.first);
    final lasts = ThemeText.inflect(tokens.last);
    for (final f in firsts) {
      for (final l in lasts) {
        final variant = [...tokens];
        variant[0] = ThemeText.spelling(f);
        variant[variant.length - 1] = ThemeText.spelling(l);
        yield variant;
      }
    }
  }

  void _addTerm(String term, MemoryTheme theme, double weight) {
    final tokens = _termTokens(term);
    if (tokens.isEmpty) return;
    if (tokens.length == 1) {
      for (final form in ThemeText.inflect(tokens.single)) {
        final key = ThemeText.normalize(form);
        final weights = _words.putIfAbsent(
          key,
          () => Float64List(MemoryTheme.values.length),
        );
        if (weight > weights[theme.index]) weights[theme.index] = weight;
      }
      return;
    }
    for (final variant in _phraseVariants(tokens)) {
      final weights = Float64List(MemoryTheme.values.length);
      weights[theme.index] = weight;
      _addPhrase(variant, weights);
    }
  }

  void _addPhrase(List<String> tokens, Float64List? weights) {
    final list = _phrases.putIfAbsent(tokens.first, () => []);
    for (var i = 0; i < list.length; i++) {
      final existing = list[i];
      if (_sameTokens(existing.tokens, tokens)) {
        if (existing.weights == null) return; // blockers win
        if (weights == null) {
          list[i] = _Phrase(tokens, null);
          return;
        }
        for (var t = 0; t < weights.length; t++) {
          if (weights[t] > existing.weights![t]) {
            existing.weights![t] = weights[t];
          }
        }
        return;
      }
    }
    list.add(_Phrase(tokens, weights));
  }

  static bool _sameTokens(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Add the evidence in [raw] (one entry field) to [scores], times [weight].
  void score(String raw, double weight, Float64List scores) {
    _scoreEmoji(raw, weight, scores);
    _scoreNames(raw, weight, scores);

    final tokens = [
      for (final w in ThemeText.words(ThemeText.clean(raw)))
        ThemeText.normalize(w),
    ];
    var i = 0;
    while (i < tokens.length) {
      final negated =
          (i > 0 && _negators.contains(tokens[i - 1])) ||
          (i > 1 && _negators.contains(tokens[i - 2]));
      var factor = weight * (negated ? ThemeDetectorService._negatedFactor : 1);
      if (_isCompanion(tokens, i)) {
        factor *= ThemeDetectorService._companionFactor;
      }

      final phrase = _matchPhrase(tokens, i);
      if (phrase != null) {
        final weights = phrase.weights;
        if (weights != null) _add(scores, weights, factor);
        i += phrase.tokens.length;
        continue;
      }
      final token = tokens[i];
      final hit = _words[token];
      if (hit != null) {
        _add(scores, hit, factor);
      } else if (token.length >= 6 && !commonStopWords.contains(token)) {
        final fuzzy = _fuzzy(token);
        if (fuzzy != null) {
          for (var t = 0; t < fuzzy.length; t++) {
            final w = fuzzy[t];
            if (w > 0) {
              scores[t] +=
                  (w < 2 ? w : 2) * ThemeDetectorService._fuzzyFactor * factor;
            }
          }
        }
      }
      i++;
    }
  }

  static const Set<String> _determiners = {'my', 'our', 'the', 'his', 'her'};

  static bool _isCompanion(List<String> tokens, int i) {
    if (i > 0 && tokens[i - 1] == 'with') return true;
    return i > 1 &&
        tokens[i - 2] == 'with' &&
        _determiners.contains(tokens[i - 1]);
  }

  _Phrase? _matchPhrase(List<String> tokens, int start) {
    final candidates = _phrases[tokens[start]];
    if (candidates == null) return null;
    outer:
    for (final phrase in candidates) {
      final n = phrase.tokens.length;
      if (start + n > tokens.length) continue;
      for (var k = 1; k < n; k++) {
        if (tokens[start + k] != phrase.tokens[k]) continue outer;
      }
      return phrase;
    }
    return null;
  }

  /// One-edit match (extra letter, missing letter, swapped neighbours).
  Float64List? _fuzzy(String token) {
    final omission = _deletions[token];
    if (omission != null && omission.isNotEmpty) return _words[omission];
    for (var i = 0; i < token.length; i++) {
      final deletion = token.substring(0, i) + token.substring(i + 1);
      final hit = _words[deletion];
      if (hit != null) return hit;
    }
    for (var i = 0; i < token.length - 1; i++) {
      final swapped =
          token.substring(0, i) +
          token[i + 1] +
          token[i] +
          token.substring(i + 2);
      final hit = _words[swapped];
      if (hit != null) return hit;
    }
    return null;
  }

  static void _add(Float64List scores, Float64List weights, double factor) {
    for (var t = 0; t < weights.length; t++) {
      final w = weights[t];
      if (w != 0) scores[t] += w * factor;
    }
  }

  void _scoreEmoji(String raw, double weight, Float64List scores) {
    var hasSymbol = false;
    for (final c in raw.codeUnits) {
      if (c >= 0x2190) {
        hasSymbol = true;
        break;
      }
    }
    if (!hasSymbol) return;
    themeEmoji.forEach((emoji, value) {
      if (raw.contains(emoji)) scores[value.$1.index] += value.$2 * weight;
    });
  }

  static final RegExp _casedWord = RegExp(r"[\p{L}][\p{L}'’]*", unicode: true);

  /// Capitalised words that are not sentence-initial and not known words:
  /// after "with"/"and" they are people (friends), after "in"/"to" places
  /// (travel), and "at Tom's" is a friend's place.
  void _scoreNames(String raw, double weight, Float64List scores) {
    final matches = _casedWord.allMatches(raw).toList();
    final seen = <String>{};
    for (var i = 1; i < matches.length; i++) {
      final word = matches[i][0]!;
      final first = word[0];
      if (first == first.toLowerCase() || first != first.toUpperCase()) {
        continue;
      }
      if (word.length > 1 && word == word.toUpperCase()) continue; // CAPS
      if (_sentenceInitial(raw, matches[i].start)) continue;
      final possessive = word.endsWith("'s") || word.endsWith('’s');
      final key = ThemeText.normalize(ThemeText.clean(word));
      if (key.length < 2 ||
          _nonNames.contains(key) ||
          commonStopWords.contains(key) ||
          _words.containsKey(key) ||
          _phrases.containsKey(key) ||
          !seen.add(key)) {
        continue;
      }
      final before = matches[i - 1][0]!.toLowerCase();
      final after = i + 1 < matches.length
          ? matches[i + 1][0]!.toLowerCase()
          : '';
      if (before == 'with' || before == 'and' || after == 'and' || possessive) {
        scores[MemoryTheme.friends.index] +=
            ThemeDetectorService._nameWithWeight * weight;
      } else if (before == 'in' || before == 'to' || before == 'from') {
        scores[MemoryTheme.travel.index] +=
            ThemeDetectorService._nameInWeight * weight;
      }
    }
  }

  static bool _sentenceInitial(String raw, int start) {
    for (var j = start - 1; j >= 0; j--) {
      final c = raw[j];
      if (c == ' ' || c == '\t' || c == '"' || c == '(' || c == '“') continue;
      return c == '.' || c == '!' || c == '?' || c == '\n' || c == ':';
    }
    return true;
  }
}
