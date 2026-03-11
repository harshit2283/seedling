import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/ritual_detection_service.dart';
import 'package:seedling/data/models/entry.dart';

void main() {
  group('RitualDetectionService', () {
    test('detects recurring candidates with minimum span and count', () {
      final now = DateTime.now();
      final entries = [
        Entry.line(text: 'Morning walk in the park')
          ..createdAt = now.subtract(const Duration(days: 28)),
        Entry.line(text: 'Morning walk in the park')
          ..createdAt = now.subtract(const Duration(days: 21)),
        Entry.line(text: 'Morning walk in the park')
          ..createdAt = now.subtract(const Duration(days: 14)),
      ];

      final service = RitualDetectionService();
      final results = service.detectCandidates(entries, lookbackDays: 120);

      expect(results, isNotEmpty);
      expect(results.first.occurrences, 3);
      expect(results.first.spanDays, greaterThanOrEqualTo(14));
    });

    test('ignores one-off entries', () {
      final now = DateTime.now();
      final entries = [
        Entry.line(text: 'One random note')
          ..createdAt = now.subtract(const Duration(days: 5)),
        Entry.line(text: 'Different memory')
          ..createdAt = now.subtract(const Duration(days: 2)),
      ];

      final service = RitualDetectionService();
      final results = service.detectCandidates(entries, lookbackDays: 120);

      expect(results, isEmpty);
    });
  });
}
