import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/providers/theme_provider.dart';
import 'package:plinth/widgets/waveform_bars.dart';

class AudioTile extends StatelessWidget {
  final AudioFile audio;
  final VoidCallback onTap;
  final bool isPlaying;
  final bool isCurrentTrack;

  const AudioTile({
    super.key,
    required this.audio,
    required this.onTap,
    this.isPlaying = false,
    this.isCurrentTrack = false,
  });

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final accent = themeProvider.accentColor.color;
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: audio.albumArt != null
                ? Image.memory(
                    audio.albumArt!,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _fallbackIcon();
                    },
                  )
                : _fallbackIcon(),
          ),
          title: Text(
            audio.title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isCurrentTrack ? accent : const Color(0xFFFFFFFF),
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            audio.artist,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isPlaying && isCurrentTrack
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: WaveformBars(),
                )
              : Text(
                  _formatDuration(audio.duration),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
          onTap: onTap,
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
