// Theme persistence: themes are detected once at save time and counted
// cheaply afterwards.
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/models/memory_theme.dart';
import 'package:seedling/core/services/ai/theme_detector_service.dart';
import 'package:seedling/data/models/entry.dart';

/// Detector that records how often keyword detection actually runs.
class _CountingDetector extends ThemeDetectorService {
  int detections = 0;

  @override
  ThemeAnalysis analyze(ThemeInput input) {
    detections++;
    return super.analyze(input);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeDetectorService persistence helpers', () {
    final detector = ThemeDetectorService();

    test('assignTheme stores the detected theme name', () {
      final entry = Entry.line(
        text:
            'Dinner with my mom and dad, my sister and brother, at home with family',
      );
      expect(detector.assignTheme(entry), isTrue);
      expect(entry.detectedTheme, MemoryTheme.family.name);
      expect(detector.assignTheme(entry), isFalse, reason: 'unchanged');
    });

    test('assignTheme leaves entries without text unthemed', () {
      final entry = Entry.fragment(text: null);
      detector.assignTheme(entry);
      expect(entry.detectedTheme, isNull);
    });

    test('assignTheme follows edited text', () {
      final entry = Entry.line(
        text:
            'Dinner with my mom and dad, my sister and brother, at home with family',
      );
      detector.assignTheme(entry);
      entry
        ..text =
            'Hiking the forest by the lake and river under a sunny sky with birds'
        ..invalidateSearchCache();
      detector.assignTheme(entry);
      expect(entry.detectedTheme, MemoryTheme.nature.name);
    });

    test('analyzeDistribution counts persisted themes without detecting', () {
      final counting = _CountingDetector();
      final entries = List.generate(
        1000,
        (i) => Entry.line(text: 'mom dad family $i')..detectedTheme = 'family',
      );
      final distribution = counting.analyzeDistribution(entries);
      expect(distribution[MemoryTheme.family], 1000);
      expect(counting.detections, 0);
    });

    test('analyzeDistribution falls back for unthemed entries', () {
      final counting = _CountingDetector();
      final distribution = counting.analyzeDistribution([
        Entry.line(
          text:
              'Hiking the forest by the lake and river under a sunny sky with birds',
        )..detectedTheme = 'nature',
        Entry.line(
          text:
              'Dinner with my mom and dad, my sister and brother, at home with family',
        ),
        Entry.fragment(text: null),
      ]);
      expect(distribution[MemoryTheme.nature], 1);
      expect(distribution[MemoryTheme.family], 1);
      expect(distribution[MemoryTheme.moments], 1);
      expect(counting.detections, 2);
    });
  });
}
