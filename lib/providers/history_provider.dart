import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plinth/models/audio_file.dart';

/// Tracks song completions.
///
/// A track is only counted as "played" if it was listened to from the
/// beginning through to completion (i.e. the player naturally reached the
/// end — not skipped midway). Quick Picks = the top 10 most-completed tracks.
class HistoryProvider extends ChangeNotifier {
  static const _completionsKey = 'play_completions_v2';
  static const _topN = 10;

  /// Completion-count per path.
  final Map<String, int> _completions = {};

  /// Full AudioFile objects populated by [hydrate].
  final Map<String, AudioFile> _trackCache = {};

  /// The top-10 most-completed tracks (used as Quick Picks).
  List<AudioFile> get quickPicks {
    final ranked = _completions.entries
        .where((e) => _trackCache.containsKey(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ranked.take(_topN).map((e) => _trackCache[e.key]!).toList();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_completionsKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in map.entries) {
          _completions[e.key] = (e.value as num).toInt();
        }
      } catch (e) {
        debugPrint('HistoryProvider: Failed to load completions: $e');
      }
    }
    notifyListeners();
  }

  /// Call this only when a track has been played to natural completion
  /// (i.e. the audio player reached ProcessingState.completed).
  Future<void> recordCompletion(AudioFile track) async {
    _trackCache[track.path] = track;
    _completions[track.path] = (_completions[track.path] ?? 0) + 1;
    notifyListeners();
    await _persist();
  }

  /// Provide AudioFile objects for paths already in the completion map so
  /// that artwork is available (cold start — artwork was not serialized).
  void hydrate(List<AudioFile> allTracks) {
    for (final t in allTracks) {
      _trackCache[t.path] = t;
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _completionsKey,
      jsonEncode(_completions.map((k, v) => MapEntry(k, v))),
    );
  }
}
