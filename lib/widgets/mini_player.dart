import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plinth/providers/player_provider.dart';
import 'package:plinth/providers/theme_provider.dart';
import 'package:plinth/screens/now_playing_screen.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final player = context.read<PlayerProvider>();
      player.positionStream.listen((pos) {
        if (pos != null && !_isDragging) {
          setState(() => _position = pos);
        }
      });
      player.durationStream.listen((dur) {
        if (dur != null) {
          setState(() => _duration = dur);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerProvider, ThemeProvider>(
      builder: (context, player, themeProvider, child) {
        final accent = themeProvider.accentColor.color;
        final track = player.currentTrack;
        if (track == null) return const SizedBox.shrink();

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: ModalRoute.of(context)?.animation ?? AlwaysStoppedAnimation(1.0),
            curve: Curves.easeOutCubic,
          )),
          child: GestureDetector(
            onTap: () => _openNowPlaying(context),
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < -300) {
                  player.skipNext();
                } else if (details.primaryVelocity! > 300) {
                  player.skipPrevious();
                }
              }
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
                _openNowPlaying(context);
              }
            },
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E).withOpacity(0.85),
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFF2C2C2E).withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: track.albumArt != null
                                    ? Image.memory(
                                        track.albumArt!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return _fallbackAlbumArt();
                                        },
                                      )
                                    : _fallbackAlbumArt(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            fontSize: 14,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      track.artist,
                                      style: Theme.of(context).textTheme.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  player.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: accent,
                                ),
                                onPressed: () => player.togglePlayPause(),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.skip_next_rounded,
                                  color: const Color(0xFFFFFFFF),
                                ),
                                onPressed: () => player.skipNext(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 3,
                        child: GestureDetector(
                          onHorizontalDragStart: (details) {
                            setState(() => _isDragging = true);
                          },
                          onHorizontalDragUpdate: (details) {
                            final box = context.findRenderObject() as RenderBox?;
                            if (box != null && _duration.inMilliseconds > 0) {
                              final dx = details.localPosition.dx;
                              final width = box.size.width;
                              final fraction = (dx / width).clamp(0.0, 1.0);
                              setState(() {
                                _position = Duration(
                                  milliseconds: (fraction * _duration.inMilliseconds).toInt(),
                                );
                              });
                            }
                          },
                          onHorizontalDragEnd: (details) {
                            setState(() => _isDragging = false);
                            final box = context.findRenderObject() as RenderBox?;
                            if (box != null && _duration.inMilliseconds > 0) {
                              final dx = details.localPosition.dx;
                              final width = box.size.width;
                              final fraction = (dx / width).clamp(0.0, 1.0);
                              player.seekTo(Duration(
                                milliseconds: (fraction * _duration.inMilliseconds).toInt(),
                              ));
                            }
                          },
                          child: LinearProgressIndicator(
                            value: _duration.inMilliseconds > 0
                                ? _position.inMilliseconds / _duration.inMilliseconds
                                : 0,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(accent.withOpacity(0.6)),
                            minHeight: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static void _openNowPlaying(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: const NowPlayingScreen(),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  Widget _fallbackAlbumArt() {
    return Container(
      width: 40,
      height: 40,
      color: const Color(0xFF2C2C2E),
      child: const Icon(
        Icons.music_note_rounded,
        color: Color(0xFF8E8E93),
        size: 24,
      ),
    );
  }
}
