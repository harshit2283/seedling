import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/palette.dart';
import '../../../../app/theme/radius.dart';
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
    final palette = context.palette;
    final accent = palette.accentVoice;
    final progress = _totalDuration.inMilliseconds > 0
        ? (_position.inMilliseconds / _totalDuration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final isPlaying = _state == PlaybackState.playing;
    final hasDuration = _totalDuration > Duration.zero;
    final timeStyle = TextStyle(
      fontSize: 12.5,
      color: palette.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // A soft voice-tinted block: a large play button and a waveform that
    // fills in as the memo plays. Never auto-plays.
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: palette.isDark ? 0.26 : 0.16),
              palette.card,
            ),
            Color.alphaBlend(
              accent.withValues(alpha: palette.isDark ? 0.12 : 0.06),
              palette.card,
            ),
          ],
        ),
        borderRadius: SeedlingRadius.card,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: isPlaying ? 'Pause voice memo' : 'Play voice memo',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: palette.isDark
                      ? null
                      : [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: _buildPlayPauseIcon(size: 26, color: palette.onMedia),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    height: 40,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _WaveformPainter(
                        seed: widget.audioPath.hashCode,
                        progress: progress,
                        played: accent,
                        unplayed: accent.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hasDuration || isPlaying
                          ? _formatDuration(_position)
                          : 'Voice memo',
                      style: timeStyle,
                    ),
                    if (hasDuration)
                      Text(_formatDuration(_totalDuration), style: timeStyle),
                  ],
                ),
              ],
            ),
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

/// A calm, deterministic waveform: the same memo always draws the same shape.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.seed,
    required this.progress,
    required this.played,
    required this.unplayed,
  });

  final int seed;
  final double progress;
  final Color played;
  final Color unplayed;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 3.0;
    const gap = 3.0;
    final count = ((size.width + gap) / (barWidth + gap)).floor();
    if (count <= 0) return;
    var x = seed & 0x7fffffff;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    for (var i = 0; i < count; i++) {
      x = (x * 1103515245 + 12345) & 0x7fffffff;
      final noise = (x % 1000) / 1000.0;
      // A gentle swell so it reads as speech, not static.
      final envelope = 0.35 + 0.65 * (1 - ((i / count) * 2 - 1).abs() * 0.6);
      final h = (0.18 + 0.82 * noise) * envelope * size.height;
      final dx = i * (barWidth + gap) + barWidth / 2;
      paint.color = (i + 0.5) / count <= progress ? played : unplayed;
      canvas.drawLine(
        Offset(dx, (size.height - h) / 2),
        Offset(dx, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.seed != seed ||
      old.played != played ||
      old.unplayed != unplayed;
}
