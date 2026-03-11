import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

void main() {
  debugPrint('Running DateFormat benchmark...');

  // Setup dates for testing different branches
  final now = DateTime.now();
  final testDates = [
    now, // Today
    now.subtract(const Duration(days: 1)), // Yesterday
    now.subtract(const Duration(days: 3)), // Within 7 days
    now.subtract(const Duration(days: 20)), // Same year
    now.subtract(const Duration(days: 400)), // Different year
  ];

  const iterations = 10000;

  // Benchmark Original (Allocating)
  final stopwatchOriginal = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    for (final date in testDates) {
      formatDateOriginal(date);
    }
  }
  stopwatchOriginal.stop();
  debugPrint(
    'Original implementation (allocating) took: ${stopwatchOriginal.elapsedMilliseconds}ms',
  );

  // Benchmark Optimized (Static)
  final stopwatchOptimized = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    for (final date in testDates) {
      formatDateOptimized(date);
    }
  }
  stopwatchOptimized.stop();
  debugPrint(
    'Optimized implementation (static) took: ${stopwatchOptimized.elapsedMilliseconds}ms',
  );

  final improvement =
      (stopwatchOriginal.elapsedMilliseconds -
          stopwatchOptimized.elapsedMilliseconds) /
      stopwatchOriginal.elapsedMilliseconds *
      100;
  debugPrint('Improvement: ${improvement.toStringAsFixed(2)}%');
}

// Original implementation logic
String formatDateOriginal(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final entryDate = DateTime(date.year, date.month, date.day);
  final difference = today.difference(entryDate).inDays;

  if (difference == 0) {
    return 'Today at ${DateFormat('h:mm a').format(date)}';
  } else if (difference == 1) {
    return 'Yesterday at ${DateFormat('h:mm a').format(date)}';
  } else if (difference < 7) {
    return '${DateFormat('EEEE').format(date)} at ${DateFormat('h:mm a').format(date)}';
  } else if (date.year == now.year) {
    return DateFormat('MMMM d').format(date);
  } else {
    return DateFormat('MMMM d, y').format(date);
  }
}

// Optimized implementation logic
final _timeFormat = DateFormat('h:mm a');
final _dayOfWeekFormat = DateFormat('EEEE');
final _monthDayFormat = DateFormat('MMMM d');
final _fullDateFormat = DateFormat('MMMM d, y');

String formatDateOptimized(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final entryDate = DateTime(date.year, date.month, date.day);
  final difference = today.difference(entryDate).inDays;

  if (difference == 0) {
    return 'Today at ${_timeFormat.format(date)}';
  } else if (difference == 1) {
    return 'Yesterday at ${_timeFormat.format(date)}';
  } else if (difference < 7) {
    return '${_dayOfWeekFormat.format(date)} at ${_timeFormat.format(date)}';
  } else if (date.year == now.year) {
    return _monthDayFormat.format(date);
  } else {
    return _fullDateFormat.format(date);
  }
}
