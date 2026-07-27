import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'l10n.dart';
import 'services/websocket_service.dart' as ws;
import 'theme.dart';

class PermissionsSettingsSection extends StatefulWidget {
  const PermissionsSettingsSection({super.key, required this.wsService});

  final ws.WebSocketService wsService;

  @override
  State<PermissionsSettingsSection> createState() =>
      _PermissionsSettingsSectionState();
}

class _PermissionsSettingsSectionState
    extends State<PermissionsSettingsSection> {
  StreamSubscription<ws.PermissionSnapshot>? _snapshotSub;
  StreamSubscription<ws.PermissionRevocationAck>? _ackSub;
  StreamSubscription<ws.ConnectionState>? _connectionSub;
  ws.PermissionSnapshot? _snapshot;
  late ws.ConnectionState _connectionState;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.wsService.permissionSnapshot;
    _connectionState = widget.wsService.state;
    _snapshotSub = widget.wsService.permissionSnapshotStream.listen((snapshot) {
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
    });
    _ackSub = widget.wsService.permissionRevocationAckStream.listen((ack) {
      if (!mounted) return;
      setState(() {});
      final strings = OsiaL10n.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ack.succeeded
                ? strings.permissionApplied
                : strings.permissionRejected,
          ),
        ),
      );
    });
    _connectionSub = widget.wsService.connectionStream.listen((state) {
      if (!mounted) return;
      setState(() => _connectionState = state);
      if (state == ws.ConnectionState.connected) {
        widget.wsService.requestPermissionSnapshot();
      }
    });
    if (_connectionState == ws.ConnectionState.connected) {
      widget.wsService.requestPermissionSnapshot();
    }
  }

  @override
  void dispose() {
    _snapshotSub?.cancel();
    _ackSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  bool get _live =>
      _connectionState == ws.ConnectionState.connected &&
      widget.wsService.permissionsLive &&
      _snapshot != null;

  bool get _hasPending =>
      widget.wsService.pendingPermissionRequestIds.isNotEmpty;

  void _submit(
    ws.PermissionRevocationOperation operation, {
    String targetId = '',
  }) {
    final requestId = widget.wsService.sendPermissionRevocation(
      operation,
      targetId: targetId,
    );
    if (requestId != null && mounted) setState(() {});
  }

  String _presetLabel(OsiaStrings strings, String preset) => switch (preset) {
    'full_access' => strings.permissionFullAccess,
    'mixed' => strings.permissionMixedAccess,
    _ => strings.permissionDefaultAccess,
  };

  String _permissionLifetime(
    OsiaStrings strings,
    ws.PermissionTemporaryItem item,
  ) {
    if (item.remainingUses != null) {
      return strings.permissionRemainingUses(item.remainingUses!);
    }
    if (item.expiresAt != null) {
      final remainingSeconds = max(
        0,
        item.expiresAt! - DateTime.now().millisecondsSinceEpoch / 1000.0,
      );
      return strings.permissionExpiresIn((remainingSeconds / 60).ceil());
    }
    return strings.permissionTemporary;
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final snapshot = _snapshot;
    final live = _live;
    final controlsEnabled =
        live && snapshot?.protectedStoreAvailable == true && !_hasPending;

    return Column(
      key: const Key('permissions-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.permissionsTitle.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.textMuted,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.permissionsSubtitle,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border, width: 0.6),
          ),
          padding: const EdgeInsets.all(16),
          child: snapshot == null
              ? _EmptyPermissionState(
                  connected: _connectionState == ws.ConnectionState.connected,
                  palette: palette,
                  strings: strings,
                  onRefresh: widget.wsService.requestPermissionSnapshot,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PermissionStatusCard(
                      preset: _presetLabel(strings, snapshot.preset),
                      live: live,
                      palette: palette,
                      strings: strings,
                      onRefresh: live
                          ? widget.wsService.requestPermissionSnapshot
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      strings.permissionPcEnableOnly,
                      key: const Key('full-access-pc-only'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final key in ws.permissionCategoryKeys)
                      _ReadOnlyPermissionRow(
                        key: Key('permission-category-$key'),
                        label: strings.permissionCategoryLabel(key),
                        active: snapshot.categories[key] == true,
                        palette: palette,
                        strings: strings,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      strings.permissionTemporary,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (snapshot.temporaryPermissions.isEmpty)
                      Text(
                        strings.permissionNoTemporary,
                        key: const Key('no-temporary-permissions'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.textMuted,
                        ),
                      )
                    else
                      for (final item in snapshot.temporaryPermissions)
                        _TemporaryPermissionRow(
                          key: Key('temporary-permission-${item.mobileItemId}'),
                          item: item,
                          lifetime: _permissionLifetime(strings, item),
                          enabled: controlsEnabled && item.revocable,
                          pending: widget.wsService.isPermissionItemPending(
                            item.mobileItemId,
                          ),
                          palette: palette,
                          strings: strings,
                          onRevoke: () => _submit(
                            ws
                                .PermissionRevocationOperation
                                .revokeTemporaryPermission,
                            targetId: item.mobileItemId,
                          ),
                          onRevokeContext: switch (item.context) {
                            'autonomous' => () => _submit(
                              ws
                                  .PermissionRevocationOperation
                                  .revokeAutonomousRun,
                              targetId: item.mobileItemId,
                            ),
                            'scheduled' => () => _submit(
                              ws
                                  .PermissionRevocationOperation
                                  .revokeScheduledTask,
                              targetId: item.mobileItemId,
                            ),
                            _ => null,
                          },
                        ),
                    if (!snapshot.protectedStoreAvailable) ...[
                      const SizedBox(height: 12),
                      Text(
                        strings.permissionChangesUnavailable,
                        key: const Key('permission-changes-unavailable'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                    if (_hasPending) ...[
                      const SizedBox(height: 12),
                      Row(
                        key: const Key('permission-pending'),
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: palette.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strings.permissionPending,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: palette.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      key: const Key('revoke-all-delegated-access'),
                      onPressed: controlsEnabled
                          ? () => _submit(
                              ws
                                  .PermissionRevocationOperation
                                  .revokeAllDelegatedAuthority,
                            )
                          : null,
                      icon: const Icon(Icons.link_off_rounded, size: 17),
                      label: Text(strings.permissionRevokeAll),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.error,
                        side: BorderSide(
                          color: controlsEnabled
                              ? palette.error.withValues(alpha: 0.55)
                              : palette.border,
                        ),
                      ),
                    ),
                    if (snapshot.fullAccessActive) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        key: const Key('disable-full-access'),
                        onPressed: controlsEnabled
                            ? () => _submit(
                                ws
                                    .PermissionRevocationOperation
                                    .disableFullAccess,
                              )
                            : null,
                        icon: const Icon(Icons.lock_outline_rounded, size: 17),
                        label: Text(strings.permissionDisableFullAccess),
                        style: TextButton.styleFrom(
                          foregroundColor: palette.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Material(
                      type: MaterialType.transparency,
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          key: const Key('permission-history'),
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 4),
                          title: Text(
                            strings.permissionHistory,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                          iconColor: palette.accent,
                          collapsedIconColor: palette.textMuted,
                          children: snapshot.history.isEmpty
                              ? [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      strings.permissionNoHistory,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: palette.textMuted,
                                      ),
                                    ),
                                  ),
                                ]
                              : [
                                  for (final event
                                      in snapshot.history.reversed.take(5))
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Text(
                                          strings.permissionHistoryLabel(
                                            event.event,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: palette.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EmptyPermissionState extends StatelessWidget {
  const _EmptyPermissionState({
    required this.connected,
    required this.palette,
    required this.strings,
    required this.onRefresh,
  });

  final bool connected;
  final OsiaPalette palette;
  final OsiaStrings strings;
  final bool Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (connected)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.accent,
            ),
          )
        else
          Icon(Icons.cloud_off_rounded, size: 18, color: palette.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            connected
                ? strings.permissionSyncing
                : strings.permissionNoSnapshot,
            style: TextStyle(fontSize: 12.5, color: palette.textMuted),
          ),
        ),
        IconButton(
          tooltip: strings.permissionRefresh,
          onPressed: connected ? onRefresh : null,
          icon: const Icon(Icons.refresh_rounded, size: 18),
        ),
      ],
    );
  }
}

class _PermissionStatusCard extends StatelessWidget {
  const _PermissionStatusCard({
    required this.preset,
    required this.live,
    required this.palette,
    required this.strings,
    required this.onRefresh,
  });

  final String preset;
  final bool live;
  final OsiaPalette palette;
  final OsiaStrings strings;
  final bool Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('permission-status-card'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.background.withValues(
          alpha: palette.isDark ? 0.62 : 0.4,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border, width: 0.6),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: live ? palette.accent : palette.textMuted,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  live ? strings.permissionLive : strings.permissionLastKnown,
                  key: const Key('permission-connection-state'),
                  style: TextStyle(fontSize: 11.5, color: palette.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: strings.permissionRefresh,
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyPermissionRow extends StatelessWidget {
  const _ReadOnlyPermissionRow({
    super.key,
    required this.label,
    required this.active,
    required this.palette,
    required this.strings,
  });

  final String label;
  final bool active;
  final OsiaPalette palette;
  final OsiaStrings strings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 16,
            color: active ? palette.accent : palette.textMuted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: palette.textPrimary),
            ),
          ),
          Text(
            active ? strings.permissionOn : strings.permissionOff,
            style: TextStyle(fontSize: 11.5, color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _TemporaryPermissionRow extends StatelessWidget {
  const _TemporaryPermissionRow({
    super.key,
    required this.item,
    required this.lifetime,
    required this.enabled,
    required this.pending,
    required this.palette,
    required this.strings,
    required this.onRevoke,
    required this.onRevokeContext,
  });

  final ws.PermissionTemporaryItem item;
  final String lifetime;
  final bool enabled;
  final bool pending;
  final OsiaPalette palette;
  final OsiaStrings strings;
  final VoidCallback onRevoke;
  final VoidCallback? onRevokeContext;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: palette.background.withValues(
          alpha: palette.isDark ? 0.5 : 0.32,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.permissionActionLabel(item.actionLabel),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${strings.permissionContextLabel(item.context)} · $lifetime',
            style: TextStyle(fontSize: 11.5, color: palette.textMuted),
          ),
          const SizedBox(height: 6),
          if (pending)
            Text(
              strings.permissionPending,
              style: TextStyle(fontSize: 11.5, color: palette.textMuted),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                TextButton(
                  onPressed: enabled ? onRevoke : null,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: palette.error,
                  ),
                  child: Text(strings.permissionRevoke),
                ),
                if (onRevokeContext != null)
                  TextButton(
                    onPressed: enabled ? onRevokeContext : null,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: palette.error,
                    ),
                    child: Text(
                      item.context == 'autonomous'
                          ? strings.permissionRevokeRun
                          : strings.permissionRevokeTask,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
