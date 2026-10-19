import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/capture/domain/capture_inference.dart';
import 'package:seedling/features/capture/presentation/quick_capture_sheet.dart';

void main() {
  group('CaptureMode enum', () {
    test('has all expected capture modes', () {
      expect(CaptureMode.values.length, 4);
      expect(CaptureMode.values.contains(CaptureMode.text), true);
      expect(CaptureMode.values.contains(CaptureMode.photo), true);
      expect(CaptureMode.values.contains(CaptureMode.voice), true);
      expect(CaptureMode.values.contains(CaptureMode.object), true);
    });

    test('text mode is first (default)', () {
      expect(CaptureMode.values.first, CaptureMode.text);
    });

    test('all modes have unique indices', () {
      final indices = CaptureMode.values.map((e) => e.index).toSet();
      expect(indices.length, CaptureMode.values.length);
    });
  });

  group('inferCaptureType', () {
    test('plain text is a line; very short text is a fragment', () {
      expect(
        inferCaptureType(text: 'The smell of rain on warm stone'),
        EntryType.line,
      );
      expect(inferCaptureType(text: 'hmm'), EntryType.fragment);
      expect(inferCaptureType(text: ''), EntryType.fragment);
      expect(isFragmentText('   ok   '), isTrue);
    });

    test('attachments infer photo, voice and object', () {
      expect(inferCaptureType(hasPhoto: true), EntryType.photo);
      expect(inferCaptureType(hasVoice: true), EntryType.voice);
      expect(inferCaptureType(title: 'Ring'), EntryType.object);
      // A titled photo is an object with a photo.
      expect(inferCaptureType(title: 'Ring', hasPhoto: true), EntryType.object);
      // A voice memo keeps its title as a title.
      expect(inferCaptureType(title: 'Ring', hasVoice: true), EntryType.voice);
      // Whitespace is not a title.
      expect(inferCaptureType(title: '   ', hasPhoto: true), EntryType.photo);
    });

    test('explicit Let go and Ritual win; other explicit types do not', () {
      expect(
        inferCaptureType(text: 'x', explicit: EntryType.release),
        EntryType.release,
      );
      expect(
        inferCaptureType(title: 'Tea', explicit: EntryType.ritual),
        EntryType.ritual,
      );
      expect(
        inferCaptureType(hasPhoto: true, explicit: EntryType.line),
        EntryType.photo,
      );
    });
  });
}
