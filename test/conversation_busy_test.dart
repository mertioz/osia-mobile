import 'package:flutter_test/flutter_test.dart';

import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  test('WebSocketService parses busy frames and refuses busy sends', () async {
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
    );
    addTearDown(service.dispose);

    final events = <ConversationBusyEvent>[];
    final sub = service.conversationBusyStream.listen(events.add);
    addTearDown(sub.cancel);

    service.handleConversationBusyFrameForTest({
      'type': 'conversation_busy_changed',
      'conversation_id': 'conv-a',
      'busy': true,
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.isConversationBusy('conv-a'), isTrue);
    expect(events.single.conversationId, 'conv-a');
    expect(events.single.busy, isTrue);
    expect(service.sendText('second', conversationId: 'conv-a'), isFalse);

    service.handleConversationBusyFrameForTest({
      'type': 'conversation_busy_changed',
      'conversation_id': 'conv-a',
      'busy': false,
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.isConversationBusy('conv-a'), isFalse);
  });
}
