import 'package:flutter_test/flutter_test.dart';

import 'package:osia_mobile/screens/providers_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart';

int _canonicalSequence = 0;

Map<String, dynamic> _canonicalFrame(Map<String, Object?> frame) {
  final sequence = ++_canonicalSequence;
  final type = frame['type']?.toString() ?? '';
  final conversationId = frame['conversation_id']?.toString() ?? '';
  final requestId =
      frame['client_request_id']?.toString() ?? 'req-$conversationId';
  final turnId = frame['turn_id']?.toString() ?? 'turn-$conversationId';
  final runId = frame['run_id']?.toString() ?? 'run-$conversationId';
  final providerId = frame['provider_id']?.toString() ?? 'provider-test';
  final modelId = frame['model_id']?.toString() ?? 'model-test';
  final effectiveReasoning =
      frame['effective_reasoning']?.toString() ?? 'medium';
  final eventId = type == 'cron_notification'
      ? frame['id']?.toString() ?? ''
      : 'event-$sequence';
  final terminal = switch (type) {
    'cron_notification' => true,
    'status' => frame['content'] == 'done' || frame['content'] == 'error',
    'conversation_busy_changed' => frame['busy'] == false,
    _ => false,
  };
  return <String, dynamic>{
    ...frame,
    'request_id': requestId,
    'client_request_id': requestId,
    'turn_id': turnId,
    'run_id': runId,
    'provider_id': providerId,
    'model_id': modelId,
    'effective_reasoning': effectiveReasoning,
    'message_id': type == 'cron_notification' ? eventId : 'message-$sequence',
    'event_id': eventId,
    'event_type': type,
    'sequence': sequence,
    'terminal': terminal,
  };
}

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
      service.rememberRequestForTest(id, 'req-$id');
      service.handleConversationBusyFrameForTest({
        'type': 'conversation_busy_changed',
        'conversation_id': id,
        'busy': true,
      });
      service.markPending(id);
      service.handleRelayEnvelopeForTest({
        'type': 'FRAME',
        'payload': {
          'frame': _canonicalFrame({
            'type': 'response_chunk',
            'conversation_id': id,
            'content': 'hello',
          }),
        },
      });
    }

    void relayFrame(Map<String, Object?> frame) {
      service.handleRelayEnvelopeForTest({
        'type': 'FRAME',
        'payload': {'frame': _canonicalFrame(frame)},
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

      final frame = _canonicalFrame({
        'type': 'cron_notification',
        'id': 'note-1',
        'task_id': 'cron_abc',
        'title': 'Daily check',
        'status': 'completed',
        'conversation_id': 'conv-a',
        'created_at': '2026-07-07T12:00:00+02:00',
      });
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

  test(
    'scheduled task settings payload preserves model and server metadata',
    () {
      final initial = <String, dynamic>{
        'id': 'cron_abc',
        'title': 'Daily check',
        'task': 'Old task',
        'schedule': 'at 15:06',
        'enabled': true,
        'conversation_id': 'conv-a',
        'next_run_at': '2026-07-07T15:06',
        'model': {
          'provider': 'anthropic',
          'id': 'claude-opus-4-8',
          'label': 'Claude Opus 4.8',
        },
      };

      final saved = buildCronJobForSettingsSave(
        initialJob: initial,
        task: 'Updated task',
        schedule: 'every 2 hours',
        enabled: false,
        conversationId: 'conv-a',
        model: initial['model'] as Map<String, dynamic>,
      );

      expect(saved['task'], 'Updated task');
      expect(saved['schedule'], 'every 2 hours');
      expect(saved['enabled'], isFalse);
      expect(saved['conversation_id'], 'conv-a');
      expect(saved['next_run_at'], '2026-07-07T15:06');
      expect((saved['model'] as Map<String, dynamic>)['id'], 'claude-opus-4-8');
    },
  );

  test('scheduled task settings payload updates model metadata', () {
    final nextModel = cronModelMetadataForModelId('gpt-5.5', const [
      OsiaModel(id: 'gpt-5.5', label: 'GPT-5.5', provider: 'openai'),
    ]);

    final saved = buildCronJobForSettingsSave(
      initialJob: {
        'id': 'cron_abc',
        'task': 'Do it',
        'schedule': 'at 15:06',
        'conversation_id': 'conv-a',
        'next_run_at': '2026-07-07T15:06',
        'model': {
          'provider': 'anthropic',
          'id': 'claude-opus-4-8',
          'label': 'Claude Opus 4.8',
        },
      },
      task: 'Do it',
      schedule: 'at 15:06',
      enabled: true,
      conversationId: 'conv-a',
      model: nextModel,
    );

    expect((saved['model'] as Map<String, dynamic>)['provider'], 'openai');
    expect((saved['model'] as Map<String, dynamic>)['id'], 'gpt-5.5');
    expect(saved['conversation_id'], 'conv-a');
    expect(saved['next_run_at'], '2026-07-07T15:06');
  });

  test('scheduled task settings payload keeps legacy no-model task valid', () {
    final saved = buildCronJobForSettingsSave(
      initialJob: {
        'id': 'cron_legacy',
        'task': 'Legacy',
        'schedule': 'every 1 days',
        'next_run_at': '2026-07-08T12:00',
        'authorization_status': 'authorized',
        'authorization_bounds': <String, Object?>{'max_executions': 2},
        'grant_refs': <String>['obsolete-grant'],
      },
      task: 'Legacy',
      schedule: 'every 1 days',
      enabled: true,
      conversationId: null,
      model: null,
    );

    expect(saved.containsKey('model'), isFalse);
    expect(saved.containsKey('authorization_status'), isFalse);
    expect(saved.containsKey('authorization_bounds'), isFalse);
    expect(saved.containsKey('grant_refs'), isFalse);
    expect(saved['conversation_id'], isNull);
    expect(saved['next_run_at'], '2026-07-08T12:00');
  });

  test('scheduled task model metadata defaults from active model id', () {
    final meta = cronModelMetadataForModelId('claude-opus-4-8', const [
      OsiaModel(
        id: 'claude-opus-4-8',
        label: 'Claude Opus 4.8',
        provider: 'anthropic',
      ),
    ]);

    expect(meta, isNotNull);
    expect(meta!['provider'], 'anthropic');
    expect(meta['id'], 'claude-opus-4-8');
    expect(meta['label'], 'Claude Opus 4.8');
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
    service.rememberRequestForTest(id, 'req-$id');

    service.handleRelayEnvelopeForTest({
      'type': 'BATCH',
      'payload': {
        'frames': [
          _canonicalFrame({
            'type': 'response_chunk',
            'conversation_id': id,
            'content': 'hello',
          }),
          _canonicalFrame({
            'type': 'status',
            'conversation_id': id,
            'content': 'done',
          }),
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

      service.rememberRequestForTest('conv-ack', 'req-ack');
      service.handleIncomingFrameForTest(
        _canonicalFrame({
          'type': 'turn_accepted',
          'conversation_id': 'conv-ack',
          'client_request_id': 'req-ack',
          'turn_id': 'turn-ack',
          'persisted': true,
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.isRequestAccepted('req-ack'), isTrue);
      expect(service.isSamePendingRequest('conv-ack', 'req-ack'), isTrue);
      expect(service.isConversationBusy('conv-ack'), isTrue);
      expect(service.isPending('conv-ack'), isTrue);
      expect(messages.single, isA<TurnAcceptedMessage>());
      final accepted = messages.single as TurnAcceptedMessage;
      expect(accepted.clientRequestId, 'req-ack');
      expect(accepted.persisted, isTrue);

      service.handleIncomingFrameForTest(
        _canonicalFrame({
          'type': 'status',
          'conversation_id': 'conv-ack',
          'content': 'done',
          'client_request_id': 'req-ack',
          'turn_id': 'turn-ack',
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.isConversationBusy('conv-ack'), isFalse);
      expect(service.isPending('conv-ack'), isFalse);
      expect(service.isSamePendingRequest('conv-ack', 'req-ack'), isFalse);
    },
  );

  test(
    'progress and delayed full response stay correlated until terminal done',
    () async {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
      );
      addTearDown(service.dispose);

      final messages = <OsiaMessage>[];
      final streamEvents = <ConvStreamEvent>[];
      final msgSub = service.messageStream.listen(messages.add);
      final convSub = service.convStreamStream.listen(streamEvents.add);
      addTearDown(msgSub.cancel);
      addTearDown(convSub.cancel);

      service.rememberRequestForTest('conv-long', 'req-long');
      service.handleIncomingFrameForTest(
        _canonicalFrame({
          'type': 'turn_accepted',
          'conversation_id': 'conv-long',
          'client_request_id': 'req-long',
          'turn_id': 'turn-long',
          'persisted': true,
        }),
      );
      service.handleIncomingFrameForTest(
        _canonicalFrame({
          'type': 'turn_status',
          'conversation_id': 'conv-long',
          'client_request_id': 'req-long',
          'turn_id': 'turn-long',
          'status': 'working',
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.isConversationBusy('conv-long'), isTrue);
      expect(service.isPending('conv-long'), isTrue);
      expect(messages.whereType<TurnAcceptedMessage>().map((m) => m.status), [
        'accepted',
        'working',
      ]);

      service.handleIncomingFrameForTest(
        _canonicalFrame({
          'type': 'response',
          'conversation_id': 'conv-long',
          'client_request_id': 'req-long',
          'turn_id': 'turn-long',
          'content': 'final report',
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.bufferedText('conv-long'), 'final report');
      expect(service.isConversationBusy('conv-long'), isTrue);
      expect(service.isPending('conv-long'), isTrue);
      expect(streamEvents.last.clientRequestId, 'req-long');
      expect(streamEvents.last.turnId, 'turn-long');
      expect(streamEvents.last.delta, 'final report');

      service.handleIncomingFrameForTest(
        _canonicalFrame({
          'type': 'status',
          'conversation_id': 'conv-long',
          'client_request_id': 'req-long',
          'turn_id': 'turn-long',
          'content': 'done',
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.isConversationBusy('conv-long'), isFalse);
      expect(service.isPending('conv-long'), isFalse);
      expect(streamEvents.last.done, isTrue);
      expect(streamEvents.last.clientRequestId, 'req-long');
      expect(streamEvents.last.turnId, 'turn-long');
    },
  );

  test(
    'stale request frames do not finish or corrupt current request',
    () async {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
      );
      addTearDown(service.dispose);

      final events = <ConvStreamEvent>[];
      final sub = service.convStreamStream.listen(events.add);
      addTearDown(sub.cancel);

      service.rememberRequestForTest('conv-current', 'req-current');
      service.handleIncomingFrameForTest(
        _canonicalFrame({
          'type': 'turn_accepted',
          'conversation_id': 'conv-current',
          'client_request_id': 'req-current',
          'turn_id': 'turn-current',
          'persisted': true,
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.isConversationBusy('conv-current'), isTrue);
      expect(service.isPending('conv-current'), isTrue);

      service.handleIncomingFrameForTest(
        _canonicalFrame({
          'type': 'response_chunk',
          'conversation_id': 'conv-current',
          'client_request_id': 'req-old',
          'turn_id': 'turn-old',
          'content': 'old text',
        }),
      );
      service.handleIncomingFrameForTest(
        _canonicalFrame({
          'type': 'status',
          'conversation_id': 'conv-current',
          'client_request_id': 'req-old',
          'turn_id': 'turn-old',
          'content': 'error',
        }),
      );
      service.handleIncomingFrameForTest(
        _canonicalFrame({
          'type': 'response_done',
          'conversation_id': 'conv-current',
          'client_request_id': 'req-old',
          'turn_id': 'turn-old',
        }),
      );
      service.handleIncomingFrameForTest(
        _canonicalFrame({
          'type': 'conversation_busy_changed',
          'conversation_id': 'conv-current',
          'client_request_id': 'req-old',
          'turn_id': 'turn-old',
          'busy': false,
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.bufferedText('conv-current'), isEmpty);
      expect(service.isConversationBusy('conv-current'), isTrue);
      expect(service.isPending('conv-current'), isTrue);
      expect(events.where((e) => e.error || e.done), isEmpty);

      service.handleIncomingFrameForTest(
        _canonicalFrame({
          'type': 'response_chunk',
          'conversation_id': 'conv-current',
          'client_request_id': 'req-current',
          'turn_id': 'turn-current',
          'content': 'fresh text',
        }),
      );
      service.handleIncomingFrameForTest(
        _canonicalFrame({
          'type': 'status',
          'conversation_id': 'conv-current',
          'client_request_id': 'req-current',
          'turn_id': 'turn-current',
          'content': 'done',
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.bufferedText('conv-current'), 'fresh text');
      expect(service.isConversationBusy('conv-current'), isFalse);
      expect(service.isPending('conv-current'), isFalse);
      expect(events.last.done, isTrue);
      expect(events.last.clientRequestId, 'req-current');
      expect(events.last.turnId, 'turn-current');
    },
  );

  test('uncorrelated terminal frame does not clear current request', () async {
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
    );
    addTearDown(service.dispose);

    final events = <ConvStreamEvent>[];
    final sub = service.convStreamStream.listen(events.add);
    addTearDown(sub.cancel);

    service.rememberRequestForTest('conv-safe', 'req-safe');
    service.handleIncomingFrameForTest(
      _canonicalFrame({
        'type': 'turn_accepted',
        'conversation_id': 'conv-safe',
        'client_request_id': 'req-safe',
        'turn_id': 'turn-safe',
      }),
    );
    await Future<void>.delayed(Duration.zero);

    service.handleIncomingFrameForTest({'type': 'status', 'content': 'done'});
    service.handleIncomingFrameForTest({'type': 'error'});
    await Future<void>.delayed(Duration.zero);

    expect(service.isConversationBusy('conv-safe'), isTrue);
    expect(service.isPending('conv-safe'), isTrue);
    expect(events.where((e) => e.done || e.error), isEmpty);
  });

  test('late progress frames do not revive a finished request', () async {
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
    );
    addTearDown(service.dispose);

    final messages = <OsiaMessage>[];
    final sub = service.messageStream.listen(messages.add);
    addTearDown(sub.cancel);

    service.rememberRequestForTest('conv-done-safe', 'req-current');
    service.handleIncomingFrameForTest(
      _canonicalFrame({
        'type': 'turn_accepted',
        'conversation_id': 'conv-done-safe',
        'client_request_id': 'req-current',
        'turn_id': 'turn-current',
      }),
    );
    service.handleIncomingFrameForTest(
      _canonicalFrame({
        'type': 'status',
        'conversation_id': 'conv-done-safe',
        'client_request_id': 'req-current',
        'turn_id': 'turn-current',
        'content': 'done',
      }),
    );
    await Future<void>.delayed(Duration.zero);

    expect(service.isConversationBusy('conv-done-safe'), isFalse);
    expect(service.isPending('conv-done-safe'), isFalse);

    service.handleIncomingFrameForTest(
      _canonicalFrame({
        'type': 'turn_status',
        'conversation_id': 'conv-done-safe',
        'client_request_id': 'req-old',
        'turn_id': 'turn-old',
        'status': 'working',
      }),
    );
    service.handleIncomingFrameForTest(
      _canonicalFrame({
        'type': 'conversation_busy_changed',
        'conversation_id': 'conv-done-safe',
        'client_request_id': 'req-old',
        'turn_id': 'turn-old',
        'busy': true,
      }),
    );
    await Future<void>.delayed(Duration.zero);

    expect(service.isConversationBusy('conv-done-safe'), isFalse);
    expect(service.isPending('conv-done-safe'), isFalse);
    expect(
      messages.whereType<TurnAcceptedMessage>().map((m) => m.clientRequestId),
      ['req-current'],
    );
  });
}
