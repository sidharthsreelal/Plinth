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

class _VinylRecordState extends State<VinylRecord>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  // The accumulated angle offset from all drags so far.
  double _baseAngle = 0;
  // The additional angle being added by the current ongoing drag.
  double _draggingDelta = 0;
  bool _isDragging = false;
  double _lastDragAngle = 0;

  // Seek tracking during drag.
  Duration _dragStartPosition = Duration.zero;
  double _dragStartAngle = 0; // value of _baseAngle when drag started

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
    final center = Offset(widget.size / 2, widget.size / 2);
    _lastDragAngle = _getAngle(center, details.localPosition);
    _dragStartAngle = _baseAngle;
    _draggingDelta = 0;
    _dragStartPosition =
        context.read<PlayerProvider>().player.position ?? Duration.zero;

    // Freeze at the current visual angle. We compute how far through one
    // full rotation the controller is and bake that into _baseAngle so the
    // record doesn't jump.
    final controllerFraction = _rotationController.value; // 0..1
    _baseAngle += controllerFraction * 2 * math.pi;
    _rotationController.stop();
    // Reset controller to 0 so it can resume cleanly from 0 later.
    _rotationController.value = 0;
    setState(() {});
  }

  void _onVinylDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final center = Offset(widget.size / 2, widget.size / 2);
    final currentAngle = _getAngle(center, details.localPosition);
    double delta = currentAngle - _lastDragAngle;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    _draggingDelta += delta;
    _lastDragAngle = currentAngle;

    // Compute seek position from drag angle relative to drag start.
    final player = context.read<PlayerProvider>();
    final duration = player.player.duration;
    if (duration != null && duration.inMilliseconds > 0) {
      final totalAngle = _draggingDelta;
      final seekAmount =
          (totalAngle / (2 * math.pi)) * duration.inMilliseconds * 0.5;
      int newMs = _dragStartPosition.inMilliseconds + seekAmount.toInt();
      newMs = newMs.clamp(0, duration.inMilliseconds - 1000);
      player.seekTo(Duration(milliseconds: newMs));
    }

    setState(() {});
  }

  void _onVinylDragEnd(DragEndDetails details) {
    _isDragging = false;
    // Permanently apply the drag delta to the base angle.
    _baseAngle = _dragStartAngle + _draggingDelta;
    _draggingDelta = 0;

    final player = context.read<PlayerProvider>();
    final duration = player.player.duration;
    final position = player.player.position;
    if (duration != null &&
        position != null &&
        position.inMilliseconds < duration.inMilliseconds - 1000 &&
        player.isPlaying) {
      _rotationController.repeat();
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

        // Total visual rotation = base angle + current drag delta +
        //   controller loop progress.
        // We put base + drag delta into a Transform.rotate and let
        // RotationTransition handle the looping on top.
        final staticAngle = _baseAngle + _draggingDelta;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Glow halo
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
            // Static rotation layer (survives across drag gestures)
            Transform.rotate(
              angle: staticAngle,
              child: RotationTransition(
                turns: _rotationController,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
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
                          child: SizedBox(
                            width: labelRadius,
                            height: labelRadius,
                            child:
                                widget.albumArt != null &&
                                        widget.albumArt!.isNotEmpty
                                    ? Image.memory(
                                        widget.albumArt!,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return _fallbackLabel(
                                              labelRadius, accent);
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
        ..color =
            Colors.white.withOpacity(0.03 + (i % 2 == 0 ? 0.02 : -0.01))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(center, grooveRadius, groovePaint);
    }

    if ((isPlaying || isDragging) && fftData.isNotEmpty) {
      _drawCircularVisualizer(canvas, center, radius);
    }
  }

  void _drawCircularVisualizer(
      Canvas canvas, Offset center, double vinylRadius) {
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
