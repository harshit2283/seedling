import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    permissionService: ref.read(permissionServiceProvider),
    storageService: ref.read(fileStorageServiceProvider),
    compressionService: ref.read(compressionServiceProvider),
  );
});

/// Provider for the voice recording service
final voiceRecordingServiceProvider = Provider<VoiceRecordingService>((ref) {
  return VoiceRecordingService(
    permissionService: ref.read(permissionServiceProvider),
    storageService: ref.read(fileStorageServiceProvider),
  );
});

/// Provider for the audio playback service
final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  final service = AudioPlaybackService();
  ref.onDispose(() => service.dispose());
  return service;
});
