import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  test('turn frames carry an optional normalized client locale', () {
    final frames = <Map<String, dynamic>>[];
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'test-token',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        frames.add(frame);
        return true;
      },
    );
    addTearDown(service.dispose);

    service.setClientLocale('fr_FR.UTF-8');
    expect(
      service.sendText(
        'bonjour',
        conversationId: 'conv-text',
        clientRequestId: 'req-text',
      ),
      isTrue,
    );
    expect(
      service.sendAttachmentTurn(
        'pièce jointe',
        attachmentBatchId: 'batch-one',
        conversationId: 'conv-file',
        clientRequestId: 'req-file',
      ),
      isTrue,
    );
    expect(
      service.sendAudio(
        'd2F2',
        conversationId: 'conv-audio',
        clientRequestId: 'req-audio',
      ),
      isTrue,
    );
    service.sendAutonomousStart('Faire le travail', 'test-model');

    expect(frames, hasLength(4));
    expect(frames.every((frame) => frame['locale'] == 'fr-fr'), isTrue);

    service.setClientLocale('../../fr');
    service.sendText(
      'fallback',
      conversationId: 'conv-fallback',
      clientRequestId: 'req-fallback',
    );
    expect(frames.last.containsKey('locale'), isFalse);
  });

  test(
    'canonical response replaces provisional text without duplication',
    () async {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'test-token',
        autoReconnect: false,
      );
      addTearDown(service.dispose);
      const conversationId = 'conv-canonical';
      const requestId = 'req-canonical';
      const turnId = 'turn-canonical';
      const messageId = 'message-canonical';
      service.rememberRequestForTest(conversationId, requestId);

      Map<String, dynamic> frame(
        String type,
        int sequence, {
        String? content,
        bool terminal = false,
      }) => <String, dynamic>{
        'type': type,
        'event_type': type,
        'conversation_id': conversationId,
        'request_id': requestId,
        'client_request_id': requestId,
        'turn_id': turnId,
        'message_id': messageId,
        'event_id': 'event-$sequence',
        'sequence': sequence,
        'terminal': terminal,
        'content': ?content,
        if (type == 'turn_status') 'status': 'done',
      };

      service.handleIncomingFrameForTest(
        frame('response_chunk', 1, content: 'Provisional draft.'),
      );
      service.handleIncomingFrameForTest(
        frame('response', 2, content: 'Canonical final.'),
      );
      service.handleIncomingFrameForTest(
        frame('turn_status', 3, terminal: true),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.bufferedText(conversationId), 'Canonical final.');
      expect(
        service.bufferedText(conversationId),
        isNot(contains('Provisional')),
      );
      expect(service.isStreaming(conversationId), isFalse);
    },
  );
}
