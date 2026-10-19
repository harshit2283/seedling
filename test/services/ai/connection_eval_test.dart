// Quality floor for "Related memories" on test/fixtures/connection_eval.json.
// See docs/engineering/themes.md.
//
// Print the report (and the train-split misses to tune against):
//   THEME_EVAL_VERBOSE=1 flutter test test/services/ai/connection_eval_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/connection_finder_service.dart';
import 'package:seedling/core/services/ai/theme_detector_service.dart';
import 'package:seedling/data/models/entry.dart';

class _Query {
  _Query(this.id, this.related, this.isTest);
  final int id;
  final Set<int> related;
  final bool isTest;
}

class _Metrics {
  double pAt3Sum = 0;
  int queries = 0;
  int shown = 0;
  int shownRelevant = 0;
  int covered = 0;

  void add(List<int> top3, Set<int> related) {
    queries++;
    final hits = top3.where(related.contains).length;
    pAt3Sum += hits / (related.length < 3 ? related.length : 3);
    shown += top3.length;
    shownRelevant += hits;
    if (top3.isNotEmpty) covered++;
  }

  double get precisionAt3 => pAt3Sum / queries;
  double get shownPrecision => shown == 0 ? 0 : shownRelevant / shown;
  double get coverage => covered / queries;

  String report(String label) =>
      '$label (n=$queries): P@3 ${precisionAt3.toStringAsFixed(3)}  '
      'shown-precision ${shownPrecision.toStringAsFixed(3)}  '
      'coverage ${(coverage * 100).toStringAsFixed(0)}%';
}

void main() {
  final doc =
      jsonDecode(File('test/fixtures/connection_eval.json').readAsStringSync())
          as Map<String, dynamic>;
  final detector = ThemeDetectorService();
  final entries = [
    for (final raw in doc['entries'] as List)
      Entry.line(text: raw['text'] as String)
        ..id = raw['id'] as int
        ..createdAt = DateTime.parse(raw['date'] as String),
  ];
  // Themes are persisted at save time in the app.
  for (final e in entries) {
    detector.assignTheme(e);
  }
  final clustered = {
    for (final raw in doc['entries'] as List)
      if (raw['cluster'] != null) raw['id'] as int,
  };
  final queries = [
    for (final raw in doc['queries'] as List)
      _Query(raw['query'] as int, {
        for (final id in raw['related'] as List) id as int,
      }, raw['split'] == 'test'),
  ];
  final byId = {for (final e in entries) e.id: e};
  final verbose = Platform.environment['THEME_EVAL_VERBOSE'] == '1';

  test('related memories quality floor', () {
    final finder = ConnectionFinderService();
    final train = _Metrics(), heldOut = _Metrics();
    for (final q in queries) {
      final top3 = [
        for (final c in finder.findConnections(byId[q.id]!, entries).take(3))
          c.relatedEntry.id,
      ];
      (q.isTest ? heldOut : train).add(top3, q.related);
      if (verbose && !q.isTest && top3.isEmpty) {
        debugPrint('  #${q.id} (nothing) ${byId[q.id]!.text}');
      }
      if (verbose && !q.isTest && top3.any((id) => !q.related.contains(id))) {
        debugPrint('  #${q.id} ${byId[q.id]!.text}');
        for (final c in finder.findConnections(byId[q.id]!, entries).take(3)) {
          final ok = q.related.contains(c.relatedEntry.id) ? '+' : '-';
          final f = c.factors;
          debugPrint(
            '    $ok ${c.similarityScore.toStringAsFixed(2)} '
            '(t ${f.textSimilarity.toStringAsFixed(2)} '
            'p ${f.entityBonus.toStringAsFixed(2)} '
            'th ${f.themeBonus.toStringAsFixed(2)} '
            'd ${f.temporalBonus.toStringAsFixed(2)}) '
            '${c.relatedEntry.text}',
          );
        }
      }
    }

    // Distractors are unrelated to everything: anything shown is noise.
    var distractorLinks = 0;
    final distractors = entries.where((e) => !clustered.contains(e.id));
    for (final e in distractors) {
      final links = finder.findConnections(e, entries).take(3).toList();
      distractorLinks += links.length;
      if (verbose && links.isNotEmpty) {
        debugPrint('  distractor #${e.id} ${e.text}');
        for (final c in links) {
          debugPrint('    ? ${c.relatedEntry.text}');
        }
      }
    }
    final noise = distractorLinks / distractors.length;

    if (verbose) {
      debugPrint(train.report('train'));
      debugPrint(heldOut.report('held-out'));
      debugPrint('distractor links per entry: ${noise.toStringAsFixed(2)}');
    }
    // Baseline (Jaccard + time + theme, cut-off 0.3): train P@3 0.176,
    // held-out P@3 0.000, 0.20 distractor links per entry.
    expect(train.precisionAt3, greaterThanOrEqualTo(0.6));
    expect(heldOut.precisionAt3, greaterThanOrEqualTo(0.75));
    expect(train.shownPrecision, greaterThanOrEqualTo(0.85));
    expect(heldOut.shownPrecision, greaterThanOrEqualTo(0.7));
    // Some distractor links are fair (two entries about Leo), but most of
    // these entries should stand alone.
    expect(noise, lessThan(0.75));
  });
}
