import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart';

const _conversationId = 'conv-wor269-mobile';
const _requestId = 'request-wor269-mobile';
const _turnId = 'turn-wor269-mobile';
const _runId = 'run-wor269-mobile';
const _streamId = 'stream-wor269-mobile';

Map<String, dynamic> _event(
  String type,
  int sequence, {
  bool recovered = false,
  bool replayed = false,
  bool historical = false,
  bool terminal = false,
  String status = '',
  String content = '',
  String requestId = _requestId,
  String turnId = _turnId,
  String runId = _runId,
}) => <String, dynamic>{
  'type': type,
  'conversation_id': _conversationId,
  'request_id': requestId,
  'client_request_id': requestId,
  'turn_id': turnId,
  'run_id': runId,
  'provider_id': 'provider-wor269',
  'model_id': 'model-wor269',
  'effective_reasoning': 'medium',
  if (!const <String>{
    'conversation_busy_changed',
    'action_truth_changed',
  }.contains(type))
    'message_id': 'message-wor269-$sequence',
  'event_id': 'event-wor269-$sequence-$type',
  'event_type': type,
  'stream_id': _streamId,
  'sequence': sequence,
  'created_at': 1000.0 + sequence,
  'producer_id': 'osia-pc',
  'payload_version': 1,
  'terminal': terminal,
  if (recovered) 'recovered': true,
  if (replayed) 'replayed': true,
  if (historical) 'historical': true,
  if (status.isNotEmpty) 'status': status,
  if (content.isNotEmpty) 'content': content,
};

WebSocketService _service(List<Map<String, dynamic>> sent) => WebSocketService(
  ip: '127.0.0.1',
  token: 'token',
  autoReconnect: false,
  lanDirectV1: true,
  webRtcDirectV1: false,
  sendFrameForTest: (frame) {
    sent.add(Map<String, dynamic>.from(frame));
    return true;
  },
);

Future<void> _flushAcks() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'osia_token': 'token',
    });
  });

  test('durable duplicate is projected once and ACKed again', () async {
    final sent = <Map<String, dynamic>>[];
    final service = _service(sent);
    final events = <ConvStreamEvent>[];
    final subscription = service.convStreamStream.listen(events.add);
    final accepted = _event('turn_accepted', 1, recovered: true);
    final chunk = _event('response_chunk', 2, content: 'durable delta');

    service.handleIncomingFrameForTest(accepted);
    service.handleIncomingFrameForTest(accepted);
    service.handleIncomingFrameForTest(chunk);
    service.handleIncomingFrameForTest(chunk);
    await _flushAcks();

    expect(service.isSamePendingRequest(_conversationId, _requestId), isTrue);
    expect(sent.where((frame) => frame['type'] == 'event_ack'), hasLength(4));
    expect(
      events.where((event) => event.delta == 'durable delta'),
      hasLength(1),
    );

    await subscription.cancel();
    service.dispose();
  });

  test('sequence gap requests exact suffix before later projection', () async {
    final sent = <Map<String, dynamic>>[];
    final service = _service(sent);

    service.handleIncomingFrameForTest(
      _event('turn_accepted', 1, recovered: true),
    );
    service.handleIncomingFrameForTest(
      _event('turn_status', 3, status: 'waiting_verification'),
    );
    await _flushAcks();

    final replayRequests = sent
        .where((frame) => frame['type'] == 'event_replay_request')
        .toList();
    expect(replayRequests, hasLength(1));
    expect(replayRequests.single['stream_id'], _streamId);
    expect(replayRequests.single['after_sequence'], 1);
    expect(service.isConversationWaiting(_conversationId), isFalse);

    service.handleIncomingFrameForTest(
      _event('turn_status', 2, status: 'working', replayed: true),
    );
    service.handleIncomingFrameForTest(
      _event('turn_status', 3, status: 'waiting_verification', replayed: true),
    );
    await _flushAcks();

    expect(service.isConversationWaiting(_conversationId), isTrue);
    expect(
      sent.where(
        (frame) => frame['type'] == 'event_ack' && frame['sequence'] == 3,
      ),
      hasLength(1),
    );
    service.dispose();
  });

  test('reconnect cursor accepts and ACKs only the missing suffix', () async {
    final sent = <Map<String, dynamic>>[];
    final service = _service(sent);

    service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'event_transport_context',
      'schema_version': 1,
      'client_id': 'client-wor269-mobile',
      'cursors': <String, int>{_streamId: 5},
    });
    service.handleIncomingFrameForTest(
      _event('action_truth_changed', 6, replayed: true),
    );
    await _flushAcks();

    expect(
      sent.where(
        (frame) => frame['type'] == 'event_ack' && frame['sequence'] == 6,
      ),
      hasLength(1),
    );
    expect(service.isConversationWorkActive(_conversationId), isFalse);
    service.dispose();
  });

  test('event id collision across streams is rejected without ACK', () async {
    final sent = <Map<String, dynamic>>[];
    final service = _service(sent);
    final first = _event('turn_accepted', 1, recovered: true);
    final conflicting = Map<String, dynamic>.from(first)
      ..['stream_id'] = 'stream-wor269-conflict';

    service.handleIncomingFrameForTest(first);
    service.handleIncomingFrameForTest(conflicting);
    await _flushAcks();

    expect(sent.where((frame) => frame['type'] == 'event_ack'), hasLength(1));
    expect(
      sent.singleWhere((frame) => frame['type'] == 'event_ack')['stream_id'],
      _streamId,
    );
    service.dispose();
  });

  test(
    'historical terminal is ACKed without reanimating old activity',
    () async {
      final sent = <Map<String, dynamic>>[];
      final service = _service(sent);
      final events = <ConvStreamEvent>[];
      final subscription = service.convStreamStream.listen(events.add);

      service.handleIncomingFrameForTest(
        _event(
          'turn_status',
          1,
          requestId: 'request-old-wor269',
          turnId: 'turn-old-wor269',
          runId: 'run-old-wor269',
          status: 'done',
          replayed: true,
          historical: true,
          terminal: true,
        ),
      );
      await _flushAcks();

      expect(events, isEmpty);
      expect(service.isConversationWorkActive(_conversationId), isFalse);
      expect(sent.where((frame) => frame['type'] == 'event_ack'), hasLength(1));

      await subscription.cancel();
      service.dispose();
    },
  );

  test('historical media cleanup releases only the owned completed turn', () async {
    final sent = <Map<String, dynamic>>[];
    final service = _service(sent);
    expect(
      service.sendText(
        'first',
        conversationId: _conversationId,
        clientRequestId: _requestId,
      ),
      isTrue,
    );
    service.handleIncomingFrameForTest(_event('turn_accepted', 1));
    service.handleIncomingFrameForTest(
      _event('turn_status', 2, status: 'working'),
    );
    final done = _event('turn_status', 3, status: 'done', terminal: true)
      ..['message_id'] = 'message-owned';
    service.handleIncomingFrameForTest(done);
    expect(service.isConversationBusy(_conversationId), isTrue);
    expect(service.isConversationWorkActive(_conversationId), isFalse);

    service.handleIncomingFrameForTest(
      _event(
        'media_status',
        1,
        requestId: 'request-stale-wor269-mobile',
        turnId: 'turn-stale-wor269-mobile',
        runId: 'run-stale-wor269-mobile',
        replayed: true,
        historical: true,
      )
        ..['stream_id'] = 'stream-stale-wor269-mobile'
        ..['message_id'] = 'message-owned'
        ..['media_terminal'] = true,
    );
    expect(service.isConversationBusy(_conversationId), isTrue);

    final media = _event(
      'media_status',
      4,
      replayed: true,
      historical: true,
    )
      ..['message_id'] = 'message-owned'
      ..['media_terminal'] = true
      ..['status'] = 'done';
    service.handleIncomingFrameForTest(media);
    service.handleIncomingFrameForTest(
      _event('conversation_busy_changed', 5, replayed: true, historical: true)
        ..['busy'] = false,
    );
    await _flushAcks();

    expect(service.isConversationBusy(_conversationId), isFalse);
    expect(
      service.sendText(
        'next',
        conversationId: _conversationId,
        clientRequestId: 'request-next-wor269-mobile',
      ),
      isTrue,
    );
    expect(
      sent.where((frame) => frame['type'] == 'event_ack'),
      hasLength(5),
    );
    service.dispose();
  });
}
