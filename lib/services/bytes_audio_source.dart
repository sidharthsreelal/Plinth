import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

class BytesAudioSource extends StreamAudioSource {
  final Uint8List bytes;
  final String mimeType;
  final String sourceName;

  BytesAudioSource({
    required this.bytes,
    required this.mimeType,
    required this.sourceName,
  });

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final startByte = start ?? 0;
    final endByte = end ?? bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: endByte - startByte,
      offset: startByte,
      stream: Stream.value(bytes.sublist(startByte, endByte)),
      contentType: mimeType,
    );
  }
}
