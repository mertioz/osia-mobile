import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  test('text and attachment retry payloads carry exact optional directives', () {
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
    final directives = <String, dynamic>{
      'schema_version': 1,
      'connector_hints': const <dynamic>[],
      'capability_requirements': <String, dynamic>{'current_web': true},
      'conversation_refs': const <dynamic>[],
      'reasoning_override': 'high',
    };

    expect(
      service.sendText(
        'current news',
        conversationId: 'conv-2',
        clientRequestId: 'req-1',
        turnDirectives: directives,
      ),
      isTrue,
    );
    expect(
      service.sendAttachmentTurn(
        'inspect',
        attachmentBatchId: 'batch-1',
        conversationId: 'conv-1',
        clientRequestId: 'req-2',
        turnDirectives: directives,
      ),
      isTrue,
    );
    expect(frames, hasLength(2));
    expect(frames[0]['turn_directives'], directives);
    expect(frames[1]['turn_directives'], directives);
    expect(frames[0]['type'], 'text');
    expect(frames[1]['type'], 'text');
    directives['capability_requirements']['current_web'] = false;
    expect(
      frames[0]['turn_directives']['capability_requirements']['current_web'],
      isTrue,
    );
    expect(
      () =>
          frames[0]['turn_directives']['capability_requirements']['current_web'] =
              false,
      throwsUnsupportedError,
    );
  });

  test('normal turns keep the legacy text frame byte-shape additive', () {
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
    service.sendText(
      'ordinary',
      conversationId: 'conv-1',
      clientRequestId: 'req-normal',
    );
    expect(frames.single.containsKey('turn_directives'), isFalse);
  });
}
