import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/entry.dart';
import '../constants/prefs_keys.dart';

/// Tracks entry type usage for smart ordering of capture buttons
class EntryTypeUsageService {
  static const _maxUsagesPerType = 3;
  static const _rollingWindowDays = 7;

  final SharedPreferences _prefs;

  EntryTypeUsageService(this._prefs);

  /// Default order when no usage data exists
  static const List<String> defaultOrder = [
    'line',
    'photo',
    'voice',
    'fragment',
    'object',
    'release',
    'capsule',
  ];

  /// Record that an entry type was successfully saved
  Future<void> recordUsage(EntryType type, {bool isCapsule = false}) async {
    final key = isCapsule ? 'capsule' : type.name.toLowerCase();
    final data = _getUsageData();

    final now = DateTime.now().millisecondsSinceEpoch;
    final usages = data[key] ?? <int>[];
    usages.add(now);
    data[key] = usages;

    await _saveUsageData(data);
  }

  /// Get entry types ordered by recent usage frequency
  List<String> getOrderedTypes() {
    final data = _getUsageData();
    final cutoff = DateTime.now()
        .subtract(Duration(days: _rollingWindowDays))
        .millisecondsSinceEpoch;

    // Count recent usages for each type (capped at maxUsagesPerType)
    final Map<String, int> scores = {};
    for (final type in defaultOrder) {
      final usages = data[type] ?? <int>[];
      final recentUsages = usages.where((ts) => ts > cutoff).toList();
      // Cap at maxUsagesPerType to prevent one type from dominating
      scores[type] = recentUsages.length.clamp(0, _maxUsagesPerType);
    }

    // Sort by score (descending), then by default order for ties
    final sorted = List<String>.from(defaultOrder);
    sorted.sort((a, b) {
      final scoreDiff = (scores[b] ?? 0) - (scores[a] ?? 0);
      if (scoreDiff != 0) return scoreDiff;
      // Maintain default order for ties
      return defaultOrder.indexOf(a) - defaultOrder.indexOf(b);
    });

    return sorted;
  }

  /// Clean up old usage data outside the rolling window
  Future<void> cleanupOldData() async {
    final data = _getUsageData();
    final cutoff = DateTime.now()
        .subtract(Duration(days: _rollingWindowDays))
        .millisecondsSinceEpoch;

    bool changed = false;
    for (final key in data.keys) {
      final usages = data[key] ?? <int>[];
      final filtered = usages.where((ts) => ts > cutoff).toList();
      if (filtered.length != usages.length) {
        data[key] = filtered;
        changed = true;
      }
    }

    if (changed) {
      await _saveUsageData(data);
    }
  }

  Map<String, List<int>> _getUsageData() {
    final jsonStr = _prefs.getString(PrefsKeys.entryTypeUsageData);
    if (jsonStr == null) return {};

    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, (value as List<dynamic>).cast<int>()),
      );
    } catch (e) {
      debugPrint('EntryTypeUsageService: parse failed: $e');
      return {};
    }
  }

  Future<void> _saveUsageData(Map<String, List<int>> data) async {
    await _prefs.setString(PrefsKeys.entryTypeUsageData, jsonEncode(data));
  }
}
