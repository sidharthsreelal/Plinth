import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/models/folder_node.dart';
import 'package:plinth/providers/pins_provider.dart';
import 'package:plinth/providers/player_provider.dart';
import 'package:plinth/providers/theme_provider.dart';
import 'package:plinth/screens/now_playing_screen.dart';
import 'package:plinth/widgets/audio_tile.dart';
import 'package:plinth/widgets/folder_tile.dart';
import 'package:plinth/widgets/mini_player.dart';

enum _SortOrder { trackNumber, nameAZ, nameZA, dateModified }

class FolderBrowserScreen extends StatefulWidget {
  final FolderNode folder;

  const FolderBrowserScreen({super.key, required this.folder});

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  late _SortOrder _sortOrder;

  @override
  void initState() {
    super.initState();
    // Read the persisted sort preference from ThemeProvider
    final key = context.read<ThemeProvider>().defaultSortOrderKey;
    _sortOrder = _sortOrderFromKey(key);
  }

  _SortOrder _sortOrderFromKey(String key) {
    switch (key) {
      case 'nameAZ': return _SortOrder.nameAZ;
      case 'nameZA': return _SortOrder.nameZA;
      case 'dateModified': return _SortOrder.dateModified;
      default: return _SortOrder.trackNumber;
    }
  }

  /// Returns sorted audio files based on the current sort order.
  List<AudioFile> get _sortedAudioFiles {
    final files = List<AudioFile>.from(widget.folder.audioFiles);
    switch (_sortOrder) {
      case _SortOrder.trackNumber:
        files.sort((a, b) {
          final tna = a.trackNumber;
          final tnb = b.trackNumber;
          if (tna != null && tnb != null) return tna.compareTo(tnb);
          if (tna != null) return -1;
          if (tnb != null) return 1;
          // Fall back to filename sort when track# is absent
          return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
        });
        break;
      case _SortOrder.nameAZ:
        files.sort((a, b) {
          final ta = a.title.isNotEmpty ? a.title : a.fileName;
          final tb = b.title.isNotEmpty ? b.title : b.fileName;
          return ta.toLowerCase().compareTo(tb.toLowerCase());
        });
        break;
      case _SortOrder.nameZA:
        files.sort((a, b) {
          final ta = a.title.isNotEmpty ? a.title : a.fileName;
          final tb = b.title.isNotEmpty ? b.title : b.fileName;
          return tb.toLowerCase().compareTo(ta.toLowerCase());
        });
        break;
      case _SortOrder.dateModified:
        files.sort((a, b) => b.fileName.compareTo(a.fileName));
        break;
    }
    return files;
  }

  /// True if this folder contains audio files directly (not just sub-folders).
  bool get _hasDirectAudio => widget.folder.audioFiles.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ThemeProvider>().accentColor.color;
    final audioFiles = _sortedAudioFiles;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Sort button — only shown when there are direct audio files
          if (_hasDirectAudio)
            IconButton(
              icon: const Icon(Icons.sort_rounded),
              tooltip: 'Sort',
              onPressed: () => _showSortMenu(context),
            ),
          // Play All + Shuffle in a compact segmented-style pair
          _PlayControls(
            onPlayAll: () => _playAll(context, audioFiles, shuffle: false),
            onShuffle: () => _playAll(context, audioFiles, shuffle: true),
            accent: accent,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.folder.totalTrackCount} tracks'
                '${_hasDirectAudio ? ' · sorted ${_sortLabel}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.folder.subFolders.length + audioFiles.length,
              itemBuilder: (context, index) {
                if (index < widget.folder.subFolders.length) {
                  final subFolder = widget.folder.subFolders[index];
                  return Consumer<PinsProvider>(
                    builder: (context, pins, _) {
                      return FolderTile(
                        folder: subFolder,
                        isPinned: pins.isPinned(subFolder.path),
                        onTap: () {
                          Navigator.push(
                            context,
                            _createRoute(FolderBrowserScreen(folder: subFolder)),
                          );
                        },
                        onLongPress: () => _showFolderOptions(context, subFolder),
                      );
                    },
                  );
                } else {
                  final audioIndex = index - widget.folder.subFolders.length;
                  final audio = audioFiles[audioIndex];
                  return Consumer<PlayerProvider>(
                    builder: (context, player, child) {
                      return AudioTile(
                        audio: audio,
                        isPlaying: player.isPlaying,
                        isCurrentTrack: player.currentTrack?.path == audio.path,
                        onTap: () {
                          // Pass sorted list so queue order matches what user sees
                          player.playTrack(audio, audioFiles);
                          Navigator.push(
                            context,
                            _createRoute(const NowPlayingScreen()),
                          );
                        },
                        onLongPress: () => _showAudioOptions(context, audio),
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

  String get _sortLabel {
    switch (_sortOrder) {
      case _SortOrder.trackNumber:
        return 'Track #';
      case _SortOrder.nameAZ:
        return 'A → Z';
      case _SortOrder.nameZA:
        return 'Z → A';
      case _SortOrder.dateModified:
        return 'newest first';
    }
  }

  void _showSortMenu(BuildContext context) {
    final accent = context.read<ThemeProvider>().accentColor.color;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    'Sort by',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 16),
                  ),
                ),
                _SortOption(
                  icon: Icons.tag_rounded,
                  label: 'Track number',
                  selected: _sortOrder == _SortOrder.trackNumber,
                  accent: accent,
                  onTap: () {
                    setState(() => _sortOrder = _SortOrder.trackNumber);
                    context.read<ThemeProvider>().setDefaultSortOrder(_SortOrder.trackNumber);
                    Navigator.pop(ctx);
                  },
                ),
                _SortOption(
                  icon: Icons.sort_by_alpha_rounded,
                  label: 'Name  A → Z',
                  selected: _sortOrder == _SortOrder.nameAZ,
                  accent: accent,
                  onTap: () {
                    setState(() => _sortOrder = _SortOrder.nameAZ);
                    context.read<ThemeProvider>().setDefaultSortOrder(_SortOrder.nameAZ);
                    Navigator.pop(ctx);
                  },
                ),
                _SortOption(
                  icon: Icons.sort_by_alpha_rounded,
                  label: 'Name  Z → A',
                  selected: _sortOrder == _SortOrder.nameZA,
                  accent: accent,
                  onTap: () {
                    setState(() => _sortOrder = _SortOrder.nameZA);
                    context.read<ThemeProvider>().setDefaultSortOrder(_SortOrder.nameZA);
                    Navigator.pop(ctx);
                  },
                ),
                _SortOption(
                  icon: Icons.access_time_rounded,
                  label: 'Newest first',
                  selected: _sortOrder == _SortOrder.dateModified,
                  accent: accent,
                  onTap: () {
                    setState(() => _sortOrder = _SortOrder.dateModified);
                    context.read<ThemeProvider>().setDefaultSortOrder(_SortOrder.dateModified);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _playAll(BuildContext context, List<AudioFile> files, {required bool shuffle}) {
    if (files.isEmpty) {
      final all = _collectAllAudio(widget.folder);
      if (all.isEmpty) return;
      _startPlayback(context, all, shuffle: shuffle);
      return;
    }
    _startPlayback(context, files, shuffle: shuffle);
  }

  void _startPlayback(BuildContext context, List<AudioFile> all, {required bool shuffle}) {
    final list = shuffle ? (List<AudioFile>.from(all)..shuffle(Random())) : all;
    context.read<PlayerProvider>().playTrack(list.first, list);
    Navigator.push(context, _createRoute(const NowPlayingScreen()));
  }

  List<AudioFile> _collectAllAudio(FolderNode node) {
    final audio = <AudioFile>[...node.audioFiles];
    for (final sub in node.subFolders) {
      audio.addAll(_collectAllAudio(sub));
    }
    return audio;
  }

  void _showFolderOptions(BuildContext context, FolderNode subFolder) {
    final allAudio = _collectAllAudio(subFolder);
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
            final isPinned = pins.isPinned(subFolder.path);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.play_arrow_rounded, color: accent),
                    title: Text('Play All (${subFolder.totalTrackCount} tracks)'),
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
                    leading: const Icon(Icons.playlist_add_rounded, color: Color(0xFF8E8E93)),
                    title: const Text('Add to Queue'),
                    onTap: () {
                      Navigator.pop(ctx);
                      final player = context.read<PlayerProvider>();
                      for (final track in allAudio) {
                        player.addToPlayNext(track);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${allAudio.length} tracks added to queue'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      pins.toggleFolder(subFolder);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isPinned ? '${subFolder.name} unpinned' : '${subFolder.name} pinned'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    leading: const Icon(Icons.playlist_add_rounded, color: Color(0xFF8E8E93)),
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
                      final title = audio.title.isNotEmpty ? audio.title : audio.fileName;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isPinned ? '$title unpinned' : '$title pinned'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

// ── Play Controls widget (compact Play All + Shuffle) ────────────────────────

class _PlayControls extends StatelessWidget {
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final Color accent;

  const _PlayControls({
    required this.onPlayAll,
    required this.onShuffle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play All
          InkWell(
            onTap: onPlayAll,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.play_arrow_rounded, color: accent, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Play All',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Divider
          Container(width: 1, height: 20, color: accent.withOpacity(0.3)),
          // Shuffle
          InkWell(
            onTap: onShuffle,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Icon(Icons.shuffle_rounded, color: accent, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sort option tile ──────────────────────────────────────────────────────────

class _SortOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SortOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? accent : const Color(0xFF8E8E93)),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? accent : Colors.white,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded, color: accent, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
