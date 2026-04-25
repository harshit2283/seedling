import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../error_reporter.dart';
import 'file_storage_service.dart';
import 'permission_service.dart';

/// State of the voice recording
enum RecordingState { idle, recording, paused, stopped }

/// Result of a voice recording operation
class VoiceRecordingResult {
  final String? path;
  final Duration? duration;
  final String? error;
  final bool permissionDenied;

  VoiceRecordingResult._({
    this.path,
    this.duration,
    this.error,
    this.permissionDenied = false,
  });

  factory VoiceRecordingResult.success(String path, Duration duration) =>
      VoiceRecordingResult._(path: path, duration: duration);

  factory VoiceRecordingResult.error(String message) =>
      VoiceRecordingResult._(error: message);

  factory VoiceRecordingResult.permissionDenied() =>
      VoiceRecordingResult._(permissionDenied: true);

  factory VoiceRecordingResult.cancelled() => VoiceRecordingResult._();

  bool get isSuccess => path != null;
  bool get isCancelled => path == null && error == null && !permissionDenied;
}

/// Result of attempting to start a voice recording.
class VoiceStartRecordingResult {
  final bool started;
  final String? error;
  final bool permissionDenied;

  const VoiceStartRecordingResult._({
    required this.started,
    this.error,
    this.permissionDenied = false,
  });

  factory VoiceStartRecordingResult.started() =>
      const VoiceStartRecordingResult._(started: true);

  factory VoiceStartRecordingResult.permissionDenied() =>
      const VoiceStartRecordingResult._(started: false, permissionDenied: true);

  factory VoiceStartRecordingResult.error(String message) =>
      VoiceStartRecordingResult._(started: false, error: message);
}

/// Service for recording voice memos
class VoiceRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final PermissionService _permissionService;
  final FileStorageService _storageService;
  final ErrorReporter _errorReporter;

  RecordingState _state = RecordingState.idle;
  DateTime? _recordingStartTime;
  String? _currentRecordingPath;
  Timer? _maxDurationTimer;

  /// Maximum recording duration (2 minutes)
  static const maxDuration = Duration(minutes: 2);

  /// Callback when max duration is reached
  VoidCallback? onMaxDurationReached;

  VoiceRecordingService({
    required PermissionService permissionService,
    required FileStorageService storageService,
    ErrorReporter? errorReporter,
  }) : _permissionService = permissionService,
       _storageService = storageService,
       _errorReporter = errorReporter ?? const ErrorReporter();

  /// Current recording state
  RecordingState get state => _state;

  /// Whether currently recording
  bool get isRecording => _state == RecordingState.recording;

  /// Current recording duration
  Duration get currentDuration {
    if (_recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Stream of amplitude values for visualization
  Stream<double> get amplitudeStream => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((amp) => amp.current);

  /// Start recording
  Future<VoiceStartRecordingResult> startRecording() async {
    if (_state == RecordingState.recording) {
      return VoiceStartRecordingResult.error('Recording already in progress');
    }

    // Check permission
    final hasPermission = await _permissionService
        .requestMicrophonePermission();
    if (!hasPermission) {
      return VoiceStartRecordingResult.permissionDenied();
    }

    try {
      // Generate path for the recording
      _currentRecordingPath = await _storageService.generateVoicePath();

      // Configure and start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _state = RecordingState.recording;
      _recordingStartTime = DateTime.now();

      // Set up max duration timer
      _maxDurationTimer = Timer(maxDuration, () {
        unawaited(stopRecording());
        onMaxDurationReached?.call();
      });

      return VoiceStartRecordingResult.started();
    } catch (e, st) {
      _state = RecordingState.idle;
      _currentRecordingPath = null;
      _errorReporter.report(
        e,
        stack: st,
        context: 'VoiceRecordingService.startRecording',
      );
      return VoiceStartRecordingResult.error('Could not start recording');
    }
  }

  /// Stop recording and return the result
  Future<VoiceRecordingResult> stopRecording() async {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    if (_state != RecordingState.recording) {
      return VoiceRecordingResult.cancelled();
    }

    try {
      final path = await _recorder.stop();
      final duration = currentDuration;

      _state = RecordingState.stopped;
      _recordingStartTime = null;

      if (path == null) {
        return VoiceRecordingResult.error('Recording failed');
      }

      // Save to the voices directory (moves from temp location)
      final savedPath = await _storageService.saveVoice(path);

      _state = RecordingState.idle;
      _currentRecordingPath = null;

      return VoiceRecordingResult.success(savedPath, duration);
    } catch (e, st) {
      _errorReporter.report(
        e,
        stack: st,
        context: 'VoiceRecordingService.stopRecording',
      );
      _state = RecordingState.idle;
      _currentRecordingPath = null;
      return VoiceRecordingResult.error('Could not save recording');
    }
  }

  /// Cancel the current recording
  Future<void> cancelRecording() async {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    if (_state == RecordingState.recording) {
      try {
        await _recorder.stop();
        // Delete the temp file
        if (_currentRecordingPath != null) {
          await _storageService.deleteFile(_currentRecordingPath!);
        }
      } catch (e, st) {
        _errorReporter.report(
          e,
          stack: st,
          context: 'VoiceRecordingService.cancelRecording',
        );
      }
    }

    _state = RecordingState.idle;
    _recordingStartTime = null;
    _currentRecordingPath = null;
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await _permissionService.hasMicrophonePermission();
  }

  /// Dispose of resources
  Future<void> dispose() async {
    _maxDurationTimer?.cancel();
    await _recorder.dispose();
  }
}
