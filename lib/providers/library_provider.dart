import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plinth/models/folder_node.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/services/file_scanner.dart';

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
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _rootPath = prefs.getString('root_folder_path');
    _hasFolder = _rootPath != null && _rootPath!.isNotEmpty;

    if (_hasFolder) {
      final savedJson = prefs.getString('saved_library');
      if (savedJson != null) {
        try {
          _rootFolder = await _loadCachedFolderNode(jsonDecode(savedJson));
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
    final audioFiles = <AudioFile>[];
    for (final e in json['audioFiles'] as List) {
      final audio = AudioFile.fromJson(e as Map<String, dynamic>);
      final cachedArt = await AudioFile.loadCachedAlbumArt(audio.path);
      audioFiles.add(audio.copyWith(albumArt: cachedArt));
    }
    final subFolders = <FolderNode>[];
    for (final e in json['subFolders'] as List) {
      subFolders.add(await _loadCachedFolderNode(e as Map<String, dynamic>));
    }
    return FolderNode(
      name: json['name'] as String,
      path: json['path'] as String,
      subFolders: subFolders,
      audioFiles: audioFiles,
    );
  }

  Future<void> setRootFolder(String path) async {
    if (kIsWeb) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('root_folder_path', path);
    _rootPath = path;
    _hasFolder = true;
    await scanFolder(path);
  }

  Future<void> scanFolder(String path) async {
    if (kIsWeb) {
      return;
    }

    _isScanning = true;
    notifyListeners();

    try {
      final scanner = FileScanner();
      _rootFolder = await scanner.scanFolder(path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_library', jsonEncode(_folderNodeToJson(_rootFolder!)));
    } catch (e) {
      debugPrint('LibraryProvider: Scan error: $e');
      _rootFolder = null;
    }

    _isScanning = false;
    notifyListeners();
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

  Map<String, dynamic> _folderNodeToJson(FolderNode node) {
    return {
      'name': node.name,
      'path': node.path,
      'subFolders': node.subFolders.map(_folderNodeToJson).toList(),
      'audioFiles': node.audioFiles.map((audio) => audio.toJson()).toList(),
    };
  }
}
