import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/models/folder_node.dart';
import 'package:plinth/providers/pins_provider.dart';
import 'package:plinth/providers/player_provider.dart';
import 'package:plinth/providers/theme_provider.dart';
import 'package:plinth/screens/folder_browser_screen.dart';
import 'package:plinth/screens/now_playing_screen.dart';

class PinsSection extends StatelessWidget {
  const PinsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<PinsProvider, ThemeProvider>(
      builder: (context, pins, themeProvider, _) {
        if (pins.pins.isEmpty) return const SizedBox.shrink();

        final accent = themeProvider.accentColor.color;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Pinned',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 20,
                          letterSpacing: -0.3,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.push_pin_rounded, color: accent, size: 16),
                ],
              ),
            ),
            SizedBox(
              height: 172,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: pins.pins.length,
                itemBuilder: (context, index) {
                  final pin = pins.pins[index];
                  if (pin.type == PinnedItemType.audioFile) {
                    return _PinnedAudioCard(pin: pin, accent: accent);
                  } else {
                    return _PinnedFolderCard(pin: pin, accent: accent);
                  }
                },
              ),
            ),
            const SizedBox(height: 4),
            const Divider(
              color: Color(0xFF2C2C2E),
              height: 1,
              indent: 24,
              endIndent: 24,
            ),
          ],
        );
      },
    );
  }
}

// ── Pinned Audio File Card ────────────────────────────────────────────────────

class _PinnedAudioCard extends StatelessWidget {
  final PinnedItem pin;
  final Color accent;

  const _PinnedAudioCard({required this.pin, required this.accent});

  @override
  Widget build(BuildContext context) {
    final track = pin.audioFile;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          if (track == null) return;
          context.read<PlayerProvider>().playTrack(track, [track]);
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (ctx, anim, _) => FadeTransition(
                opacity: anim,
                child: const NowPlayingScreen(),
              ),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        },
        onLongPress: () => _showUnpinDialog(context, pin, context.read<PinsProvider>()),
        child: SizedBox(
          width: 124,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    SizedBox(
                      width: 124,
                      height: 124,
                      child: track?.albumArt != null
                          ? Image.memory(
                              track!.albumArt!,
                              width: 124,
                              height: 124,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _fallback(),
                            )
                          : _fallback(),
                    ),
                    // Gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Pin icon overlay
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.push_pin_rounded,
                          color: Colors.black,
                          size: 13,
                        ),
                      ),
                    ),
                    // Play icon
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pin.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                track?.artist ?? 'Song',
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnpinDialog(BuildContext context, PinnedItem pin, PinsProvider pins) {
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
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF48484A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    pin.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(
                    Icons.push_pin_rounded,
                    color: accent,
                  ),
                  title: Text(
                    'Unpin',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    pins.unpin(pin.path);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close_rounded, color: Color(0xFF8E8E93)),
                  title: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
                  onTap: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fallback() => Container(
        color: const Color(0xFF2C2C2E),
        child: Icon(Icons.music_note_rounded, color: const Color(0xFF48484A).withOpacity(0.6), size: 48),
      );
}

// ── Pinned Folder Card ────────────────────────────────────────────────────────

class _PinnedFolderCard extends StatelessWidget {
  final PinnedItem pin;
  final Color accent;

  const _PinnedFolderCard({required this.pin, required this.accent});

  @override
  Widget build(BuildContext context) {
    final folder = pin.folder;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          if (folder == null) return;
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (ctx, anim, _) => FadeTransition(
                opacity: anim,
                child: FolderBrowserScreen(folder: folder),
              ),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        },
        onLongPress: () => _showUnpinDialog(context, pin, context.read<PinsProvider>()),
        child: SizedBox(
          width: 124,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Folder artwork: mosaic of up to 4 album arts or folder icon
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    _folderArtwork(folder),
                    // Gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.65),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Pin icon
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.push_pin_rounded,
                          color: Colors.black,
                          size: 13,
                        ),
                      ),
                    ),
                    // Open arrow
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.folder_open_rounded,
                          color: Colors.black,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pin.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                folder != null ? '${folder.totalTrackCount} tracks' : 'Folder',
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _folderArtwork(FolderNode? folder) {
    if (folder == null) {
      return _folderFallback();
    }

    final arts = _collectArts(folder).take(4).toList();

    if (arts.isEmpty) return _folderFallback();

    if (arts.length < 4) {
      return Image.memory(
        arts.first,
        width: 124,
        height: 124,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _folderFallback(),
      );
    }

    return SizedBox(
      width: 124,
      height: 124,
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
        children: arts.take(4).map((art) {
          return Image.memory(art, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _folderFallback());
        }).toList(),
      ),
    );
  }

  List<dynamic> _collectArts(FolderNode node) {
    final arts = <dynamic>[];
    for (final f in node.audioFiles) {
      if (f.albumArt != null) arts.add(f.albumArt!);
      if (arts.length >= 4) return arts;
    }
    for (final sub in node.subFolders) {
      arts.addAll(_collectArts(sub));
      if (arts.length >= 4) return arts;
    }
    return arts;
  }

  void _showUnpinDialog(BuildContext context, PinnedItem pin, PinsProvider pins) {
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
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF48484A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    pin.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.push_pin_rounded, color: accent),
                  title: Text(
                    'Unpin',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    pins.unpin(pin.path);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close_rounded, color: Color(0xFF8E8E93)),
                  title: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
                  onTap: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _folderFallback() => Container(
        width: 124,
        height: 124,
        color: const Color(0xFF2C2C2E),
        child: Icon(Icons.folder_rounded, color: accent.withOpacity(0.5), size: 52),
      );
}

