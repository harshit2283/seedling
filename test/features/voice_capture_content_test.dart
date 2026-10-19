import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/app/theme/colors.dart';
import 'package:seedling/app/theme/palette.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/core/services/media/audio_playback_service.dart';
import 'package:seedling/core/services/media/voice_recording_service.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/features/capture/presentation/widgets/voice_capture_content.dart';

class _MockPlayback extends Mock implements AudioPlaybackService {}

class _FakeRecordingService extends Fake implements VoiceRecordingService {
  Completer<VoiceStartRecordingResult>? startCompleter;
  int cancelCalls = 0;
  int stopCalls = 0;
  VoiceRecordingResult stopResult = VoiceRecordingResult.success(
    '/media/voices/a.m4a',
    const Duration(seconds: 3),
  );

  @override
  void Function(VoiceRecordingResult result)? onMaxDurationReached;

  @override
  Future<VoiceStartRecordingResult> startRecording() {
    final completer = startCompleter;
    if (completer != null) return completer.future;
    return Future.value(VoiceStartRecordingResult.started());
  }

  @override
  Future<VoiceRecordingResult> stopRecording() async {
    stopCalls++;
    return stopResult;
  }

  @override
  Future<void> cancelRecording() async => cancelCalls++;

  @override
  Duration get currentDuration => Duration.zero;

  @override
  Stream<double> get amplitudeStream => const Stream.empty();
}

void main() {
  late _FakeRecordingService recording;
  late _MockPlayback playback;
  String? savedPath;

  setUp(() {
    recording = _FakeRecordingService();
    playback = _MockPlayback();
    savedPath = null;
    when(() => playback.stateStream).thenAnswer((_) => const Stream.empty());
    when(() => playback.positionStream).thenAnswer((_) => const Stream.empty());
    when(() => playback.durationStream).thenAnswer((_) => const Stream.empty());
    when(() => playback.currentPath).thenReturn(null);
  });

  Widget harness({bool show = true, ThemeData? theme}) {
    return ProviderScope(
      overrides: [
        voiceRecordingServiceProvider.overrideWithValue(recording),
        audioPlaybackServiceProvider.overrideWithValue(playback),
      ],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: show
              ? VoiceCaptureContent(
                  onVoicePathChanged: (p) => savedPath = p,
                  onDurationChanged: (_) {},
                  onTextChanged: (_) {},
                  text: '',
                )
              : const SizedBox(),
        ),
      ),
    );
  }

  Finder recordButton() => find.byIcon(Icons.mic);

  testWidgets('dismissing the sheet mid-recording releases the mic', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    final gesture = await tester.startGesture(tester.getCenter(recordButton()));
    await tester.pump();

    await tester.pumpWidget(harness(show: false));
    expect(recording.cancelCalls, 1);
    await gesture.up();
  });

  testWidgets('releasing before recording has started cancels it', (
    tester,
  ) async {
    recording.startCompleter = Completer();
    await tester.pumpWidget(harness());
    final gesture = await tester.startGesture(tester.getCenter(recordButton()));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    recording.startCompleter!.complete(VoiceStartRecordingResult.started());
    await tester.pump();
    expect(recording.cancelCalls, 1);
    expect(recording.stopCalls, 0);
  });

  testWidgets('a small finger slide does not discard the recording', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    final gesture = await tester.startGesture(tester.getCenter(recordButton()));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(recording.cancelCalls, 0);
    expect(savedPath, '/media/voices/a.m4a');
  });

  testWidgets('hitting the 2-minute cap keeps the recording', (tester) async {
    await tester.pumpWidget(harness());
    final gesture = await tester.startGesture(tester.getCenter(recordButton()));
    await tester.pump();

    recording.onMaxDurationReached!(
      VoiceRecordingResult.success(
        '/media/voices/max.m4a',
        const Duration(minutes: 2),
      ),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(savedPath, '/media/voices/max.m4a');
  });

  testWidgets('voice colors follow the palette (dark mode)', (tester) async {
    final palette = SeedlingTheme.dark.palette;
    expect(palette.accentVoice, isNot(SeedlingColors.accentVoice));
    await tester.pumpWidget(harness(theme: SeedlingTheme.dark));
    final gesture = await tester.startGesture(tester.getCenter(recordButton()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final label = tester.widget<Text>(find.text('Recording...'));
    expect(label.style?.color, palette.inkFor(palette.accentVoice));
    await gesture.up();
    await tester.pump();

    final icon = tester.widget<Icon>(find.byIcon(Icons.graphic_eq));
    expect(icon.color, palette.accentVoice);
  });
}
