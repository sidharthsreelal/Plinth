import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class AudioFile {
  final String path;
  final String fileName;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final Uint8List? albumArt;
  final Uint8List? audioBytes;

  AudioSource? _audioSource;

  AudioFile({
    required this.path,
    required this.fileName,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.albumArt,
    this.audioBytes,
  });

  AudioFile copyWith({
    String? path,
    String? fileName,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    Uint8List? albumArt,
    Uint8List? audioBytes,
  }) {
    return AudioFile(
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      albumArt: albumArt ?? this.albumArt,
      audioBytes: audioBytes ?? this.audioBytes,
    );
  }

  AudioSource getAudioSource() {
    _audioSource ??= kIsWeb && audioBytes != null
        ? _BytesAudioSource(audioBytes!, fileName)
        : AudioSource.uri(Uri.file(path));
    return _audioSource!;
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'fileName': fileName,
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': duration.inMilliseconds,
    };
  }

  static AudioFile fromJson(Map<String, dynamic> json) {
    return AudioFile(
      path: json['path'] as String,
      fileName: json['fileName'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      duration: Duration(milliseconds: json['durationMs'] as int),
      albumArt: null,
    );
  }

  Future<void> cacheAlbumArt() async {
    if (albumArt == null) return;
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final artDir = Directory('${cacheDir.path}/album_art');
      if (!await artDir.exists()) {
        await artDir.create(recursive: true);
      }
      final hash = md5.convert(utf8.encode(path)).toString();
      final file = File('${artDir.path}/$hash.jpg');
      await file.writeAsBytes(albumArt!);
    } catch (e) {
      debugPrint('AudioFile: Failed to cache album art: $e');
    }
  }

  static Future<Uint8List?> loadCachedAlbumArt(String filePath) async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final hash = md5.convert(utf8.encode(filePath)).toString();
      final file = File('${cacheDir.path}/album_art/$hash.jpg');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('AudioFile: Failed to load cached album art: $e');
    }
    return null;
  }
}

class _BytesAudioSource extends StreamAudioSource {
  final Uint8List bytes;
  final String fileName;

  _BytesAudioSource(this.bytes, this.fileName);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end = end ?? bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: fileName.endsWith('.mp3')
          ? 'audio/mpeg'
          : fileName.endsWith('.m4a')
              ? 'audio/mp4'
              : fileName.endsWith('.ogg')
                  ? 'audio/ogg'
                  : fileName.endsWith('.wav')
                      ? 'audio/wav'
                      : 'audio/mpeg',
    );
  }
}
