import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// State of audio playback
enum PlaybackState { idle, playing, paused, completed }

/// Service for playing voice memos
class AudioPlaybackService {
  final AudioPlayer _player = AudioPlayer();

  PlaybackState _state = PlaybackState.idle;
  String? _currentPath;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final _stateController = StreamController<PlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  AudioPlaybackService() {
    _setupListeners();
  }

  void _setupListeners() {
    _player.onPlayerStateChanged.listen((state) {
      switch (state) {
        case PlayerState.playing:
          _state = PlaybackState.playing;
          break;
        case PlayerState.paused:
          _state = PlaybackState.paused;
          break;
        case PlayerState.stopped:
          _state = PlaybackState.idle;
          break;
        case PlayerState.completed:
          _state = PlaybackState.completed;
          _position = _duration;
          break;
        case PlayerState.disposed:
          _state = PlaybackState.idle;
          break;
      }
      _stateController.add(_state);
    });

    _player.onPositionChanged.listen((position) {
      _position = position;
      _positionController.add(position);
    });

    _player.onDurationChanged.listen((duration) {
      _duration = duration;
      _durationController.add(duration);
    });
  }

  /// Current playback state
  PlaybackState get state => _state;

  /// Current file path, if any.
  String? get currentPath => _currentPath;

  /// Whether currently playing
  bool get isPlaying => _state == PlaybackState.playing;

  /// Current position
  Duration get position => _position;

  /// Total duration
  Duration get duration => _duration;

  /// Stream of playback state changes
  Stream<PlaybackState> get stateStream => _stateController.stream;

  /// Stream of position changes
  Stream<Duration> get positionStream => _positionController.stream;

  /// Stream of duration changes
  Stream<Duration> get durationStream => _durationController.stream;

  /// Progress as a value between 0.0 and 1.0
  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  /// Play a voice memo from file path
  Future<void> play(String path) async {
    if (_currentPath == path && _state == PlaybackState.paused) {
      // Resume if same file was paused
      await _player.resume();
      return;
    }

    // Stop any current playback
    await stop();

    _currentPath = path;
    await _player.play(DeviceFileSource(path));
  }

  /// Pause playback
  Future<void> pause() async {
    if (_state == PlaybackState.playing) {
      await _player.pause();
    }
  }

  /// Resume playback
  Future<void> resume() async {
    if (_state == PlaybackState.paused) {
      await _player.resume();
    }
  }

  /// Stop playback
  Future<void> stop() async {
    await _player.stop();
    _position = Duration.zero;
    _positionController.add(_position);
  }

  /// Seek to a position
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Seek to a progress value (0.0 to 1.0)
  Future<void> seekToProgress(double progress) async {
    final position = Duration(
      milliseconds: (_duration.inMilliseconds * progress).round(),
    );
    await seek(position);
  }

  /// Toggle play/pause
  Future<void> togglePlayPause(String path) async {
    if (_currentPath == path && _state == PlaybackState.playing) {
      await pause();
    } else if (_currentPath == path && _state == PlaybackState.paused) {
      await resume();
    } else {
      await play(path);
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _player.dispose();
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
  }
}
