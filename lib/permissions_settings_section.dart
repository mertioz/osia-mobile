import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'l10n.dart';
import 'permission_contract.dart';
import 'services/websocket_service.dart' as ws;
import 'theme.dart';

class PermissionsSettingsEntry extends StatefulWidget {
  const PermissionsSettingsEntry({
    super.key,
    required this.wsService,
    required this.onTap,
  });

  final ws.WebSocketService wsService;
  final VoidCallback onTap;

  @override
  State<PermissionsSettingsEntry> createState() =>
      _PermissionsSettingsEntryState();
}

class _PermissionsSettingsEntryState extends State<PermissionsSettingsEntry> {
  StreamSubscription<ws.PermissionSnapshot>? _snapshotSub;
  StreamSubscription<ws.ConfigData>? _configSub;
  StreamSubscription<ws.ConnectionState>? _connectionSub;
  ws.PermissionSnapshot? _snapshot;
  PermissionContract? _contract;
  bool _contractReceived = false;
  late ws.ConnectionState _connectionState;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.wsService.permissionSnapshot;
    _connectionState = widget.wsService.state;
    _snapshotSub = widget.wsService.permissionSnapshotStream.listen((value) {
      if (mounted) setState(() => _snapshot = value);
    });
    _configSub = widget.wsService.configStream.listen((value) {
      final contract = PermissionContract.tryParse(
        value.settings['permission_contract'],
      );
      if (mounted) {
        setState(() {
          _contract = contract;
          _contractReceived = true;
        });
      }
    });
    _connectionSub = widget.wsService.connectionStream.listen((value) {
      if (!mounted) return;
      setState(() {
        _connectionState = value;
        if (value != ws.ConnectionState.connected) {
          _contract = null;
          _contractReceived = false;
        }
      });
      if (value == ws.ConnectionState.connected) _refresh();
    });
    _refresh();
  }

  void _refresh() {
    if (widget.wsService.state != ws.ConnectionState.connected) return;
    widget.wsService.sendGetConfig();
    widget.wsService.requestPermissionSnapshot();
  }

  @override
  void dispose() {
    _snapshotSub?.cancel();
    _configSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  String _summary(OsiaStrings strings) {
    if (_connectionState != ws.ConnectionState.connected) {
      return strings.permissionPcOffline;
    }
    final snapshot = _snapshot;
    if (!widget.wsService.permissionsLive || snapshot == null) {
      return strings.permissionSyncing;
    }
    if (!_contractReceived) return strings.permissionSyncing;
    if (_contract?.matchesSnapshot(snapshot) != true) {
      return strings.permissionSyncError;
    }
    if (widget.wsService.pendingPermissionRequestIds.isNotEmpty) {
      return strings.permissionPcConfirmationRequired;
    }
    return switch (snapshot.preset) {
      'full_access' => strings.permissionFullAccess,
      'mixed' => strings.permissionCustomAccess,
      _ => strings.permissionAskEachTime,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final live =
        _connectionState == ws.ConnectionState.connected &&
        widget.wsService.permissionsLive &&
        _contract?.matchesSnapshot(_snapshot) == true;

    return Column(
      key: const Key('settings-permissions-entry-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Text(
            strings.permissionsTitle.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.textMuted,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Material(
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: palette.border, width: 0.6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            button: true,
            label: '${strings.permissionsSubtitle}, ${_summary(strings)}',
            child: InkWell(
              key: const Key('settings-permissions-entry'),
              onTap: widget.onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 68),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        color: palette.accent,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.permissionsSubtitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _summary(strings),
                              key: const Key('settings-permissions-summary'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: palette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        live ? Icons.sync_rounded : Icons.sync_problem_rounded,
                        key: const Key('settings-permissions-sync-icon'),
                        color: live ? palette.accent : palette.textMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: palette.textMuted,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _PermissionChangeKind {
  category,
  defaultAccess,
  fullAccess,
  revokeAllTemporary,
}

class _PendingPermissionChange {
  const _PendingPermissionChange({
    required this.requestId,
    required this.kind,
    required this.sessionId,
    required this.basePolicyEpoch,
    required this.baseSequence,
    this.categoryId = '',
    this.enabled = false,
  });

  final String requestId;
  final _PermissionChangeKind kind;
  final String sessionId;
  final int basePolicyEpoch;
  final int baseSequence;
  final String categoryId;
  final bool enabled;
}

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({
    super.key,
    required this.wsService,
    this.requestTimeout = const Duration(seconds: 30),
  });

  final ws.WebSocketService wsService;
  final Duration requestTimeout;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  StreamSubscription<ws.PermissionSnapshot>? _snapshotSub;
  StreamSubscription<ws.PermissionRevocationAck>? _ackSub;
  StreamSubscription<ws.ConfigData>? _configSub;
  StreamSubscription<ws.ConnectionState>? _connectionSub;
  ws.PermissionSnapshot? _snapshot;
  PermissionContract? _contract;
  bool _contractReceived = false;
  late ws.ConnectionState _connectionState;
  _PendingPermissionChange? _pendingChange;
  Timer? _pendingTimer;
  bool _customHintVisible = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.wsService.permissionSnapshot;
    _connectionState = widget.wsService.state;
    _snapshotSub = widget.wsService.permissionSnapshotStream.listen(
      _onSnapshot,
    );
    _ackSub = widget.wsService.permissionRevocationAckStream.listen((ack) {
      if (!mounted) return;
      setState(() {});
      _showResult(ack.succeeded);
    });
    _configSub = widget.wsService.configStream.listen((value) {
      final contract = PermissionContract.tryParse(
        value.settings['permission_contract'],
      );
      if (!mounted) return;
      setState(() {
        _contract = contract;
        _contractReceived = true;
      });
      if (contract == null || !contract.matchesSnapshot(_snapshot)) {
        _finishPending(false);
      }
    });
    _connectionSub = widget.wsService.connectionStream.listen((value) {
      if (!mounted) return;
      setState(() {
        _connectionState = value;
        if (value != ws.ConnectionState.connected) {
          _contract = null;
          _contractReceived = false;
        }
      });
      if (value == ws.ConnectionState.connected) {
        _refresh();
      } else {
        _finishPending(false);
      }
    });
    _refresh();
  }

  void _refresh() {
    if (widget.wsService.state != ws.ConnectionState.connected) return;
    widget.wsService.sendGetConfig();
    widget.wsService.requestPermissionSnapshot();
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    _snapshotSub?.cancel();
    _ackSub?.cancel();
    _configSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  bool get _compatible => _contract?.matchesSnapshot(_snapshot) == true;

  bool get _live =>
      _connectionState == ws.ConnectionState.connected &&
      widget.wsService.permissionsLive &&
      _snapshot != null &&
      _compatible;

  bool get _hasPending =>
      _pendingChange != null ||
      widget.wsService.pendingPermissionRequestIds.isNotEmpty;

  bool get _controlsEnabled =>
      _live && _snapshot?.protectedStoreAvailable == true && !_hasPending;

  void _onSnapshot(ws.PermissionSnapshot snapshot) {
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
    final pending = _pendingChange;
    if (pending == null || snapshot.sequence <= pending.baseSequence) return;
    if (snapshot.sessionId != pending.sessionId) {
      _finishPending(false);
      return;
    }
    switch (pending.kind) {
      case _PermissionChangeKind.category:
        _finishPending(
          snapshot.categories[pending.categoryId] == pending.enabled,
        );
      case _PermissionChangeKind.defaultAccess:
        _finishPending(
          !snapshot.fullAccessActive &&
              !snapshot.categories.values.any((value) => value),
        );
      case _PermissionChangeKind.revokeAllTemporary:
        _finishPending(snapshot.temporaryPermissions.isEmpty);
      case _PermissionChangeKind.fullAccess:
        if (snapshot.fullAccessActive) {
          _finishPending(true);
        } else if (snapshot.policyEpoch != pending.basePolicyEpoch) {
          _finishPending(false);
        }
    }
  }

  void _finishPending(bool succeeded, {bool timedOut = false}) {
    if (_pendingChange == null || !mounted) return;
    _pendingTimer?.cancel();
    setState(() => _pendingChange = null);
    _showResult(succeeded, timedOut: timedOut);
  }

  void _showResult(bool succeeded, {bool timedOut = false}) {
    if (!mounted) return;
    final strings = OsiaL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? strings.permissionApplied
              : timedOut
              ? strings.permissionRequestTimedOut
              : strings.permissionRejected,
        ),
      ),
    );
  }

  void _submitChange(
    _PermissionChangeKind kind, {
    String categoryId = '',
    bool enabled = false,
  }) {
    final snapshot = _snapshot;
    final contract = _contract;
    if (!_controlsEnabled || snapshot == null || contract == null) return;
    final operation = switch (kind) {
      _PermissionChangeKind.category => 'set_category',
      _PermissionChangeKind.defaultAccess => 'apply_default_access',
      _PermissionChangeKind.fullAccess => 'request_full_access',
      _PermissionChangeKind.revokeAllTemporary =>
        'revoke_all_temporary_permissions',
    };
    final requestId =
        'permission-change:${ws.WebSocketService.newClientRequestId()}';
    final pending = _PendingPermissionChange(
      requestId: requestId,
      kind: kind,
      sessionId: snapshot.sessionId,
      basePolicyEpoch: snapshot.policyEpoch,
      baseSequence: snapshot.sequence,
      categoryId: categoryId,
      enabled: enabled,
    );
    setState(() => _pendingChange = pending);
    _pendingTimer?.cancel();
    final pendingTimeout = kind == _PermissionChangeKind.fullAccess
        ? const Duration(minutes: 2)
        : widget.requestTimeout;
    _pendingTimer = Timer(pendingTimeout, () {
      if (mounted && _pendingChange?.requestId == requestId) {
        _finishPending(false, timedOut: true);
      }
    });
    widget.wsService.sendSetSetting('permission_change_request', {
      'schema_version': 1,
      'contract_schema_version': permissionContractSchemaVersion,
      'request_id': requestId,
      'session_id': snapshot.sessionId,
      'expected_policy_epoch': snapshot.policyEpoch,
      'expected_snapshot_sequence': snapshot.sequence,
      'operation': operation,
      'category_id': categoryId,
      'enabled': enabled,
      'expires_at':
          DateTime.now().millisecondsSinceEpoch / 1000.0 +
          min(120, max(5, widget.requestTimeout.inSeconds)),
    });
  }

  Future<bool> _confirm({required String title, required String body}) async {
    final strings = OsiaL10n.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(strings.permissionConfirmAction),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _requestFullAccess() async {
    final strings = OsiaL10n.of(context);
    if (!_controlsEnabled || _snapshot?.fullAccessActive == true) return;
    final confirmed = await _confirm(
      title: strings.permissionFullAccess,
      body:
          '${strings.permissionFullDescription}\n\n'
          '${strings.permissionPcConfirmationRequired}',
    );
    if (confirmed) _submitChange(_PermissionChangeKind.fullAccess);
  }

  Future<void> _submitRevocation(
    ws.PermissionRevocationOperation operation, {
    String targetId = '',
    required String confirmation,
  }) async {
    if (!_controlsEnabled) return;
    final strings = OsiaL10n.of(context);
    if (!await _confirm(title: strings.permissionRevoke, body: confirmation)) {
      return;
    }
    final requestId = widget.wsService.sendPermissionRevocation(
      operation,
      targetId: targetId,
    );
    if (requestId != null && mounted) setState(() {});
  }

  String _presetLabel(OsiaStrings strings, ws.PermissionSnapshot? snapshot) {
    if (snapshot == null) return strings.permissionSyncing;
    return switch (snapshot.preset) {
      'full_access' => strings.permissionFullAccess,
      'mixed' => strings.permissionCustomAccess,
      _ => strings.permissionAskEachTime,
    };
  }

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
    final contract = _contract;
    final pendingFull =
        _pendingChange?.kind == _PermissionChangeKind.fullAccess;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(strings.permissionsSubtitle),
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const Key('permissions-screen-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            key: const Key('permissions-screen'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PermissionStatus(
                mode: _presetLabel(strings, snapshot),
                live: _live,
                offline: _connectionState != ws.ConnectionState.connected,
                palette: palette,
                strings: strings,
                onRefresh: _refresh,
              ),
              if (_contractReceived &&
                  !_compatible &&
                  _connectionState == ws.ConnectionState.connected) ...[
                const SizedBox(height: 10),
                Text(
                  strings.permissionContractIncompatible,
                  key: const Key('permission-contract-incompatible'),
                  style: TextStyle(fontSize: 12.5, color: palette.textMuted),
                ),
              ],
              const SizedBox(height: 24),
              _SectionLabel(strings.permissionModes, palette: palette),
              _ModeRow(
                key: const Key('mode-default-access'),
                title: strings.permissionAskEachTime,
                subtitle: strings.permissionDefaultDescription,
                selected: snapshot?.preset == 'default_access',
                enabled: _controlsEnabled,
                palette: palette,
                onTap: () => _submitChange(_PermissionChangeKind.defaultAccess),
              ),
              _ThinDivider(palette: palette),
              _ModeRow(
                key: const Key('mode-custom-access'),
                title: strings.permissionCustomAccess,
                subtitle: strings.permissionCustomDescription,
                selected: snapshot?.preset == 'mixed',
                enabled: _controlsEnabled,
                palette: palette,
                onTap: () => setState(() => _customHintVisible = true),
              ),
              _ThinDivider(palette: palette),
              _ModeRow(
                key: const Key('mode-full-access'),
                title: strings.permissionFullAccess,
                subtitle: strings.permissionFullDescription,
                selected: snapshot?.preset == 'full_access',
                pending: pendingFull,
                enabled: _controlsEnabled || pendingFull,
                palette: palette,
                onTap: _requestFullAccess,
              ),
              if (_customHintVisible && snapshot?.preset != 'mixed') ...[
                const SizedBox(height: 8),
                Text(
                  strings.permissionChooseCategories,
                  key: const Key('permission-custom-hint'),
                  style: TextStyle(fontSize: 12.5, color: palette.textMuted),
                ),
              ],
              if (pendingFull) ...[
                const SizedBox(height: 10),
                _PendingRow(
                  key: const Key('full-access-pending-pc'),
                  label: strings.permissionPcConfirmationRequired,
                  palette: palette,
                ),
              ],
              const SizedBox(height: 26),
              _SectionLabel(strings.permissionCategories, palette: palette),
              if (snapshot != null && contract != null && _compatible)
                for (
                  var index = 0;
                  index < contract.categories.length;
                  index++
                ) ...[
                  _CategoryRow(
                    key: Key(
                      'permission-category-${contract.categories[index].id}',
                    ),
                    label: strings.permissionContractText(
                      contract.categories[index].labelKey,
                    ),
                    description: strings.permissionContractText(
                      contract.categories[index].descriptionKey,
                    ),
                    value:
                        snapshot.categories[contract.categories[index].id] ==
                        true,
                    enabled:
                        _controlsEnabled &&
                        contract.categories[index].mobileRequestAllowed,
                    pending:
                        _pendingChange?.categoryId ==
                        contract.categories[index].id,
                    palette: palette,
                    onChanged: (value) => _submitChange(
                      _PermissionChangeKind.category,
                      categoryId: contract.categories[index].id,
                      enabled: value,
                    ),
                  ),
                  if (index != contract.categories.length - 1)
                    _ThinDivider(palette: palette),
                ]
              else
                Text(
                  _connectionState == ws.ConnectionState.connected
                      ? _contractReceived
                            ? strings.permissionChangesUnavailable
                            : strings.permissionSyncing
                      : strings.permissionNoSnapshot,
                  style: TextStyle(fontSize: 12.5, color: palette.textMuted),
                ),
              const SizedBox(height: 26),
              _SectionLabel(strings.permissionTemporary, palette: palette),
              if (snapshot == null || snapshot.temporaryPermissions.isEmpty)
                Text(
                  strings.permissionNoTemporary,
                  key: const Key('no-temporary-permissions'),
                  style: TextStyle(fontSize: 12.5, color: palette.textMuted),
                )
              else
                for (
                  var index = 0;
                  index < snapshot.temporaryPermissions.length;
                  index++
                ) ...[
                  _TemporaryPermissionRow(
                    key: Key(
                      'temporary-permission-'
                      '${snapshot.temporaryPermissions[index].mobileItemId}',
                    ),
                    item: snapshot.temporaryPermissions[index],
                    lifetime: _permissionLifetime(
                      strings,
                      snapshot.temporaryPermissions[index],
                    ),
                    enabled:
                        _controlsEnabled &&
                        snapshot.temporaryPermissions[index].revocable,
                    pending: widget.wsService.isPermissionItemPending(
                      snapshot.temporaryPermissions[index].mobileItemId,
                    ),
                    palette: palette,
                    strings: strings,
                    onRevoke: () => _submitRevocation(
                      ws
                          .PermissionRevocationOperation
                          .revokeTemporaryPermission,
                      targetId:
                          snapshot.temporaryPermissions[index].mobileItemId,
                      confirmation: strings.permissionRevokeConfirmation,
                    ),
                    onRevokeContext: switch (snapshot
                        .temporaryPermissions[index]
                        .context) {
                      'autonomous' => () => _submitRevocation(
                        ws.PermissionRevocationOperation.revokeAutonomousRun,
                        targetId:
                            snapshot.temporaryPermissions[index].mobileItemId,
                        confirmation: strings.permissionRevokeConfirmation,
                      ),
                      'scheduled' => () => _submitRevocation(
                        ws.PermissionRevocationOperation.revokeScheduledTask,
                        targetId:
                            snapshot.temporaryPermissions[index].mobileItemId,
                        confirmation: strings.permissionRevokeConfirmation,
                      ),
                      _ => null,
                    },
                  ),
                  if (index != snapshot.temporaryPermissions.length - 1)
                    _ThinDivider(palette: palette),
                ],
              if (snapshot?.temporaryPermissions.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  key: const Key('revoke-all-temporary-permissions'),
                  onPressed: _controlsEnabled
                      ? () async {
                          if (await _confirm(
                            title: strings.permissionRevokeAllTemporary,
                            body: strings.permissionRevokeAllConfirmation,
                          )) {
                            _submitChange(
                              _PermissionChangeKind.revokeAllTemporary,
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.link_off_rounded, size: 18),
                  label: Text(strings.permissionRevokeAllTemporary),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.error,
                    minimumSize: const Size(48, 48),
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ],
              if (snapshot?.fullAccessActive == true) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  key: const Key('disable-full-access'),
                  onPressed: _controlsEnabled
                      ? () => _submitRevocation(
                          ws.PermissionRevocationOperation.disableFullAccess,
                          confirmation:
                              strings.permissionDisableFullConfirmation,
                        )
                      : null,
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: Text(strings.permissionDisableFullAccess),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.error,
                    minimumSize: const Size(48, 48),
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ],
              if (_hasPending && !pendingFull) ...[
                const SizedBox(height: 8),
                _PendingRow(
                  key: const Key('permission-pending'),
                  label: strings.permissionPending,
                  palette: palette,
                ),
              ],
              const SizedBox(height: 18),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const Key('permission-history'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  minTileHeight: 48,
                  title: Text(
                    strings.permissionHistory,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  iconColor: palette.accent,
                  collapsedIconColor: palette.textMuted,
                  children: snapshot == null || snapshot.history.isEmpty
                      ? [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              strings.permissionNoHistory,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: palette.textMuted,
                              ),
                            ),
                          ),
                        ]
                      : [
                          for (final event in snapshot.history.reversed.take(8))
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  strings.permissionHistoryLabel(event.event),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: palette.textMuted,
                                  ),
                                ),
                              ),
                            ),
                        ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionStatus extends StatelessWidget {
  const _PermissionStatus({
    required this.mode,
    required this.live,
    required this.offline,
    required this.palette,
    required this.strings,
    required this.onRefresh,
  });

  final String mode;
  final bool live;
  final bool offline;
  final OsiaPalette palette;
  final OsiaStrings strings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('permission-status-card'),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode,
                  key: const Key('permission-current-mode'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  offline
                      ? strings.permissionPcOffline
                      : live
                      ? strings.permissionLive
                      : strings.permissionSyncing,
                  key: const Key('permission-connection-state'),
                  style: TextStyle(fontSize: 11.5, color: palette.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: strings.permissionRefresh,
            onPressed: offline ? null : onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.palette});

  final String label;
  final OsiaPalette palette;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: palette.textMuted,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider({required this.palette});

  final OsiaPalette palette;

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    color: palette.border.withValues(alpha: 0.5),
    indent: 4,
  );
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.palette,
    required this.onTap,
    this.pending = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final bool pending;
  final OsiaPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                pending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.accent,
                        ),
                      )
                    : Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: selected ? palette.accent : palette.textMuted,
                        size: 20,
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? palette.textPrimary
                              : palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.label,
    required this.description,
    required this.value,
    required this.enabled,
    required this.pending,
    required this.palette,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final bool enabled;
  final bool pending;
  final OsiaPalette palette;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.centerRight,
    children: [
      SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        minTileHeight: 72,
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: enabled ? palette.textPrimary : palette.textMuted,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(fontSize: 11.5, color: palette.textMuted),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
        activeThumbColor: palette.accent,
      ),
      if (pending)
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.accent,
            ),
          ),
        ),
    ],
  );
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({super.key, required this.label, required this.palette});

  final String label;
  final OsiaPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 1.8,
          color: palette.accent,
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          label,
          style: TextStyle(fontSize: 12.5, color: palette.textMuted),
        ),
      ),
    ],
  );
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              Icons.schedule_rounded,
              size: 17,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
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
                Text(
                  '${strings.permissionContextLabel(item.context)} · $lifetime',
                  style: TextStyle(fontSize: 11.5, color: palette.textMuted),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: enabled && !pending ? onRevoke : null,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.error,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: Text(strings.permissionRevoke),
                    ),
                    if (onRevokeContext != null)
                      TextButton(
                        onPressed: enabled && !pending ? onRevokeContext : null,
                        style: TextButton.styleFrom(
                          foregroundColor: palette.error,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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
          ),
          if (pending)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
