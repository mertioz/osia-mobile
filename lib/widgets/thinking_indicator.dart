import 'package:flutter/material.dart';
import '../motion.dart';
import '../theme.dart';

/// Choreographed "sliding puzzle" thinking indicator.
///
/// A 2×2 grid holds three violet dots and one empty slot. Every cycle the
/// dot sitting clockwise-before the empty slot slides into it, so the dots
/// appear to rotate clockwise around the square one move at a time — at
/// rest they always form an L-shape (three corners of the square).
///
/// Rendered just below the last message while OSIA is thinking. Each slide
/// uses sine easing over ~600 ms per the OSIA design spec.
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Distance between two adjacent corners of the grid.
  static const double _cell = 13.0;

  /// Dot diameter.
  static const double _dotSize = 8.0;

  /// Corner offsets in clockwise order: TL, TR, BR, BL.
  static const List<Offset> _corners = [
    Offset(0, 0),
    Offset(_cell, 0),
    Offset(_cell, _cell),
    Offset(0, _cell),
  ];

  /// Current corner index of each of the three dots.
  /// Initial L-shape: top-left, top-right, bottom-left (empty at bottom-right).
  final List<int> _dotCorners = [0, 1, 3];
  int _emptyCorner = 2;

  /// Index (into [_dotCorners]) of the dot sliding during this cycle.
  int _movingDot = 0;

  /// Slide motion: sine-eased, finishing slightly before the cycle ends so
  /// each move reads as a deliberate, choreographed step.
  late final Animation<double> _slide;

  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MotionDurations.thinking,
    );
    _slide = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: MotionCurves.thinkingSlide),
    );
    _pickNextMove();
    _controller.addStatusListener(_onCycleComplete);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-sync on every dependency change so a runtime reduced-motion toggle is
    // honored. Under reduced motion the loop is held on the static L-shape;
    // otherwise it (re)starts the sliding-puzzle cycle.
    _reduced = Motion.reduced(context);
    if (_reduced) {
      _controller.stop();
      _controller.value = 0; // clean static L-shape (dots parked on corners)
    } else if (!_controller.isAnimating) {
      _controller.forward();
    }
  }

  void _onCycleComplete(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    // Stop re-arming the loop once reduced motion is on.
    if (_reduced) return;
    setState(() {
      // Commit the move: the sliding dot now occupies the empty corner and
      // leaves its previous corner empty.
      final from = _dotCorners[_movingDot];
      _dotCorners[_movingDot] = _emptyCorner;
      _emptyCorner = from;
      _pickNextMove();
    });
    _controller.forward(from: 0);
  }

  /// The dot that slides next is the one at the clockwise-previous corner
  /// of the empty slot — moving it into the empty slot reads as clockwise
  /// rotation of the whole formation.
  void _pickNextMove() {
    final source = (_emptyCorner + 3) % 4;
    _movingDot = _dotCorners.indexOf(source);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final color = palette.thinking;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: _cell + _dotSize,
          height: _cell + _dotSize,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _slide.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < _dotCorners.length; i++)
                    Positioned(
                      left: _dotOffset(i, t).dx,
                      top: _dotOffset(i, t).dy,
                      child: _Dot(
                        color: color,
                        // The moving dot glows brighter mid-slide.
                        glow: i == _movingDot
                            ? 0.35 + 0.45 * (1 - (2 * t - 1).abs())
                            : 0.35,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Current position of dot [i]: parked on its corner, or interpolated
  /// toward the empty corner if it's the one sliding this cycle.
  Offset _dotOffset(int i, double t) {
    final from = _corners[_dotCorners[i]];
    if (i != _movingDot) return from;
    final to = _corners[_emptyCorner];
    return Offset.lerp(from, to, t)!;
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double glow;
  const _Dot({required this.color, required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _ThinkingIndicatorState._dotSize,
      height: _ThinkingIndicatorState._dotSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: glow),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }
}
