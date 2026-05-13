import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/models/folder_node.dart';
import 'package:plinth/services/metadata_service.dart';

class FileScanner {
  static const List<String> _audioExtensions = [
    '.mp3', '.flac', '.aac', '.m4a', '.ogg', '.wav', '.opus'
  ];

  Future<FolderNode> scanFolder(String rootPath) async {
    final dir = Directory(rootPath);
    if (!dir.existsSync()) {
      return FolderNode(
        name: path.basename(rootPath),
        path: rootPath,
        subFolders: [],
        audioFiles: [],
      );
    }
    return await _buildNode(dir);
  }

  Future<FolderNode> _buildNode(Directory dir) async {
    final List<FolderNode> subFolders = [];
    final List<AudioFile> audioFiles = [];

    final List<FileSystemEntity> entities;
    try {
      entities = dir.listSync(recursive: false)
        ..sort((a, b) => a.path.compareTo(b.path));
    } catch (e) {
      debugPrint('FileScanner: Error listing ${dir.path}: $e');
      return FolderNode(
        name: path.basename(dir.path),
        path: dir.path,
        subFolders: [],
        audioFiles: [],
      );
    }

    for (final entity in entities) {
      if (entity is Directory) {
        try {
          final child = await _buildNode(entity);
          if (!child.isEmpty) subFolders.add(child);
        } catch (e) {
          debugPrint('FileScanner: Error processing subfolder ${entity.path}: $e');
        }
      } else if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase();
        if (_audioExtensions.contains(ext)) {
          try {
            final audioFile = await MetadataService.extract(entity);
            // NOTE: Do NOT call audioFile.cacheAlbumArt() here — this code
            // runs inside a compute() isolate where Flutter platform channels
            // (needed by getApplicationCacheDirectory) are not available.
            // Art caching is performed on the main thread by LibraryProvider
            // after the scan completes.
            audioFiles.add(audioFile);
          } catch (e) {
            debugPrint('FileScanner: Error extracting metadata from ${entity.path}: $e');
          }
        }
      }
    }

    return FolderNode(
      name: path.basename(dir.path),
      path: dir.path,
      subFolders: subFolders,
      audioFiles: audioFiles,
    );
  }
}
