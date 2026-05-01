import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/models/folder_node.dart';
import 'package:plinth/providers/favourites_provider.dart';
import 'package:plinth/providers/history_provider.dart';
import 'package:plinth/providers/library_provider.dart';
import 'package:plinth/providers/pins_provider.dart';
import 'package:plinth/providers/player_provider.dart';
import 'package:plinth/providers/theme_provider.dart';
import 'package:plinth/screens/folder_browser_screen.dart';
import 'package:plinth/screens/now_playing_screen.dart';
import 'package:plinth/screens/search_screen.dart';
import 'package:plinth/services/metadata_service.dart';
import 'package:plinth/theme/app_theme.dart';
import 'package:plinth/widgets/audio_tile.dart';
import 'package:plinth/widgets/folder_tile.dart';
import 'package:plinth/widgets/mini_player.dart';
import 'package:plinth/widgets/pins_section.dart';
import 'package:plinth/widgets/quick_picks_section.dart';

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

  void _hydrateProviders(FolderNode root) {
    final all = _collectAllAudio(root);
    context.read<HistoryProvider>().hydrate(all);
    context.read<FavouritesProvider>().hydrate(all);
    context.read<PinsProvider>().hydrateAudio(all);
    context.read<PinsProvider>().hydrateFolder(root);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer2<LibraryProvider, ThemeProvider>(
          builder: (context, library, themeProvider, child) {
            final accent = themeProvider.accentColor.color;

            if (!library.isInitialized) {
              return _loadingView(accent, 'Loading…');
            }

            if (library.isScanning) {
              return _loadingView(accent, 'Scanning your music…');
            }

            if (!library.hasFolder || library.rootFolder == null) {
              return _OnboardingState(
                  onFolderPicked: kIsWeb ? _pickFiles : _pickFolder);
            }

            if (library.rootFolder!.isEmpty) {
              return _EmptyLibraryState(
                  onChangeFolder: kIsWeb ? _pickFiles : _pickFolder);
            }

            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _hydrateProviders(library.rootFolder!));

            return Column(
              children: [
                // ── Header ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Plinth',
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(fontSize: 28),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.search_rounded),
                            onPressed: () => _openSearch(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_rounded),
                            onPressed: () => _showSettings(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── Content list ────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 4),
                    itemCount: 3 +
                        library.rootFolder!.subFolders.length +
                        library.rootFolder!.audioFiles.length,
                    itemBuilder: (context, index) {
                      // Index 0 → Quick Picks
                      if (index == 0) return const QuickPicksSection();

                      // Index 1 → Pins section
                      if (index == 1) return const PinsSection();

                      // Index 2 → Favourites virtual folder
                      if (index == 2) {
                        return Consumer2<FavouritesProvider, ThemeProvider>(
                          builder: (context, favourites, tp, _) {
                            final folder = favourites.favouritesFolder;
                            if (folder == null) return const SizedBox.shrink();
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: _FavouritesFolderTile(
                                folder: folder,
                                accent: tp.accentColor.color,
                                onTap: () => Navigator.push(
                                  context,
                                  _createRoute(
                                      FolderBrowserScreen(folder: folder)),
                                ),
                              ),
                            );
                          },
                        );
                      }

                      final realIndex = index - 3;

                      if (realIndex <
                          library.rootFolder!.subFolders.length) {
                        final folder =
                            library.rootFolder!.subFolders[realIndex];
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Consumer<PinsProvider>(
                            builder: (context, pins, _) => FolderTile(
                              folder: folder,
                              isPinned: pins.isPinned(folder.path),
                              onTap: () => Navigator.push(
                                context,
                                _createRoute(
                                    FolderBrowserScreen(folder: folder)),
                              ),
                              onLongPress: () =>
                                  _showFolderOptions(context, folder),
                            ),
                          ),
                        );
                      } else {
                        final audioIndex = realIndex -
                            library.rootFolder!.subFolders.length;
                        final audio =
                            library.rootFolder!.audioFiles[audioIndex];
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Consumer<PlayerProvider>(
                            builder: (context, player, child) {
                              return AudioTile(
                                audio: audio,
                                isPlaying: player.isPlaying,
                                isCurrentTrack:
                                    player.currentTrack?.path == audio.path,
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
                                onLongPress: () =>
                                    _showAudioOptions(context, audio),
                              );
                            },
                          ),
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

  Widget _loadingView(Color accent, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: accent),
          const SizedBox(height: 24),
          Text(message,
              style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 16)),
        ],
      ),
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, anim, _) =>
            FadeTransition(opacity: anim, child: const SearchScreen()),
        transitionDuration: const Duration(milliseconds: 200),
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
      final audioFile = await MetadataService.extract(tempFile, audioBytes: file.bytes);
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
      builder: (sheetContext) {
        return Consumer2<LibraryProvider, ThemeProvider>(
          builder: (context, library, themeProvider, child) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settings',
                      style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 24),
                  const Text('Accent Color',
                      style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
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
                              ? const Icon(Icons.check,
                                  color: Color(0xFF0D0D0D), size: 24)
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
                        Icon(Icons.folder_rounded,
                            color: themeProvider.accentColor.color, size: 20),
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
                        Navigator.pop(sheetContext);
                        await _pickFolder();
                      },
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Change Folder'),
                      style: TextButton.styleFrom(
                          foregroundColor: themeProvider.accentColor.color),
                    ),
                    const SizedBox(height: 8),
                    // ── Re-scan: close sheet first, then scan ──────────
                    TextButton.icon(
                      onPressed: () {
                        // Pop the sheet first so the scanning indicator
                        // on the home screen becomes visible immediately.
                        Navigator.pop(sheetContext);
                        final path = library.rootPath;
                        if (path != null) {
                          // Use the outer context (home screen) to trigger scan
                          context.read<LibraryProvider>().scanFolder(path);
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Re-scan Library'),
                      style: TextButton.styleFrom(
                          foregroundColor: themeProvider.accentColor.color),
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

  void _showFolderOptions(BuildContext context, FolderNode folder) {
    final allAudio = _collectAllAudio(folder);
    final accent = context.read<ThemeProvider>().accentColor.color;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer<PinsProvider>(
          builder: (ctx2, pins, _) {
            final isPinned = pins.isPinned(folder.path);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.play_arrow_rounded, color: accent),
                    title: Text('Play All (${folder.totalTrackCount} tracks)'),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (allAudio.isNotEmpty) {
                        context.read<PlayerProvider>().playTrack(allAudio.first, allAudio);
                        Navigator.push(context, _createRoute(const NowPlayingScreen()));
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.shuffle_rounded, color: accent),
                    title: const Text('Shuffle Play'),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (allAudio.isNotEmpty) {
                        final shuffled = List<AudioFile>.from(allAudio)..shuffle(Random());
                        context.read<PlayerProvider>().playTrack(shuffled.first, shuffled);
                        Navigator.push(context, _createRoute(const NowPlayingScreen()));
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add_rounded,
                        color: Color(0xFF8E8E93)),
                    title: const Text('Add to Queue'),
                    onTap: () {
                      Navigator.pop(ctx);
                      for (final track in allAudio) {
                        context.read<PlayerProvider>().addToPlayNext(track);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${allAudio.length} tracks added to queue'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      ));
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                      color: isPinned ? accent : const Color(0xFF8E8E93),
                    ),
                    title: Text(isPinned ? 'Unpin Folder' : 'Pin Folder'),
                    onTap: () {
                      Navigator.pop(ctx);
                      pins.toggleFolder(folder);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isPinned
                            ? '${folder.name} unpinned'
                            : '${folder.name} pinned'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      ));
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAudioOptions(BuildContext context, AudioFile audio) {
    final accent = context.read<ThemeProvider>().accentColor.color;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer<PinsProvider>(
          builder: (ctx2, pins, _) {
            final isPinned = pins.isPinned(audio.path);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.playlist_add_rounded,
                        color: Color(0xFF8E8E93)),
                    title: const Text('Play Next'),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.read<PlayerProvider>().addToPlayNext(audio);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                      color: isPinned ? accent : const Color(0xFF8E8E93),
                    ),
                    title: Text(isPinned ? 'Unpin Song' : 'Pin Song'),
                    onTap: () {
                      Navigator.pop(ctx);
                      pins.toggleAudioFile(audio);
                      final title =
                          audio.title.isNotEmpty ? audio.title : audio.fileName;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text(isPinned ? '$title unpinned' : '$title pinned'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      ));
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<AudioFile> _collectAllAudio(FolderNode node) {
    final audio = <AudioFile>[...node.audioFiles];
    for (final subFolder in node.subFolders) {
      audio.addAll(_collectAllAudio(subFolder));
    }
    return audio;
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

// ── Onboarding ───────────────────────────────────────────────────────────────

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
                Icon(Icons.album_rounded, size: 120, color: accent.withOpacity(0.3)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

// ── Empty library ────────────────────────────────────────────────────────────

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
                const Icon(Icons.search_off_rounded, size: 80, color: Color(0xFF48484A)),
                const SizedBox(height: 24),
                Text(
                  kIsWeb ? 'No audio files selected.' : 'No audio files found in this folder.',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 20),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

// ── Favourites virtual folder tile ───────────────────────────────────────────

class _FavouritesFolderTile extends StatelessWidget {
  final FolderNode folder;
  final Color accent;
  final VoidCallback onTap;

  const _FavouritesFolderTile({
    required this.folder,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final artworks = folder.audioFiles.where((t) => t.albumArt != null).take(4).toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [accent.withOpacity(0.25), accent.withOpacity(0.08)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: accent.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            if (artworks.isNotEmpty)
              _ArtMosaic(artworks: artworks, accent: accent)
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.favorite_rounded, color: accent, size: 24),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite_rounded, color: accent, size: 14),
                      const SizedBox(width: 6),
                      Text('Favourites',
                          style: TextStyle(
                              color: accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${folder.audioFiles.length} song${folder.audioFiles.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent.withOpacity(0.6), size: 24),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _ArtMosaic extends StatelessWidget {
  final List<AudioFile> artworks;
  final Color accent;

  const _ArtMosaic({required this.artworks, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (artworks.length < 4) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(artworks.first.albumArt!,
            width: 44, height: 44, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 44,
        height: 44,
        child: GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: 1,
          crossAxisSpacing: 1,
          children: artworks.take(4).map((t) {
            return Image.memory(t.albumArt!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback());
          }).toList(),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
      color: const Color(0xFF2C2C2E),
      child: Icon(Icons.favorite_rounded, color: accent, size: 12));
}
