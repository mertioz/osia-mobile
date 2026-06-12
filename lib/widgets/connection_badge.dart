import 'package:flutter/material.dart';
import '../l10n.dart';
import '../motion.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';

/// A small status dot showing the WebSocket connection state.
///
/// Minimal: just a colored dot (green/yellow/red), no label, no chip.
/// Used next to the conversation title in the app bar.
class ConnectionBadge extends StatelessWidget {
  final ws.ConnectionState state;

  const ConnectionBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final (Color dotColor, String label) = switch (state) {
      ws.ConnectionState.connected =>
        (const Color(0xFF22C55E), strings.connected),
      ws.ConnectionState.connecting =>
        (const Color(0xFFEAB308), strings.connectingStatus),
      ws.ConnectionState.disconnected =>
        (palette.error, strings.disconnected),
    };

    return Tooltip(
      message: label,
      child: SizedBox(
        width: 14,
        height: 14,
        child: Center(
          child: state == ws.ConnectionState.connecting
              ? _PulsingDot(color: dotColor)
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: MotionDurations.pulseSlow,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-sync on every dependency change so a runtime reduced-motion toggle is
    // honored, not just the value at mount.
    if (Motion.reduced(context)) {
      _ctrl.stop();
      _ctrl.value = 1.0; // steady bright dot, no pulse
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // Ease the alpha ramp so the dot breathes instead of ticking linearly.
        final v = MotionCurves.loop.transform(_ctrl.value);
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.4 + v * 0.6),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
