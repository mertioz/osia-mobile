import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;

Map<String, dynamic> _turnFrame(
  String type,
  int sequence, {
  String conversationId = 'conv-231',
  String requestId = 'request-231',
  String turnId = 'turn-231',
  String status = '',
  bool terminal = false,
  bool recovered = false,
  String toolAttemptId = '',
}) => <String, dynamic>{
  'type': type,
  'conversation_id': conversationId,
  'request_id': requestId,
  'client_request_id': requestId,
  'turn_id': turnId,
  'message_id': type == 'turn_accepted' ? 'user-231' : 'assistant-231',
  'event_id': 'event-231-$sequence',
  'event_type': type,
  'sequence': sequence,
  'terminal': terminal,
  if (status.isNotEmpty) 'status': status,
  if (recovered) 'recovered': true,
  if (toolAttemptId.isNotEmpty) 'tool_attempt_id': toolAttemptId,
};

void main() {
  test(
    'chat Stop reuses exact turn identity and repeated taps deduplicate',
    () {
      final sent = <Map<String, dynamic>>[];
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
        sendFrameForTest: (frame) {
          sent.add(frame);
          return true;
        },
      );
      addTearDown(service.dispose);

      expect(
        service.sendText(
          'ordinary user prompt',
          conversationId: 'conv-231',
          clientRequestId: 'request-231',
        ),
        isTrue,
      );
      service.handleIncomingFrameForTest(_turnFrame('turn_accepted', 1));

      expect(
        service.requestChatCancellation(
          conversationId: 'conv-231',
          clientRequestId: 'request-231',
        ),
        isTrue,
      );
      expect(
        service.requestChatCancellation(
          conversationId: 'conv-231',
          clientRequestId: 'request-231',
        ),
        isTrue,
      );

      final controls = sent
          .where((frame) => frame['type'] == 'cancel_active_work')
          .toList();
      expect(controls, hasLength(1));
      expect(controls.single, <String, dynamic>{
        'type': 'cancel_active_work',
        'schema_version': 1,
        'scope': 'chat',
        'conversation_id': 'conv-231',
        'request_id': 'request-231',
        'client_request_id': 'request-231',
        'turn_id': 'turn-231',
      });
      expect(controls.single.containsKey('content'), isFalse);
      expect(
        service.isConversationCancellationRequested(
          'conv-231',
          clientRequestId: 'request-231',
        ),
        isTrue,
      );

      service.handleIncomingFrameForTest(
        _turnFrame(
          'turn_status',
          2,
          status: 'cancellation_requested',
          toolAttemptId: 'attempt-231',
        ),
      );
      expect(
        sent.where((frame) => frame['type'] == 'cancel_active_work'),
        hasLength(1),
        reason:
            'late tool correlation must not turn one Stop tap into a replay',
      );

      service.handleIncomingFrameForTest(
        _turnFrame('turn_status', 3, status: 'done', terminal: true),
      );
      expect(
        service.isConversationCancellationRequested(
          'conv-231',
          clientRequestId: 'request-231',
        ),
        isFalse,
      );
    },
  );

  test('Stop before turn acceptance queues against the original request', () {
    final sent = <Map<String, dynamic>>[];
    final service = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        sent.add(frame);
        return true;
      },
    );
    addTearDown(service.dispose);

    expect(
      service.sendText(
        'new conversation prompt',
        clientRequestId: 'request-231',
      ),
      isTrue,
    );
    expect(
      service.requestChatCancellation(clientRequestId: 'request-231'),
      isTrue,
    );
    expect(
      sent.where((frame) => frame['type'] == 'cancel_active_work'),
      isEmpty,
    );

    service.handleIncomingFrameForTest(
      _turnFrame('turn_accepted', 1, recovered: true),
    );
    final controls = sent
        .where((frame) => frame['type'] == 'cancel_active_work')
        .toList();
    expect(controls, hasLength(1));
    expect(controls.single['request_id'], 'request-231');
    expect(controls.single['turn_id'], 'turn-231');
    expect(
      sent.where(
        (frame) => frame['type'] == 'text' && frame['content'] == 'cancel',
      ),
      isEmpty,
    );
  });

  test('reconnect recovery preserves pending chat cancellation', () {
    final sent = <Map<String, dynamic>>[];
    final service = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        sent.add(frame);
        return true;
      },
    );
    addTearDown(service.dispose);

    service.rememberRequestForTest('conv-231', 'request-231');
    service.handleIncomingFrameForTest(_turnFrame('turn_accepted', 1));
    expect(
      service.requestChatCancellation(
        conversationId: 'conv-231',
        clientRequestId: 'request-231',
      ),
      isTrue,
    );
    service.handleChannelDoneForTest();
    expect(
      service.isConversationCancellationRequested(
        'conv-231',
        clientRequestId: 'request-231',
      ),
      isTrue,
    );

    service.handleIncomingFrameForTest(
      _turnFrame('turn_status', 2, status: 'cancellation_requested'),
    );
    expect(
      sent.where((frame) => frame['type'] == 'cancel_active_work'),
      hasLength(1),
    );
  });

  test('Autonomous Stop carries run correlations and deduplicates', () {
    final sent = <Map<String, dynamic>>[];
    final service = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        sent.add(frame);
        return true;
      },
    );
    addTearDown(service.dispose);

    service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'autonomous_authorization_state',
      'event': 'running',
      'run_id': 'run-231',
      'task_id': 'task-231',
      'operation_id': 'operation-231',
      'tool_attempt_id': 'attempt-231',
      'terminal': false,
    });
    expect(service.hasActiveAutonomousWork, isTrue);
    expect(service.requestAutonomousCancellation(), isTrue);
    expect(service.requestAutonomousCancellation(), isTrue);

    final controls = sent
        .where((frame) => frame['type'] == 'cancel_active_work')
        .toList();
    expect(controls, hasLength(1));
    expect(controls.single, <String, dynamic>{
      'type': 'cancel_active_work',
      'schema_version': 1,
      'scope': 'autonomous',
      'run_id': 'run-231',
      'task_id': 'task-231',
      'operation_id': 'operation-231',
      'tool_attempt_id': 'attempt-231',
    });
    expect(service.autonomousCancellationRequested, isTrue);

    service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'autonomous_authorization_state',
      'event': 'done',
      'run_id': 'run-231',
      'terminal': true,
    });
    expect(service.hasActiveAutonomousWork, isFalse);
    expect(service.autonomousCancellationRequested, isFalse);
  });

  test(
    'Autonomous running waiting verifying and resuming remain stoppable',
    () {
      for (final state in <String>{
        'running',
        'action_starting',
        'action_in_progress',
        'waiting_tool',
        'verifying_tool',
        'blocked_unknown_effect',
        'resuming',
      }) {
        final service = ws.WebSocketService(
          ip: '127.0.0.1',
          token: 'token',
          autoReconnect: false,
          sendFrameForTest: (_) => true,
        );
        service.handleIncomingFrameForTest(<String, dynamic>{
          'type': 'autonomous_authorization_state',
          'event': state,
          'run_id': 'run-$state',
          'terminal': false,
        });
        expect(service.hasActiveAutonomousWork, isTrue, reason: state);
        expect(service.requestAutonomousCancellation(), isTrue, reason: state);
        service.dispose();
      }
    },
  );

  test('a correlated rejection re-enables the exact Stop target', () {
    final sent = <Map<String, dynamic>>[];
    final service = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        sent.add(frame);
        return true;
      },
    );
    addTearDown(service.dispose);

    service.rememberRequestForTest('conv-231', 'request-231');
    service.handleIncomingFrameForTest(_turnFrame('turn_accepted', 1));
    service.requestChatCancellation(
      conversationId: 'conv-231',
      clientRequestId: 'request-231',
    );
    service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'cancellation_control',
      'schema_version': 1,
      'scope': 'chat',
      'state': 'rejected',
      'reason_code': 'target_mismatch',
      'conversation_id': 'conv-231',
      'request_id': 'request-231',
      'turn_id': 'turn-stale',
    });

    expect(
      service.isConversationCancellationRequested(
        'conv-231',
        clientRequestId: 'request-231',
      ),
      isFalse,
    );
    expect(
      service.requestChatCancellation(
        conversationId: 'conv-231',
        clientRequestId: 'request-231',
      ),
      isTrue,
    );
    expect(
      sent.where((frame) => frame['type'] == 'cancel_active_work'),
      hasLength(2),
    );
  });
}
