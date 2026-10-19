// Shared loader and metrics for the labelled theme evaluation set in
// test/fixtures/theme_eval.json, used by theme_eval_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:seedling/core/services/ai/models/memory_theme.dart';
import 'package:seedling/data/models/entry.dart';

class LabelledMemory {
  LabelledMemory({
    required this.id,
    required this.type,
    required this.text,
    required this.title,
    required this.primary,
    required this.secondary,
    required this.isTest,
  });

  final int id;
  final String type;
  final String text;
  final String? title;
  final MemoryTheme primary;
  final MemoryTheme? secondary;
  final bool isTest;

  /// The entry as the app would store it, so detection sees the same fields.
  Entry toEntry() {
    final entry = switch (type) {
      'release' => Entry.release(text: text),
      'capsule' => Entry.capsule(text: text, unlockDate: DateTime(2030, 1, 1)),
      'object' => Entry.object(title: title ?? '', text: text),
      _ => Entry.line(text: text),
    };
    if (title != null && type != 'object') entry.title = title;
    entry.id = id;
    return entry;
  }
}

List<LabelledMemory> loadThemeEval([
  String path = 'test/fixtures/theme_eval.json',
]) {
  final doc = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  MemoryTheme parse(String s) => MemoryTheme.values.byName(s);
  return [
    for (final raw in doc['entries'] as List)
      LabelledMemory(
        id: raw['id'] as int,
        type: raw['type'] as String,
        text: raw['text'] as String,
        title: raw['title'] as String?,
        primary: parse(raw['primary'] as String),
        secondary: raw['secondary'] == null
            ? null
            : parse(raw['secondary'] as String),
        isTest: raw['split'] == 'test',
      ),
  ];
}

class ThemeMetrics {
  ThemeMetrics(this.gold, this.predicted, this.secondary)
    : assert(gold.length == predicted.length);

  final List<MemoryTheme> gold;
  final List<MemoryTheme> predicted;
  final List<MemoryTheme?> secondary;

  int get n => gold.length;

  double get accuracy {
    var hit = 0;
    for (var i = 0; i < n; i++) {
      if (gold[i] == predicted[i]) hit++;
    }
    return hit / n;
  }

  /// Prediction matches the primary or the labelled secondary theme.
  double get lenientAccuracy {
    var hit = 0;
    for (var i = 0; i < n; i++) {
      if (gold[i] == predicted[i] || secondary[i] == predicted[i]) hit++;
    }
    return hit / n;
  }

  (double precision, double recall, double f1) perTheme(MemoryTheme t) {
    var tp = 0, fp = 0, fn = 0;
    for (var i = 0; i < n; i++) {
      final g = gold[i] == t, p = predicted[i] == t;
      if (g && p) tp++;
      if (!g && p) fp++;
      if (g && !p) fn++;
    }
    final precision = tp + fp == 0 ? 0.0 : tp / (tp + fp);
    final recall = tp + fn == 0 ? 0.0 : tp / (tp + fn);
    final f1 = precision + recall == 0
        ? 0.0
        : 2 * precision * recall / (precision + recall);
    return (precision, recall, f1);
  }

  double get macroF1 {
    final present = MemoryTheme.values.where(gold.contains).toList();
    return present.map((t) => perTheme(t).$3).reduce((a, b) => a + b) /
        present.length;
  }

  double share(List<MemoryTheme> of, MemoryTheme t) =>
      of.where((x) => x == t).length / of.length;

  double get predictedMomentsShare => share(predicted, MemoryTheme.moments);
  double get trueMomentsShare => share(gold, MemoryTheme.moments);

  String report(String label) {
    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
    final b = StringBuffer()
      ..writeln('== $label (n=$n) ==')
      ..writeln(
        'accuracy ${pct(accuracy)}  lenient ${pct(lenientAccuracy)}  '
        'macro-F1 ${macroF1.toStringAsFixed(3)}  '
        'moments predicted ${pct(predictedMomentsShare)} '
        '(true ${pct(trueMomentsShare)})',
      );
    for (final t in MemoryTheme.values) {
      final (p, r, f) = perTheme(t);
      b.writeln(
        '  ${t.name.padRight(11)} P ${p.toStringAsFixed(2)}  '
        'R ${r.toStringAsFixed(2)}  F1 ${f.toStringAsFixed(2)}',
      );
    }
    return b.toString();
  }
}

ThemeMetrics evaluate(
  List<LabelledMemory> items,
  MemoryTheme Function(Entry) detect,
) => ThemeMetrics(
  [for (final m in items) m.primary],
  [for (final m in items) detect(m.toEntry())],
  [for (final m in items) m.secondary],
);
