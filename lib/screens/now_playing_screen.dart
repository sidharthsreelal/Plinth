import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:plinth/providers/player_provider.dart';
import 'package:plinth/providers/theme_provider.dart';
import 'package:plinth/widgets/vinyl_record.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _isDragging = false;
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerProvider, ThemeProvider>(
      builder: (context, player, themeProvider, child) {
        final accent = themeProvider.accentColor.color;
        final track = player.currentTrack;
        if (track == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D0D0D),
            body: const Center(
              child: Text('No track playing', style: TextStyle(color: Color(0xFF8E8E93))),
            ),
          );
        }

        final position = player.player.position ?? Duration.zero;
        final duration = player.player.duration ?? Duration.zero;

        return GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta != null && details.primaryDelta! > 0) {
              setState(() {
                _dragOffset += details.primaryDelta!;
                _dragOffset = _dragOffset.clamp(0, 500);
              });
            }
          },
          onVerticalDragEnd: (details) {
            if (_dragOffset > 150) {
              Navigator.pop(context);
            } else {
              setState(() => _dragOffset = 0);
            }
          },
          child: Scaffold(
            body: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Opacity(
                opacity: 1.0 - (_dragOffset / 500),
                child: Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _buildBackground(track.albumArt, key: ValueKey(track.path)),
                    ),
                    SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          VinylRecord(
                            albumArt: track.albumArt,
                            isSpinning: player.isPlaying,
                            size: 280,
                          ),
                          const SizedBox(height: 32),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              children: [
                                Text(
                                  track.title,
                                  style: Theme.of(context).textTheme.displayMedium,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  track.artist,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontSize: 16,
                                      ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  track.album,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              children: [
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                    activeTrackColor: accent,
                                    inactiveTrackColor: const Color(0xFF2C2C2E),
                                    thumbColor: accent,
                                    overlayColor: accent.withOpacity(0.2),
                                  ),
                                  child: Slider(
                                    value: duration.inMilliseconds > 0
                                        ? position.inMilliseconds.toDouble()
                                        : 0,
                                    max: duration.inMilliseconds > 0
                                        ? duration.inMilliseconds.toDouble()
                                        : 1,
                                    onChanged: (value) {
                                      setState(() => _isDragging = true);
                                    },
                                    onChangeEnd: (value) {
                                      player.seekTo(Duration(milliseconds: value.toInt()));
                                      setState(() => _isDragging = false);
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(position),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      Text(
                                        _formatDuration(duration),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.skip_previous_rounded, size: 40),
                                onPressed: () => player.skipPrevious(),
                                color: const Color(0xFFFFFFFF),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent.withOpacity(0.15),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    player.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 48,
                                    color: accent,
                                  ),
                                  onPressed: () => player.togglePlayPause(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.skip_next_rounded, size: 40),
                                onPressed: () => player.skipNext(),
                                color: const Color(0xFFFFFFFF),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.shuffle_rounded,
                                  color: player.shuffle ? accent : const Color(0xFF48484A),
                                ),
                                onPressed: () => player.toggleShuffle(),
                              ),
                              IconButton(
                                icon: Icon(
                                  _getLoopIcon(player.loopMode),
                                  color: player.loopMode != LoopMode.off ? accent : const Color(0xFF48484A),
                                ),
                                onPressed: () => player.cycleLoopMode(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildBackground(Uint8List? albumArt, {required ValueKey key}) {
    if (albumArt != null) {
      return Stack(
        key: key,
        fit: StackFit.expand,
        children: [
          Image.memory(
            albumArt,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _fallbackBackground();
            },
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: const Color(0xFF0D0D0D).withOpacity(0.7),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D0D0D).withOpacity(0.5),
                  const Color(0xFF0D0D0D).withOpacity(0.85),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return _fallbackBackground(key: key);
  }

  Widget _fallbackBackground({Key? key}) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1C1C1E),
            const Color(0xFF0D0D0D),
          ],
        ),
      ),
    );
  }

  IconData _getLoopIcon(LoopMode mode) {
    switch (mode) {
      case LoopMode.one:
        return Icons.repeat_one_rounded;
      case LoopMode.all:
        return Icons.repeat_rounded;
      case LoopMode.off:
      default:
        return Icons.repeat_rounded;
    }
  }
}
