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

  test('relay final frames clear busy and streaming state', () async {
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
    );
    addTearDown(service.dispose);

    final events = <ConvStreamEvent>[];
    final sub = service.convStreamStream.listen(events.add);
    addTearDown(sub.cancel);

    void startTurn(String id) {
      service.handleConversationBusyFrameForTest({
        'type': 'conversation_busy_changed',
        'conversation_id': id,
        'busy': true,
      });
      service.markPending(id);
      service.handleRelayEnvelopeForTest({
        'type': 'FRAME',
        'payload': {
          'frame': {
            'type': 'response_chunk',
            'conversation_id': id,
            'content': 'hello',
          },
        },
      });
    }

    void relayFrame(Map<String, Object?> frame) {
      service.handleRelayEnvelopeForTest({
        'type': 'FRAME',
        'payload': {'frame': frame},
      });
    }

    startTurn('conv-done');
    await Future<void>.delayed(Duration.zero);
    expect(service.isConversationBusy('conv-done'), isTrue);
    expect(service.isPending('conv-done'), isTrue);
    expect(service.isStreaming('conv-done'), isTrue);

    relayFrame({
      'type': 'status',
      'conversation_id': 'conv-done',
      'content': 'done',
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.isConversationBusy('conv-done'), isFalse);
    expect(service.isPending('conv-done'), isFalse);
    expect(service.isStreaming('conv-done'), isFalse);
    expect(events.last.conversationId, 'conv-done');
    expect(events.last.done, isTrue);

    startTurn('conv-error');
    await Future<void>.delayed(Duration.zero);
    relayFrame({
      'type': 'status',
      'conversation_id': 'conv-error',
      'content': 'error',
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.isConversationBusy('conv-error'), isFalse);
    expect(service.isPending('conv-error'), isFalse);
    expect(service.isStreaming('conv-error'), isFalse);
    expect(events.last.conversationId, 'conv-error');
    expect(events.last.error, isTrue);

    startTurn('conv-busy-false');
    await Future<void>.delayed(Duration.zero);
    relayFrame({
      'type': 'conversation_busy_changed',
      'conversation_id': 'conv-busy-false',
      'busy': false,
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.isConversationBusy('conv-busy-false'), isFalse);
    expect(service.isPending('conv-busy-false'), isFalse);
    expect(service.isStreaming('conv-busy-false'), isFalse);
    expect(events.last.conversationId, 'conv-busy-false');
    expect(events.last.done, isTrue);

    startTurn('conv-response-done');
    await Future<void>.delayed(Duration.zero);
    relayFrame({
      'type': 'response_done',
      'conversation_id': 'conv-response-done',
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.isConversationBusy('conv-response-done'), isFalse);
    expect(service.isPending('conv-response-done'), isFalse);
    expect(service.isStreaming('conv-response-done'), isFalse);
    expect(events.last.conversationId, 'conv-response-done');
    expect(events.last.done, isTrue);
  });

  test(
    'cron notification frames use standalone stream and dedupe ids',
    () async {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
      );
      addTearDown(service.dispose);

      final events = <CronNotificationMessage>[];
      final sub = service.cronNotificationStream.listen(events.add);
      addTearDown(sub.cancel);

      final frame = {
        'type': 'cron_notification',
        'id': 'note-1',
        'task_id': 'cron_abc',
        'title': 'Daily check',
        'status': 'completed',
        'conversation_id': 'conv-a',
        'created_at': '2026-07-07T12:00:00+02:00',
      };
      service.handleIncomingFrameForTest(frame);
      service.handleIncomingFrameForTest(frame);
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.id, 'note-1');
      expect(events.single.taskId, 'cron_abc');
      expect(events.single.title, 'Daily check');
      expect(events.single.status, 'completed');
      expect(events.single.failed, isFalse);
      expect(events.single.conversationId, 'conv-a');
    },
  );

  test('config cron jobs preserve conversation and model metadata', () {
    final config = ConfigData.fromJson({
      'cron_jobs': [
        {
          'id': 'cron_abc',
          'title': 'Daily check',
          'task': 'Do the thing',
          'schedule': 'at 15:06',
          'enabled': true,
          'conversation_id': 'conv-a',
          'model': {
            'provider': 'anthropic',
            'id': 'claude-opus-4-8',
            'label': 'Claude Opus 4.8',
          },
        },
      ],
    });

    expect(config.cronJobs, hasLength(1));
    expect(config.cronJobs.single['conversation_id'], 'conv-a');
    expect(config.cronJobs.single['model'], isA<Map<String, dynamic>>());
    expect(
      (config.cronJobs.single['model'] as Map<String, dynamic>)['id'],
      'claude-opus-4-8',
    );
  });

  test('relay batch processes response content before final frame', () async {
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
    );
    addTearDown(service.dispose);

    final events = <ConvStreamEvent>[];
    final sub = service.convStreamStream.listen(events.add);
    addTearDown(sub.cancel);

    const id = 'conv-batch-order';
    service.handleConversationBusyFrameForTest({
      'type': 'conversation_busy_changed',
      'conversation_id': id,
      'busy': true,
    });
    service.markPending(id);

    service.handleRelayEnvelopeForTest({
      'type': 'BATCH',
      'payload': {
        'frames': [
          {'type': 'response_chunk', 'conversation_id': id, 'content': 'hello'},
          {'type': 'status', 'conversation_id': id, 'content': 'done'},
        ],
      },
    });
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(2));
    expect(events.first.delta, 'hello');
    expect(events.last.done, isTrue);
    expect(service.bufferedText(id), 'hello');
    expect(service.isConversationBusy(id), isFalse);
    expect(service.isPending(id), isFalse);
    expect(service.isStreaming(id), isFalse);
  });

  test(
    'turn accepted marks request accepted and final clears active retry',
    () async {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
      );
      addTearDown(service.dispose);

      final messages = <OsiaMessage>[];
      final sub = service.messageStream.listen(messages.add);
      addTearDown(sub.cancel);

      service.handleIncomingFrameForTest({
        'type': 'turn_accepted',
        'conversation_id': 'conv-ack',
        'client_request_id': 'req-ack',
        'turn_id': 'turn-ack',
        'persisted': true,
      });
      await Future<void>.delayed(Duration.zero);

      expect(service.isRequestAccepted('req-ack'), isTrue);
      expect(service.isSamePendingRequest('conv-ack', 'req-ack'), isTrue);
      expect(service.isConversationBusy('conv-ack'), isTrue);
      expect(service.isPending('conv-ack'), isTrue);
      expect(messages.single, isA<TurnAcceptedMessage>());
      final accepted = messages.single as TurnAcceptedMessage;
      expect(accepted.clientRequestId, 'req-ack');
      expect(accepted.persisted, isTrue);

      service.handleIncomingFrameForTest({
        'type': 'status',
        'conversation_id': 'conv-ack',
        'content': 'done',
        'client_request_id': 'req-ack',
        'turn_id': 'turn-ack',
      });
      await Future<void>.delayed(Duration.zero);

      expect(service.isConversationBusy('conv-ack'), isFalse);
      expect(service.isPending('conv-ack'), isFalse);
      expect(service.isSamePendingRequest('conv-ack', 'req-ack'), isFalse);
    },
  );
}
