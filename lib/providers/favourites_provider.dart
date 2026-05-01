import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/models/folder_node.dart';

class FavouritesProvider extends ChangeNotifier {
  static const _key = 'favourite_paths';

  final Set<String> _paths = {};

  /// Full AudioFile objects for every favourited path that is available in
  /// the current library. Populated/updated via [hydrate].
  final Map<String, AudioFile> _trackCache = {};

  Set<String> get paths => Set.unmodifiable(_paths);

  bool isFavourite(AudioFile track) => _paths.contains(track.path);

  /// A virtual FolderNode containing all favourited tracks that are currently
  /// available in the library. Returns null when empty.
  FolderNode? get favouritesFolder {
    final tracks = _paths
        .where((p) => _trackCache.containsKey(p))
        .map((p) => _trackCache[p]!)
        .toList();
    if (tracks.isEmpty) return null;
    return FolderNode(
      name: 'Favourites',
      path: '__favourites__',
      audioFiles: tracks,
    );
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key) ?? [];
    _paths.addAll(saved);
    notifyListeners();
  }

  /// Feed all tracks from the library so artwork is available.
  void hydrate(List<AudioFile> allTracks) {
    for (final t in allTracks) {
      _trackCache[t.path] = t;
    }
    notifyListeners();
  }

  Future<void> toggle(AudioFile track) async {
    if (_paths.contains(track.path)) {
      _paths.remove(track.path);
    } else {
      _paths.add(track.path);
      _trackCache[track.path] = track;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _paths.toList());
  }
}
