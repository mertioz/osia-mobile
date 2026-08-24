import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/execution_trace.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;

Map<String, dynamic> _turnFrame(
  String type,
  int sequence, {
  String conversationId = 'conv-231',
  String requestId = 'request-231',
  String turnId = 'turn-231',
  String runId = 'run-231',
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
  'run_id': runId,
  'provider_id': 'provider-test',
  'model_id': 'model-test',
  'effective_reasoning': 'medium',
  'message_id': type == 'turn_accepted' ? 'user-231' : 'assistant-231',
  'event_id': 'event-231-$sequence',
  'event_type': type,
  'sequence': sequence,
  'terminal': terminal,
  if (status.isNotEmpty) 'status': status,
  if (recovered) 'recovered': true,
  if (toolAttemptId.isNotEmpty) 'tool_attempt_id': toolAttemptId,
};

Map<String, dynamic> _traceFrame(int sequence, {bool terminal = false}) {
  final event = <String, dynamic>{
    'schema_version': executionTraceSchemaVersion,
    'event_id': 'trace-event-231-$sequence',
    'conversation_id': 'conv-231',
    'request_id': 'request-231',
    'turn_id': 'turn-231',
    'run_id': 'run-231',
    'provider_id': 'provider-test',
    'model_id': 'model-test',
    'effective_reasoning': 'medium',
    'sequence': sequence,
    'revision': 1,
    'kind': terminal ? 'terminal' : 'public_reasoning_summary',
    'display': <String, Object?>{
      'key': terminal
          ? 'execution.terminal.cancelled'
          : 'execution.reasoning.summary',
      'args': <String, Object?>{},
    },
    if (!terminal) 'summary': 'Late public reasoning summary.',
    'timestamp': '2026-08-24T12:00:00Z',
    'terminal': terminal,
    'redaction_class': executionTraceRedactionClass,
  };
  return <String, dynamic>{
    'type': 'execution_trace',
    ...event,
    'snapshot': <Object?>[event],
  };
}

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
        'run_id': 'run-231',
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
      'turn_id': 'turn-231',
      'run_id': 'run-231',
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

  test(
    'cancelled turn retains sanitized evidence but projects no late trace or text',
    () async {
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
      final traces = <ExecutionTraceSnapshot>[];
      final streams = <ws.ConvStreamEvent>[];
      final traceSub = service.executionTraceStream.listen(traces.add);
      final streamSub = service.convStreamStream.listen(streams.add);
      addTearDown(traceSub.cancel);
      addTearDown(streamSub.cancel);

      expect(
        service.sendText(
          'safe read-only task',
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

      service.handleIncomingFrameForTest(_traceFrame(1));
      service.handleIncomingFrameForTest(<String, dynamic>{
        ..._turnFrame('response_chunk', 2),
        'content': 'LATE_CHUNK_MUST_NOT_RENDER',
      });
      service.handleIncomingFrameForTest(<String, dynamic>{
        ..._turnFrame('response', 3),
        'content': 'LATE_FINAL_MUST_NOT_RENDER',
      });
      await Future<void>.delayed(Duration.zero);

      expect(traces, isEmpty);
      expect(streams.where((event) => event.delta?.isNotEmpty == true), isEmpty);
      expect(service.bufferedText('conv-231'), isEmpty);
      expect(
        service.executionTraceForConversation('conv-231'),
        isNotNull,
        reason: 'sanitized evidence remains retained but non-projectable',
      );

      service.handleIncomingFrameForTest(
        _turnFrame(
          'turn_status',
          4,
          status: 'cancelled',
          terminal: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.isConversationBusy('conv-231'), isFalse);
      expect(service.isConversationWorkActive('conv-231'), isFalse);
      expect(service.isConversationWaiting('conv-231'), isFalse);
      expect(service.isPending('conv-231'), isFalse);
      expect(service.activeTurnIdentity('conv-231'), isNull);
      expect(
        service.isConversationCancellationRequested(
          'conv-231',
          clientRequestId: 'request-231',
        ),
        isFalse,
      );

      expect(
        service.sendText(
          'new unaffected turn',
          conversationId: 'conv-231',
          clientRequestId: 'request-232',
        ),
        isTrue,
      );
      service.handleIncomingFrameForTest(
        _turnFrame(
          'turn_accepted',
          5,
          requestId: 'request-232',
          turnId: 'turn-232',
          runId: 'run-232',
        ),
      );
      final nextIdentity = service.activeTurnIdentity('conv-231');
      expect(nextIdentity?.requestId, 'request-232');
      expect(nextIdentity?.turnId, 'turn-232');
      expect(nextIdentity?.runId, 'run-232');
      service.handleIncomingFrameForTest(<String, dynamic>{
        ..._turnFrame(
          'response_chunk',
          6,
          requestId: 'request-232',
          turnId: 'turn-232',
          runId: 'run-232',
        ),
        'content': 'NEW_TURN_VISIBLE',
      });
      service.handleIncomingFrameForTest(_traceFrame(7));
      service.handleIncomingFrameForTest(
        _turnFrame(
          'turn_status',
          8,
          status: 'cancelled_proven',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.bufferedText('conv-231'), 'NEW_TURN_VISIBLE');
      expect(service.activeTurnIdentity('conv-231')?.requestId, 'request-232');
      expect(service.isConversationWaiting('conv-231'), isFalse);
      expect(
        service.requestChatCancellation(
          conversationId: 'conv-231',
          clientRequestId: 'request-232',
        ),
        isTrue,
      );
      final controls = sent
          .where((frame) => frame['type'] == 'cancel_active_work')
          .toList();
      expect(controls, hasLength(2));
      expect(controls.last['request_id'], 'request-232');
      expect(controls.last['turn_id'], 'turn-232');
      expect(controls.last['run_id'], 'run-232');
    },
  );
}
