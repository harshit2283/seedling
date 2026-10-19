import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../error_reporter.dart';

/// Service for managing media file storage
/// Organizes files into photos/, voices/, objects/ subdirectories
class FileStorageService {
  FileStorageService({ErrorReporter? errorReporter})
    : _errorReporter = errorReporter ?? const ErrorReporter();

  final ErrorReporter _errorReporter;

  static const _uuid = Uuid();
  static const MethodChannel _fileProtectionChannel = MethodChannel(
    'com.seedling.media/file_protection',
  );
  static const Set<String> _photoExtensions = {
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif',
    'webp',
  };
  static const Set<String> _voiceExtensions = {
    'm4a',
    'aac',
    'mp3',
    'wav',
    'caf',
  };

  Directory? _mediaDirectory;

  /// Get the base path for media storage
  String get basePath => _mediaDirectory?.path ?? '';

  static Future<Directory> canonicalMediaDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    return Directory('${appDir.path}/media');
  }

  static Future<String?> resolveMediaPath(String? storedPath) async {
    final rawPath = storedPath?.trim();
    if (rawPath == null || rawPath.isEmpty) return null;

    final directFile = File(rawPath);
    if (await directFile.exists()) {
      return directFile.path;
    }

    final relativePath = _extractRelativeMediaPath(rawPath);
    final baseDir = await canonicalMediaDirectory();

    if (relativePath != null) {
      final candidate = File('${baseDir.path}/$relativePath');
      if (await candidate.exists()) {
        return candidate.path;
      }
    }

    final baseName = _fileNameFromPath(rawPath);
    final mediaFolder = _extractMediaFolder(rawPath);
    if (mediaFolder == null || baseName.isEmpty) {
      return null;
    }

    final candidate = File('${baseDir.path}/$mediaFolder/$baseName');
    if (await candidate.exists()) {
      return candidate.path;
    }

    return null;
  }

  static Future<File?> resolveMediaFile(String? storedPath) async {
    final resolvedPath = await resolveMediaPath(storedPath);
    if (resolvedPath == null) return null;
    return File(resolvedPath);
  }

  /// Initialize the media directory
  Future<void> init() async {
    _mediaDirectory = await canonicalMediaDirectory();

    // Create subdirectories if they don't exist
    if (!await _mediaDirectory!.exists()) {
      await _mediaDirectory!.create(recursive: true);
      await _protectDirectory(_mediaDirectory!);
    }
    await _getPhotosDirectory();
    await _getVoicesDirectory();
    await _getObjectsDirectory();
  }

  /// Get the photos directory
  Future<Directory> _getPhotosDirectory() async {
    final dir = Directory('${_mediaDirectory!.path}/photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      await _protectDirectory(dir);
    }
    return dir;
  }

  /// Get the voices directory
  Future<Directory> _getVoicesDirectory() async {
    final dir = Directory('${_mediaDirectory!.path}/voices');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      await _protectDirectory(dir);
    }
    return dir;
  }

  /// Get the objects directory
  Future<Directory> _getObjectsDirectory() async {
    final dir = Directory('${_mediaDirectory!.path}/objects');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      await _protectDirectory(dir);
    }
    return dir;
  }

  /// Generate a unique path for a photo file
  Future<String> generatePhotoPath({String extension = 'jpg'}) async {
    final dir = await _getPhotosDirectory();
    final safeExtension = _sanitizeExtension(
      extension,
      allowed: _photoExtensions,
      fallback: 'jpg',
    );
    final filename = '${_uuid.v4()}.$safeExtension';
    return '${dir.path}/$filename';
  }

  /// Generate a unique path for a voice file
  Future<String> generateVoicePath({String extension = 'm4a'}) async {
    final dir = await _getVoicesDirectory();
    final safeExtension = _sanitizeExtension(
      extension,
      allowed: _voiceExtensions,
      fallback: 'm4a',
    );
    final filename = '${_uuid.v4()}.$safeExtension';
    return '${dir.path}/$filename';
  }

  /// Generate a unique path for an object photo
  Future<String> generateObjectPhotoPath({String extension = 'jpg'}) async {
    final dir = await _getObjectsDirectory();
    final safeExtension = _sanitizeExtension(
      extension,
      allowed: _photoExtensions,
      fallback: 'jpg',
    );
    final filename = '${_uuid.v4()}.$safeExtension';
    return '${dir.path}/$filename';
  }

  /// Copy a file to the photos directory
  Future<String> savePhoto(File sourceFile) async {
    final extension = _extensionFromPath(sourceFile.path);
    final destPath = await generatePhotoPath(extension: extension);
    await sourceFile.copy(destPath);
    await _protectFile(destPath);
    return destPath;
  }

  /// Copy a file to the objects directory
  Future<String> saveObjectPhoto(File sourceFile) async {
    final extension = _extensionFromPath(sourceFile.path);
    final destPath = await generateObjectPhotoPath(extension: extension);
    await sourceFile.copy(destPath);
    await _protectFile(destPath);
    return destPath;
  }

  /// Move a recorded voice file to the voices directory
  Future<String> saveVoice(String sourcePath) async {
    final sourceFile = File(sourcePath);
    final extension = _extensionFromPath(sourcePath);
    final destPath = await generateVoicePath(extension: extension);
    await sourceFile.copy(destPath);
    await _protectFile(destPath);
    // Delete the original temp file
    await sourceFile.delete();
    return destPath;
  }

  /// Delete a media file
  Future<bool> deleteFile(String path) async {
    try {
      if (!await _isPathAllowed(path)) return false;
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e, st) {
      _errorReporter.report(
        e,
        stack: st,
        context: 'FileStorageService.deleteFile path="$path"',
      );
      return false;
    }
  }

  /// Check if a media file exists
  Future<bool> fileExists(String path) async {
    if (!await _isPathAllowed(path)) return false;
    return await File(path).exists();
  }

  /// Get file size in bytes
  Future<int> getFileSize(String path) async {
    if (!await _isPathAllowed(path)) return 0;
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// Delete all media files and recreate required folders.
  Future<void> clearAllMedia() async {
    final mediaDirectory = _mediaDirectory;
    if (mediaDirectory == null) return;

    if (await mediaDirectory.exists()) {
      await mediaDirectory.delete(recursive: true);
    }

    await _getPhotosDirectory();
    await _getVoicesDirectory();
    await _getObjectsDirectory();
  }

  Future<bool> _isPathAllowed(String path) async {
    final mediaDirectory = _mediaDirectory;
    if (mediaDirectory == null || path.isEmpty) return false;

    final basePath = await mediaDirectory.resolveSymbolicLinks();
    final targetFile = File(path);
    if (!await targetFile.exists()) return false;

    final targetPath = await targetFile.resolveSymbolicLinks();
    return targetPath.startsWith('$basePath${Platform.pathSeparator}');
  }

  String _sanitizeExtension(
    String raw, {
    required Set<String> allowed,
    required String fallback,
  }) {
    final normalized = raw.trim().toLowerCase().replaceFirst('.', '');
    final safe = RegExp(r'^[a-z0-9]+$').hasMatch(normalized) ? normalized : '';
    if (allowed.contains(safe)) return safe;
    return fallback;
  }

  String _extensionFromPath(String path) {
    final fileName = _fileNameFromPath(path);
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1);
  }

  static String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  static String? _extractRelativeMediaPath(String path) {
    final normalized = path.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) return null;
    if (normalized.startsWith('media/')) {
      return normalized.substring('media/'.length);
    }
    for (final folder in ['photos', 'voices', 'objects']) {
      final marker = '/media/$folder/';
      final markerIndex = normalized.indexOf(marker);
      if (markerIndex >= 0) {
        return normalized.substring(markerIndex + '/media/'.length);
      }
      if (normalized.startsWith('$folder/')) {
        return normalized;
      }
    }
    return null;
  }

  static String? _extractMediaFolder(String path) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    for (final folder in ['photos', 'voices', 'objects']) {
      if (normalized.contains('/$folder/') ||
          normalized.startsWith('$folder/')) {
        return folder;
      }
    }
    return null;
  }

  Future<void> _protectDirectory(Directory directory) async {
    await _protectPath(directory.path);
  }

  Future<void> _protectFile(String path) async {
    await _protectPath(path);
  }

  Future<void> _protectPath(String path) async {
    if (!Platform.isIOS) return;
    try {
      await _fileProtectionChannel.invokeMethod<void>('protectPath', {
        'path': path,
      });
    } catch (e) {
      debugPrint(
        'FileStorageService._protectPath best-effort protection failed for "$path": $e',
      );
      // File protection is best-effort when the platform channel is unavailable.
    }
  }
}
