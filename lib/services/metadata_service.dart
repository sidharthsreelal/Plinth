import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:just_audio/just_audio.dart';
import 'package:plinth/models/audio_file.dart';

class MetadataService {
  static Future<AudioFile> extract(File file, {Uint8List? audioBytes}) async {
    if (kIsWeb) {
      return AudioFile(
        path: file.path,
        fileName: path.basename(file.path),
        title: _cleanFileName(path.basenameWithoutExtension(file.path)),
        artist: 'Unknown Artist',
        album: 'Unknown Album',
        duration: Duration.zero,
        albumArt: null,
        audioBytes: audioBytes,
      );
    }

    String title = _cleanFileName(path.basenameWithoutExtension(file.path));
    String artist = 'Unknown Artist';
    String album = 'Unknown Album';
    Duration duration = Duration.zero;
    Uint8List? albumArt;

    try {
      final metadata = readMetadata(file, getImage: true);

      title = metadata.title ?? title;
      artist = metadata.artist ?? artist;
      album = metadata.album ?? album;

      if (metadata.pictures != null && metadata.pictures!.isNotEmpty) {
        albumArt = metadata.pictures!.first.bytes;
        debugPrint('MetadataService: Album art for ${path.basename(file.path)}: ${albumArt!.length} bytes, mime: ${metadata.pictures!.first.mimetype}');
      } else {
        debugPrint('MetadataService: No album art found for ${path.basename(file.path)}');
      }

      if (metadata.duration != null) {
        duration = metadata.duration!;
      }

      debugPrint('MetadataService: OK - ${path.basename(file.path)} | $title | $artist | ${duration.inSeconds}s');
    } catch (e) {
      debugPrint('MetadataService: metadata extraction failed for ${path.basename(file.path)}: $e');
    }

    if (duration == Duration.zero && !kIsWeb) {
      try {
        final player = AudioPlayer();
        await player.setFilePath(file.path);
        final dur = player.duration;
        if (dur != null) {
          duration = dur;
          debugPrint('MetadataService: Duration from just_audio: ${duration.inSeconds}s');
        }
        await player.dispose();
      } catch (e) {
        debugPrint('MetadataService: just_audio duration failed: $e');
      }
    }

    return AudioFile(
      path: file.path,
      fileName: path.basename(file.path),
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      albumArt: albumArt,
      audioBytes: audioBytes,
    );
  }

  static String _cleanFileName(String name) {
    return name.replaceAll(RegExp(r'^\d+[\s.\-]+'), '').trim();
  }
}
