import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  test('obsolete mouse flags are inert and keep the conversation readable', () {
    final old = Conversation.fromJson({'id': 'old', 'special_mode': true});
    expect(old.id, 'old');
    expect(old.controlDisabled, isFalse);
    final config = ConfigData.fromJson({
      'chat_slash_extensions': 1,
      'conversation_mouse_control': true,
    });
    expect(config.chatSlashExtensions, isTrue);
    expect(config.conversationControl, isFalse);
    expect(config.conversationContextCompaction, isFalse);
  });

  test('control persists only after the exact PC acknowledgement', () async {
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
    final pending = service.setConversationControl(
      conversationId: 'conv-1',
      disabled: true,
    );
    final request = frames.single;
    expect(request['type'], 'set_conversation_control');
    expect(request['disabled'], isTrue);
    expect(request['operation_id'], startsWith('control_'));
    service.handleIncomingFrameForTest({
      'type': 'conversations',
      'operation_id': 'other-operation',
      'control_conversation_id': 'conv-1',
      'items': [
        {'id': 'conv-1', 'control_disabled': true},
      ],
    });
    service.handleIncomingFrameForTest({
      'type': 'conversations',
      'operation_id': request['operation_id'],
      'control_conversation_id': 'conv-1',
      'items': [
        {'id': 'conv-1', 'control_disabled': true},
      ],
    });
    expect((await pending).controlDisabled, isTrue);

    final enabled = service.setConversationControl(
      conversationId: 'conv-1',
      disabled: false,
    );
    service.handleIncomingFrameForTest({
      'type': 'conversations',
      'operation_id': frames.last['operation_id'],
      'control_conversation_id': 'conv-1',
      'items': [
        {'id': 'conv-1', 'control_disabled': false},
      ],
    });
    expect((await enabled).controlDisabled, isFalse);
  });

  test(
    'control errors and wrong conversation cannot fabricate a mode change',
    () async {
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
      final pending = service.setConversationControl(
        conversationId: 'conv-1',
        disabled: true,
      );
      final rejected = expectLater(pending, throwsStateError);
      service.handleIncomingFrameForTest({
        'type': 'conversations',
        'operation_id': frames.last['operation_id'],
        'control_conversation_id': 'conv-2',
        'items': [
          {'id': 'conv-2', 'control_disabled': true},
        ],
      });
      await rejected;
      final busy = service.setConversationControl(
        conversationId: 'conv-1',
        disabled: true,
      );
      final failed = expectLater(
        busy,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'reason',
            'conversation_busy',
          ),
        ),
      );
      service.handleIncomingFrameForTest({
        'type': 'conversations',
        'operation_id': frames.last['operation_id'],
        'control_conversation_id': 'conv-1',
        'control_error': 'conversation_busy',
        'items': [],
      });
      await failed;
      expect(
        ConfigData.fromJson({'conversation_control': true}).conversationControl,
        isTrue,
      );
    },
  );

  test('control can create a new conversation from the PC snapshot', () async {
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
    final pending = service.setConversationControl(
      conversationId: null,
      disabled: true,
    );
    expect(frames.single['conversation_id'], '');
    service.handleIncomingFrameForTest({
      'type': 'conversations',
      'operation_id': frames.single['operation_id'],
      'control_conversation_id': 'pc-created',
      'items': [
        {'id': 'pc-created', 'control_disabled': true},
      ],
    });
    expect((await pending).id, 'pc-created');
  });

  test('context compaction waits for the exact PC acknowledgement', () async {
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
    final pending = service.compactConversationContext('conv-1');
    final request = frames.single;
    expect(request['type'], 'compact_conversation_context');
    expect(request['conversation_id'], 'conv-1');
    service.handleIncomingFrameForTest({
      'type': 'conversations',
      'operation_id': 'unrelated',
      'compact_conversation_id': 'conv-2',
      'compact_changed': false,
      'items': [],
    });
    service.handleIncomingFrameForTest({
      'type': 'conversations',
      'operation_id': request['operation_id'],
      'compact_conversation_id': 'conv-1',
      'compact_changed': true,
      'items': [],
    });
    expect(await pending, isTrue);
    expect(ConfigData.fromJson({}).conversationContextCompaction, isFalse);
    expect(
      ConfigData.fromJson({
        'conversation_context_compaction': true,
      }).conversationContextCompaction,
      isTrue,
    );
  });

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
