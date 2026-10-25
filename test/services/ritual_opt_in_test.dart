// Rituals are opt-in: detection only suggests. Nothing is stored until the
// user confirms a candidate.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/datasources/local/seedling_database.dart';
import 'package:seedling/data/models/entry.dart';

/// Four Sunday-morning entries a week apart: a clear recurring pattern.
List<Entry> _weeklyPattern() {
  final now = DateTime.now();
  final base = DateTime(now.year, now.month, now.day, 8);
  return [
    for (var week = 4; week >= 1; week--)
      Entry.line(text: 'pancakes garden coffee with the kids')
        ..createdAt = base.subtract(Duration(days: week * 7)),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('detection never creates a ritual on its own', () {
    late Directory dir;
    late SeedlingDatabase db;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('obx_ritual_opt_in');
      db = await SeedlingDatabase.openForTesting(directory: dir.path);
    });

    tearDown(() async {
      db.close();
      await dir.delete(recursive: true);
    });

    test('a detected pattern stays a suggestion until confirmed', () async {
      final store = db;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final service = container.read(ritualServiceProvider);

      // Save the pattern the way capture does: save, then track.
      for (final entry in _weeklyPattern()) {
        final saved = await store.saveEntry(entry);
        await service.updateAfterEntry(saved);
      }

      expect(store.getAllRituals(), isEmpty, reason: 'no silent ritual');

      container.listen(allEntriesStreamProvider, (_, _) {});
      await container.read(allEntriesStreamProvider.future);
      final detected = container.read(ritualCandidatesProvider);
      expect(detected, isNotEmpty, reason: 'the pattern is suggested');
      expect(store.getAllRituals(), isEmpty);

      // Only an explicit confirmation creates it.
      await service.createFromCandidate(
        detected.first,
        name: 'Sunday pancakes',
        cadenceDays: 7,
      );
      expect(store.getAllRituals().single.name, 'Sunday pancakes');
    });
  });
}
