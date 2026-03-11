import 'package:flutter_test/flutter_test.dart';
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

  // Note: Widget tests for QuickCaptureSheet require ProviderScope
  // and mocked services. Key test scenarios:
  //
  // - Sheet opens with text mode by default
  // - Tapping Photo button switches to photo mode
  // - Tapping Voice button switches to voice mode
  // - Tapping Object button switches to object mode
  // - Toggling Capsule enables unlock-date controls across all modes
  // - Tapping Line/Fragment/Release switches back to text mode
  // - Text field is focused in text mode
  // - Text field loses focus in non-text modes
  // - Swipe down saves entry (text mode)
  // - Swipe down saves entry (photo mode with photo)
  // - Swipe down saves entry (voice mode with recording)
  // - Swipe down saves entry (object mode with title)
  // - Empty text mode doesn't save (except fragment)
  // - Photo mode without photo doesn't save
  // - Voice mode without recording doesn't save
  // - Object mode without title doesn't save
  // - Haptic feedback on button taps
  // - Save hint text updates based on mode
}
