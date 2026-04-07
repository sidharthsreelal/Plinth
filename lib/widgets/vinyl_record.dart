import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plinth/providers/player_provider.dart';
import 'package:plinth/providers/theme_provider.dart';

class VinylRecord extends StatefulWidget {
  final Uint8List? albumArt;
  final bool isSpinning;
  final double size;

  const VinylRecord({
    super.key,
    this.albumArt,
    required this.isSpinning,
    this.size = 280,
  });

  @override
  State<VinylRecord> createState() => _VinylRecordState();
}

class _VinylRecordState extends State<VinylRecord> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  double _dragAngle = 0;
  bool _isDragging = false;
  double _lastAngle = 0;
  Duration _dragStartPosition = Duration.zero;
  double _dragVelocity = 0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.isSpinning) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(VinylRecord oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpinning != oldWidget.isSpinning && !_isDragging) {
      if (widget.isSpinning) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  double _getAngle(Offset center, Offset point) {
    return math.atan2(point.dy - center.dy, point.dx - center.dx);
  }

  void _onVinylDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragVelocity = 0;
    final center = Offset(widget.size / 2, widget.size / 2);
    _lastAngle = _getAngle(center, details.localPosition);
    _dragStartPosition = context.read<PlayerProvider>().player.position ?? Duration.zero;
    _rotationController.stop();
  }

  void _onVinylDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final center = Offset(widget.size / 2, widget.size / 2);
    final currentAngle = _getAngle(center, details.localPosition);
    double delta = currentAngle - _lastAngle;

    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    final player = context.read<PlayerProvider>();
    final duration = player.player.duration;
    if (duration != null && duration.inMilliseconds > 0) {
      final seekAmount = (_dragAngle / (2 * math.pi)) * duration.inMilliseconds * 0.5;
      int newPosition = _dragStartPosition.inMilliseconds + seekAmount.toInt();

      final limitMs = duration.inMilliseconds - 1000;
      if (newPosition < 0) {
        newPosition = 0;
        _dragAngle += delta;
        _dragVelocity = delta;
      } else if (newPosition > limitMs) {
        newPosition = limitMs;
      } else {
        _dragAngle += delta;
        _dragVelocity = delta;
      }

      final clampedPosition = Duration(milliseconds: newPosition);
      final currentPosition = player.player.position ?? Duration.zero;
      if ((clampedPosition - currentPosition).abs() > const Duration(milliseconds: 200)) {
        player.seekTo(clampedPosition);
      }
    } else {
      _dragVelocity = delta;
      _dragAngle += delta;
    }

    _lastAngle = currentAngle;
    setState(() {});
  }

  void _onVinylDragEnd(DragEndDetails details) {
    _isDragging = false;
    _dragAngle = 0;
    _dragVelocity = 0;
    final player = context.read<PlayerProvider>();
    final duration = player.player.duration;
    final position = player.player.position;
    if (duration != null && position != null) {
      final limitMs = duration.inMilliseconds - 1000;
      if (position.inMilliseconds < limitMs && player.isPlaying) {
        _rotationController.repeat();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, PlayerProvider>(
      builder: (context, themeProvider, playerProvider, child) {
        final accent = themeProvider.accentColor.color;
        final fftData = playerProvider.fftData;
        final isPlaying = playerProvider.isPlaying;
        final labelRadius = widget.size * 0.45;
        final glowSize = widget.size + 60;

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: glowSize,
              height: glowSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(isPlaying ? 0.3 : 0.08),
                    blurRadius: isPlaying ? 50 : 35,
                    spreadRadius: isPlaying ? 6 : 3,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
            ),
            Transform.rotate(
              angle: _isDragging ? _dragAngle : 0,
              child: RotationTransition(
                turns: _rotationController,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onPanStart: _onVinylDragStart,
                        onPanUpdate: _onVinylDragUpdate,
                        onPanEnd: _onVinylDragEnd,
                        child: CustomPaint(
                          size: Size(widget.size, widget.size),
                          painter: _VinylPainter(
                            isPlaying: isPlaying,
                            accent: accent,
                            fftData: fftData,
                            isDragging: _isDragging,
                          ),
                        ),
                      ),
                      ClipOval(
                        child: GestureDetector(
                          onTap: () => playerProvider.togglePlayPause(),
                          child: Container(
                            width: labelRadius,
                            height: labelRadius,
                            child: widget.albumArt != null && widget.albumArt!.isNotEmpty
                                ? Image.memory(
                                    widget.albumArt!,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _fallbackLabel(labelRadius, accent);
                                    },
                                  )
                                : _fallbackLabel(labelRadius, accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _fallbackLabel(double size, Color accent) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF1a1a1a),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: accent.withOpacity(0.5),
          size: size * 0.45,
        ),
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  final bool isPlaying;
  final Color accent;
  final List<double> fftData;
  final bool isDragging;

  _VinylPainter({
    required this.isPlaying,
    required this.accent,
    required this.fftData,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final vinylPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2a2a2a),
          const Color(0xFF1a1a1a),
          const Color(0xFF111111),
          const Color(0xFF1a1a1a),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, vinylPaint);

    for (int i = 0; i < 8; i++) {
      final grooveRadius = radius * (0.55 + (i * 0.05));
      final groovePaint = Paint()
        ..color = Colors.white.withOpacity(0.03 + (i % 2 == 0 ? 0.02 : -0.01))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(center, grooveRadius, groovePaint);
    }

    if (isPlaying && fftData.isNotEmpty && !isDragging) {
      _drawCircularVisualizer(canvas, center, radius);
    }
  }

  void _drawCircularVisualizer(Canvas canvas, Offset center, double vinylRadius) {
    final barCount = fftData.length;
    final angleStep = (2 * math.pi) / barCount;
    final innerRadius = vinylRadius + 2;
    final maxBarHeight = 22.0;

    for (int i = 0; i < barCount; i++) {
      final angle = i * angleStep - math.pi / 2;
      final normalizedHeight = (fftData[i] + 128) / 255;
      final height = normalizedHeight.clamp(0.0, 1.0) * maxBarHeight;

      final x1 = center.dx + math.cos(angle) * innerRadius;
      final y1 = center.dy + math.sin(angle) * innerRadius;
      final x2 = center.dx + math.cos(angle) * (innerRadius + height);
      final y2 = center.dy + math.sin(angle) * (innerRadius + height);

      final barPaint = Paint()
        ..color = accent.withOpacity(0.3 + normalizedHeight * 0.7)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VinylPainter oldDelegate) {
    return oldDelegate.isPlaying != isPlaying ||
        oldDelegate.accent != accent ||
        oldDelegate.fftData != fftData ||
        oldDelegate.isDragging != isDragging;
  }
}
