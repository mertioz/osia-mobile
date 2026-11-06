import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  const screenshotId = '0123456789abcdef0123456789abcdef';

  test(
    'chat history and the live final response carry screenshot references',
    () async {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'test-token',
        autoReconnect: false,
      );
      addTearDown(service.dispose);
      final stream = <ConvStreamEvent>[];
      final subscription = service.convStreamStream.listen(stream.add);
      addTearDown(subscription.cancel);
      const screenshots = [
        {'id': screenshotId, 'width': 100, 'height': 80},
      ];
      final history = HistoryMessage.fromJson({
        'role': 'assistant',
        'content': 'Result',
        'message_id': 'assistant-id',
        'screenshots': screenshots,
      });
      expect(history.screenshotIds, [screenshotId]);

      service.rememberRequestForTest('conv-a', 'request-a');
      service.handleIncomingFrameForTest({
        'type': 'response',
        'event_type': 'response',
        'event_id': 'event-a',
        'sequence': 1,
        'conversation_id': 'conv-a',
        'request_id': 'request-a',
        'client_request_id': 'request-a',
        'turn_id': 'turn-a',
        'message_id': 'assistant-id',
        'content': 'Result',
        'screenshots': screenshots,
      });
      await Future<void>.delayed(Duration.zero);
      expect(stream.single.messageId, 'assistant-id');
      expect(stream.single.screenshotIds, [screenshotId]);
    },
  );

  test(
    'screenshot download accepts only the exact request and ordered chunks',
    () async {
      final sent = <Map<String, dynamic>>[];
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'test-token',
        autoReconnect: false,
        sendFrameForTest: (frame) {
          sent.add(frame);
          return true;
        },
      );
      addTearDown(service.dispose);
      final preview = service.requestChatScreenshot(
        conversationId: 'conv-a',
        turnId: 'turn-a',
        messageId: 'assistant-id',
        screenshotId: screenshotId,
      );
      expect(sent.single['type'], 'get_chat_screenshot');
      final frame = {
        ...sent.single,
        'type': 'chat_screenshot_chunk',
        'count': 2,
      };
      service.handleIncomingFrameForTest({
        ...frame,
        'turn_id': 'different-turn',
        'index': 0,
        'data': base64Encode([99]),
      });
      service.handleIncomingFrameForTest({
        ...frame,
        'index': 0,
        'data': base64Encode([1, 2]),
      });
      service.handleIncomingFrameForTest({
        ...frame,
        'index': 1,
        'data': base64Encode([3, 4]),
      });
      expect(await preview, [1, 2, 3, 4]);
    },
  );
}
