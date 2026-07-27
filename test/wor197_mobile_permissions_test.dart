import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/permissions_settings_section.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

Map<String, bool> _categories({bool enabled = false}) => <String, bool>{
  for (final key in ws.permissionCategoryKeys) key: enabled,
};

Map<String, dynamic> _snapshot(
  ws.WebSocketService service, {
  String session = 'permission-session:one',
  int sequence = 1,
  int epoch = 3,
  bool fullAccess = false,
  Map<String, bool>? categories,
  List<Map<String, dynamic>>? permissions,
  List<Map<String, dynamic>>? history,
  List<Map<String, dynamic>>? pending,
  int schema = 1,
}) => <String, dynamic>{
  'type': 'permission_snapshot',
  'schema_version': schema,
  'snapshot_id': 'snapshot:$session:$sequence',
  'server_id': service.expectedPermissionServerIdForTest,
  'session_id': session,
  'policy_epoch': epoch,
  'sequence': sequence,
  'generated_at': 2000000000.0 + sequence,
  'preset': fullAccess
      ? 'full_access'
      : (categories?.values.any((value) => value) ?? false)
      ? 'mixed'
      : 'default_access',
  'categories': categories ?? _categories(enabled: fullAccess),
  'full_access_active': fullAccess,
  'protected_store': 'available',
  'temporary_permissions':
      permissions ??
      <Map<String, dynamic>>[
        <String, dynamic>{
          'action_label': 'files_and_folders',
          'context': 'chat',
          'expires_at': 2100000000.0,
          'remaining_uses': 2,
          'mobile_item_id': 'permission:item-chat',
          'revocable': true,
        },
        <String, dynamic>{
          'action_label': 'commands',
          'context': 'autonomous',
          'expires_at': 2100000000.0,
          'remaining_uses': null,
          'mobile_item_id': 'permission:item-run',
          'revocable': true,
        },
        <String, dynamic>{
          'action_label': 'connected_services',
          'context': 'scheduled',
          'expires_at': null,
          'remaining_uses': 4,
          'mobile_item_id': 'permission:item-task',
          'revocable': true,
        },
      ],
  'history':
      history ??
      <Map<String, dynamic>>[
        <String, dynamic>{
          'timestamp': 2000000000.0,
          'event': 'grant_created',
          'context': 'chat',
        },
      ],
  'pending_requests': pending ?? <Map<String, dynamic>>[],
};

Map<String, dynamic> _ack(
  ws.WebSocketService service,
  Map<String, dynamic> request, {
  int? baseSequence,
  int? baseEpoch,
  int? policyEpoch,
  String status = 'applied',
  String reason = 'applied',
  String? session,
}) => <String, dynamic>{
  'type': 'permission_revocation_ack',
  'schema_version': 1,
  'request_id': request['request_id'],
  'server_id': service.expectedPermissionServerIdForTest,
  'session_id': session ?? request['session_id'],
  'base_policy_epoch': baseEpoch ?? request['expected_policy_epoch'],
  'base_snapshot_sequence':
      baseSequence ?? request['expected_snapshot_sequence'],
  'status': status,
  'reason': reason,
  'policy_epoch': policyEpoch ?? request['expected_policy_epoch'] + 1,
};

Widget _harness(ws.WebSocketService service) => MaterialApp(
  theme: buildOsiaTheme(osiaPaletteViolet),
  home: OsiaTheme(
    palette: osiaPaletteViolet,
    child: OsiaL10n(
      strings: osiaStringsEn,
      child: Scaffold(
        body: SingleChildScrollView(
          child: PermissionsSettingsSection(wsService: service),
        ),
      ),
    ),
  ),
);

void main() {
  test(
    'strict snapshots reject schema, server, epoch, order and old session',
    () {
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'wor197-token',
        autoReconnect: false,
        sendFrameForTest: (_) => true,
      );
      addTearDown(service.dispose);
      service.setPermissionConnectionForTest(true);

      service.handleIncomingFrameForTest(_snapshot(service));
      expect(service.permissionSnapshot?.sequence, 1);
      expect(service.permissionsLive, isTrue);

      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 1, epoch: 4),
      );
      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 0, epoch: 4),
      );
      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 2, epoch: 2),
      );
      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 2, schema: 9),
      );
      final wrongServer = _snapshot(service, sequence: 2, epoch: 4)
        ..['server_id'] = List<String>.filled(64, 'b').join();
      service.handleIncomingFrameForTest(wrongServer);
      expect(service.permissionSnapshot?.sequence, 1);
      expect(service.permissionSnapshot?.policyEpoch, 3);

      service.setPermissionConnectionForTest(false);
      expect(service.permissionsLive, isFalse);
      expect(service.permissionSnapshot?.sequence, 1);
      service.setPermissionConnectionForTest(true);
      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 9, epoch: 5),
      );
      expect(service.permissionsLive, isFalse);
      service.handleIncomingFrameForTest(
        _snapshot(
          service,
          session: 'permission-session:two',
          sequence: 1,
          epoch: 5,
        ),
      );
      expect(service.permissionsLive, isTrue);
      expect(service.permissionSnapshot?.sessionId, 'permission-session:two');

      service.setPermissionConnectionForTest(false);
      service.setPermissionConnectionForTest(true);
      service.handleIncomingFrameForTest(
        _snapshot(service, session: 'permission-session:one', epoch: 6),
      );
      service.handleIncomingFrameForTest(
        _snapshot(service, session: 'permission-session:two', epoch: 6),
      );
      expect(service.permissionsLive, isFalse);
      service.handleIncomingFrameForTest(
        _snapshot(service, session: 'permission-session:three', epoch: 6),
      );
      expect(service.permissionsLive, isTrue);
      expect(service.permissionSnapshot?.sessionId, 'permission-session:three');
    },
  );

  test('revocation remains pending until a current bound acknowledgement', () {
    final sent = <Map<String, dynamic>>[];
    final service = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'wor197-token',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        sent.add(frame);
        return true;
      },
    );
    addTearDown(service.dispose);
    service.setPermissionConnectionForTest(true);
    service.handleIncomingFrameForTest(_snapshot(service));

    final requestId = service.sendPermissionRevocation(
      ws.PermissionRevocationOperation.revokeTemporaryPermission,
      targetId: 'permission:item-chat',
    );
    expect(requestId, isNotNull);
    expect(service.pendingPermissionRequestIds, contains(requestId));
    expect(service.permissionSnapshot!.temporaryPermissions, hasLength(3));
    final request = sent.last;
    expect(request['device_id'], service.permissionDeviceIdForTest);
    expect(request['expected_policy_epoch'], 3);
    expect(request['expected_snapshot_sequence'], 1);

    service.handleIncomingFrameForTest(_ack(service, request, baseSequence: 0));
    service.handleIncomingFrameForTest(
      _ack(service, request, session: 'permission-session:old'),
    );
    expect(service.pendingPermissionRequestIds, contains(requestId));
    expect(service.permissionSnapshot!.temporaryPermissions, hasLength(3));

    service.handleIncomingFrameForTest(_ack(service, request));
    expect(service.pendingPermissionRequestIds, isNot(contains(requestId)));
    expect(service.permissionSnapshot!.temporaryPermissions, hasLength(3));
    expect(service.permissionsLive, isFalse);

    service.handleIncomingFrameForTest(
      _snapshot(
        service,
        sequence: 2,
        epoch: 4,
        permissions: <Map<String, dynamic>>[],
      ),
    );
    expect(service.permissionSnapshot!.temporaryPermissions, isEmpty);
    expect(service.permissionsLive, isTrue);
  });

  testWidgets(
    'renders OSIA permission status, nine read-only categories and privacy',
    (tester) async {
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'wor197-token',
        autoReconnect: false,
        sendFrameForTest: (_) => true,
      );
      addTearDown(service.dispose);
      service.setPermissionConnectionForTest(true);
      service.handleIncomingFrameForTest(_snapshot(service));
      await tester.pumpWidget(_harness(service));
      await tester.pump();

      expect(find.byKey(const Key('permissions-section')), findsOneWidget);
      expect(find.text('Default Access'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.byKey(const Key('full-access-pc-only')), findsOneWidget);
      for (final key in ws.permissionCategoryKeys) {
        expect(find.byKey(Key('permission-category-$key')), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('permissions-section')),
          matching: find.byType(Switch),
        ),
        findsNothing,
      );
      expect(find.byKey(const Key('disable-full-access')), findsNothing);
      expect(find.textContaining('WOR197_PRIVATE'), findsNothing);
      for (final forbidden in <String>[
        'policy epoch',
        'snapshot sequence',
        'grant',
        'scope',
        'hash',
        'permit',
        'protected store',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(const Key('permissions-section')),
            matching: find.textContaining(forbidden, findRichText: true),
          ),
          findsNothing,
        );
      }
      final status = tester.widget<Container>(
        find.byKey(const Key('permission-status-card')),
      );
      final decoration = status.decoration! as BoxDecoration;
      expect(decoration.color, isNotNull);
      expect(osiaPaletteViolet.background, const Color(0xFF0D0B12));
      expect(osiaPaletteViolet.accent, const Color(0xFFC4B5F5));
    },
  );

  testWidgets(
    'UI sends revoke, run/task/all and disable-only-when-active without optimism',
    (tester) async {
      final sent = <Map<String, dynamic>>[];
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'wor197-token',
        autoReconnect: false,
        sendFrameForTest: (frame) {
          sent.add(frame);
          return true;
        },
      );
      addTearDown(service.dispose);
      final allPermissions = List<Map<String, dynamic>>.from(
        _snapshot(service)['temporary_permissions'] as List,
      );
      service.setPermissionConnectionForTest(true);
      service.handleIncomingFrameForTest(
        _snapshot(service, permissions: allPermissions),
      );
      await tester.pumpWidget(_harness(service));
      await tester.pump();

      final chatRow = find.byKey(
        const Key('temporary-permission-permission:item-chat'),
      );
      final chatRevoke = find.descendant(
        of: chatRow,
        matching: find.text('Revoke'),
      );
      await tester.ensureVisible(chatRevoke);
      await tester.tap(chatRevoke);
      await tester.pump();
      expect(service.permissionSnapshot!.temporaryPermissions, hasLength(3));
      expect(find.byKey(const Key('permission-pending')), findsOneWidget);
      var request = sent.last;
      expect(request['operation'], 'revoke_temporary_permission');
      service.handleIncomingFrameForTest(_ack(service, request));
      service.handleIncomingFrameForTest(
        _snapshot(
          service,
          sequence: 2,
          epoch: 4,
          permissions: allPermissions
              .where((item) => item['mobile_item_id'] != 'permission:item-chat')
              .toList(),
        ),
      );
      await tester.pump();

      final runRow = find.byKey(
        const Key('temporary-permission-permission:item-run'),
      );
      final runRevoke = find.descendant(
        of: runRow,
        matching: find.text('Revoke all for this run'),
      );
      await tester.ensureVisible(runRevoke);
      await tester.tap(runRevoke);
      await tester.pump();
      request = sent.last;
      expect(request['operation'], 'revoke_autonomous_run');
      service.handleIncomingFrameForTest(_ack(service, request));
      service.handleIncomingFrameForTest(
        _snapshot(
          service,
          sequence: 3,
          epoch: 5,
          permissions: allPermissions
              .where((item) => item['mobile_item_id'] == 'permission:item-task')
              .toList(),
        ),
      );
      await tester.pump();

      final taskRow = find.byKey(
        const Key('temporary-permission-permission:item-task'),
      );
      final taskRevoke = find.descendant(
        of: taskRow,
        matching: find.text('Revoke all for this task'),
      );
      await tester.ensureVisible(taskRevoke);
      await tester.tap(taskRevoke);
      await tester.pump();
      request = sent.last;
      expect(request['operation'], 'revoke_scheduled_task');
      service.handleIncomingFrameForTest(_ack(service, request));
      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 4, epoch: 6, permissions: const []),
      );
      await tester.pump();

      final revokeAll = find.byKey(const Key('revoke-all-delegated-access'));
      await tester.ensureVisible(revokeAll);
      await tester.tap(revokeAll);
      await tester.pump();
      request = sent.last;
      expect(request['operation'], 'revoke_all_delegated_authority');
      service.handleIncomingFrameForTest(_ack(service, request));
      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 5, epoch: 7, permissions: const []),
      );
      await tester.pump();

      service.handleIncomingFrameForTest(
        _snapshot(
          service,
          sequence: 6,
          epoch: 8,
          fullAccess: true,
          permissions: const [],
        ),
      );
      await tester.pump();
      final disable = find.byKey(const Key('disable-full-access'));
      await tester.ensureVisible(disable);
      expect(disable, findsOneWidget);
      await tester.tap(disable);
      await tester.pump();
      expect(sent.last['operation'], 'disable_full_access');
    },
  );

  testWidgets(
    'offline keeps last known state and disables revocation controls',
    (tester) async {
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'wor197-token',
        autoReconnect: false,
        sendFrameForTest: (_) => true,
      );
      addTearDown(service.dispose);
      service.setPermissionConnectionForTest(true);
      service.handleIncomingFrameForTest(_snapshot(service));
      await tester.pumpWidget(_harness(service));
      await tester.pump();

      service.setPermissionConnectionForTest(false);
      await tester.pumpAndSettle();
      final connectionLabel = tester.widget<Text>(
        find.byKey(const Key('permission-connection-state')),
      );
      expect(connectionLabel.data, 'Last known state');
      expect(find.text('Files and folders'), findsOneWidget);
      final revokeAll = tester.widget<OutlinedButton>(
        find.byKey(const Key('revoke-all-delegated-access')),
      );
      expect(revokeAll.onPressed, isNull);
      final chatRow = find.byKey(
        const Key('temporary-permission-permission:item-chat'),
      );
      final revoke = tester.widget<TextButton>(
        find.descendant(of: chatRow, matching: find.byType(TextButton)),
      );
      expect(revoke.onPressed, isNull);
    },
  );
}
