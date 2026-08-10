import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/execution_trace.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;

const conversationId = 'conv-254';
const requestId = 'request-254';
const turnId = 'turn-254';

Map<String, dynamic> event({
  required String eventId,
  required int sequence,
  required int revision,
  required String kind,
  required String displayKey,
  bool terminal = false,
}) => <String, dynamic>{
  'schema_version': executionTraceSchemaVersion,
  'event_id': eventId,
  'conversation_id': conversationId,
  'request_id': requestId,
  'turn_id': turnId,
  'sequence': sequence,
  'revision': revision,
  'kind': kind,
  'display': <String, Object?>{'key': displayKey, 'args': <String, Object?>{}},
  'timestamp': '2026-08-10T10:00:00Z',
  'terminal': terminal,
  'redaction_class': executionTraceRedactionClass,
};

Map<String, dynamic> envelope(
  Map<String, dynamic> current,
  List<Map<String, dynamic>> snapshot,
) => <String, dynamic>{
  'type': 'execution_trace',
  ...current,
  'snapshot': snapshot,
};

ws.WebSocketService service() => ws.WebSocketService(
  ip: '127.0.0.1',
  token: 'wor-254-test-token',
  autoReconnect: false,
  relayFallbackV1: false,
  lanDirectV1: false,
  webRtcDirectV1: false,
);

void bindTurn(ws.WebSocketService service) {
  service.rememberRequestForTest(conversationId, requestId);
  service.handleIncomingFrameForTest(<String, dynamic>{
    'type': 'turn_accepted',
    'conversation_id': conversationId,
    'request_id': requestId,
    'turn_id': turnId,
    'status': 'accepted',
  });
}

void main() {
  test('strict live trace merges revisions and tombstones after terminal', () {
    final client = service();
    addTearDown(client.dispose);
    bindTurn(client);
    final seen = <ExecutionTraceSnapshot>[];
    final subscription = client.executionTraceStream.listen(seen.add);
    addTearDown(subscription.cancel);

    final goal = event(
      eventId: 'trace-goal',
      sequence: 1,
      revision: 1,
      kind: 'goal',
      displayKey: 'execution.goal.answer',
    );
    client.handleIncomingFrameForTest(
      envelope(goal, <Map<String, dynamic>>[goal]),
    );
    final revisedGoal = event(
      eventId: 'trace-goal',
      sequence: 1,
      revision: 2,
      kind: 'goal',
      displayKey: 'execution.goal.complete_task',
    );
    client.handleIncomingFrameForTest(
      envelope(revisedGoal, <Map<String, dynamic>>[revisedGoal]),
    );
    final terminal = event(
      eventId: 'trace-terminal',
      sequence: 2,
      revision: 1,
      kind: 'terminal',
      displayKey: 'execution.terminal.success',
      terminal: true,
    );
    client.handleIncomingFrameForTest(
      envelope(terminal, <Map<String, dynamic>>[revisedGoal, terminal]),
    );
    final late = event(
      eventId: 'trace-late',
      sequence: 3,
      revision: 1,
      kind: 'action',
      displayKey: 'execution.action.shell',
    );
    client.handleIncomingFrameForTest(
      envelope(late, <Map<String, dynamic>>[late]),
    );

    expect(seen, hasLength(3));
    expect(seen[1].events.single.revision, 2);
    expect(seen.last.terminal, isTrue);
    expect(seen.last.events, hasLength(2));
  });

  test('trace rejects stale correlation, free args, and unknown fields', () {
    final client = service();
    addTearDown(client.dispose);
    bindTurn(client);
    final seen = <ExecutionTraceSnapshot>[];
    final subscription = client.executionTraceStream.listen(seen.add);
    addTearDown(subscription.cancel);

    final safe = event(
      eventId: 'trace-safe',
      sequence: 1,
      revision: 1,
      kind: 'action',
      displayKey: 'execution.action.shell',
    );
    final stale = Map<String, dynamic>.from(safe)
      ..['request_id'] = 'request-stale';
    client.handleIncomingFrameForTest(
      envelope(stale, <Map<String, dynamic>>[stale]),
    );
    final freeArgs = Map<String, dynamic>.from(safe)
      ..['display'] = <String, Object?>{
        'key': 'execution.action.shell',
        'args': <String, Object?>{'command': 'secret --token=value'},
      };
    client.handleIncomingFrameForTest(
      envelope(freeArgs, <Map<String, dynamic>>[freeArgs]),
    );
    final extra = Map<String, dynamic>.from(safe)..['raw_result'] = 'private';
    client.handleIncomingFrameForTest(
      envelope(extra, <Map<String, dynamic>>[extra]),
    );

    expect(seen, isEmpty);
  });

  test('history trace is bounded and fail-closed', () {
    final goal = event(
      eventId: 'trace-history',
      sequence: 1,
      revision: 1,
      kind: 'goal',
      displayKey: 'execution.goal.answer',
    );
    final raw = <String, dynamic>{
      'schema_version': executionTraceSchemaVersion,
      'conversation_id': conversationId,
      'request_id': requestId,
      'turn_id': turnId,
      'redaction_class': executionTraceRedactionClass,
      'events': <Map<String, dynamic>>[goal],
    };
    expect(ExecutionTraceSnapshot.parseHistory(raw)?.events, hasLength(1));
    raw['raw_prompt'] = 'private';
    expect(ExecutionTraceSnapshot.parseHistory(raw), isNull);
  });
}
