import 'dart:io';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../util/dominant_color.dart';
import '../error_reporter.dart';
import '../media/audio_playback_service.dart';
import '../media/file_storage_service.dart';
import '../media/media_compression_service.dart';
import '../media/permission_service.dart';
import '../media/photo_capture_service.dart';
import '../media/voice_recording_service.dart';

// ============================================================================
// Media Services Providers
// ============================================================================

/// Provider for the permission service
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

/// Provider for the file storage service
/// Must be overridden at app startup after initialization
final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  throw UnimplementedError(
    'fileStorageServiceProvider must be overridden with the initialized service',
  );
});

/// Provider for the media compression service
final compressionServiceProvider = Provider<MediaCompressionService>((ref) {
  return MediaCompressionService();
});

/// Provider for the photo capture service
final photoCaptureServiceProvider = Provider<PhotoCaptureService>((ref) {
  return PhotoCaptureService(
    permissionService: ref.watch(permissionServiceProvider),
    storageService: ref.watch(fileStorageServiceProvider),
    compressionService: ref.watch(compressionServiceProvider),
  );
});

/// Provider for the voice recording service
final voiceRecordingServiceProvider = Provider<VoiceRecordingService>((ref) {
  return VoiceRecordingService(
    permissionService: ref.watch(permissionServiceProvider),
    storageService: ref.watch(fileStorageServiceProvider),
    errorReporter: ref.watch(errorReporterProvider),
  );
});

/// Provider for the audio playback service
final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  final service = AudioPlaybackService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Resolves a stored media path to an absolute filesystem path.
/// Memoised per stored path so repeated card builds reuse the same Future.
final resolvedMediaPathProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, storedPath) async {
  if (storedPath.isEmpty) return null;
  return FileStorageService.resolveMediaPath(storedPath);
});

/// File-resolved variant of [resolvedMediaPathProvider]; returns null when the
/// underlying file is missing.
final resolvedMediaFileProvider = FutureProvider.autoDispose
    .family<File?, String>((ref, storedPath) async {
  final path = await ref.watch(resolvedMediaPathProvider(storedPath).future);
  if (path == null) return null;
  return File(path);
});

/// Extracts a subtle dominant color from a stored media path. Used to tint
/// the entry detail header for photo/object entries. Returns null on failure.
final dominantColorProvider = FutureProvider.autoDispose
    .family<Color?, String>((ref, storedPath) async {
  final path = await ref.watch(resolvedMediaPathProvider(storedPath).future);
  if (path == null) return null;
  final file = File(path);
  if (!await file.exists()) return null;
  return extractDominantColor(file);
});
