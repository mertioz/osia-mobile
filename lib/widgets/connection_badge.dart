import 'package:flutter/material.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';

/// A small badge showing the WebSocket connection status.
///
/// Displays a colored dot with a label:
/// - Green dot + "Connecté" when connected
/// - Yellow dot + "Connexion..." when connecting
/// - Red dot + "Déconnecté" when disconnected
class ConnectionBadge extends StatelessWidget {
  final ws.ConnectionState state;

  const ConnectionBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (Color dotColor, String label) = switch (state) {
      ws.ConnectionState.connected => (const Color(0xFF22C55E), 'Connecté'),
      ws.ConnectionState.connecting => (const Color(0xFFEAB308), 'Connexion…'),
      ws.ConnectionState.disconnected => (const Color(0xFFEF4444), 'Déconnecté'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: osiaSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: osiaBorder, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing dot for connecting state
          if (state == ws.ConnectionState.connecting)
            _PulsingDot(color: dotColor)
          else
            Container(
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
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: dotColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
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
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.4 + _ctrl.value * 0.6),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
