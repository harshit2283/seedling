import 'dart:math' as math;

import '../../../data/models/entry.dart';
import 'models/memory_connection.dart';
import 'models/memory_theme.dart';
import 'stop_words.dart';
import 'theme_detector_service.dart';
import 'theme_lexicon.dart';

/// Service for finding connections between memory entries ("Related
/// memories").
///
/// Signals, strongest first:
/// * text: TF-IDF cosine over the user's own collection, on normalised,
///   lightly stemmed terms, so a rare shared word ("kiln", "Lisbon")
///   counts far more than a common one ("today");
/// * people and places: shared names and relationship words (mum/mom/
///   mother are one person), weighted by how rare they are;
/// * theme: same or related persisted theme;
/// * time: proximity within a week.
///
/// Theme and time only rank; they never create a connection on their own,
/// so two unrelated entries from the same week are not "related".
/// Evaluation: docs/engineering/themes.md.
class ConnectionFinderService {
  /// Minimum similarity score to consider a connection meaningful
  static const double _minimumThreshold = 0.3;

  /// Content evidence (text or shared people/places) a pair needs before
  /// theme and time are allowed to count.
  static const double _minimumContent = 0.05;

  /// Maximum number of connections to return per entry
  static const int _maxConnections = 5;

  /// Days within which temporal proximity bonus applies
  static const int _temporalWindowDays = 7;

  /// Token sets per entry id, tagged with the content they came from. A
  /// stale entry (edited text) misses because its content no longer matches,
  /// so edits invalidate themselves without explicit bookkeeping.
  final Map<int, _TokenSets> _tokenCache = {};

  /// Document frequencies for the last collection seen, rebuilt when a
  /// different list is passed in or any of its entries changed.
  _CorpusStats? _corpus;
  List<Entry>? _corpusSource;

  /// Drop all cached token sets (tests, memory pressure).
  void clearTokenCache() {
    _tokenCache.clear();
    _corpus = null;
    _corpusSource = null;
  }

  /// Forget one entry's tokens, e.g. after it is deleted.
  void evictTokens(int entryId) {
    _tokenCache.remove(entryId);
    _corpus = null;
    _corpusSource = null;
  }

  _TokenSets _tokensFor(Entry entry) {
    final content = entry.searchableContent;
    final cached = _tokenCache[entry.id];
    if (cached != null &&
        (identical(cached.content, content) || cached.content == content)) {
      return cached;
    }
    final sets = _TokenSets.build(content, entry);
    // Unsaved entries (id 0) share a key, so never cache them.
    if (entry.id != 0) _tokenCache[entry.id] = sets;
    return sets;
  }

  _CorpusStats _corpusFor(List<Entry> entries) {
    final docs = [
      for (final e in entries)
        if (!e.isDeleted) _tokensFor(e),
    ];
    final cached = _corpus;
    if (cached != null &&
        identical(_corpusSource, entries) &&
        cached.isBuiltFrom(docs)) {
      return cached;
    }
    final stats = _CorpusStats(docs);
    _corpus = stats;
    _corpusSource = entries;
    return stats;
  }

  /// Find connections for a specific entry
  ///
  /// Returns a list of related entries sorted by similarity score.
  List<MemoryConnection> findConnections(Entry entry, List<Entry> allEntries) {
    if (entry.searchableContent.isEmpty) return [];

    final corpus = _corpusFor(allEntries);
    final source = _tokensFor(entry);
    final sourceNorm = corpus.norm(source);
    final sourceEntities = corpus.entities(source);
    final connections = <MemoryConnection>[];

    for (final candidate in allEntries) {
      // Skip self and deleted entries
      if (candidate.id == entry.id || candidate.isDeleted) continue;
      final other = _tokensFor(candidate);

      final text = corpus.cosine(source, sourceNorm, other);
      final people = corpus.entityOverlap(
        sourceEntities,
        corpus.entities(other),
      );
      if (text < _minimumContent && people == 0) continue;

      final factors = ConnectionFactors(
        textSimilarity: text,
        temporalBonus: _calculateTemporalBonus(entry, candidate),
        themeBonus: _calculateThemeBonus(entry, candidate),
        entityBonus: people,
      );
      final score = factors.total;
      if (score >= _minimumThreshold) {
        connections.add(
          MemoryConnection(
            relatedEntry: candidate,
            similarityScore: score,
            factors: factors,
          ),
        );
      }
    }

    // Sort by similarity score (highest first); newer first on ties.
    connections.sort((a, b) {
      final byScore = b.similarityScore.compareTo(a.similarityScore);
      if (byScore != 0) return byScore;
      return b.relatedEntry.createdAt.compareTo(a.relatedEntry.createdAt);
    });

    return connections.take(_maxConnections).toList();
  }

  /// Calculate temporal proximity bonus
  ///
  /// Entries within the same week get a bonus.
  double _calculateTemporalBonus(Entry a, Entry b) {
    final daysDifference = a.createdAt.difference(b.createdAt).inDays.abs();

    if (daysDifference <= 1) return 1.0; // Same day or adjacent
    if (daysDifference <= _temporalWindowDays) {
      // Linear decay over the window
      return 1.0 - (daysDifference / _temporalWindowDays);
    }
    return 0.0;
  }

  /// Calculate shared theme bonus
  ///
  /// Entries with the same theme get a bonus. 'moments' means "no theme",
  /// so two unthemed entries do not share anything.
  double _calculateThemeBonus(Entry a, Entry b) {
    if (!a.hasTheme || !b.hasTheme) return 0.0;

    final themeA = MemoryThemeExtension.fromString(a.detectedTheme);
    final themeB = MemoryThemeExtension.fromString(b.detectedTheme);

    if (themeA == null || themeB == null) return 0.0;
    if (themeA == MemoryTheme.moments || themeB == MemoryTheme.moments) {
      return 0.0;
    }
    if (themeA == themeB) return 1.0;

    // Partial bonus for related themes
    if (_areThemesRelated(themeA, themeB)) return 0.5;

    return 0.0;
  }

  /// Check if two themes are related
  bool _areThemesRelated(MemoryTheme a, MemoryTheme b) {
    final relatedGroups = [
      {MemoryTheme.family, MemoryTheme.friends},
      {MemoryTheme.nature, MemoryTheme.travel, MemoryTheme.health},
      {MemoryTheme.reflection, MemoryTheme.gratitude},
      {MemoryTheme.creativity, MemoryTheme.work},
      {MemoryTheme.food, MemoryTheme.friends},
    ];

    for (final group in relatedGroups) {
      if (group.contains(a) && group.contains(b)) return true;
    }

    return false;
  }

  /// Get IDs of connected entries as comma-separated string
  String getConnectionIdsString(List<MemoryConnection> connections) {
    return connections.map((c) => c.relatedEntry.id.toString()).join(',');
  }

  /// Calculate overall similarity between two entries (0.0 to 1.0), using
  /// the pair itself as the collection.
  double calculateSimilarity(Entry a, Entry b) {
    final ta = _tokensFor(a), tb = _tokensFor(b);
    final corpus = _CorpusStats([ta, tb]);
    return ConnectionFactors(
      textSimilarity: corpus.cosine(ta, corpus.norm(ta), tb),
      temporalBonus: _calculateTemporalBonus(a, b),
      themeBonus: _calculateThemeBonus(a, b),
      entityBonus: corpus.entityOverlap(
        corpus.entities(ta),
        corpus.entities(tb),
      ),
    ).total;
  }
}

/// Per-entry features, cached by entry id and invalidated by content.
class _TokenSets {
  _TokenSets(
    this.content,
    this.terms,
    this.relations,
    this.capitalised,
    this.lowercase,
  );

  factory _TokenSets.build(String content, Entry entry) {
    final terms = <String>{};
    for (final w in ThemeText.words(ThemeText.clean(content))) {
      final term = _term(w);
      if (term != null) terms.add(term);
    }

    // Case matters for names, so read the raw fields.
    final relations = <String>{};
    final capitalised = <String>{};
    final lowercase = <String>{};
    for (final field in [
      entry.text,
      entry.title,
      entry.context,
      entry.transcription,
    ]) {
      if (field == null || field.isEmpty) continue;
      var previous = '';
      for (final m in _word.allMatches(field)) {
        final raw = m[0]!;
        final before = previous;
        previous = raw;
        final key = ThemeText.normalize(ThemeText.clean(raw));
        if (key.length < 2) continue;
        final person = _relationWords[key];
        if (person != null) {
          // "her mum" or "Priya's mum" is someone else's mum.
          if (!_othersPossessive(before)) relations.add(person);
          continue;
        }
        final first = raw[0];
        final isCapital =
            first != first.toLowerCase() &&
            !(raw.length > 1 && raw == raw.toUpperCase());
        (isCapital ? capitalised : lowercase).add(key);
      }
    }
    return _TokenSets(
      content,
      terms,
      relations,
      capitalised..removeAll(lowercase),
      lowercase,
    );
  }

  final String content;

  /// Normalised, stemmed content terms without stop words.
  final Set<String> terms;

  /// Canonical relationship words ('mum' for mum/mom/mother...).
  final Set<String> relations;

  /// Words written capitalised (and never lowercase) in this entry.
  final Set<String> capitalised;

  /// Words written lowercase in this entry.
  final Set<String> lowercase;

  static bool _othersPossessive(String word) {
    final w = word.toLowerCase();
    return w == 'her' ||
        w == 'his' ||
        w == 'their' ||
        w == 'your' ||
        w.endsWith("'s") ||
        w.endsWith('’s');
  }

  static final RegExp _word = RegExp(r"[\p{L}][\p{L}'’]*", unicode: true);

  static const Set<String> _extraStopWords = {
    'his',
    'her',
    'she',
    'him',
    'they',
    'them',
    'their',
    'our',
    'ours',
    'myself',
    'yourself',
    'it',
    'its',
    'were',
    'was',
    'is',
    'are',
    'am',
    'be',
    'been',
    'do',
    'does',
    'did',
    'didnt',
    'dont',
    'im',
    'ive',
    'ill',
    'id',
    'just',
    'really',
    'very',
    'so',
    'too',
    'got',
    'get',
    'today',
    'tonight',
    'yesterday',
    'day',
    'thing',
    'things',
    'again',
    'everyone',
    'everything',
    'nothing',
    'someone',
    'something',
    'all',
    'still',
    'only',
    'ever',
    'never',
    'why',
    'what',
    'who',
    'which',
    'off',
    'out',
    'up',
    'down',
    'over',
    'into',
    'onto',
    'till',
    'until',
    'without',
    'within',
    'around',
    'about',
    'every',
    'away',
    'next',
    'last',
    'week',
    'month',
    'minute',
    'hour',
    'time',
    'lot',
    'night',
    'morning',
    'evening',
    'afternoon',
  };

  /// Lightly stemmed term for matching, or null for a stop word / number.
  static String? _term(String word) {
    if (word.length < 2) return null;
    if (_allDigits(word)) return null;
    final normal = ThemeText.normalize(word);
    // mum/mom/mother match as one word, as they are one person.
    final person = _relationWords[normal];
    if (person != null) return person;
    if (normal.length < 3 && !_hasDigit(normal)) return null;
    if (commonStopWords.contains(normal) || _extraStopWords.contains(normal)) {
      return null;
    }
    return stem(normal);
  }

  static bool _allDigits(String s) {
    for (final c in s.codeUnits) {
      if (c < 0x30 || c > 0x39) return false;
    }
    return true;
  }

  static bool _hasDigit(String s) =>
      s.codeUnits.any((c) => c >= 0x30 && c <= 0x39);

  /// Strip common suffixes so 'cups'/'cup' and 'glazed'/'glaze' match.
  static String stem(String t) {
    if (t.length <= 3) return t;
    if (t.endsWith('ies') && t.length > 4) {
      t = '${t.substring(0, t.length - 3)}y';
    } else if (t.endsWith('ing') && t.length > 5) {
      t = _undouble(t.substring(0, t.length - 3));
    } else if (t.endsWith('ed') && t.length > 4) {
      t = _undouble(t.substring(0, t.length - 2));
    } else if (t.endsWith('ses') ||
        t.endsWith('xes') ||
        t.endsWith('ches') ||
        t.endsWith('shes') ||
        t.endsWith('oes')) {
      t = t.substring(0, t.length - 2);
    } else if (t.endsWith('s') &&
        !t.endsWith('ss') &&
        !t.endsWith('us') &&
        !t.endsWith('is')) {
      t = t.substring(0, t.length - 1);
    }
    if (t.endsWith('e') && t.length > 4) t = t.substring(0, t.length - 1);
    return t;
  }

  static String _undouble(String t) {
    if (t.length < 3) return t;
    final a = t.codeUnitAt(t.length - 1), b = t.codeUnitAt(t.length - 2);
    if (a == b &&
        !'lsfz'.codeUnits.contains(a) &&
        !'aeiou'.codeUnits.contains(a)) {
      return t.substring(0, t.length - 1);
    }
    return t;
  }

  /// Relationship words, folded to one key per person.
  static final Map<String, String> _relationWords = () {
    const groups = {
      'mum': [
        'mum',
        'mom',
        'mam',
        'mother',
        'mommy',
        'mummy',
        'mama',
        'mamma',
        'amma',
        'ammi',
        'maman',
      ],
      'dad': [
        'dad',
        'daddy',
        'father',
        'papa',
        'pops',
        'baba',
        'appa',
        'abba',
        'abbu',
      ],
      'grandad': [
        'grandad',
        'granddad',
        'grandpa',
        'grandfather',
        'opa',
        'abuelo',
        'nonno',
        'dziadek',
        'zayde',
        'lolo',
        'papou',
      ],
      'grandma': [
        'grandma',
        'grandmother',
        'gran',
        'granny',
        'nan',
        'nana',
        'nanna',
        'oma',
        'abuela',
        'nonna',
        'babcia',
        'bubbe',
        'lola',
        'yiayia',
        'dadi',
        'nani',
      ],
      'aunt': ['aunt', 'auntie', 'aunty'],
      'sister': ['sister', 'sis'],
      'brother': ['brother'],
      'son': ['son'],
      'daughter': ['daughter'],
      'wife': ['wife'],
      'husband': ['husband', 'hubby'],
      'uncle': ['uncle'],
      'cousin': ['cousin'],
      'niece': ['niece'],
      'nephew': ['nephew'],
      'partner': ['partner'],
      'baby': ['baby', 'newborn'],
    };
    return {
      for (final MapEntry(key: person, value: words) in groups.entries)
        for (final w in words) ThemeText.normalize(w): person,
    };
  }();
}

/// Collection-level statistics: document frequencies and which capitalised
/// words are names rather than sentence starts.
class _CorpusStats {
  _CorpusStats(this._docs) : size = _docs.length {
    final docs = _docs;
    final capitalisedDf = <String, int>{};
    for (final d in docs) {
      for (final t in d.terms) {
        _df[t] = (_df[t] ?? 0) + 1;
      }
      for (final r in d.relations) {
        _df['@$r'] = (_df['@$r'] ?? 0) + 1;
      }
      _lowercaseSeen.addAll(d.lowercase);
      for (final c in d.capitalised) {
        capitalisedDf[c] = (capitalisedDf[c] ?? 0) + 1;
      }
    }
    capitalisedDf.forEach((word, df) => _df['@$word'] = df);
    _maxIdf = _idf(1);
  }

  final int size;
  final List<_TokenSets> _docs;

  /// True when [docs] are exactly the token sets these stats were built
  /// from: same entries, none edited since (an edit makes new token sets).
  bool isBuiltFrom(List<_TokenSets> docs) {
    if (docs.length != _docs.length) return false;
    for (var i = 0; i < docs.length; i++) {
      if (!identical(docs[i], _docs[i])) return false;
    }
    return true;
  }

  final Map<String, int> _df = {};
  final Set<String> _lowercaseSeen = {};
  late final double _maxIdf;
  final Map<_TokenSets, double> _norms = Map.identity();
  final Map<_TokenSets, Set<String>> _entities = Map.identity();

  /// Words that start sentences but are not names.
  static const Set<String> _notNames = {
    'found',
    'took',
    'met',
    'ran',
    'run',
    'rode',
    'saw',
    'went',
    'got',
    'had',
    'made',
    'long',
    'hot',
    'cold',
    'big',
    'small',
    'little',
    'first',
    'last',
    'new',
    'old',
    'back',
    'still',
    'today',
    'tonight',
    'yesterday',
    'tomorrow',
    'this',
    'that',
    'these',
    'those',
    'my',
    'our',
    'so',
    'what',
    'why',
    'how',
    'when',
    'where',
    'nothing',
    'everything',
    'someone',
    'everyone',
    'another',
    'best',
    'worst',
    'quiet',
    'early',
    'late',
    'great',
    'good',
    'bad',
    'sat',
    'stood',
    'woke',
    'slept',
    'ate',
    'drank',
    'heard',
    'felt',
    'thought',
    'bought',
    'sold',
    'wrote',
    'read',
    'left',
    'kept',
    'lost',
    'won',
    'tried',
    'said',
    'told',
    'gave',
    'put',
    'set',
    'oh',
    'yes',
    'wow',
    'dear',
    'happy',
    'sad',
    'proper',
    'lots',
    'some',
    'one',
    'two',
    'three',
    'both',
    'each',
    'every',
    'such',
    'here',
    'there',
    'then',
    'now',
    'maybe',
    'also',
    'even',
    'just',
    'only',
    'very',
    'really',
    'ok',
    'okay',
    'i',
    'im',
    'ive',
    'we',
    'he',
    'she',
    'it',
    'they',
    'you',
    'me',
    'us',
    'him',
    'her',
    'his',
    'its',
    'their',
    'a',
    'an',
    'the',
    'and',
    'but',
    'or',
    'if',
    'at',
    'on',
    'in',
    'to',
    'of',
    'for',
    'with',
    'from',
    'by',
    'after',
    'before',
    'during',
    'dr',
    'mr',
    'mrs',
    'ms',
    'kick',
    'week',
    'year',
    'month',
  };

  static const Set<String> _calendar = {
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
    'christmas',
    'easter',
  };

  /// Pseudo-documents (containing none of the terms) added to the count, so
  /// a new user's handful of entries does not make every shared word look
  /// common. Negligible once the collection is large.
  static const int _priorDocs = 20;

  double _idf(int df) => math.log(1 + (size + _priorDocs) / df);

  double idfOf(String key) => _idf(_df[key] ?? 1);

  double norm(_TokenSets d) => _norms.putIfAbsent(d, () {
    var sum = 0.0;
    for (final t in d.terms) {
      final w = idfOf(t);
      sum += w * w;
    }
    return math.sqrt(sum);
  });

  /// TF-IDF cosine (binary term frequency: memories are short).
  double cosine(_TokenSets a, double normA, _TokenSets b) {
    if (normA == 0) return 0;
    final normB = norm(b);
    if (normB == 0) return 0;
    final (small, large) = a.terms.length <= b.terms.length
        ? (a.terms, b.terms)
        : (b.terms, a.terms);
    var dot = 0.0;
    for (final t in small) {
      if (large.contains(t)) {
        final w = idfOf(t);
        dot += w * w;
      }
    }
    return dot / (normA * normB);
  }

  /// People and places in [d]: relationship words plus capitalised words
  /// that the collection never writes in lowercase.
  Set<String> entities(_TokenSets d) => _entities.putIfAbsent(d, () {
    final out = <String>{for (final r in d.relations) '@$r'};
    for (final c in d.capitalised) {
      if (_lowercaseSeen.contains(c) ||
          _notNames.contains(c) ||
          _calendar.contains(c) ||
          commonStopWords.contains(c) ||
          c.endsWith('ed') ||
          c.endsWith('ing') ||
          c.endsWith('ly')) {
        continue;
      }
      // Ordinary theme words written at the start of a sentence ("Pottery:
      // finally...") are topics, not names. Places stay.
      if (_isLexiconWord(c) && !travelPlaces.contains(c)) continue;
      out.add('@$c');
    }
    return out;
  });

  static final Set<String> _lexiconWords = {
    for (final terms in themeLexicon.values)
      for (final term in terms.keys)
        if (!term.contains(' ')) ThemeText.normalize(ThemeText.clean(term)),
  };

  static bool _isLexiconWord(String w) =>
      _lexiconWords.contains(w) ||
      (w.endsWith('s') && _lexiconWords.contains(w.substring(0, w.length - 1)));

  /// Rarity-weighted overlap of two entity sets, 0..1.
  double entityOverlap(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    var shared = 0.0;
    for (final e in a) {
      if (b.contains(e)) shared += idfOf(e) / _maxIdf;
    }
    if (shared == 0) return 0;
    final smaller = math.min(a.length, b.length);
    return math.min(1.0, shared / math.sqrt(smaller.toDouble()));
  }
}
