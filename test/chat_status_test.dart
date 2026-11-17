import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/chat_status.dart';
import 'package:osia_mobile/guide/onboarding_content.dart';
import 'package:osia_mobile/services/websocket_service.dart';

Map<String, dynamic> status({String connection = 'account'}) => {
  'schema_version': 1,
  'command_id': 'status.info',
  'connection': connection,
  'model': {
    'provider_id': 'fixture',
    'id': 'fixture-model',
    'label': 'Model A',
  },
  'context': {'used': 100, 'maximum': 1000, 'estimated': false},
  'quota': {
    'state': 'available',
    'windows': [
      {'label': '5 h', 'remaining_percent': 25},
    ],
  },
  'usage': {
    'estimated': true,
    'total_tokens': 1200,
    'cost_usd': 0.003,
    'currency': 'USD',
    'basis': 'visible_conversation',
    'models': [
      {
        'model': {'label': 'Model A'},
        'total_tokens': 1000,
        'cost_usd': 0.003,
      },
      {
        'model': {'label': 'Model B'},
        'total_tokens': 200,
        'cost_usd': null,
      },
    ],
  },
};

void main() {
  test(
    'the onboarding guide explains slash commands and past-chat context',
    () {
      final chat = onboardingSlides.singleWhere((slide) => slide.id == 'chat');
      for (final language in ['en', 'fr', 'zh', 'ja', 'de', 'es']) {
        final text = chat.body.resolve(language);
        expect(text, contains('/'));
        expect(text, contains('@'));
      }
    },
  );

  test('account status only projects model, context and provider quota', () {
    final snapshot = ChatStatusSnapshot.fromJson(status());
    final rows = snapshot.rows(french: true);
    expect(rows, [
      ('Modèle', 'Model A'),
      ('Contexte', '100 / 1\u202f000 tokens'),
      ('Quota restant · 5 h', '25 %'),
    ]);
    expect(snapshot.models, isEmpty);
    expect(snapshot.totalTokens, isNull);
    expect(snapshot.costUsd, isNull);
    expect(snapshot.estimateNotice(french: true), isNull);
  });

  test('API estimates and per-model prices come directly from the PC', () {
    final snapshot = ChatStatusSnapshot.fromJson(status(connection: 'api'));
    final rows = snapshot.rows(french: false);
    expect(rows[2], ('Tokens used (estimate)', '≈ 1\u202f200'));
    expect(rows[3], ('Cost (estimate)', '≈ 0.003 USD'));
    expect(rows[4], ('Model A', '≈ 1\u202f000 tokens · ≈ 0.003 USD'));
    expect(rows[5], ('Model B', '≈ 200 tokens · pricing unavailable'));
    expect(rows.any((row) => row.$1.contains('quota')), isFalse);
    expect(snapshot.estimateNotice(french: true), contains('texte visible'));
  });

  test('unknown context/quota/pricing is not fabricated as zero', () {
    final account = status()
      ..['context'] = null
      ..['quota'] = {'state': 'unavailable', 'windows': []};
    final rows = ChatStatusSnapshot.fromJson(account).rows(french: false);
    expect(rows[1].$2, 'Unavailable');
    expect(rows[2].$2, 'Unavailable');

    final api = status(connection: 'api')..['usage'] = null;
    expect(
      ChatStatusSnapshot.fromJson(api).rows(french: false)[3].$2,
      'Unavailable',
    );
    final local = ChatStatusSnapshot.fromJson(status(connection: 'local'));
    expect(local.costUsd, isNull);
    expect(local.models.every((row) => row.costUsd == null), isTrue);
  });

  test(
    'zero remaining quota is retained and invalid values are unavailable',
    () {
      final value = status();
      (value['quota'] as Map)['windows'] = [
        {'label': 'Window', 'remaining_percent': 0},
        {'label': 'Invalid', 'remaining_percent': 200},
        {'label': 'Invalid', 'remaining_percent': -1},
      ];
      final snapshot = ChatStatusSnapshot.fromJson(value);
      expect(snapshot.quotaWindows, [('Window', 0.0)]);
      expect(snapshot.rows(french: false).last.$2, '0 %');
    },
  );

  test('unsupported status shapes are rejected instead of projected', () {
    expect(
      () => ChatStatusSnapshot.fromJson({'schema_version': 9}),
      throwsFormatException,
    );
    expect(
      () => ChatStatusSnapshot.fromJson(status()..['connection'] = 'other'),
      throwsFormatException,
    );
  });

  test(
    'all PC models and quota windows remain visible without local truncation',
    () {
      final api = status(connection: 'api');
      (api['usage'] as Map)['models'] = List.generate(
        65,
        (index) => {
          'model': {'label': 'Model $index'},
          'total_tokens': 1,
          'cost_usd': 0.000001,
        },
      );
      final projected = ChatStatusSnapshot.fromJson(api);
      expect(projected.models, hasLength(65));
      expect(projected.rows(french: false).last.$1, 'Model 64');
      expect(
        projected.totalTokens,
        1200,
      ); // The PC total is not recalculated here.

      final account = status();
      (account['quota'] as Map)['windows'] = List.generate(
        17,
        (index) => {'label': 'Window $index', 'remaining_percent': index},
      );
      final quotas = ChatStatusSnapshot.fromJson(account);
      expect(quotas.quotaWindows, hasLength(17));
      expect(quotas.rows(french: false).last.$1, 'Remaining quota · Window 16');
    },
  );

  test(
    'status response is correlated to both operation and conversation',
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
      final pending = service.requestChatStatus(conversationId: 'conv-1');
      final request = frames.single;
      expect(request['type'], 'get_chat_status');
      expect(request['conversation_id'], 'conv-1');
      var completed = false;
      pending.then((_) => completed = true);
      service.handleIncomingFrameForTest({
        'type': 'chat_status',
        'operation_id': 'other',
        'conversation_id': 'conv-1',
        'status': status(),
      });
      service.handleIncomingFrameForTest({
        'type': 'chat_status',
        'operation_id': request['operation_id'],
        'conversation_id': 'conv-2',
        'status': status(),
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      service.handleIncomingFrameForTest({
        'type': 'chat_status',
        'operation_id': request['operation_id'],
        'conversation_id': 'conv-1',
        'status': status(),
      });
      expect((await pending).modelLabel, 'Model A');
    },
  );

  test(
    'timeout discards stale replies without blocking a new request',
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
      await expectLater(
        service.requestChatStatus(
          conversationId: 'conv-1',
          timeout: const Duration(milliseconds: 1),
        ),
        throwsA(isA<TimeoutException>()),
      );
      final pending = service.requestChatStatus(conversationId: 'conv-1');
      service.handleIncomingFrameForTest({
        'type': 'chat_status',
        'operation_id': frames.first['operation_id'],
        'conversation_id': 'conv-1',
        'status': status(),
      });
      service.handleIncomingFrameForTest({
        'type': 'chat_status',
        'operation_id': frames.last['operation_id'],
        'conversation_id': 'conv-1',
        'status': status(connection: 'api'),
      });
      expect((await pending).connection, 'api');
    },
  );

  test(
    'disconnect ends pending status reads without cancelling chat work',
    () async {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: 'test-token',
        autoReconnect: false,
        sendFrameForTest: (_) => true,
      );
      addTearDown(service.dispose);
      final pending = service.requestChatStatus(conversationId: 'conv-1');
      final rejected = expectLater(pending, throwsStateError);
      service.disconnect();
      await rejected;
      expect(service.isPending('conv-1'), isFalse);
    },
  );

  test('invalid payload and offline send are honest failures', () async {
    final frames = <Map<String, dynamic>>[];
    var send = true;
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: 'test-token',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        frames.add(frame);
        return send;
      },
    );
    addTearDown(service.dispose);
    final pending = service.requestChatStatus(conversationId: '');
    final rejected = expectLater(pending, throwsFormatException);
    service.handleIncomingFrameForTest({
      'type': 'chat_status',
      'operation_id': frames.single['operation_id'],
      'conversation_id': '',
      'status': {'schema_version': 9},
    });
    await rejected;
    send = false;
    await expectLater(
      service.requestChatStatus(conversationId: ''),
      throwsStateError,
    );
  });
}
