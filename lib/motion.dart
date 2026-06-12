import 'package:flutter/material.dart';

/// ── OSIA motion tokens ──────────────────────────────────────────────────
///
/// Single source of truth for the app's motion language. The feel is
/// "expressive": fast and classy, with a restrained light-bounce spring
/// (≈6.5% overshoot — visible, never childish). No widget should hardcode
/// `Duration` / `Curve` literals; everything pulls from here so every
/// surface — taps, routes, sheets, lists, banners, indicators — moves to one
/// coherent rhythm.
///
/// ⚠ IMPORTANT: [MotionCurves.spring] overshoots past 1.0. Only ever feed it
/// to TRANSFORMS (scale / slide / translate). NEVER to opacity
/// (`FadeTransition` / `AnimatedOpacity`) or any value asserted to stay within
/// `[0, 1]` — that throws at runtime. Use [MotionCurves.enter] for opacity.

/// Standard durations. Names describe intent, not just length, so call sites
/// read meaningfully and a future retune stays centralized.
abstract final class MotionDurations {
  /// Press-down feedback — under the ~100ms "instant" perceptual threshold.
  static const Duration tap = Duration(milliseconds: 90);

  /// Quick taps, press spring-back, small implicit tweaks.
  static const Duration fast = Duration(milliseconds: 150);

  /// The app's default in-content transition: switchers, sizes, highlights,
  /// the input bar's implicit animations.
  static const Duration medium = Duration(milliseconds: 240);

  /// Page / route forward transition.
  static const Duration route = Duration(milliseconds: 280);

  /// Page / route reverse (pop) — a touch quicker than forward.
  static const Duration routeReverse = Duration(milliseconds: 220);

  /// First-paint screen entrance (the connection screen hero).
  static const Duration entrance = Duration(milliseconds: 400);

  /// Choreographed thinking-indicator slide (per the OSIA design spec).
  static const Duration thinking = Duration(milliseconds: 600);

  /// Continuous "alive" loop — mic recording glow, mid-stream dots.
  static const Duration pulse = Duration(milliseconds: 1000);

  /// Slower continuous loop — the "connecting" status dot.
  static const Duration pulseSlow = Duration(milliseconds: 800);

  /// Blinking stream-cursor toggle period.
  static const Duration cursorBlink = Duration(milliseconds: 500);

  /// Per-item delay step for staggered list entrances.
  static const Duration stagger = Duration(milliseconds: 26);
}

/// Standard curves. The whole app shares this small set so motion never feels
/// like several apps stitched together.
abstract final class MotionCurves {
  /// OSIA's light-bounce spring — restrained ≈6.5% overshoot.
  /// TRANSFORMS ONLY (scale / slide); never opacity. See file header.
  static const Curve spring = Cubic(0.22, 0.88, 0.30, 1.22);

  /// Snappy deceleration, no overshoot — safe for opacity and any entrance
  /// that should not bounce.
  static const Curve enter = Curves.easeOutCubic;

  /// Acceleration for exits / dismissals.
  static const Curve exit = Curves.easeInCubic;

  /// Smooth symmetric easing for continuous loops (pulsing dots, glows).
  static const Curve loop = Curves.easeInOut;

  /// Sine in-out for the thinking indicator's deliberate sliding-puzzle step.
  static const Curve thinkingSlide = Curves.easeInOutSine;
}

/// Reduced-motion helpers. When the OS "remove animations" accessibility flag
/// is set ([MediaQuery.disableAnimations] / `accessibilityFeatures
/// .disableAnimations`), motion collapses to instant / minimal so the UI stays
/// usable for users who requested it.
abstract final class Motion {
  /// True when the user requested reduced motion (resolves against the nearest
  /// [MediaQuery], so it updates reactively).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Context-free variant for route construction, where no [BuildContext] is
  /// available yet.
  static bool get reducedGlobal =>
      WidgetsBinding.instance.accessibilityFeatures.disableAnimations;

  /// Collapse a duration to zero under reduced motion.
  static Duration duration(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;

  /// Flatten a curve to linear under reduced motion (also neutralizes any
  /// overshoot so reduced-motion users never see a bounce).
  static Curve curve(BuildContext context, Curve c) =>
      reduced(context) ? Curves.linear : c;
}

/// Wraps any tappable child with the app-wide tactile feedback: a quick
/// scale-down on press and a light-spring rebound (with a hair of overshoot)
/// on release. Keep the child's own `InkWell` / `onTap` inside — this adds
/// only the scale via a [Listener], which does NOT claim the gesture, so taps,
/// long-presses, ripples and drags still fire normally. Honors reduced motion
/// by rendering the child unscaled.
class PressableScale extends StatefulWidget {
  final Widget child;

  /// Scale at full press. 0.96 ≈ a 4% dip — felt, not seen.
  final double pressedScale;

  /// When false, the child is passed straight through with no scale feedback —
  /// but the widget keeps its identity (and its controller) across toggles, so
  /// callers can flip this on a disabled→enabled button without tearing the
  /// state down mid-press.
  final bool enabled;

  const PressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.96,
    this.enabled = true,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  // value: 0 = released (scale 1.0), 1 = fully pressed (scale pressedScale).
  // lowerBound is negative so the spring rebound can overshoot just past 1.0
  // for a light bounce before settling at the resting scale.
  late final AnimationController _c = AnimationController(
    vsync: this,
    lowerBound: -1.0,
    upperBound: 1.0,
    value: 0.0,
  );

  void _press() => _c.animateTo(
        1.0,
        duration: MotionDurations.tap,
        curve: MotionCurves.enter,
      );

  void _release() => _c.animateTo(
        0.0,
        duration: MotionDurations.fast,
        curve: MotionCurves.spring,
      );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Disabled, or reduced motion: no scale feedback — pass the child straight
    // through so taps still work, just without the squeeze. The State (and its
    // controller) survive, so re-enabling doesn't churn the element.
    if (!widget.enabled || Motion.reduced(context)) return widget.child;

    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final scale = 1.0 + _c.value * (widget.pressedScale - 1.0);
          return Transform.scale(scale: scale, child: child);
        },
      ),
    );
  }
}

/// One-shot entrance for list items: a small fade + upward slide with a light
/// spring, delayed by [index] so a freshly shown list cascades in instead of
/// snapping. Plays once on mount; honors reduced motion by appearing
/// instantly. The cascade is capped so long lists still finish quickly.
class StaggeredAppear extends StatefulWidget {
  final int index;
  final Widget child;

  const StaggeredAppear({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<StaggeredAppear> createState() => _StaggeredAppearState();
}

class _StaggeredAppearState extends State<StaggeredAppear>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: MotionDurations.medium,
  );
  bool _kicked = false;

  // Keep the entrance state alive when the item scrolls out of the list's
  // cache extent, so re-scrolling doesn't replay the fade/slide.
  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_kicked) return;
    _kicked = true;

    if (Motion.reduced(context)) {
      _c.value = 1.0; // appear instantly, no cascade
      return;
    }
    // Cap the cascade depth so a long list still settles quickly.
    final steps = widget.index.clamp(0, 8);
    final delay = MotionDurations.stagger * steps;
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    // Opacity rides [enter] (no overshoot — safe); the slide rides [spring].
    final fade = CurvedAnimation(parent: _c, curve: MotionCurves.enter);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: MotionCurves.spring));
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: widget.child),
    );
  }
}
