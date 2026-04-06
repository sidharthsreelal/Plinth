import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/models/folder_node.dart';
import 'package:plinth/providers/library_provider.dart';
import 'package:plinth/providers/player_provider.dart';
import 'package:plinth/providers/theme_provider.dart';
import 'package:plinth/screens/now_playing_screen.dart';
import 'package:plinth/widgets/audio_tile.dart';
import 'package:plinth/widgets/folder_tile.dart';
import 'package:plinth/widgets/mini_player.dart';

class FolderBrowserScreen extends StatelessWidget {
  final FolderNode folder;

  const FolderBrowserScreen({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _playAll(context),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play All'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16),
            child: Text(
              '${folder.totalTrackCount} tracks',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: folder.subFolders.length + folder.audioFiles.length,
              itemBuilder: (context, index) {
                if (index < folder.subFolders.length) {
                  final subFolder = folder.subFolders[index];
                  return FolderTile(
                    folder: subFolder,
                    onTap: () {
                      Navigator.push(
                        context,
                        _createRoute(FolderBrowserScreen(folder: subFolder)),
                      );
                    },
                    onLongPress: () => _showFolderOptions(context, subFolder),
                  );
                } else {
                  final audioIndex = index - folder.subFolders.length;
                  final audio = folder.audioFiles[audioIndex];
                  return Consumer<PlayerProvider>(
                    builder: (context, player, child) {
                      return AudioTile(
                        audio: audio,
                        isPlaying: player.isPlaying,
                        isCurrentTrack: player.currentTrack?.path == audio.path,
                        onTap: () {
                          player.playTrack(audio, folder.audioFiles);
                          Navigator.push(
                            context,
                            _createRoute(const NowPlayingScreen()),
                          );
                        },
                      );
                    },
                  );
                }
              },
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }

  void _playAll(BuildContext context) {
    final allAudio = _collectAllAudio(folder);
    if (allAudio.isNotEmpty) {
      context.read<PlayerProvider>().playTrack(allAudio.first, allAudio);
      Navigator.push(
        context,
        _createRoute(const NowPlayingScreen()),
      );
    }
  }

  List<AudioFile> _collectAllAudio(FolderNode node) {
    final audio = <AudioFile>[...node.audioFiles];
    for (final subFolder in node.subFolders) {
      audio.addAll(_collectAllAudio(subFolder));
    }
    return audio;
  }

  void _showFolderOptions(BuildContext context, FolderNode subFolder) {
    final allAudio = _collectAllAudio(subFolder);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.play_arrow_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                title: Text('Play All (${subFolder.totalTrackCount} tracks)'),
                onTap: () {
                  Navigator.pop(context);
                  if (allAudio.isNotEmpty) {
                    context.read<PlayerProvider>().playTrack(allAudio.first, allAudio);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: page,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}
