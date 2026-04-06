import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/providers/library_provider.dart';
import 'package:plinth/providers/player_provider.dart';
import 'package:plinth/providers/theme_provider.dart';
import 'package:plinth/screens/folder_browser_screen.dart';
import 'package:plinth/screens/now_playing_screen.dart';
import 'package:plinth/services/metadata_service.dart';
import 'package:plinth/theme/app_theme.dart';
import 'package:plinth/widgets/audio_tile.dart';
import 'package:plinth/widgets/folder_tile.dart';
import 'package:plinth/widgets/mini_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (!kIsWeb && Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer2<LibraryProvider, ThemeProvider>(
          builder: (context, library, themeProvider, child) {
            final accent = themeProvider.accentColor.color;

            if (!library.isInitialized) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: accent),
                    const SizedBox(height: 24),
                    const Text(
                      'Loading…',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            if (library.isScanning) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: accent),
                    const SizedBox(height: 24),
                    const Text(
                      'Scanning your music…',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            if (!library.hasFolder || library.rootFolder == null) {
              return _OnboardingState(onFolderPicked: kIsWeb ? _pickFiles : _pickFolder);
            }

            if (library.rootFolder!.isEmpty) {
              return _EmptyLibraryState(onChangeFolder: kIsWeb ? _pickFiles : _pickFolder);
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Plinth',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: 28,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_rounded),
                        onPressed: () => _showSettings(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount:
                        library.rootFolder!.subFolders.length +
                        library.rootFolder!.audioFiles.length,
                    itemBuilder: (context, index) {
                      if (index < library.rootFolder!.subFolders.length) {
                        final folder = library.rootFolder!.subFolders[index];
                        return FolderTile(
                          folder: folder,
                          onTap: () {
                            Navigator.push(
                              context,
                              _createRoute(FolderBrowserScreen(folder: folder)),
                            );
                          },
                          onLongPress: () => _showFolderOptions(context, folder),
                        );
                      } else {
                        final audioIndex = index - library.rootFolder!.subFolders.length;
                        final audio = library.rootFolder!.audioFiles[audioIndex];
                        return Consumer<PlayerProvider>(
                          builder: (context, player, child) {
                            return AudioTile(
                              audio: audio,
                              isPlaying: player.isPlaying,
                              isCurrentTrack: player.currentTrack?.path == audio.path,
                              onTap: () {
                                player.playTrack(
                                  audio,
                                  library.rootFolder!.audioFiles,
                                );
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
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final audioFiles = <AudioFile>[];
    for (final file in result.files) {
      if (file.bytes == null) continue;
      final name = file.name ?? 'unknown';
      final tempFile = File(name);
      final audioFile = await MetadataService.extract(
        tempFile,
        audioBytes: file.bytes,
      );
      audioFiles.add(audioFile);
    }

    if (audioFiles.isNotEmpty && mounted) {
      await context.read<LibraryProvider>().setWebAudioFiles(audioFiles);
    }
  }

  Future<void> _pickFolder() async {
    if (kIsWeb) return;
    await _requestPermissions();
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null && mounted) {
      await context.read<LibraryProvider>().setRootFolder(result);
    }
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer2<LibraryProvider, ThemeProvider>(
          builder: (context, library, themeProvider, child) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Accent Color',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: AccentColor.values.map((color) {
                      final isSelected = themeProvider.accentColor == color;
                      return GestureDetector(
                        onTap: () => themeProvider.setAccentColor(color),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFFFFFF)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Color(0xFF0D0D0D), size: 24)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF2C2C2E)),
                  const SizedBox(height: 12),
                  if (library.rootPath != null) ...[
                    Row(
                      children: [
                        Icon(Icons.folder_rounded, color: themeProvider.accentColor.color, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            library.rootPath!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _pickFolder();
                      },
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Change Folder'),
                      style: TextButton.styleFrom(
                        foregroundColor: themeProvider.accentColor.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (library.rootPath != null) {
                          await library.scanFolder(library.rootPath!);
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Re-scan Library'),
                      style: TextButton.styleFrom(
                        foregroundColor: themeProvider.accentColor.color,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFolderOptions(BuildContext context, dynamic folder) {
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
                leading: Icon(Icons.play_arrow_rounded, color: Theme.of(context).colorScheme.secondary),
                title: Text('Play All (${folder.totalTrackCount} tracks)'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: Color(0xFF8E8E93)),
                title: const Text('Add to Queue'),
                onTap: () {
                  Navigator.pop(context);
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

class _OnboardingState extends StatelessWidget {
  final VoidCallback onFolderPicked;

  const _OnboardingState({required this.onFolderPicked});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final accent = themeProvider.accentColor.color;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.album_rounded,
                  size: 120,
                  color: accent.withOpacity(0.3),
                ),
                const SizedBox(height: 32),
                Text(
                  kIsWeb ? 'Your music, right in your browser.' : 'Your music, your structure.',
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  kIsWeb
                      ? 'Select audio files from your device and start listening instantly.'
                      : 'Pick a folder and Plinth will follow how you\'ve organized your music — no re-sorting, no surprises.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: onFolderPicked,
                  icon: Icon(kIsWeb ? Icons.upload_file_rounded : Icons.folder_open_rounded),
                  label: Text(kIsWeb ? 'Choose Music Files' : 'Choose Music Folder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: const Color(0xFF0D0D0D),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  final VoidCallback onChangeFolder;

  const _EmptyLibraryState({required this.onChangeFolder});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final accent = themeProvider.accentColor.color;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 80,
                  color: Color(0xFF48484A),
                ),
                const SizedBox(height: 24),
                Text(
                  kIsWeb ? 'No audio files selected.' : 'No audio files found in this folder.',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: 20,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  kIsWeb
                      ? 'Select some MP3, FLAC, or other audio files to start listening.'
                      : 'Try selecting a different folder that contains MP3, FLAC, or other audio files.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: onChangeFolder,
                  icon: Icon(kIsWeb ? Icons.upload_file_rounded : Icons.folder_open_rounded),
                  label: Text(kIsWeb ? 'Choose Different Files' : 'Choose Different Folder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: const Color(0xFF0D0D0D),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
