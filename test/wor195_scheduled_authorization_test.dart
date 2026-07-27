import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart';

const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  test(
    'scheduled authorization parser retains only sanitized fields',
    () async {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'test',
        autoReconnect: false,
        sendFrameForTest: (_) => true,
      );
      addTearDown(service.dispose);
      final pending = service.scheduledAuthorizationStream.first;
      service.handleIncomingFrameForTest({
        'type': 'scheduled_task_authorization_request',
        'protocol_version': 1,
        'request_id': 'sched:request',
        'task_id': 'cron_fixture',
        'task_revision': 2,
        'definition_hash': _hashA,
        'authorization_revision': 3,
        'policy_epoch': 4,
        'expiration': 12345.0,
        'request_expires_at': 12000.0,
        'origin_ref': 'mobile:fixture',
        'capabilities': const [
          {
            'id': 'cap:one',
            'tool_category': 'native',
            'effect_class': 'reversible',
            'safe_category': 'safe_local_setting',
            'raw_path': r'C:\PRIVATE_SENTINEL',
          },
        ],
        'tool_arguments': const {'recipient': 'PRIVATE_SENTINEL'},
        'grant_refs': const ['PRIVATE_SENTINEL'],
        'scope_hash': 'PRIVATE_SENTINEL',
      });
      final event = await pending.timeout(const Duration(seconds: 1));
      final serialized = jsonEncode(event.request);
      expect(event.taskId, 'cron_fixture');
      expect(serialized, isNot(contains('PRIVATE_SENTINEL')));
      expect(serialized, isNot(contains('raw_path')));
      expect(serialized, isNot(contains('grant_refs')));
      expect(serialized, isNot(contains('scope_hash')));
      expect(
        (event.request?['capabilities'] as List).single['safe_category'],
        'safe_local_setting',
      );
    },
  );

  test(
    'approval echoes every binding and duplicate response is suppressed',
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
        'type': 'scheduled_task_authorization_context',
        'protocol_version': 1,
        'origin_ref': 'mobile:fixture',
      });
      final event = ScheduledTaskAuthorizationEvent.fromJson({
        'type': 'scheduled_task_authorization_request',
        'protocol_version': 1,
        'request_id': 'sched:request',
        'task_id': 'cron_fixture',
        'task_revision': 2,
        'definition_hash': _hashA,
        'authorization_revision': 3,
        'policy_epoch': 4,
        'expiration': 12345.0,
        'origin_ref': 'mobile:fixture',
        'capabilities': const [],
      });
      service.sendScheduledTaskAuthorizationResponse(event, 'approve');
      service.sendScheduledTaskAuthorizationResponse(event, 'approve');
      expect(frames, hasLength(1));
      expect(frames.single, containsPair('request_id', 'sched:request'));
      expect(frames.single, containsPair('task_id', 'cron_fixture'));
      expect(frames.single, containsPair('task_revision', 2));
      expect(frames.single, containsPair('definition_hash', _hashA));
      expect(frames.single, containsPair('authorization_revision', 3));
      expect(frames.single, containsPair('policy_epoch', 4));
      expect(frames.single, containsPair('expiration', 12345.0));
      expect(frames.single, containsPair('origin_ref', 'mobile:fixture'));
    },
  );

  test('wrong authenticated origin cannot answer', () {
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
      'type': 'scheduled_task_authorization_context',
      'origin_ref': 'mobile:other',
    });
    final event = ScheduledTaskAuthorizationEvent.fromJson({
      'type': 'scheduled_task_authorization_request',
      'request_id': 'sched:request',
      'origin_ref': 'mobile:fixture',
    });
    service.sendScheduledTaskAuthorizationResponse(event, 'approve');
    expect(frames, isEmpty);
  });

  test('revoke and disable carry revision hash epoch and expiration', () {
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
      'type': 'scheduled_task_authorization_context',
      'origin_ref': 'mobile:fixture',
    });
    final job = <String, dynamic>{
      'id': 'cron_fixture',
      'task_revision': 2,
      'definition_hash': _hashB,
      'authorization_revision': 3,
      'policy_epoch': 4,
      'authorization_expires_at': 12345.0,
    };
    service.sendScheduledTaskAuthorizationRevoke(job);
    service.sendScheduledTaskDisable(job);
    expect(frames, hasLength(2));
    expect(frames[0]['type'], 'scheduled_task_authorization_revoke');
    expect(frames[1]['type'], 'scheduled_task_disable');
    for (final frame in frames) {
      expect(frame, containsPair('task_revision', 2));
      expect(frame, containsPair('definition_hash', _hashB));
      expect(frame, containsPair('authorization_revision', 3));
      expect(frame, containsPair('policy_epoch', 4));
      expect(frame, containsPair('expiration', 12345.0));
      expect(frame, containsPair('origin_ref', 'mobile:fixture'));
    }
  });
}
