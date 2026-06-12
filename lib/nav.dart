import 'package:flutter/material.dart';
import 'motion.dart';

/// Shared page transition: a slide-up + fade used for every route in the app
/// so navigation has one consistent rhythm. The slide rides the light-bounce
/// [MotionCurves.spring] for a touch of expressive overshoot; the fade rides
/// [MotionCurves.enter] (no overshoot — opacity must stay within [0, 1]).
/// Under reduced motion the transition collapses to an instant cut.
Route<T> slideFadeRoute<T>(Widget page, [RouteSettings? settings]) {
  // Resolved without a context (none exists at construction): if the user
  // asked for reduced motion, skip the transition entirely.
  final reduced = Motion.reducedGlobal;
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration:
        reduced ? Duration.zero : MotionDurations.route,
    reverseTransitionDuration:
        reduced ? Duration.zero : MotionDurations.routeReverse,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (context, animation, _, child) {
      // Re-check against the live MediaQuery so an in-flight setting change is
      // honored too; return the page unanimated when reduced.
      if (Motion.reduced(context)) return child;
      final slide = CurvedAnimation(
        parent: animation,
        curve: MotionCurves.spring,
        reverseCurve: MotionCurves.exit,
      );
      final fade = CurvedAnimation(
        parent: animation,
        curve: MotionCurves.enter,
        reverseCurve: MotionCurves.exit,
      );
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(slide),
          child: child,
        ),
      );
    },
  );
}
