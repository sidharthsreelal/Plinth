import 'package:plinth/models/audio_file.dart';

class FolderNode {
  final String name;
  final String path;
  final List<FolderNode> subFolders;
  final List<AudioFile> audioFiles;

  FolderNode({
    required this.name,
    required this.path,
    this.subFolders = const [],
    this.audioFiles = const [],
  });

  bool get isEmpty => subFolders.isEmpty && audioFiles.isEmpty;

  int get totalTrackCount {
    int count = audioFiles.length;
    for (final folder in subFolders) {
      count += folder.totalTrackCount;
    }
    return count;
  }
}
