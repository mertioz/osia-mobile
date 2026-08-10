import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';

Future<void> showTransportStatusSheet(
  BuildContext context,
  ws.WebSocketService service,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _TransportStatusSheet(service: service),
  );
}

class _TransportStatusSheet extends StatelessWidget {
  const _TransportStatusSheet({required this.service});

  final ws.WebSocketService service;

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.border),
        ),
        child: StreamBuilder<ws.CommittedTransportState>(
          stream: service.committedTransportStream,
          initialData: service.committedTransportState,
          builder: (context, snapshot) {
            final state = snapshot.data ?? ws.CommittedTransportState.switching;
            final switching = state == ws.CommittedTransportState.switching;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  strings.activeTransportTitle,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: switching ? palette.warning : palette.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (switching ? palette.warning : palette.success)
                                    .withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        strings.transportStateText(state.name),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
