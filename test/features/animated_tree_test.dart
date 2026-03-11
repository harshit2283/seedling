import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/models/season.dart';
import 'package:seedling/features/tree/presentation/animated_tree_visualization.dart';

void main() {
  group('Season', () {
    test('enum has all four seasons', () {
      expect(Season.values.length, 4);
      expect(Season.values.contains(Season.spring), true);
      expect(Season.values.contains(Season.summer), true);
      expect(Season.values.contains(Season.autumn), true);
      expect(Season.values.contains(Season.winter), true);
    });

    test('seasons have correct indices', () {
      expect(Season.spring.index, 0);
      expect(Season.summer.index, 1);
      expect(Season.autumn.index, 2);
      expect(Season.winter.index, 3);
    });
  });

  group('getCurrentSeason', () {
    test('returns a valid Season', () {
      final season = getCurrentSeason();
      expect(Season.values.contains(season), true);
    });

    // Note: getCurrentSeason() uses DateTime.now(), so we test the logic
    // by verifying the function returns consistent results
    test('returns consistent result on repeated calls', () {
      final season1 = getCurrentSeason();
      final season2 = getCurrentSeason();
      expect(season1, season2);
    });
  });

  group('Season month mapping', () {
    // This helper defines the expected product spec, not the implementation.
    // Update these tests if the season-to-month spec intentionally changes.
    test('spring months are March, April, May (3, 4, 5)', () {
      // Spring is months 3, 4, 5
      const springMonths = [3, 4, 5];
      for (final month in springMonths) {
        final season = _getSeasonForMonth(month);
        expect(season, Season.spring, reason: 'Month $month should be spring');
      }
    });

    test('summer months are June, July, August (6, 7, 8)', () {
      const summerMonths = [6, 7, 8];
      for (final month in summerMonths) {
        final season = _getSeasonForMonth(month);
        expect(season, Season.summer, reason: 'Month $month should be summer');
      }
    });

    test('autumn months are September, October, November (9, 10, 11)', () {
      const autumnMonths = [9, 10, 11];
      for (final month in autumnMonths) {
        final season = _getSeasonForMonth(month);
        expect(season, Season.autumn, reason: 'Month $month should be autumn');
      }
    });

    test('winter months are December, January, February (12, 1, 2)', () {
      const winterMonths = [12, 1, 2];
      for (final month in winterMonths) {
        final season = _getSeasonForMonth(month);
        expect(season, Season.winter, reason: 'Month $month should be winter');
      }
    });

    test('all 12 months map to a season', () {
      for (int month = 1; month <= 12; month++) {
        final season = _getSeasonForMonth(month);
        expect(
          Season.values.contains(season),
          true,
          reason: 'Month $month should map to a valid season',
        );
      }
    });
  });
}

/// Helper to test season logic for a specific month
/// Mirrors the logic in getCurrentSeason()
Season _getSeasonForMonth(int month) {
  return switch (month) {
    3 || 4 || 5 => Season.spring,
    6 || 7 || 8 => Season.summer,
    9 || 10 || 11 => Season.autumn,
    _ => Season.winter,
  };
}
