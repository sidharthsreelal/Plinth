import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/services/bytes_audio_source.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);

  List<AudioFile> _queue = [];
  List<AudioFile> _originalQueue = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;
  List<double> _fftData = List.filled(64, 0);

  /// Number of tracks that have been inserted as "play next" and are still
  /// waiting ahead of the current index. This is purely a counter so the
  /// queue badge dot can still appear. The actual tracks live in _queue.
  int _playNextCount = 0;

  // ── Sleep timer ──────────────────────────────────────────────────────
  Timer? _sleepTimer;
  Duration? _sleepRemaining;

  Duration? get sleepRemaining => _sleepRemaining;
  bool get sleepTimerActive => _sleepTimer != null;

  // ── Listen-time heartbeat ────────────────────────────────────────────
  /// Fires every [_heartbeatInterval] while actively playing so that the
  /// HistoryProvider can accumulate listen time even if the app is killed
  /// without a clean pause event.
  static const _heartbeatInterval = Duration(seconds: 5);
  Timer? _heartbeatTimer;

  /// Callback invoked whenever a new track starts (index changed in native player).
  void Function(AudioFile)? onTrackStarted;

  /// Callback invoked whenever a track starts — richer variant used by
  /// HistoryProvider to record a play start + begin accumulating listen time.
  void Function(AudioFile)? onTrackStartedWithFile;

  /// Callback invoked whenever a track completes naturally (reached the end).
  void Function(AudioFile)? onTrackCompleted;

  /// Callback invoked when playback pauses (user-initiated or sleep timer).
  /// HistoryProvider flushes the accumulated listen window on this event.
  VoidCallback? onPlaybackPaused;

  /// Callback invoked when playback resumes after a pause.
  VoidCallback? onPlaybackResumed;

  // ── Getters ───────────────────────────────────────────────────────────
  AudioPlayer get player => _player;
  List<AudioFile> get queue => _queue;
  /// True when there are play-next tracks ahead of the current position.
  bool get hasPlayNext => _playNextCount > 0;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get shuffle => _shuffle;
  LoopMode get loopMode => _loopMode;
  List<double> get fftData => _fftData;

  AudioFile? get currentTrack =>
      _queue.isNotEmpty && _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  // ── Constructor ───────────────────────────────────────────────────────
  PlayerProvider() {
    _init();
  }

  Future<void> _init() async {
    // Track index changes to keep our state in sync with the native player.
    // We use a flag to suppress the spurious index-0 event that fires when
    // setAudioSource is called before seekToIndex.
    _player.currentIndexStream.listen((index) {
      if (index != null && index != _currentIndex && index < _queue.length) {
        _currentIndex = index;
        _fireTrackStarted(_queue[_currentIndex]);
        notifyListeners();
      }
    });

    bool _wasPlaying = false;

    _player.playerStateStream.listen((state) {
      final nowPlaying = state.playing;

      if (!_wasPlaying && nowPlaying) {
        // Transition: paused → playing (resume)
        onPlaybackResumed?.call();
        _startHeartbeat();
      } else if (_wasPlaying && !nowPlaying) {
        // Transition: playing → paused
        onPlaybackPaused?.call();
        _stopHeartbeat();
      }
      _wasPlaying = nowPlaying;

      _isPlaying = nowPlaying;
      if (!nowPlaying) {
        _fftData = List.filled(64, 0);
      }

      // Detect natural completion: processing state switches to completed
      // while the player was in the playing/buffering state.
      if (state.processingState == ProcessingState.completed) {
        _handleTrackCompleted();
      }

      notifyListeners();
    });

    _player.positionStream.listen((pos) {
      if (_isPlaying) {
        _updateSimulatedFFT(pos);
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      // onHeartbeat is wired in main.dart → historyProvider.heartbeat()
      onHeartbeat?.call();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Fires every [_heartbeatInterval] while playing. Wire to
  /// HistoryProvider.heartbeat() in main.dart.
  VoidCallback? onHeartbeat;

  void _handleTrackCompleted() {
    final track = currentTrack;
    if (track != null) {
      onTrackCompleted?.call(track);
    }
  }

  // Override the track-started firing to also call the richer callback.
  void _fireTrackStarted(AudioFile track) {
    onTrackStarted?.call(track);
    onTrackStartedWithFile?.call(track);
    _startHeartbeat();
  }

  // ── Artwork Caching ───────────────────────────────────────────────────

  /// Saves artwork to a temp file and returns a file:// URI.
  /// This prevents TransactionTooLargeException in Android's media session IPC.
  Future<Uri?> _getArtUri(AudioFile track) async {
    if (track.albumArt == null) return null;
    try {
      final tempDir = await getTemporaryDirectory();
      final filename = 'art_${track.path.hashCode}.jpg';
      final file = File(p.join(tempDir.path, filename));
      if (!await file.exists()) {
        await file.writeAsBytes(track.albumArt!);
      }
      return Uri.file(file.path);
    } catch (e) {
      debugPrint('Error caching artwork: $e');
      return null;
    }
  }

  // ── MediaItem helper ──────────────────────────────────────────────────

  Future<MediaItem> _mediaItemFor(AudioFile track) async {
    final artUri = await _getArtUri(track);
    return MediaItem(
      id: track.path,
      title: track.title.isNotEmpty ? track.title : track.fileName,
      artist: track.artist.isNotEmpty ? track.artist : 'Unknown artist',
      album: track.album.isNotEmpty ? track.album : 'Unknown album',
      artUri: artUri,
    );
  }

  Future<AudioSource> _sourceFor(AudioFile track) async {
    final tag = await _mediaItemFor(track);
    if (kIsWeb && track.audioBytes != null) {
      return BytesAudioSource(
        bytes: track.audioBytes!,
        mimeType: _getMimeType(track.fileName),
        sourceName: track.fileName,
      );
    }
    return AudioSource.uri(
      Uri.file(track.path),
      tag: tag,
    );
  }

  // ── Play-next queue API ───────────────────────────────────────────────

  bool addToPlayNext(AudioFile track) {
    // Insert immediately after the current track.
    // Each swipe pushes the new track to position currentIndex+1, bumping
    // previous play-next entries further along. Result:
    //   swipe A → queue: [cur, A, ...rest]
    //   swipe B → queue: [cur, B, A, ...rest]
    // which matches "play next" semantics correctly.
    final insertIdx = _currentIndex + 1;
    if (insertIdx <= _queue.length) {
      _queue.insert(insertIdx, track);
      _sourceFor(track).then((src) => _playlist.insert(insertIdx, src));
    } else {
      _queue.add(track);
      _sourceFor(track).then((src) => _playlist.add(src));
    }
    _playNextCount++;
    notifyListeners();
    return true;
  }

  void removeFromPlayNext(int index) {
    // index here is relative to _currentIndex+1 in the main queue
    final absIdx = _currentIndex + 1 + index;
    if (absIdx < _queue.length) {
      _queue.removeAt(absIdx);
      _playlist.removeAt(absIdx);
      if (_playNextCount > 0) _playNextCount--;
      notifyListeners();
    }
  }

  void clearPlayNext() {
    // Remove all upcoming entries that were queued as play-next.
    final removeCount = _playNextCount;
    for (int i = removeCount - 1; i >= 0; i--) {
      final absIdx = _currentIndex + 1 + i;
      if (absIdx < _queue.length) {
        _queue.removeAt(absIdx);
        _playlist.removeAt(absIdx);
      }
    }
    _playNextCount = 0;
    notifyListeners();
  }

  void reorderPlayNext(int oldIndex, int newIndex) {
    // Reorder within upcoming entries (same as reorderUpcoming)
    reorderUpcoming(oldIndex, newIndex);
  }

  // ── Unified upcoming-queue API ────────────────────────────────────────

  void reorderUpcoming(int oldIndex, int newIndex) {
    final base = _currentIndex + 1;
    if (base >= _queue.length) return;

    final absOld = base + oldIndex;
    final absNew = base + newIndex;

    if (absOld < _queue.length && absNew <= _queue.length) {
      final item = _queue.removeAt(absOld);
      _queue.insert(absNew > absOld ? absNew - 1 : absNew, item);
      _playlist.move(absOld, absNew > absOld ? absNew - 1 : absNew);
    }
    notifyListeners();
  }

  void removeFromUpcoming(int index) {
    final absIdx = _currentIndex + 1 + index;
    if (absIdx < _queue.length) {
      _queue.removeAt(absIdx);
      _playlist.removeAt(absIdx);
      notifyListeners();
    }
  }

  void insertIntoPlayNext(int index, AudioFile track) {
    final insertIdx = (_currentIndex + 1 + index).clamp(
        _currentIndex + 1, _queue.length);
    _queue.insert(insertIdx, track);
    _sourceFor(track).then((src) => _playlist.insert(insertIdx, src));
    _playNextCount++;
    notifyListeners();
  }

  void notifyListenersPublic() => notifyListeners();

  // ── Playback Logic ────────────────────────────────────────────────────

  Future<void> playTrack(AudioFile track, List<AudioFile> queue) async {
    _queue = List.from(queue);
    _originalQueue = List.from(queue);
    _playNextCount = 0;

    // Determine the correct starting index.
    int startIndex = _queue.indexOf(track);
    if (startIndex == -1) {
      startIndex = 0;
      _queue = [track];
    }

    // Optimistically set the index and notify so the UI (e.g. NowPlayingScreen)
    // shows the correct track immediately before sources are built.
    _currentIndex = startIndex;
    notifyListeners();

    try {
      final sources = await Future.wait(_queue.map((t) => _sourceFor(t)));
      await _playlist.clear();
      await _playlist.addAll(sources);

      // setAudioSource with initialIndex tells the native player to start at
      // the correct position. This is the fix for "always plays the first song".
      await _player.setAudioSource(_playlist, initialIndex: startIndex);
      await _player.play();

      // Fire both callbacks explicitly rather than relying on the
      // currentIndexStream event (which fires at 0 before seeking).
      _fireTrackStarted(track);
    } catch (e) {
      debugPrint('Error playing track: $e');
    }
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.audioSource != null) {
        await _player.play();
      }
    }
  }

  Future<void> skipNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_loopMode == LoopMode.all && _queue.isNotEmpty) {
      await _player.seek(Duration.zero, index: 0);
    }
  }

  Future<void> skipPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  Future<void> skipToTrack(AudioFile track, {bool insertAsNext = false}) async {
    final idx = _queue.indexOf(track);
    if (idx != -1) {
      await _player.seek(Duration.zero, index: idx);
      await _player.play();
    } else if (insertAsNext) {
      insertIntoPlayNext(0, track);
      await _player.seekToNext();
      await _player.play();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _player.setShuffleModeEnabled(_shuffle);
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
    _player.setLoopMode(_loopMode);
    notifyListeners();
  }

  // ── Sleep Timer ───────────────────────────────────────────────────────

  void startSleepTimer(Duration duration) {
    _cancelSleepTimer();
    _sleepRemaining = duration;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_sleepRemaining == null || _sleepRemaining! <= Duration.zero) {
        _triggerSleep();
        return;
      }
      _sleepRemaining = _sleepRemaining! - const Duration(seconds: 1);
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _cancelSleepTimer();
    notifyListeners();
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepRemaining = null;
  }

  void _triggerSleep() {
    _cancelSleepTimer();
    _player.pause();
    notifyListeners();
  }

  // ── Simulated FFT ─────────────────────────────────────────────────────

  void _updateSimulatedFFT(Duration? position) {
    if (position == null) return;
    final posMs = position.inMilliseconds;
    final timeSlot = DateTime.now().millisecondsSinceEpoch ~/ 60;
    final posRng = math.Random(posMs ~/ 500);
    final timeRng = math.Random(timeSlot ^ posMs.hashCode);

    _fftData = List.generate(64, (i) {
      final t = i / 64.0;
      double envelope;
      if (t < 0.05) {
        envelope = 0.7 + posRng.nextDouble() * 0.3;
      } else if (t < 0.15) {
        envelope = 0.6 + posRng.nextDouble() * 0.4;
      } else if (t < 0.40) {
        envelope = 0.45 + posRng.nextDouble() * 0.45;
      } else if (t < 0.70) {
        envelope = 0.25 + posRng.nextDouble() * 0.40;
      } else {
        envelope = 0.10 + posRng.nextDouble() * 0.25;
      }
      final wobble = (timeRng.nextDouble() - 0.5) * 0.4;
      final amplitude = (envelope + wobble * envelope).clamp(0.0, 1.0);
      return (amplitude * 255 - 128).clamp(-128, 127).toDouble();
    });
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

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _heartbeatTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}
