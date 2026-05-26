import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// Four small violet dots that animate together in a synced bounce.
///
/// Rendered just below the last message while OSIA is thinking. The dots
/// share one [AnimationController] so they rise and fall in unison rather
/// than the classic staggered loader — gives it a calmer, more deliberate
/// rhythm.
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Synced bounce: all four dots ride the same sine wave with no
            // per-dot phase offset, so they bob together as a unit.
            final t = math.sin(_controller.value * 2 * math.pi);
            final lift = -3.5 * t.abs();
            final scale = 1.0 + 0.18 * t.abs();
            final glow = 0.45 + 0.35 * t.abs();
            return Transform.translate(
              offset: Offset(0, lift),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(scale: scale, glow: glow),
                  const SizedBox(width: 7),
                  _Dot(scale: scale, glow: glow),
                  const SizedBox(width: 7),
                  _Dot(scale: scale, glow: glow),
                  const SizedBox(width: 7),
                  _Dot(scale: scale, glow: glow),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double scale;
  final double glow;
  const _Dot({required this.scale, required this.glow});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: osiaThinking,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: osiaThinking.withValues(alpha: glow),
              blurRadius: 6,
              spreadRadius: 0.5,
            ),
          ],
        ),
      ),
    );
  }
}
