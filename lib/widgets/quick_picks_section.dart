import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/providers/history_provider.dart';
import 'package:plinth/providers/player_provider.dart';
import 'package:plinth/providers/theme_provider.dart';
import 'package:plinth/screens/now_playing_screen.dart';

class QuickPicksSection extends StatelessWidget {
  const QuickPicksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<HistoryProvider, ThemeProvider>(
      builder: (context, history, themeProvider, _) {
        final picks = history.quickPicks;
        if (picks.isEmpty) return const SizedBox.shrink();

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
                    'Quick Picks',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 20,
                          letterSpacing: -0.3,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 172,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: picks.length,
                itemBuilder: (context, index) {
                  return _QuickPickCard(
                    track: picks[index],
                    accent: accent,
                    allPicks: picks,
                  );
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

class _QuickPickCard extends StatelessWidget {
  final AudioFile track;
  final Color accent;
  final List<AudioFile> allPicks;

  const _QuickPickCard({
    required this.track,
    required this.accent,
    required this.allPicks,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          context.read<PlayerProvider>().playTrack(track, allPicks);
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, _) => FadeTransition(
                opacity: animation,
                child: const NowPlayingScreen(),
              ),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        },
        child: SizedBox(
          width: 124,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Artwork card
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Art
                    SizedBox(
                      width: 124,
                      height: 124,
                      child: track.albumArt != null
                          ? Image.memory(
                              track.albumArt!,
                              width: 124,
                              height: 124,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _fallback(),
                            )
                          : _fallback(),
                    ),
                    // Subtle gradient overlay at bottom
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
                    // Play icon overlay
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
              // Title
              Text(
                track.title,
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
              // Artist
              Text(
                track.artist,
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

  Widget _fallback() {
    return Container(
      color: const Color(0xFF2C2C2E),
      child: const Icon(
        Icons.album_rounded,
        color: Color(0xFF48484A),
        size: 48,
      ),
    );
  }
}
