import 'package:flutter/services.dart';

/// Result of a transcription operation
class TranscriptionResult {
  final String transcription;
  final List<TranscriptionSegment> segments;
  final bool isFinal;

  const TranscriptionResult({
    required this.transcription,
    this.segments = const [],
    this.isFinal = true,
  });

  bool get isEmpty => transcription.isEmpty;
  bool get isNotEmpty => transcription.isNotEmpty;
}

/// A segment of transcribed speech with timing info
class TranscriptionSegment {
  final String text;
  final double timestamp;
  final double duration;
  final double confidence;

  const TranscriptionSegment({
    required this.text,
    required this.timestamp,
    required this.duration,
    required this.confidence,
  });
}

/// Speech transcription service
///
/// Uses Apple Speech framework on iOS and Android SpeechRecognizer.
/// On-device recognition is preferred where the platform supports it.
class SpeechTranscriptionService {
  static const _channel = MethodChannel('com.seedling.speech_transcription');

  bool? _cachedAvailability;

  /// Check if on-device transcription is available
  Future<bool> isAvailable() async {
    if (_cachedAvailability != null) return _cachedAvailability!;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'isAvailable',
      );
      if (result == null) return false;
      final available = result['isAvailable'] as bool? ?? false;
      final onDevice = result['supportsOnDevice'] as bool? ?? false;
      _cachedAvailability = available && onDevice;
      return _cachedAvailability!;
    } on PlatformException {
      _cachedAvailability = false;
      return false;
    }
  }

  /// Request speech recognition permission
  Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'requestPermission',
      );
      return result?['authorized'] as bool? ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Transcribe an audio file at the given path
  ///
  /// Returns null if transcription fails or is unavailable.
  /// [locale] optionally specifies the language (e.g., 'en-US').
  Future<TranscriptionResult?> transcribe(
    String filePath, {
    String? locale,
  }) async {
    try {
      final args = <String, dynamic>{'filePath': filePath};
      if (locale != null) args['locale'] = locale;

      final result = await _channel.invokeMapMethod<String, dynamic>(
        'transcribe',
        args,
      );
      if (result == null) return null;

      final segments = <TranscriptionSegment>[];
      final rawSegments = result['segments'] as List<dynamic>? ?? [];
      for (final seg in rawSegments) {
        if (seg is Map) {
          segments.add(
            TranscriptionSegment(
              text: seg['substring'] as String? ?? '',
              timestamp: (seg['timestamp'] as num?)?.toDouble() ?? 0.0,
              duration: (seg['duration'] as num?)?.toDouble() ?? 0.0,
              confidence: (seg['confidence'] as num?)?.toDouble() ?? 0.0,
            ),
          );
        }
      }

      return TranscriptionResult(
        transcription: result['transcription'] as String? ?? '',
        segments: segments,
        isFinal: result['isFinal'] as bool? ?? true,
      );
    } on PlatformException {
      return null;
    }
  }

  /// Reset cached availability (e.g., after settings change)
  void resetCache() {
    _cachedAvailability = null;
  }
}
