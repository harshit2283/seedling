import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';
import 'package:seedling/core/services/media/file_storage_service.dart';
import 'package:seedling/core/services/media/permission_service.dart';
import 'package:seedling/core/services/media/voice_recording_service.dart';

class _MockRecorder extends Mock implements AudioRecorder {}

class _MockPermissions extends Mock implements PermissionService {}

class _MockStorage extends Mock implements FileStorageService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const RecordConfig());
  });

  test(
    'auto-stop at the max duration hands the saved recording back',
    () async {
      final recorder = _MockRecorder();
      final permissions = _MockPermissions();
      final storage = _MockStorage();
      when(
        () => permissions.requestMicrophonePermission(),
      ).thenAnswer((_) async => true);
      when(
        () => storage.generateVoicePath(),
      ).thenAnswer((_) async => '/tmp/in-progress.m4a');
      when(
        () => recorder.start(any(), path: any(named: 'path')),
      ).thenAnswer((_) async {});
      when(
        () => recorder.stop(),
      ).thenAnswer((_) async => '/tmp/in-progress.m4a');
      when(
        () => storage.saveVoice('/tmp/in-progress.m4a'),
      ).thenAnswer((_) async => '/media/voices/kept.m4a');

      final service = VoiceRecordingService(
        permissionService: permissions,
        storageService: storage,
        recorder: recorder,
        maxRecordingDuration: const Duration(milliseconds: 20),
      );
      VoiceRecordingResult? autoStopped;
      service.onMaxDurationReached = (result) => autoStopped = result;

      final start = await service.startRecording();
      expect(start.started, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(autoStopped, isNotNull);
      expect(autoStopped!.isSuccess, isTrue);
      expect(autoStopped!.path, '/media/voices/kept.m4a');
      expect(service.isRecording, isFalse);
    },
  );
}
