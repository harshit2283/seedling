// Main test entry point for Seedling app
// Individual test files are in subdirectories

import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'models/entry_test.dart' as entry_tests;
import 'models/tree_test.dart' as tree_tests;
import 'services/voice_recording_service_test.dart' as voice_recording_tests;
import 'services/photo_capture_service_test.dart' as photo_capture_tests;
import 'services/media_compression_service_test.dart'
    as media_compression_tests;
import 'services/file_storage_service_test.dart' as file_storage_tests;
import 'features/capture_mode_test.dart' as capture_mode_tests;

void main() {
  group('Seedling Tests', () {
    // Model tests
    group('Models', () {
      entry_tests.main();
      tree_tests.main();
    });

    // Service tests (unit testable without platform)
    group('Services', () {
      voice_recording_tests.main();
      photo_capture_tests.main();
      media_compression_tests.main();
      file_storage_tests.main();
      // Note: audio_playback_service_test.dart requires Flutter bindings
      // and must be run separately as an integration test
    });

    // Feature tests
    group('Features', () {
      capture_mode_tests.main();
    });
  });
}
