// Theme persistence: themes are detected once at save time, counted cheaply
// afterwards, and backfilled for older entries. The backfill tests run
// against a real ObjectBox store and skip without the native library.
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seedling/core/constants/prefs_keys.dart';
import 'package:seedling/core/services/ai/models/memory_theme.dart';
import 'package:seedling/core/services/ai/theme_backfill_service.dart';
import 'package:seedling/core/services/ai/theme_detector_service.dart';
import 'package:seedling/core/services/security/at_rest_encryption_service.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';

/// Detector that records how often keyword detection actually runs.
class _CountingDetector extends ThemeDetectorService {
  int detections = 0;

  @override
  MemoryTheme detectThemeForContent(String content) {
    detections++;
    return super.detectThemeForContent(content);
  }
}

Future<ObjectBoxDatabase?> _tryOpen(Directory dir) async {
  try {
    return await ObjectBoxDatabase.openForTesting(
      directory: dir.path,
      encryptionService: AtRestEncryptionService(),
    );
  } on ArgumentError catch (e) {
    if ('$e'.contains('dynamic library')) return null;
    rethrow;
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

    test('classify (isolate payload) matches detectTheme', () {
      final entry = Entry.line(text: 'Hiked the forest trail up the mountain');
      final result = ThemeBackfillService.classify([
        (7, entry.searchableContent),
      ]);
      expect(result[7], detector.detectTheme(entry).name);
    });
  });

  group('ThemeBackfillService (real store)', () {
    late Directory dir;
    ObjectBoxDatabase? db;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('obx_theme_backfill');
      db = await _tryOpen(dir);
    });

    tearDown(() async {
      db?.close();
      await dir.delete(recursive: true);
    });

    test('themes old entries once, keeps modifiedAt, sets flag', () async {
      final store = db;
      if (store == null) {
        markTestSkipped('ObjectBox native library not available');
        return;
      }
      final family = await store.saveEntry(
        Entry.line(
          text:
              'Dinner with my mom and dad, my sister and brother, at home with family',
        ),
      );
      final empty = await store.saveEntry(Entry.fragment(text: null));
      final kept = await store.saveEntry(
        Entry.line(text: 'mom')..detectedTheme = MemoryTheme.work.name,
      );
      final modifiedBefore = store.getEntry(family.id)!.modifiedAt;

      final prefs = await SharedPreferences.getInstance();
      final service = ThemeBackfillService(store, prefs);
      expect(await service.run(), 1);

      expect(store.getEntry(family.id)!.detectedTheme, 'family');
      expect(store.getEntry(family.id)!.modifiedAt, modifiedBefore);
      expect(store.getEntry(empty.id)!.detectedTheme, isNull);
      expect(store.getEntry(kept.id)!.detectedTheme, 'work');
      expect(
        prefs.getInt(PrefsKeys.themeBackfillVersion),
        ThemeBackfillService.currentVersion,
      );

      // Second launch: nothing to do.
      await store.saveEntry(Entry.line(text: 'mom and dad'));
      expect(await service.run(), 0);
    });

    test('large collections classify in an isolate', () async {
      final store = db;
      if (store == null) {
        markTestSkipped('ObjectBox native library not available');
        return;
      }
      await store.saveEntries([
        for (var i = 0; i < ThemeBackfillService.isolateThreshold + 50; i++)
          Entry.line(
            text:
                'hiking the forest by the lake and river, sunny sky, birds $i',
          ),
      ]);
      final prefs = await SharedPreferences.getInstance();
      final updated = await ThemeBackfillService(store, prefs).run();
      expect(updated, ThemeBackfillService.isolateThreshold + 50);
      expect(
        store.getAllEntries().every((e) => e.detectedTheme == 'nature'),
        isTrue,
      );
    });
  });
}
