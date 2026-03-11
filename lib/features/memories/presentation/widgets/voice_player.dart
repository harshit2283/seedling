import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/media/audio_playback_service.dart';
import '../../../../core/services/providers.dart';

/// Voice memo player widget
class VoicePlayer extends ConsumerStatefulWidget {
  final String audioPath;
  final Duration? duration;
  final bool compact;

  const VoicePlayer({
    super.key,
    required this.audioPath,
    this.duration,
    this.compact = false,
  });

  @override
  ConsumerState<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends ConsumerState<VoicePlayer> {
  late AudioPlaybackService _playbackService;
  StreamSubscription<PlaybackState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  PlaybackState _state = PlaybackState.idle;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _playbackService = ref.read(audioPlaybackServiceProvider);
    _totalDuration = widget.duration ?? Duration.zero;
    _setupListeners();
  }

  void _setupListeners() {
    _stateSubscription = _playbackService.stateStream.listen((state) {
      if (mounted) setState(() => _state = state);
    });

    _positionSubscription = _playbackService.positionStream.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _durationSubscription = _playbackService.durationStream.listen((duration) {
      if (mounted) setState(() => _totalDuration = duration);
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactPlayer();
    }
    return _buildFullPlayer();
  }

  Widget _buildCompactPlayer() {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: SeedlingColors.accentVoice.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlayPauseIcon(size: 20),
            const SizedBox(width: 8),
            Text(
              _formatDuration(_totalDuration),
              style: TextStyle(
                fontSize: 12,
                color: SeedlingColors.accentVoice,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullPlayer() {
    final progress = _totalDuration.inMilliseconds > 0
        ? _position.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SeedlingColors.accentVoice.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SeedlingColors.accentVoice.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Play/pause button
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SeedlingColors.accentVoice,
                    shape: BoxShape.circle,
                  ),
                  child: _buildPlayPauseIcon(size: 24, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              // Progress and time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: SeedlingColors.accentVoice.withValues(
                          alpha: 0.2,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          SeedlingColors.accentVoice,
                        ),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Time display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(
                            fontSize: 12,
                            color: SeedlingColors.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          _formatDuration(_totalDuration),
                          style: TextStyle(
                            fontSize: 12,
                            color: SeedlingColors.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseIcon({required double size, Color? color}) {
    final iconColor = color ?? SeedlingColors.accentVoice;
    final isPlaying = _state == PlaybackState.playing;

    if (PlatformUtils.isIOS) {
      return Icon(
        isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
        size: size,
        color: iconColor,
      );
    }

    return Icon(
      isPlaying ? Icons.pause : Icons.play_arrow,
      size: size,
      color: iconColor,
    );
  }

  void _togglePlayPause() {
    HapticFeedback.selectionClick();
    _playbackService.togglePlayPause(widget.audioPath);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Voice memo indicator for memory cards
class VoiceIndicator extends StatelessWidget {
  final Duration? duration;
  final double size;
  final VoidCallback? onTap;

  const VoiceIndicator({super.key, this.duration, this.size = 60, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: SeedlingColors.accentVoice.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: SeedlingColors.accentVoice.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PlatformUtils.isIOS ? CupertinoIcons.waveform : Icons.graphic_eq,
              color: SeedlingColors.accentVoice,
              size: size * 0.4,
            ),
            if (duration != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatDuration(duration!),
                style: TextStyle(
                  fontSize: 10,
                  color: SeedlingColors.accentVoice,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
