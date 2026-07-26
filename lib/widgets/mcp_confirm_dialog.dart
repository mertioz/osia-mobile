import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/websocket_service.dart' as ws;
import '../theme.dart';

/// Modal confirmation for a write MCP tool about to run (WOR-44 Phase 5).
///
/// Shown when the server sends an `mcp_confirm_request` on a mobile-initiated
/// turn and BLOCKS the agent until the client answers. The dialog only chooses
/// the verdict; the caller (the chat screen) owns sending exactly one
/// `mcp_confirm_response` based on the popped result:
///   - Approve → pops `true`
///   - Decline → pops `false`
///   - back button / tap-outside → `null` (the caller treats null as decline)
///
/// Decline is the safe default (and the visually-neutral button); Approve
/// carries the violet accent. The body shows the server, the tool, a short
/// write-warning, and a secret-free argument summary — never any argument
/// values. On-brand: #0d0b12-family surface, #c4b5f5 accent.
class McpConfirmDialog extends StatelessWidget {
  final ws.McpConfirmRequest request;
  const McpConfirmDialog({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final summary = request.summary.trim();
    final pcOnlyDeletion = request.isPcOnlyColossalDeletion;
    final nonApprovable = !request.canApprove;

    return AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 20, color: palette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pcOnlyDeletion
                  ? strings.colossalDeletionPcReviewTitle
                  : strings.mcpConfirmTitle(request.server, request.tool),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pcOnlyDeletion
                ? strings.colossalDeletionPcReviewBody
                : strings.mcpConfirmWriteWarning,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: palette.textMuted,
            ),
          ),
          if (pcOnlyDeletion) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                strings.colossalDeletionSafeCounts(
                  request.filesCount,
                  request.foldersCount,
                  request.totalBytes,
                  request.rootCount,
                ),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ] else if (summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              strings.mcpConfirmArgsLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                summary,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      actions: nonApprovable
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  strings.colossalDeletionClose,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]
          : [
              // Decline — the safe default. Plain/neutral so Approve is the only
              // emphasized action.
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  strings.mcpConfirmDecline,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Approve — accent, requires an explicit tap.
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.isDark
                      ? palette.background
                      : Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(strings.mcpConfirmApprove),
              ),
            ],
    );
  }
}
