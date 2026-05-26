import 'dart:io';
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
    String? lyrics;

    try {
      // Use readAllMetadata() instead of readMetadata() so we get the concrete
      // format-specific ParserTag type. This is critical for lyrics:
      // readMetadata() checks ApeParser first — MP3 files with an APEv2 header
      // get parsed as APE and their ID3v2 USLT lyrics frame is never read.
      // readAllMetadata() lets us extract lyrics from the correct tag type.
      final rawTag = readAllMetadata(file, getImage: true);

      switch (rawTag) {
        case Mp3Metadata m:
          title = m.songName ?? title;
          artist = m.bandOrOrchestra ?? m.leadPerformer ?? m.originalArtist ?? artist;
          album = m.album ?? album;
          duration = m.duration ?? duration;
          trackNumber = m.trackNumber;
          if (m.pictures.isNotEmpty) albumArt = m.pictures.first.bytes;
          final mp3Lyrics = m.lyric;
          if (mp3Lyrics != null && mp3Lyrics.trim().isNotEmpty) {
            lyrics = mp3Lyrics.trim();
          }

        case VorbisMetadata m:
          title = m.title.firstOrNull ?? title;
          artist = m.artist.firstOrNull ?? artist;
          album = m.album.firstOrNull ?? album;
          duration = m.duration ?? duration;
          trackNumber = m.trackNumber.firstOrNull;
          if (m.pictures.isNotEmpty) albumArt = m.pictures.first.bytes;
          final vorbisLyrics = m.lyric;
          if (vorbisLyrics != null && vorbisLyrics.trim().isNotEmpty) {
            lyrics = vorbisLyrics.trim();
          }

        case Mp4Metadata m:
          title = m.title ?? title;
          artist = m.artist ?? artist;
          album = m.album ?? album;
          duration = m.duration ?? duration;
          trackNumber = m.trackNumber;
          if (m.picture != null) albumArt = m.picture!.bytes;
          final mp4Lyrics = m.lyrics;
          if (mp4Lyrics != null && mp4Lyrics.trim().isNotEmpty) {
            lyrics = mp4Lyrics.trim();
          }

        case ApeMetadata m:
          title = m.title ?? title;
          artist = m.artist ?? artist;
          album = m.album ?? album;
          duration = m.duration ?? duration;
          trackNumber = m.trackNumber;
          if (m.pictures.isNotEmpty) albumArt = m.pictures.first.bytes;
          final apeLyrics = m.lyric;
          if (apeLyrics != null && apeLyrics.trim().isNotEmpty) {
            lyrics = apeLyrics.trim();
          }

        case RiffMetadata m:
          title = m.title ?? title;
          artist = m.artist ?? artist;
          album = m.album ?? album;
          duration = m.duration ?? duration;
          trackNumber = m.trackNumber;
          if (m.pictures.isNotEmpty) albumArt = m.pictures.first.bytes;
          // RIFF (.wav) does not support embedded lyrics
      }
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
      lyrics: lyrics,
    );
  }

  static String _cleanFileName(String name) {
    return name.replaceAll(RegExp(r'^\d+[\s.\-]+'), '').trim();
  }
}
