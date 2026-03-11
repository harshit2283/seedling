import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Service for compressing media files
class MediaCompressionService {
  static const _uuid = Uuid();

  /// Maximum image dimension (1920x1920)
  static const int maxDimension = 1920;

  /// JPEG quality (85%)
  static const int jpegQuality = 85;

  /// Compress an image file
  /// Returns a new compressed file (or the original if compression fails)
  Future<File> compressImage(File file) async {
    try {
      // Get temp directory for compressed output
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${_uuid.v4()}.jpg';

      // Compress the image
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: jpegQuality,
        minWidth: maxDimension,
        minHeight: maxDimension,
        // Keep EXIF data (contains orientation info)
        keepExif: true,
      );

      if (result != null) {
        return File(result.path);
      }

      // Return original if compression fails
      return file;
    } catch (e) {
      debugPrint('MediaCompressionService.compressImage failed: $e');
      // Return original if any error occurs
      return file;
    }
  }

  /// Get the compressed file size estimate
  /// Useful for showing the user how much space will be used
  Future<int> estimateCompressedSize(File file) async {
    try {
      final compressed = await compressImage(file);
      final size = await compressed.length();

      // Clean up temp file if different from original
      if (compressed.path != file.path) {
        await compressed.delete();
      }

      return size;
    } catch (e) {
      debugPrint('MediaCompressionService.estimateCompressedSize failed: $e');
      // Return original size estimate
      return await file.length();
    }
  }
}
