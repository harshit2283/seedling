// Regression floor for theme quality on the held-out split of
// test/fixtures/theme_eval.json. See docs/engineering/themes.md.
//
// Print the full report (train + held-out, per-theme P/R/F1, and the
// misses on the TRAIN split only: tune against those, never the held-out):
//   THEME_EVAL_VERBOSE=1 flutter test test/services/ai/theme_eval_test.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/theme_detector_service.dart';

import 'theme_eval_support.dart';

void main() {
  final all = loadThemeEval();
  final train = all.where((m) => !m.isTest).toList();
  final heldOut = all.where((m) => m.isTest).toList();
  final detector = ThemeDetectorService();
  final verbose = Platform.environment['THEME_EVAL_VERBOSE'] == '1';

  test('fixture is well formed and split ~70/30', () {
    expect(all.length, greaterThanOrEqualTo(300));
    expect(heldOut.length / all.length, closeTo(0.3, 0.02));
    expect(all.where((m) => m.type == 'release').length, 30);
    expect(all.where((m) => m.type == 'capsule').length, 20);
  });

  test('held-out quality floor', () {
    final trainMetrics = evaluate(train, detector.detectTheme);
    final testMetrics = evaluate(heldOut, detector.detectTheme);
    if (verbose) {
      debugPrint(trainMetrics.report('train'));
      debugPrint(testMetrics.report('held-out'));
      for (final m in train) {
        final p = detector.detectTheme(m.toEntry());
        if (p != m.primary) {
          debugPrint(
            '  miss #${m.id}: ${m.primary.name} -> ${p.name}: ${m.text}',
          );
        }
      }
    }
    // Baseline (keyword detector): accuracy 0.087, macro-F1 0.014, 100%
    // moments. Floors sit a little under the current held-out numbers so
    // lexicon edits that regress quality fail here.
    expect(testMetrics.macroF1, greaterThanOrEqualTo(0.78));
    expect(testMetrics.accuracy, greaterThanOrEqualTo(0.78));
    expect(
      (testMetrics.predictedMomentsShare - testMetrics.trueMomentsShare).abs(),
      lessThan(0.05),
      reason: "'moments' should mean unthemed, not 'the detector gave up'",
    );
  });

  test('inference stays well under 1ms per entry', () {
    final inputs = [for (final m in all) ThemeInput.fromEntry(m.toEntry())];
    for (final input in inputs) {
      detector.analyze(input); // warm-up, builds the lexicon tables
    }
    final sw = Stopwatch()..start();
    const rounds = 5;
    for (var r = 0; r < rounds; r++) {
      for (final input in inputs) {
        detector.analyze(input);
      }
    }
    final perEntryUs = sw.elapsedMicroseconds / (rounds * inputs.length);
    if (verbose) {
      debugPrint('analyze: ${perEntryUs.toStringAsFixed(1)}us/entry');
    }
    expect(perEntryUs, lessThan(1000));
  });
}
