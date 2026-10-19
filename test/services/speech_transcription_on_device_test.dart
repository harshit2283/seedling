import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/transcription/speech_transcription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.seedling.speech_transcription');
  late List<String> calls;

  void mockPlatform({required bool supportsOnDevice}) {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'isAvailable':
              return {
                'isAvailable': true,
                'supportsOnDevice': supportsOnDevice,
              };
            case 'requestPermission':
              return {'authorized': true};
            case 'transcribe':
              return {'transcription': 'hello', 'isFinal': true};
          }
          return null;
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('never sends audio to a recognizer that is not on-device', () async {
    mockPlatform(supportsOnDevice: false);
    final service = SpeechTranscriptionService();

    expect(await service.prepareOnDevice(), isFalse);
    expect(await service.transcribe('/voice.m4a'), isNull);
    expect(calls, isNot(contains('transcribe')));
  });

  test('transcribes when on-device recognition is available', () async {
    mockPlatform(supportsOnDevice: true);
    final service = SpeechTranscriptionService();

    expect(await service.prepareOnDevice(), isTrue);
    final result = await service.transcribe('/voice.m4a');
    expect(result?.transcription, 'hello');
  });
}
