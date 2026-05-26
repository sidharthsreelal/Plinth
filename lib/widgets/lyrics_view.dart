import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────
//  LRC line model
// ─────────────────────────────────────────────────────────────
class _LrcLine {
  final Duration timestamp;
  final String text;
  const _LrcLine(this.timestamp, this.text);
}

// ─────────────────────────────────────────────────────────────
//  LRC parser
// ─────────────────────────────────────────────────────────────
/// Returns a sorted list of timed lines, or null if no timestamps found.
List<_LrcLine>? _parseLrc(String raw) {
  final tsPattern = RegExp(r'\[(\d{1,2}):(\d{2})[.:](\d{1,3})\]');
  final lines = <_LrcLine>[];

  for (final rawLine in raw.split('\n')) {
    final matches = tsPattern.allMatches(rawLine);
    if (matches.isEmpty) continue;

    final text = rawLine.substring(matches.last.end).trim();
    if (text.isEmpty) continue;

    for (final m in matches) {
      final min  = int.parse(m.group(1)!);
      final sec  = int.parse(m.group(2)!);
      final raw3 = m.group(3)!.padRight(3, '0').substring(0, 3);
      final ms   = int.parse(raw3);
      lines.add(_LrcLine(
        Duration(minutes: min, seconds: sec, milliseconds: ms),
        text,
      ));
    }
  }

  if (lines.isEmpty) return null;
  lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return lines;
}

// ─────────────────────────────────────────────────────────────
//  LyricsView
// ─────────────────────────────────────────────────────────────
class LyricsView extends StatefulWidget {
  final String? lyrics;
  final Color accent;
  final double size;

  /// Current playback position — updated every tick from positionStream.
  final Duration position;

  const LyricsView({
    super.key,
    required this.lyrics,
    required this.accent,
    required this.position,
    this.size = 280,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scroll = ScrollController();

  List<_LrcLine>? _lines;
  int _activeIndex = -1;

  // ── User-scroll detection ───────────────────────────────────
  // We track whether the user is manually scrolling with a flag that is set
  // via NotificationListener<ScrollNotification>. Programmatic scrolls are
  // wrapped in a flag so they don't trigger the cooldown.
  bool _userScrolling = false;
  DateTime? _lastUserScroll;
  bool _programmaticScrolling = false; // prevents our own animateTo from tripping the cooldown

  // Fixed item height so scroll math is always exact.
  static const double _itemH = 52.0;
  static const Duration _cooldown = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(LyricsView old) {
    super.didUpdateWidget(old);
    if (old.lyrics != widget.lyrics) {
      _parse();
      return;
    }
    if (widget.position != old.position) {
      _tick();
    }
  }

  void _parse() {
    _lines = widget.lyrics != null ? _parseLrc(widget.lyrics!) : null;
    _activeIndex = -1;
    _userScrolling = false;
    _lastUserScroll = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
    // Delay initial tick so position is read after parse.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  /// Called whenever a scroll notification fires. We only set _userScrolling
  /// if the event was NOT caused by our own programmatic scrolls.
  void _onScrollNotification(ScrollNotification n) {
    if (_programmaticScrolling) return;
    if (n is UserScrollNotification) return; // handled below
    if (n is ScrollUpdateNotification && n.dragDetails != null) {
      // Only real drag-driven updates count as user scroll
      _lastUserScroll = DateTime.now();
      if (!_userScrolling) setState(() => _userScrolling = true);
    }
  }

  void _onUserScroll(ScrollDirection direction) {
    if (_programmaticScrolling) return;
    if (direction != ScrollDirection.idle) {
      _lastUserScroll = DateTime.now();
      if (!_userScrolling) setState(() => _userScrolling = true);
    }
  }

  void _tick() {
    final lines = _lines;
    if (lines == null || lines.isEmpty) return;

    // Find the last line whose timestamp ≤ current position.
    // Start at -1: if no line qualifies yet, we show nothing highlighted
    // (avoids showing line 0 before its timestamp).
    int idx = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].timestamp <= widget.position) {
        idx = i;
      } else {
        break;
      }
    }

    // Check if user-scroll cooldown has elapsed.
    if (_userScrolling && _lastUserScroll != null) {
      if (DateTime.now().difference(_lastUserScroll!) >= _cooldown) {
        setState(() => _userScrolling = false);
      }
    }

    if (idx != _activeIndex) {
      setState(() => _activeIndex = idx);
      // Auto-scroll whenever we have a valid active line and user isn't overriding
      if (!_userScrolling && idx >= 0) {
        _scrollTo(idx);
      }
    }
  }

  /// Scroll so that item [index] is centred in the viewport.
  ///
  /// With symmetric padding = size/2 − itemH/2, item i's centre is at:
  ///   padding + i × itemH + itemH/2 = (size/2 − itemH/2) + i × itemH + itemH/2 = size/2 + i × itemH
  ///
  /// We want that centre to sit at scroll + size/2, so:
  ///   scroll = i × itemH
  void _scrollTo(int index) {
    if (!_scroll.hasClients) return;
    final target = (index * _itemH)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _programmaticScrolling = true;
    _scroll
        .animateTo(
          target,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        )
        .whenComplete(() => _programmaticScrolling = false);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLyrics = widget.lyrics != null && widget.lyrics!.trim().isNotEmpty;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: hasLyrics
          ? (_lines != null ? _buildLrc() : _buildPlain())
          : _buildNoLyrics(),
    );
  }

  // ── LRC synced ───────────────────────────────────────────────
  Widget _buildLrc() {
    final lines = _lines!;
    final pad = widget.size / 2 - _itemH / 2;

    return Container(
      decoration: _box(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            _onScrollNotification(n);
            return false; // don't absorb
          },
          child: NotificationListener<UserScrollNotification>(
            onNotification: (n) {
              _onUserScroll(n.direction);
              return false;
            },
            child: ShaderMask(
              shaderCallback: (b) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent
                ],
                stops: const [0.0, 0.12, 0.88, 1.0],
              ).createShader(b),
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: _scroll,
                itemCount: lines.length,
                itemExtent: _itemH,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: pad),
                physics: const BouncingScrollPhysics(),
                itemBuilder: (ctx, i) {
                  final isActive = i == _activeIndex;
                  final dist = _activeIndex < 0
                      ? i + 1
                      : (i - _activeIndex).abs();

                  final double opacity = _userScrolling
                      ? 0.60
                      : isActive
                          ? 1.0
                          : dist == 1
                              ? 0.55
                              : dist == 2
                                  ? 0.32
                                  : dist == 3
                                      ? 0.18
                                      : 0.08;

                  final double fontSize =
                      isActive && !_userScrolling ? 15.5 : 13.5;
                  final FontWeight fw = isActive && !_userScrolling
                      ? FontWeight.w700
                      : FontWeight.w400;

                  return AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(opacity),
                      fontSize: fontSize,
                      fontWeight: fw,
                      height: 1.35,
                    ),
                    child: SizedBox(
                      height: _itemH,
                      child: Center(
                        child: Text(
                          lines[i].text,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Plain text ───────────────────────────────────────────────
  Widget _buildPlain() {
    return Container(
      decoration: _box(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: ShaderMask(
          shaderCallback: (b) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent
            ],
            stops: const [0.0, 0.07, 0.93, 1.0],
          ).createShader(b),
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            physics: const BouncingScrollPhysics(),
            child: Text(
              widget.lyrics!,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14.0,
                height: 1.9,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // ── No-lyrics placeholder ────────────────────────────────────
  Widget _buildNoLyrics() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_rounded,
                color: Colors.white.withOpacity(0.18), size: 52),
            const SizedBox(height: 14),
            Text('No lyrics available',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(height: 6),
            Text('This track has no embedded lyrics.',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.18),
                  fontSize: 12.5,
                )),
          ],
        ),
      ),
    );
  }

  BoxDecoration _box() => BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: widget.accent.withOpacity(0.18)),
      );
}
