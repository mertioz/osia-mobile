import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;

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
      ],
  'history': <Map<String, dynamic>>[
    <String, dynamic>{
      'timestamp': 2000000000.0,
      'event': 'grant_created',
      'context': 'chat',
    },
  ],
  'pending_requests': <Map<String, dynamic>>[],
};

Map<String, dynamic> _ack(
  ws.WebSocketService service,
  Map<String, dynamic> request, {
  int? baseSequence,
  String? session,
}) => <String, dynamic>{
  'type': 'permission_revocation_ack',
  'schema_version': 1,
  'request_id': request['request_id'],
  'server_id': service.expectedPermissionServerIdForTest,
  'session_id': session ?? request['session_id'],
  'base_policy_epoch': request['expected_policy_epoch'],
  'base_snapshot_sequence':
      baseSequence ?? request['expected_snapshot_sequence'],
  'status': 'applied',
  'reason': 'applied',
  'policy_epoch': request['expected_policy_epoch'] + 1,
};

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
        _snapshot(
          service,
          session: 'permission-session:two',
          sequence: 1,
          epoch: 5,
        ),
      );
      expect(service.permissionsLive, isTrue);
      expect(service.permissionSnapshot?.sessionId, 'permission-session:two');
    },
  );

  test(
    'revocation remains pending until a bound acknowledgement and snapshot',
    () {
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
      expect(service.permissionSnapshot!.temporaryPermissions, hasLength(1));
      final request = sent.last;
      expect(request['expected_policy_epoch'], 3);
      expect(request['expected_snapshot_sequence'], 1);

      service.handleIncomingFrameForTest(
        _ack(service, request, baseSequence: 0),
      );
      service.handleIncomingFrameForTest(
        _ack(service, request, session: 'permission-session:old'),
      );
      expect(service.pendingPermissionRequestIds, contains(requestId));

      service.handleIncomingFrameForTest(_ack(service, request));
      expect(service.pendingPermissionRequestIds, isNot(contains(requestId)));
      expect(service.permissionSnapshot!.temporaryPermissions, hasLength(1));
      expect(service.permissionsLive, isFalse);

      service.handleIncomingFrameForTest(
        _snapshot(service, sequence: 2, epoch: 4, permissions: const []),
      );
      expect(service.permissionSnapshot!.temporaryPermissions, isEmpty);
      expect(service.permissionsLive, isTrue);
    },
  );
}
