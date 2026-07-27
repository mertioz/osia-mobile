import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/screens/autonomous_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  test('plan review parses sanitized run authorization fields', () async {
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'test',
      autoReconnect: false,
      sendFrameForTest: (_) => true,
    );
    addTearDown(service.dispose);
    final message = service.autonomousStream.first;
    service.handleIncomingFrameForTest({
      'type': 'autonomous_plan_ready',
      'event': 'authorization_pending',
      'protocol_version': 1,
      'run_id': 'run:one',
      'plan_revision': 1,
      'authorization_revision': 0,
      'policy_epoch': 4,
      'run_state': 'authorization_pending',
      'authorization_source': 'none',
      'grant_count': 0,
      'plan_summary': [
        {
          'name': 'Prepare',
          'tasks': ['Create [local target]'],
        },
      ],
      'capability_summary': [
        {
          'capability_id': 'cap:one',
          'label': 'local_files:write',
          'effect_class': 'persistent_local',
          'target_precision': 'exact',
          'delegable': true,
        },
      ],
      'authorization_request': {
        'protocol_version': 1,
        'request_id': 'auth:one',
        'run_id': 'run:one',
        'plan_revision': 1,
        'authorization_revision': 0,
        'expected_policy_epoch': 4,
        'origin_ref': 'mobile:one',
      },
    });
    final parsed = await message.timeout(const Duration(seconds: 1));
    expect(parsed.runState, 'authorization_pending');
    expect(parsed.runId, 'run:one');
    expect(parsed.planSummary.single['name'], 'Prepare');
    expect(parsed.capabilitySummary.single['capability_id'], 'cap:one');
    expect(parsed.authorizationRequest?['request_id'], 'auth:one');
  });

  test(
    'authorization response echoes every binding from authenticated origin',
    () {
      final frames = <Map<String, dynamic>>[];
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'test',
        autoReconnect: false,
        sendFrameForTest: (frame) {
          frames.add(frame);
          return true;
        },
      );
      addTearDown(service.dispose);
      service.handleIncomingFrameForTest({
        'type': 'autonomous_authorization_context',
        'protocol_version': 1,
        'origin_ref': 'mobile:one',
      });
      const run = AutonomousProgressMessage(
        protocolVersion: 1,
        runId: 'run:one',
        planRevision: 2,
        authorizationRevision: 3,
        policyEpoch: 4,
        authorizationRequest: {
          'protocol_version': 1,
          'request_id': 'auth:one',
          'run_id': 'run:one',
          'plan_revision': 2,
          'authorization_revision': 3,
          'expected_policy_epoch': 4,
          'origin_ref': 'mobile:one',
        },
      );
      service.sendAutonomousAuthorizationResponse(
        run,
        'approve',
        selectedCapabilityIds: const ['cap:one'],
      );
      expect(frames, hasLength(1));
      expect(frames.single, containsPair('request_id', 'auth:one'));
      expect(frames.single, containsPair('run_id', 'run:one'));
      expect(frames.single, containsPair('plan_revision', 2));
      expect(frames.single, containsPair('authorization_revision', 3));
      expect(frames.single, containsPair('expected_policy_epoch', 4));
      expect(frames.single, containsPair('origin_ref', 'mobile:one'));
    },
  );

  test('wrong channel cannot answer a pending request', () {
    final frames = <Map<String, dynamic>>[];
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'test',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        frames.add(frame);
        return true;
      },
    );
    addTearDown(service.dispose);
    service.handleIncomingFrameForTest({
      'type': 'autonomous_authorization_context',
      'origin_ref': 'mobile:other',
    });
    const run = AutonomousProgressMessage(
      authorizationRequest: {
        'protocol_version': 1,
        'request_id': 'auth:one',
        'run_id': 'run:one',
        'plan_revision': 1,
        'authorization_revision': 0,
        'expected_policy_epoch': 0,
        'origin_ref': 'mobile:one',
      },
    );
    service.sendAutonomousAuthorizationResponse(run, 'approve');
    expect(frames, isEmpty);
  });

  test('responded request cannot be answered twice', () {
    final frames = <Map<String, dynamic>>[];
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'test',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        frames.add(frame);
        return true;
      },
    );
    addTearDown(service.dispose);
    service.handleIncomingFrameForTest({
      'type': 'autonomous_authorization_context',
      'origin_ref': 'mobile:one',
    });
    const run = AutonomousProgressMessage(
      authorizationRequest: {
        'request_id': 'auth:one',
        'origin_ref': 'mobile:one',
        'responded': true,
      },
    );
    service.sendAutonomousAuthorizationResponse(run, 'approve');
    expect(frames, isEmpty);
  });

  test('mobile scope approval is absent for local and universal review', () {
    expect(
      autonomousMobileScopeCanApprove({
        'local_pc_review_required': false,
        'can_approve_mobile': true,
        'universal_barrier': '',
      }, originMatches: true),
      isTrue,
    );
    expect(
      autonomousMobileScopeCanApprove({
        'local_pc_review_required': true,
        'can_approve_mobile': true,
        'universal_barrier': '',
      }, originMatches: true),
      isFalse,
    );
    for (final barrier in ['system_destruction', 'colossal_deletion_pc_only']) {
      expect(
        autonomousMobileScopeCanApprove({
          'local_pc_review_required': false,
          'can_approve_mobile': true,
          'universal_barrier': barrier,
        }, originMatches: true),
        isFalse,
      );
    }
  });

  test('initial local exact scope requires PC review', () {
    expect(
      autonomousMobileInitialCanApprove([
        {
          'delegable': true,
          'can_approve_mobile': false,
          'safe_category': 'local_path',
        },
      ], originMatches: true),
      isFalse,
    );
    expect(
      autonomousMobileInitialCanApprove([
        {'delegable': true, 'can_approve_mobile': true},
      ], originMatches: true),
      isTrue,
    );
    expect(
      autonomousMobileInitialCanApprove([
        {
          'delegable': false,
          'can_approve_mobile': false,
          'universal_barrier': 'colossal_deletion_pc_only',
        },
      ], originMatches: true),
      isFalse,
    );
  });
}
