import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart';

Map<String, dynamic> _frame(
  String type,
  int sequence, {
  Map<String, dynamic> payload = const <String, dynamic>{},
}) {
  return <String, dynamic>{
    'type': type,
    'event_type': type,
    'event_id': 'event-$sequence',
    'sequence': sequence,
    'terminal': type == 'turn_status' && payload['status'] == 'done',
    'conversation_id': 'conv-wor55',
    'request_id': 'request-wor55',
    'client_request_id': 'request-wor55',
    'turn_id': 'turn-wor55',
    'message_id': type == 'turn_accepted' ? 'user-wor55' : 'assistant-wor55',
    ...payload,
  };
}

void main() {
  test(
    'ordered nonterminal audio chunks remain owned until media terminal',
    () async {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
        lanDirectV1: true,
        webRtcDirectV1: false,
      );
      addTearDown(service.dispose);
      final messages = <OsiaMessage>[];
      final sub = service.messageStream.listen(messages.add);
      addTearDown(sub.cancel);
      service.rememberRequestForTest('conv-wor55', 'request-wor55');

      service.handleIncomingFrameForTest(
        _frame(
          'turn_accepted',
          1,
          payload: <String, dynamic>{'persisted': true},
        ),
      );
      service.handleIncomingFrameForTest(
        _frame(
          'audio',
          2,
          payload: <String, dynamic>{
            'data': 'Zmlyc3Q=',
            'source': 'response',
            'media_terminal': false,
          },
        ),
      );
      service.handleIncomingFrameForTest(
        _frame(
          'audio',
          3,
          payload: <String, dynamic>{
            'data': 'c2Vjb25k',
            'source': 'response',
            'media_terminal': false,
          },
        ),
      );
      service.handleIncomingFrameForTest(
        _frame(
          'response',
          4,
          payload: <String, dynamic>{'content': 'First. Second. Tail'},
        ),
      );
      service.handleIncomingFrameForTest(
        _frame(
          'turn_status',
          5,
          payload: <String, dynamic>{'status': 'done', 'persisted': true},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.isConversationBusy('conv-wor55'), isTrue);

      service.handleIncomingFrameForTest(
        _frame(
          'audio',
          6,
          payload: <String, dynamic>{
            'data': 'dGFpbA==',
            'source': 'response',
            'media_terminal': true,
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final audio = messages.whereType<AudioMessage>().toList();
      expect(audio.map((item) => item.data), <String>[
        'Zmlyc3Q=',
        'c2Vjb25k',
        'dGFpbA==',
      ]);
      expect(
        audio.every(
          (item) =>
              item.clientRequestId == 'request-wor55' &&
              item.turnId == 'turn-wor55' &&
              item.messageId == 'assistant-wor55',
        ),
        isTrue,
      );
      expect(service.isConversationBusy('conv-wor55'), isFalse);
    },
  );
}
