import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;

Map<String, dynamic> _turnFrame({
  required String conversationId,
  required String requestId,
  required String turnId,
}) => <String, dynamic>{
  'type': 'turn_accepted',
  'conversation_id': conversationId,
  'request_id': requestId,
  'client_request_id': requestId,
  'turn_id': turnId,
  'message_id': 'user-$turnId',
  'event_id': 'event-$turnId',
  'event_type': 'turn_accepted',
  'sequence': 1,
  'terminal': false,
  'persisted': true,
};

Map<String, dynamic> _autonomousFrame(
  ws.WebSocketService service, {
  required int sequence,
  required String event,
  required bool terminal,
  String abandonState = '',
  String abandonEffectState = '',
}) => <String, dynamic>{
  'type': 'autonomous_progress',
  'schema_version': 1,
  'event_id': 'wor235-autonomous-$sequence',
  'sequence': sequence,
  'server_id': service.expectedPermissionServerIdForTest,
  'session_id': 'wor235-session',
  'run_id': 'run-wor235',
  'plan_revision': 1,
  'authorization_revision': 1,
  'event': event,
  'safe_operation_phase': event,
  'safe_site_display': '',
  'safe_progress_text': terminal
      ? 'Autonomous work stopped with an error'
      : 'Autonomous state updated',
  'terminal': terminal,
  'status': terminal ? 'failed' : 'in_progress',
  'run_state': terminal ? 'failed' : 'waiting_tool',
  'durable_state': terminal ? '' : 'waiting_tool',
  'task_id': 'task-wor235',
  'operation_id': 'operation-wor235',
  'tool_attempt_id': 'attempt-wor235',
  if (abandonState.isNotEmpty) 'abandon_state': abandonState,
  if (abandonEffectState.isNotEmpty) 'abandon_effect_state': abandonEffectState,
  'tasks_done': 0,
  'tasks_total': 1,
};

void main() {
  test('active Autonomous permits independent concurrent Chat turns', () {
    final sent = <Map<String, dynamic>>[];
    final service = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'test',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        sent.add(frame);
        return true;
      },
    );
    addTearDown(service.dispose);
    service.handleIncomingFrameForTest(
      _autonomousFrame(
        service,
        sequence: 1,
        event: 'state_updated',
        terminal: false,
      ),
    );

    expect(
      service.sendText(
        'first chat turn',
        conversationId: 'conv-wor235-a',
        clientRequestId: 'request-wor235-a',
      ),
      isTrue,
    );
    service.handleIncomingFrameForTest(
      _turnFrame(
        conversationId: 'conv-wor235-a',
        requestId: 'request-wor235-a',
        turnId: 'turn-wor235-a',
      ),
    );
    expect(
      service.sendText(
        'second chat turn',
        conversationId: 'conv-wor235-b',
        clientRequestId: 'request-wor235-b',
      ),
      isTrue,
    );
    service.handleIncomingFrameForTest(
      _turnFrame(
        conversationId: 'conv-wor235-b',
        requestId: 'request-wor235-b',
        turnId: 'turn-wor235-b',
      ),
    );

    expect(service.hasActiveAutonomousWork, isTrue);
    expect(service.isConversationBusy('conv-wor235-a'), isTrue);
    expect(service.isConversationBusy('conv-wor235-b'), isTrue);
    expect(
      sent
          .where((frame) => frame['type'] == 'text')
          .map((frame) => frame['client_request_id']),
      <String>['request-wor235-a', 'request-wor235-b'],
    );

    expect(
      service.requestChatCancellation(
        conversationId: 'conv-wor235-a',
        clientRequestId: 'request-wor235-a',
      ),
      isTrue,
    );
    final control = sent.lastWhere(
      (frame) => frame['type'] == 'cancel_active_work',
    );
    expect(control['scope'], 'chat');
    expect(control['request_id'], 'request-wor235-a');
    expect(control['turn_id'], 'turn-wor235-a');
    expect(service.autonomousCancellationRequested, isFalse);
    expect(service.hasActiveAutonomousWork, isTrue);
  });

  test('failed Autonomous Abandon deduplicates and never mutates Chat', () {
    final sent = <Map<String, dynamic>>[];
    final service = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'test',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        sent.add(frame);
        return true;
      },
    );
    addTearDown(service.dispose);
    expect(
      service.sendText(
        'chat remains active',
        conversationId: 'conv-wor235-chat',
        clientRequestId: 'request-wor235-chat',
      ),
      isTrue,
    );
    service.handleIncomingFrameForTest(
      _turnFrame(
        conversationId: 'conv-wor235-chat',
        requestId: 'request-wor235-chat',
        turnId: 'turn-wor235-chat',
      ),
    );
    service.handleIncomingFrameForTest(
      _autonomousFrame(service, sequence: 1, event: 'failed', terminal: true),
    );

    expect(service.canAbandonAutonomousWork, isTrue);
    expect(service.requestAutonomousCancellation(), isTrue);
    expect(service.requestAutonomousCancellation(), isTrue);
    expect(
      sent.where(
        (frame) =>
            frame['type'] == 'cancel_active_work' &&
            frame['scope'] == 'autonomous',
      ),
      hasLength(1),
    );
    expect(service.isConversationBusy('conv-wor235-chat'), isTrue);
    expect(
      service.isConversationCancellationRequested(
        'conv-wor235-chat',
        clientRequestId: 'request-wor235-chat',
      ),
      isFalse,
    );

    service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'cancellation_control',
      'schema_version': 1,
      'scope': 'autonomous',
      'state': 'accepted',
      'run_id': 'run-wor235',
      'task_id': 'task-wor235',
      'operation_id': 'operation-wor235',
      'tool_attempt_id': 'attempt-wor235',
      'abandon_state': 'abandoned_proven',
      'abandon_effect_state': 'effect_possible_or_unknown',
    });
    expect(service.autonomousAbandonState, 'abandoned_proven');
    expect(service.autonomousAbandonEffectState, 'effect_possible_or_unknown');
    expect(service.canAbandonAutonomousWork, isFalse);
    expect(service.autonomousCancellationRequested, isFalse);
    expect(service.isConversationBusy('conv-wor235-chat'), isTrue);
  });

  test('reconnect cache restores Chat and Autonomous independently', () {
    final service = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'test',
      autoReconnect: false,
      sendFrameForTest: (_) => true,
    );
    addTearDown(service.dispose);
    service.rememberRequestForTest(
      'conv-wor235-reconnect',
      'request-wor235-reconnect',
    );
    service.handleIncomingFrameForTest(
      _turnFrame(
        conversationId: 'conv-wor235-reconnect',
        requestId: 'request-wor235-reconnect',
        turnId: 'turn-wor235-reconnect',
      ),
    );
    service.handleIncomingFrameForTest(
      _autonomousFrame(
        service,
        sequence: 1,
        event: 'state_updated',
        terminal: false,
        abandonState: 'abandon_requested',
        abandonEffectState: 'effect_possible_or_unknown',
      ),
    );

    service.handleChannelDoneForTest();

    expect(service.isConversationBusy('conv-wor235-reconnect'), isTrue);
    expect(service.autonomousProgress?.runId, 'run-wor235');
    expect(service.autonomousProgress?.taskId, 'task-wor235');
    expect(service.autonomousAbandonState, 'abandon_requested');
    expect(service.autonomousAbandonEffectState, 'effect_possible_or_unknown');
  });
}
