import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/providers/favourites_provider.dart';
import 'package:plinth/providers/player_provider.dart';
import 'package:plinth/providers/theme_provider.dart';
import 'package:plinth/widgets/waveform_bars.dart';

class AudioTile extends StatefulWidget {
  final AudioFile audio;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isPlaying;
  final bool isCurrentTrack;

  const AudioTile({
    super.key,
    required this.audio,
    required this.onTap,
    this.onLongPress,
    this.isPlaying = false,
    this.isCurrentTrack = false,
  });

  @override
  State<AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<AudioTile>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  bool _triggered = false;
  static const double _triggerThreshold = 72;

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--:--';
    final minutes = duration.inMinutes;
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta == null) return;
    if (details.primaryDelta! < 0 && _dragX <= 0) return;
    setState(() {
      _dragX = (_dragX + details.primaryDelta!).clamp(0.0, 120.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragX >= _triggerThreshold && !_triggered) {
      _triggered = true;
      final player = context.read<PlayerProvider>();
      final added = player.addToPlayNext(widget.audio);
      if (added) _showPlayNextBanner();
    }
    setState(() {
      _dragX = 0;
      _triggered = false;
    });
  }

  void _showPlayNextBanner() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.playlist_add_rounded,
                color: Color(0xFF0D0D0D), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Playing next: ${widget.audio.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF0D0D0D), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor:
            context.read<ThemeProvider>().accentColor.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, PlayerProvider, FavouritesProvider>(
      builder: (context, themeProvider, player, favourites, child) {
        final accent = themeProvider.accentColor.color;
        final isFav = favourites.isFavourite(widget.audio);
        final progress = (_dragX / _triggerThreshold).clamp(0.0, 1.0);

        return GestureDetector(
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onLongPress: widget.onLongPress,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // Swipe-right reveal
              if (_dragX > 0)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 60),
                      width: _dragX,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withOpacity(0.8 * progress),
                            accent.withOpacity(0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Opacity(
                            opacity: progress.clamp(0.0, 1.0),
                            child: Icon(
                              Icons.playlist_add_rounded,
                              color: Colors.white,
                              size: 22 + (6 * progress),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Main tile
              Transform.translate(
                offset: Offset(_dragX, 0),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: widget.audio.albumArt != null
                        ? Image.memory(
                            widget.audio.albumArt!,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _fallbackIcon(),
                          )
                        : _fallbackIcon(),
                  ),
                  title: Text(
                    widget.audio.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: widget.isCurrentTrack
                              ? accent
                              : const Color(0xFFFFFFFF),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    widget.audio.artist,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Favourite heart
                      GestureDetector(
                        onTap: () => favourites.toggle(widget.audio),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            key: ValueKey(isFav),
                            color: isFav ? accent : const Color(0xFF48484A),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Duration or waveform
                      if (widget.isPlaying && widget.isCurrentTrack)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: WaveformBars(),
                        )
                      else
                        Text(
                          _formatDuration(widget.audio.duration),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  onTap: widget.onTap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fallbackIcon() {
    return Container(
      width: 36,
      height: 36,
      color: const Color(0xFF2C2C2E),
      child: const Icon(
        Icons.music_note_rounded,
        color: Color(0xFF8E8E93),
        size: 20,
      ),
    );
  }
}
