import 'dart:io';
import 'package:seedling/core/services/media/file_storage_service.dart';
import 'package:path_provider/path_provider.dart';

/// Breakdown of storage usage by category
class StorageUsage {
  final int databaseBytes;
  final int photosBytes;
  final int voicesBytes;
  final int objectsBytes;

  const StorageUsage({
    this.databaseBytes = 0,
    this.photosBytes = 0,
    this.voicesBytes = 0,
    this.objectsBytes = 0,
  });

  /// Total storage used in bytes
  int get totalBytes =>
      databaseBytes + photosBytes + voicesBytes + objectsBytes;

  /// Format bytes as human-readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get totalFormatted => formatBytes(totalBytes);
  String get databaseFormatted => formatBytes(databaseBytes);
  String get photosFormatted => formatBytes(photosBytes);
  String get voicesFormatted => formatBytes(voicesBytes);
  String get objectsFormatted => formatBytes(objectsBytes);
}

/// Service for calculating storage usage
class StorageUsageService {
  /// Calculate storage usage breakdown
  Future<StorageUsage> calculateUsage() async {
    final docDir = await getApplicationDocumentsDirectory();

    // Calculate database size
    final dbDir = Directory('${docDir.path}/objectbox');
    final dbSize = await _getDirectorySize(dbDir);

    // Calculate media sizes
    final mediaDir = await FileStorageService.canonicalMediaDirectory();
    final photosDir = Directory('${mediaDir.path}/photos');
    final voicesDir = Directory('${mediaDir.path}/voices');
    final objectsDir = Directory('${mediaDir.path}/objects');

    final photosSize = await _getDirectorySize(photosDir);
    final voicesSize = await _getDirectorySize(voicesDir);
    final objectsSize = await _getDirectorySize(objectsDir);

    return StorageUsage(
      databaseBytes: dbSize,
      photosBytes: photosSize,
      voicesBytes: voicesSize,
      objectsBytes: objectsSize,
    );
  }

  /// Get total size of a directory
  Future<int> _getDirectorySize(Directory dir) async {
    int totalSize = 0;

    if (!await dir.exists()) return 0;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          totalSize += await entity.length();
        } catch (_) {
          // Skip files that can't be read
        }
      }
    }

    return totalSize;
  }
}
