import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/media/audio_playback_service.dart';
import '../../../../core/services/providers.dart';

/// Content widget for voice capture mode
class VoiceCaptureContent extends ConsumerStatefulWidget {
  final String? initialVoicePath;
  final Duration? initialDuration;
  final ValueChanged<String?> onVoicePathChanged;
  final ValueChanged<Duration?> onDurationChanged;
  final ValueChanged<String> onTextChanged;
  final String text;

  const VoiceCaptureContent({
    super.key,
    this.initialVoicePath,
    this.initialDuration,
    required this.onVoicePathChanged,
    required this.onDurationChanged,
    required this.onTextChanged,
    required this.text,
  });

  @override
  ConsumerState<VoiceCaptureContent> createState() =>
      _VoiceCaptureContentState();
}

class _VoiceCaptureContentState extends ConsumerState<VoiceCaptureContent>
    with TickerProviderStateMixin {
  String? _voicePath;
  Duration? _recordedDuration;
  bool _isRecording = false;
  Duration _currentDuration = Duration.zero;
  Timer? _durationTimer;
  late TextEditingController _textController;
  late AnimationController _pulseController;
  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  StreamSubscription<Duration>? _playbackPositionSubscription;
  StreamSubscription<Duration>? _playbackDurationSubscription;
  late AudioPlaybackService _playbackService;
  double _currentAmplitude = 0.0;
  PlaybackState _playbackState = PlaybackState.idle;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  static const int _waveformBarCount = 24;
  final List<double> _waveformSamples =
      List<double>.filled(_waveformBarCount, 0.0);
  int _waveformCursor = 0;
  late AnimationController _waveformFadeController;

  @override
  void initState() {
    super.initState();
    _voicePath = widget.initialVoicePath;
    _recordedDuration = widget.initialDuration;
    _textController = TextEditingController(text: widget.text);
    _playbackService = ref.read(audioPlaybackServiceProvider);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _waveformFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 0,
    );
    _playbackDuration = widget.initialDuration ?? Duration.zero;
    _setupPlaybackListeners();

    // Set up max duration callback
    final service = ref.read(voiceRecordingServiceProvider);
    service.onMaxDurationReached = _onMaxDurationReached;
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _playbackPositionSubscription?.cancel();
    _playbackDurationSubscription?.cancel();
    if (_voicePath != null && _playbackService.currentPath == _voicePath) {
      unawaited(
        _playbackService.stop().catchError((error, stackTrace) {
          debugPrint('Failed to stop voice playback during dispose: $error');
        }),
      );
    }
    _textController.dispose();
    _pulseController.dispose();
    _waveformFadeController.dispose();
    super.dispose();
  }

  void _setupPlaybackListeners() {
    _playbackStateSubscription = _playbackService.stateStream.listen((state) {
      if (!mounted || _playbackService.currentPath != _voicePath) return;
      setState(() {
        _playbackState = state;
        if (state == PlaybackState.completed) {
          _playbackPosition = _playbackDuration;
        }
      });
    });

    _playbackPositionSubscription = _playbackService.positionStream.listen((
      position,
    ) {
      if (!mounted || _playbackService.currentPath != _voicePath) return;
      setState(() => _playbackPosition = position);
    });

    _playbackDurationSubscription = _playbackService.durationStream.listen((
      duration,
    ) {
      if (!mounted || _playbackService.currentPath != _voicePath) return;
      setState(() => _playbackDuration = duration);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_voicePath != null) {
      return _buildRecordingPreview();
    }
    return _buildRecordingInterface();
  }

  Widget _buildRecordingInterface() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Text(
          _isRecording ? 'Recording...' : 'Hold to record',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _isRecording
                ? SeedlingColors.accentVoice
                : SeedlingColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isRecording ? _formatDuration(_currentDuration) : 'Max 2 minutes',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: SeedlingColors.textMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 24),
        // Record button
        GestureDetector(
          onTapDown: (_) => _startRecording(),
          onTapUp: (_) => _stopRecording(),
          onTapCancel: () => _cancelRecording(),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = _isRecording
                  ? 1.0 + (_pulseController.value * 0.1)
                  : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? SeedlingColors.accentVoice
                    : SeedlingColors.accentVoice.withValues(alpha: 0.15),
                border: Border.all(color: SeedlingColors.accentVoice, width: 3),
                boxShadow: _isRecording
                    ? [
                        BoxShadow(
                          color: SeedlingColors.accentVoice.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  PlatformUtils.isIOS ? CupertinoIcons.mic_fill : Icons.mic,
                  size: 40,
                  color: _isRecording
                      ? Colors.white
                      : SeedlingColors.accentVoice,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Amplitude indicator
        if (_isRecording) _buildAmplitudeIndicator(),
      ],
    );
  }

  Widget _buildAmplitudeIndicator() {
    return FadeTransition(
      opacity: _waveformFadeController,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _WaveformPainter(
                samples: List<double>.unmodifiable(_waveformSamples),
                cursor: _waveformCursor,
                color: SeedlingColors.accentVoice,
              ),
              size: const Size(double.infinity, 44),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingPreview() {
    final effectiveDuration = _playbackDuration.inMilliseconds > 0
        ? _playbackDuration
        : (_recordedDuration ?? Duration.zero);
    final progress = effectiveDuration.inMilliseconds > 0
        ? _playbackPosition.inMilliseconds / effectiveDuration.inMilliseconds
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Recording indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: SeedlingColors.accentVoice.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: SeedlingColors.accentVoice.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                PlatformUtils.isIOS
                    ? CupertinoIcons.waveform
                    : Icons.graphic_eq,
                color: SeedlingColors.accentVoice,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice memo',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: SeedlingColors.textPrimary,
                      ),
                    ),
                    Text(
                      _formatDuration(effectiveDuration),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SeedlingColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label:
                    _playbackService.currentPath == _voicePath &&
                        _playbackState == PlaybackState.playing
                    ? 'Pause voice memo playback'
                    : 'Play voice memo',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _togglePlayback,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: SeedlingColors.accentVoice,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _playbackIcon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Delete button
              Semantics(
                button: true,
                label: 'Delete voice memo recording',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _removeRecording,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          PlatformUtils.isIOS
                              ? CupertinoIcons.xmark
                              : Icons.close,
                          color: SeedlingColors.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: SeedlingColors.accentVoice.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(
              SeedlingColors.accentVoice,
            ),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(_playbackPosition),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: SeedlingColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              _formatDuration(effectiveDuration),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: SeedlingColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Optional text field
        _buildTextField(),
      ],
    );
  }

  Widget _buildTextField() {
    if (PlatformUtils.isIOS) {
      return CupertinoTextField(
        controller: _textController,
        maxLines: 2,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        placeholder: 'Add a note (optional)',
        placeholderStyle: TextStyle(
          color: CupertinoColors.placeholderText,
          fontSize: 16,
        ),
        style: const TextStyle(fontSize: 16, color: SeedlingColors.textPrimary),
        decoration: const BoxDecoration(color: Colors.transparent),
        padding: EdgeInsets.zero,
        onChanged: widget.onTextChanged,
      );
    }

    return TextField(
      controller: _textController,
      maxLines: 2,
      minLines: 1,
      textCapitalization: TextCapitalization.sentences,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: 'Add a note (optional)',
        hintStyle: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: SeedlingColors.textMuted),
        border: InputBorder.none,
        filled: false,
      ),
      onChanged: widget.onTextChanged,
    );
  }

  Future<void> _startRecording() async {
    if (_isRecording || _voicePath != null) return;

    final service = ref.read(voiceRecordingServiceProvider);
    final result = await service.startRecording();

    if (!mounted) return;

    if (!result.started) {
      if (result.permissionDenied) {
        await _showPermissionDenied();
        return;
      }
      if (result.error != null) {
        _showError(result.error!);
        return;
      }
      _showError('Could not start recording');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
      for (int i = 0; i < _waveformSamples.length; i++) {
        _waveformSamples[i] = 0.0;
      }
      _waveformCursor = 0;
    });
    _waveformFadeController.forward();

    // Start duration timer
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _isRecording) {
        setState(() {
          _currentDuration = service.currentDuration;
        });
      }
    });

    // Listen to amplitude for visualization
    _amplitudeSubscription = service.amplitudeStream.listen((amplitude) {
      if (mounted && _isRecording) {
        // Normalize amplitude (-160 to 0 dB) to 0.0 to 1.0
        final normalized = ((amplitude + 60) / 60).clamp(0.0, 1.0);
        // Smooth toward the new sample to avoid jagged spikes.
        final previous = _waveformSamples[_waveformCursor];
        final smoothed = previous * 0.35 + normalized * 0.65;
        setState(() {
          _currentAmplitude = normalized;
          _waveformSamples[_waveformCursor] = smoothed;
          _waveformCursor = (_waveformCursor + 1) % _waveformSamples.length;
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    _durationTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _waveformFadeController.reverse();

    final service = ref.read(voiceRecordingServiceProvider);
    final result = await service.stopRecording();

    if (!mounted) return;

    setState(() {
      _isRecording = false;
      _currentAmplitude = 0.0;
    });

    if (result.isSuccess) {
      HapticFeedback.lightImpact();
      setState(() {
        _voicePath = result.path;
        _recordedDuration = result.duration;
        _playbackPosition = Duration.zero;
        _playbackDuration = result.duration ?? Duration.zero;
      });
      widget.onVoicePathChanged(result.path);
      widget.onDurationChanged(result.duration);
    } else if (result.error != null) {
      _showError(result.error!);
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    _durationTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _waveformFadeController.reverse();

    final service = ref.read(voiceRecordingServiceProvider);
    await service.cancelRecording();

    if (!mounted) return;

    HapticFeedback.selectionClick();
    setState(() {
      _isRecording = false;
      _currentDuration = Duration.zero;
      _currentAmplitude = 0.0;
    });
  }

  void _onMaxDurationReached() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    // Recording is auto-stopped by the service
    _durationTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _waveformFadeController.reverse();
    setState(() {
      _isRecording = false;
      _currentAmplitude = 0.0;
    });
  }

  Future<void> _removeRecording() async {
    HapticFeedback.selectionClick();
    if (_voicePath != null && _playbackService.currentPath == _voicePath) {
      try {
        await _playbackService.stop();
      } catch (error) {
        debugPrint('Failed to stop voice playback before delete: $error');
        if (mounted) {
          _showError('Could not stop voice playback');
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _voicePath = null;
      _recordedDuration = null;
      _currentDuration = Duration.zero;
      _playbackState = PlaybackState.idle;
      _playbackPosition = Duration.zero;
      _playbackDuration = Duration.zero;
    });
    widget.onVoicePathChanged(null);
    widget.onDurationChanged(null);
  }

  Future<void> _togglePlayback() async {
    final voicePath = _voicePath;
    if (voicePath == null) return;
    HapticFeedback.selectionClick();
    try {
      await _playbackService.togglePlayPause(voicePath);
    } catch (error) {
      debugPrint('Failed to toggle voice playback: $error');
      if (mounted) {
        _showError('Could not play this voice memo');
      }
    }
  }

  IconData get _playbackIcon {
    final isPlaying =
        _playbackService.currentPath == _voicePath &&
        _playbackState == PlaybackState.playing;
    if (PlatformUtils.isIOS) {
      return isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill;
    }
    return isPlaying ? Icons.pause : Icons.play_arrow;
  }

  Future<void> _showPermissionDenied() async {
    final permissionService = ref.read(permissionServiceProvider);
    final shouldOpenSettings = await permissionService.shouldOpenSettingsFor(
      Permission.microphone,
    );
    if (!mounted) return;
    if (shouldOpenSettings) {
      await permissionService.showPermissionDeniedDialog(
        context,
        permissionName: 'Microphone',
        purpose: 'record voice memories',
      );
      return;
    }
    _showError('Microphone permission was denied');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples;
  final int cursor;
  final Color color;

  _WaveformPainter({
    required this.samples,
    required this.cursor,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final barCount = samples.length;
    final spacing = 2.0;
    final totalSpacing = spacing * (barCount - 1);
    final barWidth = ((size.width - totalSpacing) / barCount).clamp(1.5, 6.0);
    final centerY = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final readIndex = (cursor + i) % barCount;
      final value = samples[readIndex].clamp(0.0, 1.0);
      final alpha = 0.35 + value * 0.65;
      paint.color = color.withValues(alpha: alpha);

      final barHeight = (size.height * 0.18) + value * (size.height * 0.78);
      final x = i * (barWidth + spacing);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - barHeight / 2, barWidth, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.cursor != cursor ||
        oldDelegate.color != color ||
        !identical(oldDelegate.samples, samples);
  }
}
