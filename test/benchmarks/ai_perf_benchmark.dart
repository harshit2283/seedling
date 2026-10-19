// Manual micro-benchmarks for the on-device AI hot paths. Not part of the
// suite (no `_test` suffix); run with:
//   flutter test test/benchmarks/ai_perf_benchmark.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/connection_finder_service.dart';
import 'package:seedling/core/services/ai/theme_detector_service.dart';
import 'package:seedling/data/models/entry.dart';

const _phrases = [
  'Dinner with my mom and dad, we laughed about childhood holidays',
  'Hiking the forest trail by the lake, sunny sky and birds singing',
  'Finished the project presentation for the client before the deadline',
  'Grateful for a quiet morning coffee and the light through the window',
  'Painted for an hour, trying a new color palette on the canvas',
  'A long run in the rain, legs tired but mind clear',
  'Coffee with friends downtown, talked for hours',
  'Thinking about where the year has gone and what matters to me',
];

List<Entry> _entries(int n) => [
  for (var i = 0; i < n; i++)
    Entry.line(text: '${_phrases[i % _phrases.length]} note $i')
      ..id = i + 1
      ..createdAt = DateTime(2026, 1, 1).add(Duration(hours: i * 7)),
];

double _timeUs(int runs, void Function() body) {
  body(); // warm-up
  final sw = Stopwatch()..start();
  for (var i = 0; i < runs; i++) {
    body();
  }
  return sw.elapsedMicroseconds / runs;
}

void main() {
  test('theme distribution and connections', () {
    final detector = ThemeDetectorService();
    final finder = ConnectionFinderService();
    for (final n in [500, 2000]) {
      final unthemed = _entries(n);
      final themed = _entries(n);
      for (final e in themed) {
        detector.assignTheme(e);
      }
      final detect = _timeUs(5, () => detector.analyzeDistribution(unthemed));
      final count = _timeUs(5, () => detector.analyzeDistribution(themed));
      debugPrint(
        'analyzeDistribution n=$n: detect-all ${(detect / 1000).toStringAsFixed(2)}ms, '
        'persisted ${(count / 1000).toStringAsFixed(3)}ms',
      );

      final source = themed[n ~/ 2];
      final cold = _timeUs(5, () {
        finder.clearTokenCache();
        finder.findConnections(source, themed);
      });
      final warm = _timeUs(5, () => finder.findConnections(source, themed));
      debugPrint(
        'findConnections n=$n: cold ${(cold / 1000).toStringAsFixed(2)}ms, '
        'cached tokens ${(warm / 1000).toStringAsFixed(2)}ms',
      );
    }
  });
}
