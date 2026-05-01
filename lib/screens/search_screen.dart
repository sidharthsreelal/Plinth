import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/models/folder_node.dart';
import 'package:plinth/providers/library_provider.dart';
import 'package:plinth/providers/player_provider.dart';
import 'package:plinth/providers/theme_provider.dart';
import 'package:plinth/screens/now_playing_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<AudioFile> _search(FolderNode? root, String query) {
    if (root == null || query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    final results = <AudioFile>[];
    _collect(root, q, results);
    return results;
  }

  void _collect(FolderNode node, String q, List<AudioFile> out) {
    for (final audio in node.audioFiles) {
      if (audio.title.toLowerCase().contains(q) ||
          audio.artist.toLowerCase().contains(q) ||
          audio.album.toLowerCase().contains(q)) {
        out.add(audio);
      }
    }
    for (final sub in node.subFolders) {
      _collect(sub, q, out);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ThemeProvider>().accentColor.color;
    final library = context.watch<LibraryProvider>();
    final results = _search(library.rootFolder, _query);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  cursorColor: accent,
                  decoration: InputDecoration(
                    hintText: 'Songs, artists, albums…',
                    hintStyle: const TextStyle(color: Color(0xFF636366)),
                    border: InputBorder.none,
                    isDense: true,
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFF8E8E93), size: 20),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(context, results, accent),
    );
  }

  Widget _buildBody(
      BuildContext context, List<AudioFile> results, Color accent) {
    if (_query.trim().isEmpty) {
      return _buildEmptyPrompt();
    }

    if (results.isEmpty) {
      return _buildNoResults();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            '${results.length} result${results.length == 1 ? '' : 's'} · swipe right to queue',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Divider(color: Color(0xFF2C2C2E), height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final audio = results[index];
              return _SearchResultTile(
                audio: audio,
                accent: accent,
                query: _query,
                onTap: () {
                  context.read<PlayerProvider>().playTrack(audio, results);
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.search_rounded, size: 64, color: Color(0xFF2C2C2E)),
          SizedBox(height: 16),
          Text(
            'Search your library',
            style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 6),
          Text(
            'Title, artist or album',
            style: TextStyle(color: Color(0xFF636366), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 64, color: Color(0xFF2C2C2E)),
          const SizedBox(height: 16),
          Text(
            'No results for "$_query"',
            style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 16,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Individual result row with swipe-to-queue ────────────────────────────────

class _SearchResultTile extends StatefulWidget {
  final AudioFile audio;
  final Color accent;
  final String query;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.audio,
    required this.accent,
    required this.query,
    required this.onTap,
  });

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  double _dragX = 0;
  static const double _triggerThreshold = 72;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta == null) return;
    if (details.primaryDelta! < 0 && _dragX <= 0) return;
    setState(() {
      _dragX = (_dragX + details.primaryDelta!).clamp(0.0, 120.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragX >= _triggerThreshold) {
      final player = context.read<PlayerProvider>();
      final added = player.addToPlayNext(widget.audio);
      if (added) _showPlayNextBanner();
    }
    setState(() => _dragX = 0);
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
        backgroundColor: widget.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragX / _triggerThreshold).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Swipe reveal
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
                        widget.accent.withOpacity(0.8 * progress),
                        widget.accent.withOpacity(0),
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.audio.albumArt != null
                    ? Image.memory(widget.audio.albumArt!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallback())
                    : _fallback(),
              ),
              title: _highlight(context, widget.audio.title, widget.query,
                  isTitle: true),
              subtitle: _highlight(context,
                  '${widget.audio.artist} · ${widget.audio.album}', widget.query),
              onTap: widget.onTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlight(BuildContext context, String text, String query,
      {bool isTitle = false}) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isTitle ? Colors.white : const Color(0xFF8E8E93),
          fontSize: isTitle ? 14 : 12,
          fontWeight: isTitle ? FontWeight.w500 : FontWeight.normal,
        ),
      );
    }

    final lower = text.toLowerCase();
    final qLower = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lower.indexOf(qLower, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          color: widget.accent,
          fontWeight: FontWeight.w700,
        ),
      ));
      start = idx + query.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: isTitle ? Colors.white : const Color(0xFF8E8E93),
        fontSize: isTitle ? 14 : 12,
        fontWeight: isTitle ? FontWeight.w500 : FontWeight.normal,
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: 44,
      height: 44,
      color: const Color(0xFF2C2C2E),
      child: const Icon(Icons.music_note_rounded,
          color: Color(0xFF8E8E93), size: 22),
    );
  }
}
