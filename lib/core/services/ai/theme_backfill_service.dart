import 'dart:isolate';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/datasources/local/objectbox_database.dart';
import '../../../data/models/entry.dart';
import '../../constants/prefs_keys.dart';
import 'theme_detector_service.dart';

/// Persists detected themes on entries saved before themes were stored at
/// capture time. Runs once (tracked in preferences), off the UI isolate, and
/// writes everything back in a single transaction.
class ThemeBackfillService {
  ThemeBackfillService(this._db, this._prefs);

  /// Bump to re-run the pass, e.g. after the keyword lists change.
  static const int currentVersion = 1;

  /// Collections smaller than this are classified inline: spawning an isolate
  /// costs more than the work.
  static const int isolateThreshold = 200;

  final ObjectBoxDatabase _db;
  final SharedPreferences _prefs;

  bool get isDone =>
      (_prefs.getInt(PrefsKeys.themeBackfillVersion) ?? 0) >= currentVersion;

  /// Classify every live entry that has text but no stored theme. Returns the
  /// number of entries updated. Safe to call repeatedly; it no-ops once done.
  Future<int> run() async {
    if (isDone) return 0;

    final pending = <(int, ThemeInput)>[];
    final snapshot = <int, String>{};
    for (final entry in _db.getAllEntries()) {
      if (entry.hasTheme || entry.searchableContent.isEmpty) continue;
      pending.add((entry.id, ThemeInput.fromEntry(entry)));
      snapshot[entry.id] = entry.searchableContent;
    }

    final themes = pending.length >= isolateThreshold
        ? await _classifyInBackground(pending)
        : classify(pending);

    final updates = <Entry>[];
    for (final (id, _) in pending) {
      // Re-read: the user may have edited the entry while we classified.
      final current = _db.getEntry(id);
      if (current == null || current.hasTheme) continue;
      if (current.searchableContent != snapshot[id]) continue;
      current.detectedTheme = themes[id];
      updates.add(current);
    }
    if (updates.isNotEmpty) {
      // A derived field, not a user edit: keep modifiedAt so sync does not
      // treat every old entry as freshly changed.
      await _db.saveEntries(updates, preserveModifiedAt: true);
    }
    await _prefs.setInt(PrefsKeys.themeBackfillVersion, currentVersion);
    return updates.length;
  }

  // Static so the isolate closure captures only [items], never `this`.
  static Future<Map<int, String>> _classifyInBackground(
    List<(int, ThemeInput)> items,
  ) => Isolate.run(() => classify(items));

  /// Pure classification over (id, fields) pairs. Top-level-safe so it can
  /// run inside [Isolate.run].
  static Map<int, String> classify(List<(int, ThemeInput)> items) {
    final detector = ThemeDetectorService();
    return {
      for (final (id, input) in items) id: detector.analyze(input).primary.name,
    };
  }
}
