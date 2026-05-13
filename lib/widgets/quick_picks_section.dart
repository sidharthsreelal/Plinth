import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/providers/history_provider.dart';
import 'package:plinth/providers/library_provider.dart';
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
        final accent = themeProvider.accentColor.color;

        // Show the section if we have picks OR if the library is loaded
        // (so the dice card is always accessible).
        final library = context.watch<LibraryProvider>();
        final hasLibrary = library.rootFolder != null;

        if (picks.isEmpty && !hasLibrary) return const SizedBox.shrink();

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
                // +1 for the dice card always at the front
                itemCount: picks.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _ShuffleDiceCard(accent: accent);
                  }
                  final track = picks[index - 1];
                  return _QuickPickCard(
                    track: track,
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

// ─────────────────────────────────────────────────────────────────────────────
//  Shuffle Dice Card
// ─────────────────────────────────────────────────────────────────────────────

class _ShuffleDiceCard extends StatefulWidget {
  final Color accent;
  const _ShuffleDiceCard({required this.accent});

  @override
  State<_ShuffleDiceCard> createState() => _ShuffleDiceCardState();
}

class _ShuffleDiceCardState extends State<_ShuffleDiceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -0.12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.12, end: -0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onTap() async {
    final library = context.read<LibraryProvider>();
    final player = context.read<PlayerProvider>();

    final allTracks = library.getAllTracks();
    if (allTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tracks found in library.')),
      );
      return;
    }

    // Shake animation first, then play
    _shakeCtrl.forward(from: 0);

    // Shuffle all tracks from every folder
    final shuffled = List<AudioFile>.from(allTracks)..shuffle(Random());
    final startTrack = shuffled.first;

    await Future.delayed(const Duration(milliseconds: 250));

    player.playTrack(startTrack, shuffled);

    if (!mounted) return;
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
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: _onTap,
        child: SizedBox(
          width: 124,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _shake.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _DiceFivePainter(accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Die face showing a 5 (quincunx pattern)
// ─────────────────────────────────────────────────────────────────────────────

class _DiceFivePainter extends CustomPainter {
  final Color color;
  const _DiceFivePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = size.width * 0.09;
    final pad = size.width * 0.22;

    // Die 5: corners + center
    final dots = [
      Offset(pad, pad),                         // top-left
      Offset(size.width - pad, pad),             // top-right
      Offset(size.width / 2, size.height / 2),  // center
      Offset(pad, size.height - pad),            // bottom-left
      Offset(size.width - pad, size.height - pad), // bottom-right
    ];

    for (final dot in dots) {
      canvas.drawCircle(dot, r, paint);
    }
  }

  @override
  bool shouldRepaint(_DiceFivePainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Regular quick-pick card
// ─────────────────────────────────────────────────────────────────────────────

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
