import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;

Map<String, dynamic> _legacyReplayHistory({
  required String conversationId,
  required String requestId,
  String turnId = 'turn-legacy-audio',
  bool replayed = true,
  bool legacyRouteUnavailable = true,
  List<Map<String, dynamic>>? messages,
}) => <String, dynamic>{
  'type': 'conversation_history',
  'id': conversationId,
  'conversation_id': conversationId,
  'replayed': replayed,
  'legacy_route_unavailable': legacyRouteUnavailable,
  'request_id': requestId,
  'client_request_id': requestId,
  'messages':
      messages ??
      <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'user',
          'content': 'legacy transcript',
          'conversation_id': conversationId,
          'request_id': requestId,
          'client_request_id': requestId,
          'turn_id': turnId,
          'message_id': 'message-user',
        },
        <String, dynamic>{
          'role': 'assistant',
          'content': 'persisted answer',
          'conversation_id': conversationId,
          'request_id': requestId,
          'client_request_id': requestId,
          'turn_id': turnId,
          'message_id': 'message-assistant',
        },
      ],
};

ws.WebSocketService _service() => ws.WebSocketService(
  ip: '127.0.0.1',
  token: 'wor265-test-token',
  autoReconnect: false,
  sendFrameForTest: (_) => true,
);

void main() {
  test(
    'exact legacy audio replay history parses its proof and releases busy',
    () async {
      const conversationId = 'conv-wor265-legacy-audio';
      const requestId = 'req-wor265-legacy-audio';
      final service = _service();
      addTearDown(service.dispose);
      final historyFuture = service.messageStream
          .where((message) => message is ws.ConversationHistoryMessage)
          .cast<ws.ConversationHistoryMessage>()
          .first;

      expect(
        service.sendAudio(
          'AA==',
          conversationId: conversationId,
          clientRequestId: requestId,
        ),
        isTrue,
      );
      expect(service.isConversationBusy(conversationId), isTrue);

      service.handleIncomingFrameForTest(
        _legacyReplayHistory(
          conversationId: conversationId,
          requestId: requestId,
        ),
      );

      expect(service.isConversationBusy(conversationId), isFalse);
      final history = await historyFuture.timeout(const Duration(seconds: 1));
      expect(history.id, conversationId);
      expect(history.requestId, requestId);
      expect(history.replayed, isTrue);
      expect(history.legacyRouteUnavailable, isTrue);
      expect(
        history.messages.map((message) => message.clientRequestId),
        everyElement(requestId),
      );
    },
  );

  test('legacy replay cannot release a newer request in the same chat', () {
    const conversationId = 'conv-wor265-newer-request';
    const oldRequestId = 'req-wor265-old';
    const newRequestId = 'req-wor265-new';
    final service = _service();
    addTearDown(service.dispose);

    expect(
      service.sendAudio(
        'AA==',
        conversationId: conversationId,
        clientRequestId: oldRequestId,
      ),
      isTrue,
    );
    service.rememberRequestForTest(conversationId, newRequestId);

    service.handleIncomingFrameForTest(
      _legacyReplayHistory(
        conversationId: conversationId,
        requestId: oldRequestId,
      ),
    );

    expect(service.isConversationBusy(conversationId), isTrue);
    expect(service.isSamePendingRequest(conversationId, newRequestId), isTrue);
  });

  test('legacy replay fails closed unless the persisted pair is exact', () {
    const conversationId = 'conv-wor265-invalid-proof';
    const requestId = 'req-wor265-invalid-proof';
    final invalidFrames = <Map<String, dynamic>>[
      _legacyReplayHistory(
        conversationId: conversationId,
        requestId: requestId,
        replayed: false,
      ),
      _legacyReplayHistory(
        conversationId: conversationId,
        requestId: requestId,
        messages: <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'user',
            'content': 'legacy transcript',
            'conversation_id': conversationId,
            'request_id': requestId,
            'turn_id': 'turn-user-only',
            'message_id': 'message-user-only',
          },
        ],
      ),
      _legacyReplayHistory(
        conversationId: conversationId,
        requestId: requestId,
        messages: <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'user',
            'content': 'legacy transcript',
            'conversation_id': conversationId,
            'request_id': requestId,
            'turn_id': 'turn-user',
            'message_id': 'message-user',
          },
          <String, dynamic>{
            'role': 'assistant',
            'content': 'persisted answer',
            'conversation_id': conversationId,
            'request_id': requestId,
            'turn_id': 'turn-assistant',
            'message_id': 'message-assistant',
          },
        ],
      ),
      _legacyReplayHistory(
        conversationId: conversationId,
        requestId: requestId,
        messages: <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'assistant',
            'content': 'persisted answer',
            'conversation_id': conversationId,
            'request_id': requestId,
            'turn_id': 'turn-reversed',
            'message_id': 'message-assistant',
          },
          <String, dynamic>{
            'role': 'user',
            'content': 'legacy transcript',
            'conversation_id': conversationId,
            'request_id': requestId,
            'turn_id': 'turn-reversed',
            'message_id': 'message-user',
          },
        ],
      ),
    ];

    for (final frame in invalidFrames) {
      final service = _service();
      expect(
        service.sendAudio(
          'AA==',
          conversationId: conversationId,
          clientRequestId: requestId,
        ),
        isTrue,
      );
      service.handleIncomingFrameForTest(frame);
      expect(service.isConversationBusy(conversationId), isTrue);
      service.dispose();
    }
  });
}
