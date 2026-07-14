import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  test(
    'attachment acknowledgements use their standalone protocol stream',
    () async {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'public-token',
        autoReconnect: false,
      );
      addTearDown(service.dispose);
      final protocol = <AttachmentProtocolMessage>[];
      final ordinary = <OsiaMessage>[];
      final protocolSub = service.attachmentProtocolStream.listen(protocol.add);
      final ordinarySub = service.messageStream.listen(ordinary.add);
      addTearDown(protocolSub.cancel);
      addTearDown(ordinarySub.cancel);

      service.handleRelayEnvelopeForTest({
        'type': 'FRAME',
        'payload': {
          'frame': {
            'type': 'attachment_batch_commit_ack',
            'batch_id': 'batch_public',
            'client_request_id': 'request_public',
            'file_count': 1,
            'aggregate_size': 6,
          },
        },
      });
      await Future<void>.delayed(Duration.zero);

      expect(protocol, hasLength(1));
      expect(protocol.single.data['batch_id'], 'batch_public');
      expect(ordinary, isEmpty);
    },
  );

  test(
    'attachment events refuse unavailable sessions and unknown event types',
    () async {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'public-token',
        autoReconnect: false,
      );
      addTearDown(service.dispose);

      expect(service.attachmentTransportSession, isEmpty);
      expect(
        service.sendAttachmentTurn(
          'public prompt',
          attachmentBatchId: 'batch_public',
          conversationId: 'conv_public',
          clientRequestId: 'request_public',
          expectedTransportSession: 'lan:public',
        ),
        isFalse,
      );
      expect(
        await service.sendAttachmentEvent(const {
          'type': 'attachment_batch_prepare',
        }, ''),
        isFalse,
      );
      expect(
        await service.sendAttachmentEvent(const {
          'type': 'text',
        }, 'relay:public'),
        isFalse,
      );
    },
  );
}
