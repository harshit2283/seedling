import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/media/audio_playback_service.dart';
import 'package:seedling/core/services/media/draft_media_tracker.dart';
import 'package:seedling/core/services/media/file_storage_service.dart';
import 'package:seedling/core/services/media/photo_capture_service.dart';
import 'package:seedling/core/services/media/voice_recording_service.dart';
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

class _MockPlayback extends Mock implements AudioPlaybackService {}

class _FakeRecorder extends Fake implements VoiceRecordingService {
  @override
  void Function(VoiceRecordingResult result)? onMaxDurationReached;

  @override
  Future<VoiceStartRecordingResult> startRecording() async =>
      VoiceStartRecordingResult.started();

  @override
  Future<VoiceRecordingResult> stopRecording() async =>
      VoiceRecordingResult.success('/m/voice.m4a', const Duration(seconds: 3));

  @override
  Future<void> cancelRecording() async {}

  @override
  Duration get currentDuration => Duration.zero;

  @override
  Stream<double> get amplitudeStream => const Stream.empty();
}

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

    test('commit never deletes a capture nobody removed', () async {
      await tracker.update(next: 'photo.jpg');
      await tracker.update(next: 'voice.m4a');
      await tracker.commit('voice.m4a');
      // Only an explicit removal or replacement deletes a file; anything
      // else left over is for the orphan sweeper, never a silent loss.
      expect(deleted, isEmpty);
      await tracker.discard();
      expect(deleted, isEmpty);
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
    late _MockPlayback playback;
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
      playback = _MockPlayback();
      when(() => playback.stateStream).thenAnswer((_) => const Stream.empty());
      when(
        () => playback.positionStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => playback.durationStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => playback.currentPath).thenReturn(null);
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

    Widget harness({
      bool show = true,
      bool ritualFails = false,
      bool asSheet = false,
    }) {
      final ritual = _MockRitual();
      if (ritualFails) {
        when(
          () => ritual.updateAfterEntry(any()),
        ).thenThrow(StateError('ritual db'));
      } else {
        when(() => ritual.updateAfterEntry(any())).thenAnswer((_) async {});
      }
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ritualServiceProvider.overrideWithValue(ritual),
          syncEngineProvider.overrideWithValue(_MockSync()),
          photoCaptureServiceProvider.overrideWithValue(photoCapture),
          fileStorageServiceProvider.overrideWithValue(fileStorage),
          voiceRecordingServiceProvider.overrideWithValue(_FakeRecorder()),
          audioPlaybackServiceProvider.overrideWithValue(playback),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: !show
                ? const SizedBox()
                : asSheet
                ? Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showQuickCaptureSheet(context),
                      child: const Text('open'),
                    ),
                  )
                : const QuickCaptureSheet(),
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

    testWidgets('a picked photo plus words saves as a photo and is kept', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      final picked = await pickPhoto(tester);

      await tester.enterText(find.byType(TextField), 'just words');
      await tester.pump();
      await tester.tap(find.text('Save memory'));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved.single.type, EntryType.photo);
      expect(saved.single.mediaPath, picked);
      expect(saved.single.text, 'just words');
      expect(deleted, isEmpty);
    });

    testWidgets('a failure after the entry is written keeps its photo', (
      tester,
    ) async {
      await tester.pumpWidget(harness(ritualFails: true, asSheet: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final picked = await pickPhoto(tester);

      await tester.tap(find.text('Save memory'));
      await tester.pumpAndSettle();
      // However the sheet goes away, the saved photo must survive it.
      if (find.byType(QuickCaptureSheet).evaluate().isNotEmpty) {
        await tester.fling(
          find.byType(QuickCaptureSheet),
          const Offset(0, 500),
          2000,
        );
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(harness(show: false));
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureSheet), findsNothing);

      expect(saved, hasLength(1));
      expect(saved.single.mediaPath, picked);
      expect(deleted, isEmpty);
    });

    /// Holds the toolbar mic long enough to record, then lets go.
    void tallScreen(WidgetTester tester) {
      // Room for a photo preview and the recorder at once.
      tester.view.physicalSize = const Size(2400, 4200);
      addTearDown(tester.view.reset);
    }

    Future<void> holdMic(WidgetTester tester) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Voice')),
      );
      // Let the recorder build before the hold delay elapses.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('holding the mic with a photo attached never drops the photo', (
      tester,
    ) async {
      tallScreen(tester);
      await tester.pumpWidget(harness(asSheet: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final picked = await pickPhoto(tester);

      await holdMic(tester);
      // Whatever the sheet asks, keeping the photo is the safe answer.
      if (find.text('Keep photo').evaluate().isNotEmpty) {
        await tester.tap(find.text('Keep photo'));
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.bySemanticsLabel('Attached photo'), findsOneWidget);

      await tester.tap(find.text('Save memory'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(saved, hasLength(1));
      expect(saved.single.mediaPath, picked);
      expect(deleted, isEmpty);
    });

    testWidgets('the mic asks before a voice memo replaces the photo', (
      tester,
    ) async {
      tallScreen(tester);
      await tester.pumpWidget(harness(asSheet: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final picked = await pickPhoto(tester);

      await tester.tap(find.text('Voice'));
      await tester.pumpAndSettle();
      expect(find.text('Replace the photo with a voice memo?'), findsOneWidget);
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      // The photo stays until there is a recording to take its place.
      expect(deleted, isEmpty);
      expect(find.bySemanticsLabel('Attached photo'), findsOneWidget);

      await holdMic(tester);
      expect(deleted, [picked]);
      expect(find.bySemanticsLabel('Attached photo'), findsNothing);

      await tester.tap(find.text('Save memory'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(saved.single.type, EntryType.voice);
      expect(saved.single.mediaPath, '/m/voice.m4a');
      expect(deleted, [picked]);
    });

    testWidgets('adding a photo asks before it replaces a voice memo', (
      tester,
    ) async {
      tallScreen(tester);
      await tester.pumpWidget(harness(asSheet: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await holdMic(tester);

      await tester.tap(find.text('Photo'));
      await tester.pumpAndSettle();
      expect(find.text('Replace the voice memo with a photo?'), findsOneWidget);
      await tester.tap(find.text('Keep voice memo'));
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsNothing);

      await tester.tap(find.text('Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(deleted, isEmpty);
      await tester.tap(find.text('Library'));
      await tester.pump();
      await tester.pump();
      final picked = '/m/p${next - 1}.jpg';
      expect(deleted, ['/m/voice.m4a']);

      await tester.tap(find.text('Save memory'));
      await tester.pumpAndSettle();
      expect(saved.single.type, EntryType.photo);
      expect(saved.single.mediaPath, picked);
    });

    testWidgets('replacing a picked photo deletes the first one', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      final first = await pickPhoto(tester);
      await pickPhoto(tester);

      expect(deleted, [first]);
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

  group('orphan sweep never touches an open draft', () {
    test('live draft paths are registered until saved or released', () async {
      final tracker = DraftMediaTracker(
        () =>
            (path) async => true,
      );
      await tracker.update(next: '/m/photos/draft.jpg');
      await tracker.update(next: '/m/voices/other.m4a');
      expect(
        DraftMediaTracker.liveDraftPaths,
        containsAll(['/m/photos/draft.jpg', '/m/voices/other.m4a']),
      );

      await tracker.commit('/m/photos/draft.jpg');
      expect(
        DraftMediaTracker.liveDraftPaths,
        isNot(contains('/m/photos/draft.jpg')),
      );
      expect(
        DraftMediaTracker.liveDraftPaths,
        isNot(contains('/m/voices/other.m4a')),
      );
    });

    test('sweeper keeps an old file that an open draft holds', () async {
      final media = Directory.systemTemp.createTempSync('sweep_draft');
      addTearDown(() => media.deleteSync(recursive: true));
      final old = DateTime.now().subtract(const Duration(days: 5));
      // A library photo copied with its original (old) timestamp.
      final draft = File('${media.path}/photos/draft.jpg')
        ..createSync(recursive: true)
        ..setLastModifiedSync(old);
      final orphan = File('${media.path}/photos/orphan.jpg')
        ..createSync(recursive: true)
        ..setLastModifiedSync(old);

      final tracker = DraftMediaTracker(
        () =>
            (path) async => true,
      );
      await tracker.update(next: draft.path);
      addTearDown(tracker.discard);

      final count = await const MediaOrphanSweeper().sweep(
        mediaDirectory: media,
        referencedPaths: const ['/elsewhere/photos/live.jpg'],
        protectedPaths: DraftMediaTracker.liveDraftPaths,
      );

      expect(count, 1);
      expect(draft.existsSync(), isTrue);
      expect(orphan.existsSync(), isFalse);
    });
  });
}
