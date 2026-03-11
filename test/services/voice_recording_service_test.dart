import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/media/voice_recording_service.dart';

void main() {
  group('VoiceRecordingService', () {
    group('VoiceStartRecordingResult', () {
      test('started factory creates successful start result', () {
        final result = VoiceStartRecordingResult.started();

        expect(result.started, true);
        expect(result.permissionDenied, false);
        expect(result.error, isNull);
      });

      test('permissionDenied factory marks denied state', () {
        final result = VoiceStartRecordingResult.permissionDenied();

        expect(result.started, false);
        expect(result.permissionDenied, true);
        expect(result.error, isNull);
      });

      test('error factory stores message', () {
        final result = VoiceStartRecordingResult.error('Could not start');

        expect(result.started, false);
        expect(result.permissionDenied, false);
        expect(result.error, 'Could not start');
      });
    });

    group('VoiceRecordingResult', () {
      test('success factory creates successful result', () {
        final result = VoiceRecordingResult.success(
          '/path/to/recording.m4a',
          const Duration(seconds: 30),
        );

        expect(result.isSuccess, true);
        expect(result.isCancelled, false);
        expect(result.path, '/path/to/recording.m4a');
        expect(result.duration, const Duration(seconds: 30));
        expect(result.error, isNull);
        expect(result.permissionDenied, false);
      });

      test('error factory creates error result', () {
        final result = VoiceRecordingResult.error('Recording failed');

        expect(result.isSuccess, false);
        expect(result.isCancelled, false);
        expect(result.path, isNull);
        expect(result.duration, isNull);
        expect(result.error, 'Recording failed');
        expect(result.permissionDenied, false);
      });

      test('permissionDenied factory creates permission denied result', () {
        final result = VoiceRecordingResult.permissionDenied();

        expect(result.isSuccess, false);
        expect(result.isCancelled, false);
        expect(result.path, isNull);
        expect(result.error, isNull);
        expect(result.permissionDenied, true);
      });

      test('cancelled factory creates cancelled result', () {
        final result = VoiceRecordingResult.cancelled();

        expect(result.isSuccess, false);
        expect(result.isCancelled, true);
        expect(result.path, isNull);
        expect(result.duration, isNull);
        expect(result.error, isNull);
        expect(result.permissionDenied, false);
      });
    });

    group('RecordingState enum', () {
      test('has all expected states', () {
        expect(RecordingState.values.length, 4);
        expect(RecordingState.values.contains(RecordingState.idle), true);
        expect(RecordingState.values.contains(RecordingState.recording), true);
        expect(RecordingState.values.contains(RecordingState.paused), true);
        expect(RecordingState.values.contains(RecordingState.stopped), true);
      });
    });

    group('maxDuration constant', () {
      test('max duration is 2 minutes', () {
        expect(VoiceRecordingService.maxDuration, const Duration(minutes: 2));
      });
    });

    // Note: Full service tests require platform integration and are better
    // suited for integration testing with mock permission and storage services.
    //
    // Integration test scenarios:
    // - startRecording() with permission granted returns started=true
    // - startRecording() without permission returns permissionDenied=true
    // - stopRecording() saves file and returns success result
    // - cancelRecording() deletes temp file
    // - max duration timer auto-stops recording
    // - onMaxDurationReached callback is called
    // - isRecording reflects current state
    // - currentDuration updates during recording
    // - amplitudeStream emits values during recording
  });
}
