import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/models/folder_node.dart';

enum PinnedItemType { audioFile, folder }

class PinnedItem {
  final String path;
  final String name;
  final PinnedItemType type;

  // Hydrated references — populated after library loads
  AudioFile? audioFile;
  FolderNode? folder;

  PinnedItem({
    required this.path,
    required this.name,
    required this.type,
    this.audioFile,
    this.folder,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'type': type.name,
      };

  static PinnedItem fromJson(Map<String, dynamic> json) => PinnedItem(
        path: json['path'] as String,
        name: json['name'] as String,
        type: PinnedItemType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => PinnedItemType.audioFile,
        ),
      );
}

class PinsProvider extends ChangeNotifier {
  static const _key = 'pinned_items';

  final List<PinnedItem> _pins = [];

  List<PinnedItem> get pins => List.unmodifiable(_pins);

  bool isPinned(String path) => _pins.any((p) => p.path == path);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _pins.addAll(list.map((e) => PinnedItem.fromJson(e as Map<String, dynamic>)));
      } catch (e) {
        debugPrint('PinsProvider: Failed to load pins: $e');
      }
    }
    notifyListeners();
  }

  /// Hydrate pinned audio files from the loaded library.
  void hydrateAudio(List<AudioFile> allTracks) {
    for (final track in allTracks) {
      final pin = _pins.where((p) => p.path == track.path).firstOrNull;
      if (pin != null) pin.audioFile = track;
    }
    notifyListeners();
  }

  /// Hydrate pinned folders from the loaded library (recursive).
  void hydrateFolder(FolderNode root) {
    _hydrateFolderRecursive(root);
    notifyListeners();
  }

  void _hydrateFolderRecursive(FolderNode node) {
    final pin = _pins.where((p) => p.path == node.path).firstOrNull;
    if (pin != null) pin.folder = node;
    for (final sub in node.subFolders) {
      _hydrateFolderRecursive(sub);
    }
  }

  Future<void> pinAudioFile(AudioFile track) async {
    if (isPinned(track.path)) return;
    final item = PinnedItem(
      path: track.path,
      name: track.title.isNotEmpty ? track.title : track.fileName,
      type: PinnedItemType.audioFile,
      audioFile: track,
    );
    _pins.add(item);
    notifyListeners();
    await _persist();
  }

  Future<void> pinFolder(FolderNode folder) async {
    if (isPinned(folder.path)) return;
    final item = PinnedItem(
      path: folder.path,
      name: folder.name,
      type: PinnedItemType.folder,
      folder: folder,
    );
    _pins.add(item);
    notifyListeners();
    await _persist();
  }

  Future<void> unpin(String path) async {
    _pins.removeWhere((p) => p.path == path);
    notifyListeners();
    await _persist();
  }

  Future<void> toggleAudioFile(AudioFile track) async {
    if (isPinned(track.path)) {
      await unpin(track.path);
    } else {
      await pinAudioFile(track);
    }
  }

  Future<void> toggleFolder(FolderNode folder) async {
    if (isPinned(folder.path)) {
      await unpin(folder.path);
    } else {
      await pinFolder(folder);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_pins.map((p) => p.toJson()).toList()));
  }
}
