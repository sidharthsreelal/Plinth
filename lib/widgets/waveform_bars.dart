import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plinth/providers/theme_provider.dart';

class WaveformBars extends StatefulWidget {
  const WaveformBars({super.key});

  @override
  State<WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<WaveformBars> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(5, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + (i * 100)),
      )..repeat(reverse: true);
    });
    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final accent = themeProvider.accentColor.color;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(5, (i) {
            return AnimatedBuilder(
              animation: _animations[i],
              builder: (context, child) {
                return Container(
                  width: 3,
                  height: 16 * _animations[i].value,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              },
            );
          }),
        );
      },
    );
  }
}
