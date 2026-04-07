import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/services/bytes_audio_source.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  List<AudioFile> _queue = [];
  List<AudioFile> _originalQueue = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;
  List<double> _fftData = List.filled(64, 0);
  bool _isScrubbing = false;
  DateTime? _lastScrubTime;
  DateTime? _lastCompleteEvent;

  AudioPlayer get player => _player;
  List<AudioFile> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get shuffle => _shuffle;
  LoopMode get loopMode => _loopMode;
  bool get isScrubbing => _isScrubbing;
  List<double> get fftData => _fftData;

  AudioFile? get currentTrack => _queue.isNotEmpty ? _queue[_currentIndex] : null;
  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  PlayerProvider() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onTrackComplete();
      } else if (state.processingState == ProcessingState.idle) {
        _isPlaying = false;
        _fftData = List.filled(64, 0);
      } else {
        _isPlaying = state.playing;
        if (!state.playing) {
          _fftData = List.filled(64, 0);
        }
      }
      notifyListeners();
    });

    _player.positionStream.listen((pos) {
      if (_isPlaying) {
        _updateSimulatedFFT(pos);
      }
    });
  }

  void _updateSimulatedFFT(Duration? position) {
    if (position == null) return;
    final rng = math.Random(position.inMilliseconds.hashCode);
    _fftData = List.generate(64, (i) {
      final frequency = (i / 64) * 20000;
      double amplitude;
      if (frequency < 200) {
        amplitude = 0.6 + rng.nextDouble() * 0.4;
      } else if (frequency < 2000) {
        amplitude = 0.4 + rng.nextDouble() * 0.5;
      } else if (frequency < 8000) {
        amplitude = 0.2 + rng.nextDouble() * 0.4;
      } else {
        amplitude = 0.1 + rng.nextDouble() * 0.3;
      }
      return (amplitude * 255 - 128).clamp(-128, 127).toDouble();
    });
    notifyListeners();
  }

  Future<void> playTrack(AudioFile track, List<AudioFile> queue) async {
    _isScrubbing = false;
    _queue = List.from(queue);
    _originalQueue = List.from(queue);
    _currentIndex = queue.indexOf(track);
    if (_currentIndex == -1) {
      _currentIndex = 0;
      _queue = [track];
      _originalQueue = [track];
    }
    try {
      if (kIsWeb && track.audioBytes != null) {
        final mimeType = _getMimeType(track.fileName);
        final source = BytesAudioSource(
          bytes: track.audioBytes!,
          mimeType: mimeType,
          sourceName: track.fileName,
        );
        await _player.setAudioSource(source);
      } else {
        await _player.setFilePath(track.path);
      }
      await _player.play();
    } catch (e) {
      debugPrint('Error playing track: $e');
      await skipNext();
    }
    _isPlaying = true;
    notifyListeners();
  }

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp3':
        return 'audio/mpeg';
      case 'flac':
        return 'audio/flac';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      case 'ogg':
        return 'audio/ogg';
      case 'wav':
        return 'audio/wav';
      case 'opus':
        return 'audio/opus';
      default:
        return 'audio/mpeg';
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_player.duration != null) {
        await _player.play();
      } else if (currentTrack != null) {
        if (kIsWeb && currentTrack!.audioBytes != null) {
          final mimeType = _getMimeType(currentTrack!.fileName);
          final source = BytesAudioSource(
            bytes: currentTrack!.audioBytes!,
            mimeType: mimeType,
            sourceName: currentTrack!.fileName,
          );
          await _player.setAudioSource(source);
        } else {
          await _player.setFilePath(currentTrack!.path);
        }
        await _player.play();
      }
    }
    _isPlaying = _player.playing;
    notifyListeners();
  }

  Future<void> skipNext() async {
    if (_queue.isEmpty) return;

    _isScrubbing = false;

    if (_loopMode == LoopMode.one) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }

    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else if (_loopMode == LoopMode.all) {
      _currentIndex = 0;
    } else {
      return;
    }

    try {
      if (kIsWeb && _queue[_currentIndex].audioBytes != null) {
        final mimeType = _getMimeType(_queue[_currentIndex].fileName);
        final source = BytesAudioSource(
          bytes: _queue[_currentIndex].audioBytes!,
          mimeType: mimeType,
          sourceName: _queue[_currentIndex].fileName,
        );
        await _player.setAudioSource(source);
      } else {
        await _player.setFilePath(_queue[_currentIndex].path);
      }
      await _player.play();
      _isPlaying = true;
    } catch (e) {
      debugPrint('Error skipping to next: $e');
      await skipNext();
    }
    notifyListeners();
  }

  Future<void> skipPrevious() async {
    if (_queue.isEmpty) return;

    if (_player.position > Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      notifyListeners();
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
      try {
        if (kIsWeb && _queue[_currentIndex].audioBytes != null) {
          final mimeType = _getMimeType(_queue[_currentIndex].fileName);
          final source = BytesAudioSource(
            bytes: _queue[_currentIndex].audioBytes!,
            mimeType: mimeType,
            sourceName: _queue[_currentIndex].fileName,
          );
          await _player.setAudioSource(source);
        } else {
          await _player.setFilePath(_queue[_currentIndex].path);
        }
        await _player.play();
        _isPlaying = true;
      } catch (e) {
        debugPrint('Error skipping to previous: $e');
      }
      notifyListeners();
    }
  }

  Future<void> seekTo(Duration position) async {
    _isScrubbing = true;
    _lastScrubTime = DateTime.now();
    await _player.seek(position);
    Future.delayed(const Duration(milliseconds: 1000), () {
      _isScrubbing = false;
    });
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    if (_shuffle) {
      final current = _queue[_currentIndex];
      final remaining = _queue.where((t) => t != current).toList()..shuffle();
      _queue = [current, ...remaining];
      _currentIndex = 0;
    } else {
      final current = _queue[_currentIndex];
      final originalIndex = _originalQueue.indexOf(current);
      _queue = List.from(_originalQueue);
      _currentIndex = originalIndex >= 0 ? originalIndex : 0;
    }
    notifyListeners();
  }

  void cycleLoopMode() {
    switch (_loopMode) {
      case LoopMode.off:
        _loopMode = LoopMode.one;
        break;
      case LoopMode.one:
        _loopMode = LoopMode.all;
        break;
      case LoopMode.all:
        _loopMode = LoopMode.off;
        break;
    }
    notifyListeners();
  }

  void _onTrackComplete() {
    final now = DateTime.now();
    if (_isScrubbing) return;
    if (_lastCompleteEvent != null && now.difference(_lastCompleteEvent!) < const Duration(seconds: 2)) {
      return;
    }
    _lastCompleteEvent = now;

    if (_loopMode == LoopMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else if (_loopMode == LoopMode.all || _currentIndex < _queue.length - 1) {
      skipNext();
    } else {
      _isPlaying = false;
      _fftData = List.filled(64, 0);
      _player.pause();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
