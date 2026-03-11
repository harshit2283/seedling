import '../../../data/models/entry.dart';
import 'models/ritual_candidate.dart';

/// Detects recurring memory patterns that may represent rituals.
class RitualDetectionService {
  static const _minimumOccurrences = 3;
  static const _minimumSpanDays = 14;

  List<RitualCandidate> detectCandidates(
    List<Entry> entries, {
    int lookbackDays = 120,
  }) {
    if (entries.isEmpty) return const [];

    final now = DateTime.now();
    final threshold = now.subtract(Duration(days: lookbackDays));
    final groups = <String, List<Entry>>{};

    for (final entry in entries) {
      if (entry.isDeleted) continue;
      if (entry.createdAt.isBefore(threshold)) continue;
      final content = entry.searchableContent.trim();
      if (content.isEmpty) continue;
      final signature = _signatureFor(content, entry.createdAt);
      if (signature == null) continue;
      groups.putIfAbsent(signature, () => []).add(entry);
    }

    final candidates = <RitualCandidate>[];
    for (final group in groups.entries) {
      final values = group.value
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final first = values.first.createdAt;
      final last = values.last.createdAt;
      final occurrences = values.length;
      final span = last.difference(first).inDays;

      if (occurrences < _minimumOccurrences) continue;
      if (span < _minimumSpanDays) continue;

      candidates.add(
        RitualCandidate(
          signature: group.key,
          occurrences: occurrences,
          firstSeen: first,
          lastSeen: last,
          sampleText: values.last.displayContent,
        ),
      );
    }

    candidates.sort((a, b) {
      final byCount = b.occurrences.compareTo(a.occurrences);
      if (byCount != 0) return byCount;
      return b.lastSeen.compareTo(a.lastSeen);
    });
    return candidates;
  }

  /// Public accessor for signature computation (used by RitualService for matching)
  String? computeSignaturePublic(String content, DateTime timestamp) {
    return _signatureFor(content, timestamp);
  }

  String? _signatureFor(String content, DateTime timestamp) {
    final tokens =
        content
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), ' ')
            .split(RegExp(r'\s+'))
            .where((word) => word.length >= 3)
            .where((word) => !_stopWords.contains(word))
            .toSet()
            .toList()
          ..sort();
    if (tokens.length < 2) return null;

    final bucket = _hourBucket(timestamp.hour);
    final top = tokens.take(3).join('-');
    return '$bucket:$top';
  }

  String _hourBucket(int hour) {
    if (hour < 11) return 'morning';
    if (hour < 17) return 'afternoon';
    if (hour < 22) return 'evening';
    return 'night';
  }

  static const Set<String> _stopWords = {
    'the',
    'and',
    'with',
    'from',
    'that',
    'this',
    'have',
    'just',
    'about',
    'after',
    'before',
    'into',
    'while',
    'today',
    'night',
    'morning',
    'evening',
  };
}
