import 'package:flutter/material.dart';

/// Shared page transition: a smooth slide-up + fade, used for every route
/// in the app so navigation has one consistent rhythm (250 ms-class,
/// easeOutCubic — matching the rest of the UI's motion).
Route<T> slideFadeRoute<T>(Widget page, [RouteSettings? settings]) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
