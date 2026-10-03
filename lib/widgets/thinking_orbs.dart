import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../motion.dart';
import '../theme.dart';

class ThinkingOrbs extends StatefulWidget {
  const ThinkingOrbs({super.key, required this.active});

  static const int orbCount = 6;
  final bool active;

  @override
  State<ThinkingOrbs> createState() => _ThinkingOrbsState();
}

class _ThinkingOrbsState extends State<ThinkingOrbs>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  ScrollPosition? _scrollPosition;
  bool _onScreen = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (!identical(nextPosition, _scrollPosition)) {
      _scrollPosition?.removeListener(_refreshVisibility);
      _scrollPosition = nextPosition;
      _scrollPosition?.addListener(_refreshVisibility);
    }
    _scheduleVisibilityRefresh();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ThinkingOrbs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncAnimation();
  }

  void _scheduleVisibilityRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshVisibility();
    });
  }

  void _refreshVisibility() {
    final position = _scrollPosition;
    final renderObject = context.findRenderObject();
    var visible = true;
    if (position != null &&
        position.hasContentDimensions &&
        renderObject is RenderBox &&
        renderObject.attached) {
      try {
        final viewport = RenderAbstractViewport.of(renderObject);
        final leading = viewport.getOffsetToReveal(renderObject, 0).offset;
        visible =
            leading + renderObject.size.height > position.pixels &&
            leading < position.pixels + position.viewportDimension;
      } on FlutterError {
        visible = true;
      }
    }
    if (_onScreen != visible && mounted) {
      setState(() => _onScreen = visible);
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    if (!mounted) return;
    final foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final shouldAnimate =
        widget.active &&
        _onScreen &&
        foreground &&
        TickerMode.valuesOf(context).enabled &&
        !Motion.reduced(context);
    if (shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      if (_controller.value != 0) _controller.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_refreshVisibility);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = OsiaTheme.of(context).accent;
    final animate =
        widget.active &&
        _onScreen &&
        TickerMode.valuesOf(context).enabled &&
        !Motion.reduced(context);
    Widget paint(double phase) => RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey<String>('thinking_orbs_paint'),
        size: const Size(54, 20),
        painter: _ThinkingOrbsPainter(
          accent: accent,
          phase: phase,
          active: animate,
        ),
      ),
    );
    if (!animate) return SizedBox(width: 54, height: 20, child: paint(0));
    return SizedBox(
      width: 54,
      height: 20,
      child: AnimatedBuilder(
        key: const ValueKey<String>('thinking_orbs_animation'),
        animation: _controller,
        builder: (context, _) => paint(_controller.value),
      ),
    );
  }
}

class _ThinkingOrbsPainter extends CustomPainter {
  const _ThinkingOrbsPainter({
    required this.accent,
    required this.phase,
    required this.active,
  });

  final Color accent;
  final double phase;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    const speeds = <double>[0.82, 1.06, 1.19, 0.91, 1.13, 0.76];
    const offsets = <double>[0, 1.05, 2.20, 3.18, 4.17, 5.23];
    final points =
        <({double depth, Offset center, double radius, int index})>[];
    for (var index = 0; index < ThinkingOrbs.orbCount; index++) {
      if (!active) {
        final y = size.height / 2 + (index.isEven ? -0.7 : 0.7);
        points.add((
          depth: y,
          center: Offset(5 + index * 8.8, y),
          radius: 3.2,
          index: index,
        ));
        continue;
      }
      final angle = phase * math.pi * 2 * speeds[index] + offsets[index];
      final x = size.width / 2 + math.cos(angle) * 15.4;
      final y =
          size.height / 2 +
          math.sin(angle * 1.21 + offsets[index] * 0.23) * 3.7 +
          math.sin(angle * 0.57 + index) * 1.0;
      final radius = 2.7 + 0.8 * (0.5 + 0.5 * math.sin(angle * 0.83));
      points.add((
        depth: y + math.sin(angle) * 0.25,
        center: Offset(x, y),
        radius: radius,
        index: index,
      ));
    }
    points.sort((a, b) => a.depth.compareTo(b.depth));
    for (final point in points) {
      final opacity = (0.68 + (point.depth - size.height / 2) * 0.035).clamp(
        0.45,
        1.0,
      );
      final color = accent.withValues(alpha: opacity);
      final shaded = point.index % 3 == 1
          ? Color.lerp(color, Colors.white, 0.08)!
          : color;
      canvas.drawCircle(point.center, point.radius, Paint()..color = shaded);
    }
  }

  @override
  bool shouldRepaint(covariant _ThinkingOrbsPainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.phase != phase ||
      oldDelegate.active != active;
}
