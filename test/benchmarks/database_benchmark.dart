// Manual benchmark for the local database. Not part of the suite (no
// `_test` suffix); run with:
//   flutter test test/benchmarks/database_benchmark.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/datasources/local/seedling_database.dart';
import 'package:seedling/data/models/entry.dart';

Future<SeedlingDatabase> _open(String dir) =>
    SeedlingDatabase.openForTesting(directory: dir);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('save 500 entries, then load the memories list', () async {
    final dir = await Directory.systemTemp.createTemp('db_bench');
    var db = await _open(dir.path);
    // Subscribed the way the app is (entriesStreamProvider and
    // allEntriesStreamProvider are always alive).
    var refreshes = 0;
    final subs = [
      db.watchEntries().listen((_) => refreshes++),
      db.watchAllEntries().listen((_) => refreshes++),
    ];

    const n = 500;
    Entry memory(int i) => Entry.line(text: 'A walk by the river, memory $i')
      ..title = 'title $i'
      ..context = 'somewhere';

    // One at a time, letting the watchers refresh after each save (a person
    // saving memories one by one).
    final eachWithRefresh = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      await db.saveEntry(memory(i));
      await Future<void>.delayed(Duration.zero);
    }
    eachWithRefresh.stop();
    final refreshesAfterEach = refreshes;

    // Back to back, as an import or sync merge does.
    final backToBack = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      await db.saveEntry(memory(i));
    }
    backToBack.stop();

    final batch = Stopwatch()..start();
    await db.saveEntries([for (var i = 0; i < n; i++) memory(i)]);
    batch.stop();
    await Future<void>.delayed(Duration.zero);
    for (final s in subs) {
      await s.cancel();
    }
    db.close();

    // Cold: a fresh open, as on app launch.
    final open = Stopwatch()..start();
    db = await _open(dir.path);
    open.stop();
    final cold = Stopwatch()..start();
    final page = db.getEntriesPage(
      limit: 50,
      offset: 0,
      year: DateTime.now().year,
    );
    final year = db.getCurrentYearEntries();
    cold.stop();

    final warm = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      db.getEntriesPage(limit: 50, offset: 0, year: DateTime.now().year);
    }
    warm.stop();
    final warmYear = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      db.getCurrentYearEntries();
    }
    warmYear.stop();

    debugPrint(
      'save $n one by one + refresh: ${eachWithRefresh.elapsedMilliseconds}ms '
      '($refreshesAfterEach refreshes); '
      'back to back: ${backToBack.elapsedMilliseconds}ms; '
      'batch: ${batch.elapsedMilliseconds}ms; '
      'open: ${open.elapsedMilliseconds}ms; '
      'cold page 50 + year (${year.length}): ${cold.elapsedMilliseconds}ms; '
      'warm page 50: ${(warm.elapsedMicroseconds / 10000).toStringAsFixed(2)}ms; '
      'warm year: ${(warmYear.elapsedMicroseconds / 10000).toStringAsFixed(2)}ms',
    );
    expect(page, hasLength(50));
    db.close();
    await dir.delete(recursive: true);
  });
}
