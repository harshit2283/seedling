import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/media/photo_capture_service.dart';

void main() {
  group('PhotoCaptureService', () {
    group('PhotoCaptureResult', () {
      test('success factory creates successful result', () {
        final result = PhotoCaptureResult.success('/path/to/photo.jpg');

        expect(result.isSuccess, true);
        expect(result.isCancelled, false);
        expect(result.path, '/path/to/photo.jpg');
        expect(result.error, isNull);
        expect(result.permissionDenied, false);
      });

      test('error factory creates error result', () {
        final result = PhotoCaptureResult.error('Camera failed');

        expect(result.isSuccess, false);
        expect(result.isCancelled, false);
        expect(result.path, isNull);
        expect(result.error, 'Camera failed');
        expect(result.permissionDenied, false);
      });

      test('permissionDenied factory creates permission denied result', () {
        final result = PhotoCaptureResult.permissionDenied();

        expect(result.isSuccess, false);
        expect(result.isCancelled, false);
        expect(result.path, isNull);
        expect(result.error, isNull);
        expect(result.permissionDenied, true);
      });

      test('cancelled factory creates cancelled result', () {
        final result = PhotoCaptureResult.cancelled();

        expect(result.isSuccess, false);
        expect(result.isCancelled, true);
        expect(result.path, isNull);
        expect(result.error, isNull);
        expect(result.permissionDenied, false);
      });

      test('isSuccess is true only when path is present', () {
        expect(PhotoCaptureResult.success('/path.jpg').isSuccess, true);
        expect(PhotoCaptureResult.cancelled().isSuccess, false);
        expect(PhotoCaptureResult.error('err').isSuccess, false);
        expect(PhotoCaptureResult.permissionDenied().isSuccess, false);
      });

      test('isCancelled is true only for cancelled result', () {
        expect(PhotoCaptureResult.cancelled().isCancelled, true);
        expect(PhotoCaptureResult.success('/path.jpg').isCancelled, false);
        expect(PhotoCaptureResult.error('err').isCancelled, false);
        expect(PhotoCaptureResult.permissionDenied().isCancelled, false);
      });
    });

    // Note: Full service tests require platform integration (camera, image picker)
    // and are better suited for integration testing with mock services.
    //
    // Integration test scenarios:
    // - captureFromCamera() with permission granted captures photo
    // - captureFromCamera() without permission returns permissionDenied
    // - captureFromCamera() user cancels returns cancelled
    // - pickFromGallery() with permission granted picks photo
    // - pickFromGallery() without permission returns permissionDenied
    // - pickFromGallery() user cancels returns cancelled
    // - captureObjectPhoto() saves to objects directory
    // - photos are compressed before saving
    // - saved photos have unique filenames (UUID)
  });
}
