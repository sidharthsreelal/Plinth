import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
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
    int? trackNumber;

    try {
      final metadata = readMetadata(file, getImage: true);

      title = metadata.title ?? title;
      artist = metadata.artist ?? artist;
      album = metadata.album ?? album;

      if (metadata.pictures != null && metadata.pictures!.isNotEmpty) {
        albumArt = metadata.pictures!.first.bytes;
      }

      if (metadata.duration != null) {
        duration = metadata.duration!;
      }

      // Extract track number — audio_metadata_reader exposes it as trackNumber
      trackNumber = metadata.trackNumber;
    } catch (e) {
      debugPrint('MetadataService: metadata extraction failed for ${path.basename(file.path)}: $e');
    }

    // NOTE: We intentionally do NOT spin up a new AudioPlayer here for a
    // duration fallback. That was causing startup/re-scan hangs because
    // creating hundreds of AudioPlayer instances in sequence is very slow
    // and leaks Android audio session handles. If duration is zero after
    // metadata extraction it will show as "--:--" in the UI, which is
    // acceptable for edge-case files.

    return AudioFile(
      path: file.path,
      fileName: path.basename(file.path),
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      albumArt: albumArt,
      audioBytes: audioBytes,
      trackNumber: trackNumber,
    );
  }

  static String _cleanFileName(String name) {
    return name.replaceAll(RegExp(r'^\d+[\s.\-]+'), '').trim();
  }
}
