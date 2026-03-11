import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'file_storage_service.dart';
import 'media_compression_service.dart';
import 'permission_service.dart';

/// Result of a photo capture operation
class PhotoCaptureResult {
  final String? path;
  final String? error;
  final bool permissionDenied;

  PhotoCaptureResult._({this.path, this.error, this.permissionDenied = false});

  factory PhotoCaptureResult.success(String path) =>
      PhotoCaptureResult._(path: path);

  factory PhotoCaptureResult.error(String message) =>
      PhotoCaptureResult._(error: message);

  factory PhotoCaptureResult.permissionDenied() =>
      PhotoCaptureResult._(permissionDenied: true);

  factory PhotoCaptureResult.cancelled() => PhotoCaptureResult._();

  bool get isSuccess => path != null;
  bool get isCancelled => path == null && error == null && !permissionDenied;
}

/// Service for capturing photos using the device camera or gallery
class PhotoCaptureService {
  final ImagePicker _picker = ImagePicker();
  final PermissionService _permissionService;
  final FileStorageService _storageService;
  final MediaCompressionService _compressionService;

  PhotoCaptureService({
    required PermissionService permissionService,
    required FileStorageService storageService,
    required MediaCompressionService compressionService,
  }) : _permissionService = permissionService,
       _storageService = storageService,
       _compressionService = compressionService;

  /// Capture a photo from the camera
  Future<PhotoCaptureResult> captureFromCamera() async {
    // Check permission
    final hasPermission = await _permissionService.requestCameraPermission();
    if (!hasPermission) {
      return PhotoCaptureResult.permissionDenied();
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null) {
        return PhotoCaptureResult.cancelled();
      }

      // Compress and save
      final savedPath = await _processAndSavePhoto(File(image.path));
      return PhotoCaptureResult.success(savedPath);
    } catch (e) {
      return PhotoCaptureResult.error('Failed to capture photo: $e');
    }
  }

  /// Pick a photo from the gallery
  Future<PhotoCaptureResult> pickFromGallery() async {
    // Check permission
    final hasPermission = await _permissionService.requestPhotosPermission();
    if (!hasPermission) {
      return PhotoCaptureResult.permissionDenied();
    }

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        return PhotoCaptureResult.cancelled();
      }

      // Compress and save
      final savedPath = await _processAndSavePhoto(File(image.path));
      return PhotoCaptureResult.success(savedPath);
    } catch (e) {
      return PhotoCaptureResult.error('Failed to pick photo: $e');
    }
  }

  /// Process (compress) and save a photo
  Future<String> _processAndSavePhoto(File sourceFile) async {
    // Compress the image
    final compressedFile = await _compressionService.compressImage(sourceFile);

    // Save to media directory
    final savedPath = await _storageService.savePhoto(compressedFile);

    // Clean up compressed temp file if different from source
    if (compressedFile.path != sourceFile.path) {
      await compressedFile.delete();
    }

    return savedPath;
  }

  /// Save an existing image file (e.g., from share extension)
  /// Compresses and copies to app storage
  Future<PhotoCaptureResult> saveExistingImage(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return PhotoCaptureResult.error('Source file does not exist');
      }

      // Compress and save
      final savedPath = await _processAndSavePhoto(sourceFile);
      return PhotoCaptureResult.success(savedPath);
    } catch (e) {
      return PhotoCaptureResult.error('Failed to save image: $e');
    }
  }

  /// Capture a photo for an object entry
  /// Uses the same flow but saves to the objects directory
  Future<PhotoCaptureResult> captureObjectPhoto() async {
    // Check permission
    final hasPermission = await _permissionService.requestCameraPermission();
    if (!hasPermission) {
      return PhotoCaptureResult.permissionDenied();
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null) {
        return PhotoCaptureResult.cancelled();
      }

      // Compress the image
      final compressedFile = await _compressionService.compressImage(
        File(image.path),
      );

      // Save to objects directory
      final savedPath = await _storageService.saveObjectPhoto(compressedFile);

      // Clean up compressed temp file
      if (compressedFile.path != image.path) {
        await compressedFile.delete();
      }

      return PhotoCaptureResult.success(savedPath);
    } catch (e) {
      return PhotoCaptureResult.error('Failed to capture photo: $e');
    }
  }
}
