import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/media/draft_media_tracker.dart';
import 'package:seedling/core/services/media/file_storage_service.dart';
import 'package:seedling/core/services/media/photo_capture_service.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/core/services/ritual/ritual_service.dart';
import 'package:seedling/core/services/storage/media_orphan_sweeper.dart';
import 'package:seedling/core/services/sync/sync_engine.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/capture/presentation/quick_capture_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDb extends Mock implements ObjectBoxDatabase {}

class _MockSync extends Mock implements SyncEngine {}

class _MockRitual extends Mock implements RitualService {}

class _MockPhotoCapture extends Mock implements PhotoCaptureService {}

class _MockFileStorage extends Mock implements FileStorageService {}

void main() {
  group('DraftMediaTracker', () {
    late List<String> deleted;
    late DraftMediaTracker tracker;

    setUp(() {
      deleted = [];
      tracker = DraftMediaTracker(
        () => (path) async {
          deleted.add(path);
          return true;
        },
      );
    });

    test('replacing or removing a capture deletes the old file', () async {
      await tracker.update(next: 'a.jpg');
      await tracker.update(previous: 'a.jpg', next: 'b.jpg');
      expect(deleted, ['a.jpg']);
      await tracker.update(previous: 'b.jpg');
      expect(deleted, ['a.jpg', 'b.jpg']);
      expect(tracker.pending, isEmpty);
    });

    test('commit keeps the saved file and deletes other captures', () async {
      await tracker.update(next: 'photo.jpg');
      await tracker.update(next: 'voice.m4a');
      await tracker.commit('voice.m4a');
      expect(deleted, ['photo.jpg']);
      await tracker.discard();
      expect(deleted, ['photo.jpg']);
    });

    test('discard deletes every captured file', () async {
      await tracker.update(next: 'photo.jpg');
      await tracker.update(next: 'object.jpg');
      await tracker.discard();
      expect(deleted, unorderedEquals(['photo.jpg', 'object.jpg']));
    });
  });

  group('QuickCaptureSheet media cleanup', () {
    late _MockDb db;
    late _MockPhotoCapture photoCapture;
    late _MockFileStorage fileStorage;
    late SharedPreferences prefs;
    late List<String> deleted;
    late List<Entry> saved;
    var next = 0;

    setUpAll(() {
      registerFallbackValue(Entry.line(text: ''));
    });

    setUp(() async {
      db = _MockDb();
      photoCapture = _MockPhotoCapture();
      fileStorage = _MockFileStorage();
      deleted = [];
      saved = [];
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      when(() => db.saveEntry(any())).thenAnswer((inv) async {
        final entry = inv.positionalArguments.first as Entry;
        entry.id = saved.length + 1;
        saved.add(entry);
        return entry;
      });
      when(() => db.watchEntries()).thenAnswer((_) => Stream.value([]));
      when(() => db.watchCurrentTree()).thenAnswer((_) => Stream.value(null));
      when(() => db.watchRituals()).thenAnswer((_) => Stream.value([]));
      when(() => db.getAllEntries()).thenReturn([]);
      when(() => db.getAllCapsules()).thenReturn([]);
      when(() => db.getDeletedEntries()).thenReturn([]);
      when(() => db.getCapsulesToUnlockToday()).thenReturn([]);
      when(() => db.getAllTrees()).thenReturn([]);
      when(() => photoCapture.pickFromGallery()).thenAnswer(
        (_) async => PhotoCaptureResult.success('/m/p${next++}.jpg'),
      );
      when(() => fileStorage.deleteFile(any())).thenAnswer((inv) async {
        deleted.add(inv.positionalArguments.first as String);
        return true;
      });
    });

    Widget harness({bool show = true}) {
      final ritual = _MockRitual();
      when(() => ritual.updateAfterEntry(any())).thenAnswer((_) async {});
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ritualServiceProvider.overrideWithValue(ritual),
          syncEngineProvider.overrideWithValue(_MockSync()),
          photoCaptureServiceProvider.overrideWithValue(photoCapture),
          fileStorageServiceProvider.overrideWithValue(fileStorage),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: show ? const QuickCaptureSheet() : const SizedBox(),
          ),
        ),
      );
    }

    Future<String> pickPhoto(WidgetTester tester) async {
      await tester.tap(find.text('Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library'));
      await tester.pump();
      await tester.pump();
      return '/m/p${next - 1}.jpg';
    }

    testWidgets('removing a picked photo deletes it', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      final picked = await pickPhoto(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(deleted, [picked]);
    });

    testWidgets('closing the sheet with an unsaved photo deletes it', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      final picked = await pickPhoto(tester);

      await tester.pumpWidget(harness(show: false));
      await tester.pump();

      expect(deleted, [picked]);
    });

    testWidgets('a photo left in photo mode is deleted when a text memory '
        'is saved instead', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      final picked = await pickPhoto(tester);

      await tester.tap(find.text('Line'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'just words');
      await tester.pump();
      await tester.tap(find.text('Save memory'));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(deleted, [picked]);
    });
  });

  group('MediaOrphanSweeper', () {
    late Directory media;
    final now = DateTime(2026, 10, 19, 12);
    final old = now.subtract(const Duration(days: 3));

    setUp(() {
      media = Directory.systemTemp.createTempSync('orphan_sweep');
    });

    tearDown(() => media.deleteSync(recursive: true));

    File file(String relative, DateTime modified) {
      final f = File('${media.path}/$relative')..createSync(recursive: true);
      f.setLastModifiedSync(modified);
      return f;
    }

    test(
      'deletes old unreferenced files, keeps referenced and fresh ones',
      () async {
        final live = file('photos/live.jpg', old);
        final trashed = file('voices/trashed.m4a', old);
        final staleRef = file('objects/moved.jpg', old);
        final orphan = file('photos/orphan.jpg', old);
        final freshOrphan = file('photos/fresh.jpg', now);

        final count = await const MediaOrphanSweeper().sweep(
          mediaDirectory: media,
          referencedPaths: [
            '${media.path}/photos/live.jpg',
            '/old/container/media/voices/trashed.m4a', // soft-deleted entry
            '/var/mobile/OLD/media/objects/moved.jpg', // stale container path
            null, // text entry
          ],
          now: now,
        );

        expect(count, 1);
        expect(orphan.existsSync(), isFalse);
        for (final f in [live, trashed, staleRef, freshOrphan]) {
          expect(f.existsSync(), isTrue, reason: f.path);
        }
      },
    );

    test('does nothing when there are no entries at all', () async {
      final orphan = file('photos/orphan.jpg', old);
      final count = await const MediaOrphanSweeper().sweep(
        mediaDirectory: media,
        referencedPaths: const [],
        now: now,
      );
      expect(count, 0);
      expect(orphan.existsSync(), isTrue);
    });
  });
}
