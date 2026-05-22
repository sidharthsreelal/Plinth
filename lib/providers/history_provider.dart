import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plinth/models/audio_file.dart';

/// Tracks listening behaviour and surfaces Quick Picks.
///
/// Three independent signals are recorded per track:
///
///  1. **playCount**   — how many times the track was started (any tap/play).
///  2. **listenMs**    — total milliseconds actually listened (accumulated while
///                       audio is playing, sampled every [_sampleInterval]).
///  3. **completions** — how many times the track was played to its natural end.
///
/// Quick Picks are the top [_topN] tracks ranked by a composite score:
///
///   score = listenMs × 0.50
///         + playCount  × 90_000 × 0.30   (≈ weight of 1.5 min per start)
///         + completions × 150_000 × 0.20 (≈ weight of 2.5 min per finish)
///
/// Using multiple signals means the recommendations actually reflect what the
/// user chooses to listen to — not just what they happen to sit through.
class HistoryProvider extends ChangeNotifier {
  static const _prefsKey = 'listening_stats_v3';
  static const _topN = 8;

  // ── Per-track stats ───────────────────────────────────────────────────────

  /// Number of times a track has been started.
  final Map<String, int> _playCount = {};

  /// Total milliseconds listened per track (accumulated).
  final Map<String, int> _listenMs = {};

  /// Number of full-completion plays per track.
  final Map<String, int> _completions = {};

  // ── Live listen-time accumulation ─────────────────────────────────────────

  /// Track currently being listened to.
  String? _activePath;

  /// Wall-clock time the current active-listen session started.
  DateTime? _listenStart;

  // ── AudioFile cache (hydrated from library) ───────────────────────────────

  final Map<String, AudioFile> _trackCache = {};

  // ─────────────────────────────────────────────────────────────────────────
  //  Public API — Quick Picks
  // ─────────────────────────────────────────────────────────────────────────

  /// Top-[_topN] tracks ranked by composite listening score.
  List<AudioFile> get quickPicks {
    final allPaths = {
      ..._playCount.keys,
      ..._listenMs.keys,
      ..._completions.keys,
    };

    final scored = allPaths
        .where((p) => _trackCache.containsKey(p))
        .map((p) => MapEntry(p, _score(p)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return scored.take(_topN).map((e) => _trackCache[e.key]!).toList();
  }

  double _score(String path) {
    final ms = (_listenMs[path] ?? 0).toDouble();
    final plays = (_playCount[path] ?? 0).toDouble();
    final done = (_completions[path] ?? 0).toDouble();

    return ms * 0.50 + plays * 90000 * 0.30 + done * 150000 * 0.20;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Public API — Event hooks (called from PlayerProvider callbacks)
  // ─────────────────────────────────────────────────────────────────────────

  /// Call when a new track starts playing.
  Future<void> recordTrackStarted(AudioFile track) async {
    // Flush accumulated time for the previous track before switching.
    await _flushListenTime();

    _activePath = track.path;
    _listenStart = DateTime.now();

    _trackCache[track.path] = track;
    _playCount[track.path] = (_playCount[track.path] ?? 0) + 1;
    notifyListeners();
    await _persist();
  }

  /// Call when the active track is paused or the player stops.
  /// Accumulates listened time up to this point.
  Future<void> recordPaused() async {
    await _flushListenTime();
    notifyListeners();
  }

  /// Call when the active track resumes after a pause.
  void recordResumed() {
    if (_activePath != null) {
      _listenStart = DateTime.now();
    }
  }

  /// Call when a track completes naturally (not via skip).
  Future<void> recordCompletion(AudioFile track) async {
    await _flushListenTime();
    _trackCache[track.path] = track;
    _completions[track.path] = (_completions[track.path] ?? 0) + 1;
    notifyListeners();
    await _persist();
  }

  /// Periodic heartbeat — call every few seconds while playing to keep
  /// accumulated listen time up to date (for the case where the app is killed
  /// mid-session without a pause event).
  Future<void> heartbeat() async {
    if (_activePath == null || _listenStart == null) return;
    await _flushListenTime();
    // Immediately restart the listen window.
    _listenStart = DateTime.now();
    await _persist();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Internal helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _flushListenTime() async {
    if (_activePath == null || _listenStart == null) return;
    final elapsed = DateTime.now().difference(_listenStart!).inMilliseconds;
    if (elapsed > 0) {
      _listenMs[_activePath!] = (_listenMs[_activePath!] ?? 0) + elapsed;
    }
    _listenStart = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Initialisation & persistence
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final plays = map['plays'] as Map<String, dynamic>?;
        final times = map['listenMs'] as Map<String, dynamic>?;
        final done = map['completions'] as Map<String, dynamic>?;

        plays?.forEach((k, v) => _playCount[k] = (v as num).toInt());
        times?.forEach((k, v) => _listenMs[k] = (v as num).toInt());
        done?.forEach((k, v) => _completions[k] = (v as num).toInt());
      } catch (e) {
        debugPrint('HistoryProvider: failed to load stats: $e');
      }
    }
    notifyListeners();
  }

  /// Provide fresh AudioFile objects for paths in our stats maps so that
  /// artwork is available after a cold start (art bytes are not serialised).
  void hydrate(List<AudioFile> allTracks) {
    for (final t in allTracks) {
      _trackCache[t.path] = t;
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'plays': _playCount,
        'listenMs': _listenMs,
        'completions': _completions,
      }),
    );
  }
}
