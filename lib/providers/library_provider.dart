import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plinth/models/folder_node.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/services/file_scanner.dart';

/// Runs inside an isolate: scans the filesystem and returns the JSON-serialised
/// folder tree. We cannot pass FolderNode objects across isolates (they contain
/// Uint8List album art which is fine, but ChangeNotifier is not), so we
/// serialise to plain Maps and deserialise back on the main isolate.
Future<Map<String, dynamic>> _scanInIsolate(String rootPath) async {
  final scanner = FileScanner();
  final node = await scanner.scanFolder(rootPath);
  return _folderNodeToJson(node);
}

Map<String, dynamic> _folderNodeToJson(FolderNode node) {
  return {
    'name': node.name,
    'path': node.path,
    'subFolders': node.subFolders.map(_folderNodeToJson).toList(),
    // toJson() includes albumArtB64 so art bytes cross the isolate boundary.
    'audioFiles': node.audioFiles.map((audio) => audio.toJson()).toList(),
  };
}

/// Lean version (no art bytes) for storing to SharedPreferences.
Map<String, dynamic> _folderNodeToJsonLean(FolderNode node) {
  return {
    'name': node.name,
    'path': node.path,
    'subFolders': node.subFolders.map(_folderNodeToJsonLean).toList(),
    'audioFiles': node.audioFiles.map((audio) => audio.toJsonWithoutArt()).toList(),
  };
}

class LibraryProvider extends ChangeNotifier {
  FolderNode? _rootFolder;
  String? _rootPath;
  bool _isScanning = false;
  bool _hasFolder = false;
  bool _isInitialized = false;
  List<AudioFile> _webAudioFiles = [];

  FolderNode? get rootFolder => _rootFolder;
  String? get rootPath => _rootPath;
  bool get isScanning => _isScanning;
  bool get hasFolder => _hasFolder;
  bool get isInitialized => _isInitialized;
  List<AudioFile> get webAudioFiles => _webAudioFiles;

  Future<void> init() async {
    if (kIsWeb) {
      _isInitialized = true;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _rootPath = prefs.getString('root_folder_path');
    _hasFolder = _rootPath != null && _rootPath!.isNotEmpty;

    if (_hasFolder) {
      final savedJson = prefs.getString('saved_library');
      if (savedJson != null) {
        try {
          _rootFolder = await _loadCachedFolderNode(
              jsonDecode(savedJson) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('LibraryProvider: Failed to load saved library: $e');
          _rootFolder = null;
        }
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<FolderNode> _loadCachedFolderNode(Map<String, dynamic> json) async {
    // Deserialize audio files — art bytes come via albumArtB64 (if present).
    final rawAudioList = json['audioFiles'] as List;
    final audioFiles = await Future.wait(
      rawAudioList.map((e) async {
        final audio = AudioFile.fromJson(e as Map<String, dynamic>);
        // If no art came via the JSON (startup-from-cache path), fall back to
        // the on-disk cache written during a previous scan.
        if (audio.albumArt == null) {
          final cachedArt = await AudioFile.loadCachedAlbumArt(audio.path);
          return audio.copyWith(albumArt: cachedArt);
        }
        return audio;
      }),
    );

    // Recurse into subfolders in parallel.
    final rawSubList = json['subFolders'] as List;
    final subFolders = await Future.wait(
      rawSubList.map((e) => _loadCachedFolderNode(e as Map<String, dynamic>)),
    );

    return FolderNode(
      name: json['name'] as String,
      path: json['path'] as String,
      subFolders: subFolders,
      audioFiles: audioFiles,
    );
  }

  Future<void> setRootFolder(String path) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('root_folder_path', path);
    _rootPath = path;
    _hasFolder = true;
    await scanFolder(path);
  }

  /// Scans the filesystem in a background isolate so the UI stays responsive.
  /// The scanning indicator will be visible while this runs.
  Future<void> scanFolder(String path) async {
    if (kIsWeb) return;

    _isScanning = true;
    notifyListeners();

    try {
      // Run the file scan in a separate isolate so it doesn't block the UI thread.
      // The JSON returned includes albumArtB64 bytes so art crosses the boundary.
      final jsonMap = await compute(_scanInIsolate, path);

      // Deserialise + hydrate art bytes back on the main isolate.
      _rootFolder = await _loadCachedFolderNode(jsonMap);

      // Persist art to the on-disk cache (main thread — platform channels work here).
      _cacheArtworkInBackground(_rootFolder!);

      // Save lean JSON (no art bytes) to SharedPreferences for next startup.
      final leanJson = _folderNodeToJsonLean(_rootFolder!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_library', jsonEncode(leanJson));
    } catch (e) {
      debugPrint('LibraryProvider: Scan error: $e');
      _rootFolder = null;
    }

    _isScanning = false;
    notifyListeners();
  }

  /// Fire-and-forget artwork caching — does not block the UI or the scan result.
  void _cacheArtworkInBackground(FolderNode node) {
    for (final audio in node.audioFiles) {
      audio.cacheAlbumArt();
    }
    for (final sub in node.subFolders) {
      _cacheArtworkInBackground(sub);
    }
  }

  Future<void> setWebAudioFiles(List<AudioFile> files) async {
    _webAudioFiles = files;
    _hasFolder = files.isNotEmpty;
    _rootFolder = FolderNode(
      name: 'My Music',
      path: 'web://memory',
      subFolders: [],
      audioFiles: files,
    );
    notifyListeners();
  }

  Future<void> changeFolder(String newPath) async {
    await setRootFolder(newPath);
  }

  Future<void> clearFolder() async {
    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('root_folder_path');
      await prefs.remove('saved_library');
    }
    _rootPath = null;
    _rootFolder = null;
    _webAudioFiles = [];
    _hasFolder = false;
    notifyListeners();
  }

  /// Returns every AudioFile in the library, recursively collected across
  /// all folders. Used by the Shuffle All / dice feature.
  List<AudioFile> getAllTracks() {
    if (_rootFolder == null) return [];
    final result = <AudioFile>[];
    _collectTracks(_rootFolder!, result);
    return result;
  }

  void _collectTracks(FolderNode node, List<AudioFile> out) {
    out.addAll(node.audioFiles);
    for (final sub in node.subFolders) {
      _collectTracks(sub, out);
    }
  }

  /// Returns the [FolderNode] that directly contains the audio file at [audioPath].
  /// Returns null if not found.
  FolderNode? findFolderContaining(String audioPath) {
    if (_rootFolder == null) return null;
    return _findFolderContaining(_rootFolder!, audioPath);
  }

  FolderNode? _findFolderContaining(FolderNode node, String audioPath) {
    if (node.audioFiles.any((a) => a.path == audioPath)) return node;
    for (final sub in node.subFolders) {
      final found = _findFolderContaining(sub, audioPath);
      if (found != null) return found;
    }
    return null;
  }
}
