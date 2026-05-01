import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/providers/favourites_provider.dart';
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

  // Slider scrubbing state — keeps the slider position in sync immediately
  // during drag, without waiting for the position stream to respond.
  bool _sliderDragging = false;
  double _sliderValue = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer3<PlayerProvider, ThemeProvider, FavouritesProvider>(
      builder: (context, player, themeProvider, favourites, child) {
        final accent = themeProvider.accentColor.color;
        final track = player.currentTrack;
        if (track == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D0D0D),
            body: const Center(
              child: Text('No track playing',
                  style: TextStyle(color: Color(0xFF8E8E93))),
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
                      child: _buildBackground(track.albumArt,
                          key: ValueKey(track.path)),
                    ),
                    SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 32),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                // Placeholder keep row height consistent
                                const SizedBox(width: 48),
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              children: [
                                Text(
                                  track.title,
                                  style:
                                      Theme.of(context).textTheme.displayMedium,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  track.artist,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontSize: 16),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  track.album,
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              children: [
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 3,
                                    thumbShape:
                                        const RoundSliderThumbShape(
                                            enabledThumbRadius: 6),
                                    overlayShape:
                                        const RoundSliderOverlayShape(
                                            overlayRadius: 14),
                                    activeTrackColor: accent,
                                    inactiveTrackColor:
                                        const Color(0xFF2C2C2E),
                                    thumbColor: accent,
                                    overlayColor: accent.withOpacity(0.2),
                                  ),
                                  child: Builder(builder: (context) {
                                    final maxMs = duration.inMilliseconds > 0
                                        ? duration.inMilliseconds.toDouble()
                                        : 1.0;
                                    final currentVal = _sliderDragging
                                        ? _sliderValue
                                        : (duration.inMilliseconds > 0
                                            ? position.inMilliseconds
                                                .toDouble()
                                                .clamp(0.0, maxMs)
                                            : 0.0);
                                    return Slider(
                                      value: currentVal,
                                      max: maxMs,
                                      onChanged: (value) {
                                        setState(() {
                                          _sliderDragging = true;
                                          _sliderValue = value;
                                        });
                                      },
                                      onChangeEnd: (value) {
                                        player.seekTo(Duration(
                                            milliseconds: value.toInt()));
                                        setState(() {
                                          _sliderDragging = false;
                                        });
                                      },
                                    );
                                  }),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(
                                          _sliderDragging
                                              ? Duration(
                                                  milliseconds:
                                                      _sliderValue.toInt())
                                              : position,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      Text(
                                        _formatDuration(duration),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ── Primary controls row: shuffle | prev | play | next | heart
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Shuffle
                                IconButton(
                                  icon: Icon(
                                    Icons.shuffle_rounded,
                                    size: 26,
                                    color: player.shuffle
                                        ? accent
                                        : const Color(0xFF48484A),
                                  ),
                                  onPressed: () => player.toggleShuffle(),
                                ),
                                // Skip previous
                                IconButton(
                                  icon: const Icon(
                                      Icons.skip_previous_rounded, size: 40),
                                  onPressed: () => player.skipPrevious(),
                                  color: const Color(0xFFFFFFFF),
                                ),
                                // Play / Pause
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
                                    onPressed: () =>
                                        player.togglePlayPause(),
                                  ),
                                ),
                                // Skip next
                                IconButton(
                                  icon: const Icon(
                                      Icons.skip_next_rounded, size: 40),
                                  onPressed: () => player.skipNext(),
                                  color: const Color(0xFFFFFFFF),
                                ),
                                // Heart / favourite
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: IconButton(
                                    key: ValueKey(
                                        favourites.isFavourite(track)),
                                    icon: Icon(
                                      favourites.isFavourite(track)
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 26,
                                      color: favourites.isFavourite(track)
                                          ? accent
                                          : const Color(0xFF48484A),
                                    ),
                                    onPressed: () =>
                                        favourites.toggle(track),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // ── Secondary controls: repeat | sleep timer | queue
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Repeat / loop
                              IconButton(
                                icon: Icon(
                                  _getLoopIcon(player.loopMode),
                                  color: player.loopMode != LoopMode.off
                                      ? accent
                                      : const Color(0xFF48484A),
                                ),
                                onPressed: () => player.cycleLoopMode(),
                              ),
                              // Sleep timer
                              _SleepTimerButton(
                                player: player,
                                accent: accent,
                              ),
                              // Queue button with badge
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    tooltip: 'Up next',
                                    icon: const Icon(
                                        Icons.queue_music_rounded),
                                    color: const Color(0xFF48484A),
                                    onPressed: () => _showQueueSheet(
                                        context, player, accent),
                                  ),
                                  if (player.playNextQueue.isNotEmpty)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
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

  // ─────────────────────────── Queue sheet ────────────────────────────

  void _showQueueSheet(
      BuildContext context, PlayerProvider player, Color accent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _QueueSheet(accent: accent);
      },
    );
  }

  // ─────────────────────────── Helpers ────────────────────────────────

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '0:00';
    final minutes = duration.inMinutes;
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');
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
            errorBuilder: (context, error, stackTrace) =>
                _fallbackBackground(),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C1C1E), Color(0xFF0D0D0D)],
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

// ══════════════════════════════════════════════════════════════════════
//  Queue Sheet — single unified reorderable, dismissible list
// ══════════════════════════════════════════════════════════════════════

class _QueueSheet extends StatelessWidget {
  final Color accent;

  const _QueueSheet({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final playNextItems = List<AudioFile>.from(player.playNextQueue);
        final mainQueue = player.queue;
        final currentIdx = player.currentIndex;
        final upcomingMain = currentIdx + 1 < mainQueue.length
            ? mainQueue.sublist(currentIdx + 1)
            : <AudioFile>[];

        // Unified list: play-next items first, then upcoming main-queue tracks.
        final unified = [...playNextItems, ...upcomingMain];

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF48484A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
                    child: Row(
                      children: [
                        Icon(Icons.queue_music_rounded,
                            color: accent, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Up Next',
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                        ),
                        const Spacer(),
                        if (unified.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              player.clearPlayNext();
                              // Also clear all upcoming from main queue.
                              for (int i = upcomingMain.length - 1;
                                  i >= 0;
                                  i--) {
                                player.removeFromUpcoming(i);
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF8E8E93),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                            ),
                            child: const Text('Clear all'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(
                      color: Color(0xFF2C2C2E), height: 1, thickness: 1),
                  // Unified list
                  Expanded(
                    child: unified.isEmpty
                        ? _buildEmptyState()
                        : ReorderableListView.builder(
                            scrollController: scrollController,
                            padding: const EdgeInsets.only(
                                bottom: 24, top: 4),
                            itemCount: unified.length,
                            onReorder: (oldIndex, newIndex) =>
                                _onReorder(player, oldIndex, newIndex,
                                    playNextItems.length,
                                    upcomingMain.length),
                            proxyDecorator: (child, index, animation) =>
                                Material(
                                    color: Colors.transparent,
                                    child: child),
                            itemBuilder: (context, index) {
                              final track = unified[index];
                              return _buildQueueRow(
                                context,
                                key: ValueKey(
                                    'q_${track.path}_$index'),
                                track: track,
                                onRemove: () => _onRemove(
                                    player,
                                    index,
                                    playNextItems.length),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Handles reorder across the play-next / main-queue boundary.
  void _onReorder(
    PlayerProvider player,
    int oldIndex,
    int newIndex,
    int playNextCount,
    int upcomingCount,
  ) {
    final bool fromPlayNext = oldIndex < playNextCount;

    // Moving across or within buckets.
    if (fromPlayNext) {
      if (newIndex <= playNextCount) {
        // Within Play-Next
        player.reorderPlayNext(oldIndex, newIndex);
      } else {
        // Play-Next to Main Queue
        final track = player.playNextQueue[oldIndex];
        player.removeFromPlayNext(oldIndex);
        // Correct target index in main queue: (newIndex - playNextCount)
        // Since we removed 1 from playNextCount, the normalization happens naturally.
        final targetInMain = newIndex - playNextCount;
        final base = player.currentIndex + 1;
        player.queue.insert(
            (base + targetInMain).clamp(base, player.queue.length), track);
        player.notifyListenersPublic();
      }
    } else {
      final mainIdx = oldIndex - playNextCount;
      if (newIndex >= playNextCount) {
        // Within Main Queue
        player.reorderUpcoming(mainIdx, newIndex - playNextCount);
      } else {
        // Main Queue to Play-Next
        final mainSeq = player.queue;
        final base = player.currentIndex + 1;
        if (base + mainIdx < mainSeq.length) {
          final track = mainSeq[base + mainIdx];
          player.removeFromUpcoming(mainIdx);
          player.insertIntoPlayNext(newIndex, track);
        }
      }
    }
  }


  /// Removes from the correct bucket based on index.
  void _onRemove(
      PlayerProvider player, int index, int playNextCount) {
    if (index < playNextCount) {
      player.removeFromPlayNext(index);
    } else {
      player.removeFromUpcoming(index - playNextCount);
    }
  }

  Widget _buildQueueRow(
    BuildContext context, {
    required Key key,
    required AudioFile track,
    required VoidCallback onRemove,
  }) {
    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFF3A1C1C),
        child: const Icon(Icons.delete_outline_rounded,
            color: Color(0xFFFF453A)),
      ),
      child: ListTile(
        key: ValueKey('qtile_${track.path}'),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: track.albumArt != null
              ? Image.memory(track.albumArt!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallback())
              : _fallback(),
        ),
        title: Text(
          track.title,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          track.artist,
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.drag_handle_rounded,
            color: Color(0xFF48484A), size: 20),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.queue_music_rounded,
              size: 64, color: Color(0xFF48484A)),
          SizedBox(height: 16),
          Text(
            'Queue is empty',
            style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Swipe right on any song to add it next.',
            style: TextStyle(color: Color(0xFF636366), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: 36,
      height: 36,
      color: const Color(0xFF2C2C2E),
      child: const Icon(Icons.music_note_rounded,
          color: Color(0xFF8E8E93), size: 20),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  Sleep Timer Button
// ══════════════════════════════════════════════════════════════════════

class _SleepTimerButton extends StatelessWidget {
  final PlayerProvider player;
  final Color accent;

  const _SleepTimerButton({required this.player, required this.accent});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final active = player.sleepTimerActive;
    final remaining = player.sleepRemaining;

    return GestureDetector(
      onTap: () => _showPicker(context),
      onLongPress: active ? () => player.cancelSleepTimer() : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bedtime_rounded,
            color: active ? accent : const Color(0xFF48484A),
            size: 26,
          ),
          if (active && remaining != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _fmt(remaining),
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final presets = [
      const Duration(minutes: 5),
      const Duration(minutes: 10),
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(minutes: 45),
      const Duration(minutes: 60),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF48484A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.bedtime_rounded, color: accent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Sleep Timer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (player.sleepTimerActive)
                      TextButton(
                        onPressed: () {
                          player.cancelSleepTimer();
                          Navigator.pop(ctx);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF453A),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                        ),
                        child: const Text('Cancel'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(
                  color: Color(0xFF2C2C2E), height: 1, thickness: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: presets.map((dur) {
                    final label = dur.inMinutes < 60
                        ? '${dur.inMinutes} min'
                        : '${dur.inHours} hr';
                    final isActive = player.sleepTimerActive &&
                        player.sleepRemaining != null &&
                        (player.sleepRemaining!.inMinutes == dur.inMinutes ||
                            player.sleepRemaining!.inMinutes ==
                                dur.inMinutes - 1);
                    return GestureDetector(
                      onTap: () {
                        player.startSleepTimer(dur);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              isActive ? accent.withOpacity(0.15) : const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(20),
                          border: isActive
                              ? Border.all(color: accent, width: 1)
                              : null,
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isActive ? accent : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

