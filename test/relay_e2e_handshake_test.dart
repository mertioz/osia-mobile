import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/relay_crypto_service.dart';
import 'package:osia_mobile/services/relay_service.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  const token = 'osia-local-handshake-test-token';

  test('ready/hello duplicates settle to a quiet bounded handshake', () async {
    final peer = await _LocalRelayPeer.start(token: token);
    addTearDown(peer.close);
    final config = await _mobileConfig(peer.endpoint, token, 1);
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: token,
      autoReconnect: false,
      resolveRelay: () async => config,
    );
    addTearDown(service.dispose);
    final errors = <String>[];
    final errorSub = service.errorStream.listen(errors.add);
    addTearDown(errorSub.cancel);

    await service.ensureConnected(reason: 'handshake_order_test');
    await peer.mobileReadySeen.future.timeout(const Duration(seconds: 2));

    expect(service.state, ConnectionState.connected);
    expect(service.relayHandshakeStateForTest(), <String, bool>{
      'pc_ready': true,
      'peer_ready': true,
      'context_ready': true,
      'keys_ready': true,
    });
    expect(errors, isEmpty);
    expect(peer.requestUris.single.path, '/ws');
    expect(peer.requestUris.single.queryParametersAll, <String, List<String>>{
      'pair_id': <String>[config.pairId],
    });
    expect(peer.receivedTypes.first, 'PAIR_START');
    expect(
      peer.receivedTypes.where((type) => type == 'E2E_HELLO'),
      hasLength(2),
    );
    expect(
      peer.receivedTypes.where((type) => type == 'E2E_READY'),
      hasLength(1),
    );
    expect(
      peer.receivedTypes.where((type) => type == 'MOBILE_READY'),
      hasLength(1),
    );

    final settledCount = peer.receivedTypes.length;
    for (var second = 0; second < 60; second++) {
      peer.sendSettledHandshakeDuplicates();
    }
    peer.sendApplicationPong();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(peer.receivedTypes, hasLength(settledCount));
    expect(peer.receivedTypes, isNot(contains('PING')));
    expect(service.relayNativePingIntervalForTest, const Duration(seconds: 25));
  });

  test('LAN-capable client accepts an authenticated relay-only PC', () async {
    final peer = await _LocalRelayPeer.start(token: token);
    addTearDown(peer.close);
    final config = await _mobileConfig(peer.endpoint, token, 101);
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: token,
      autoReconnect: false,
      resolveRelay: () async => config,
      lanDirectV1: true,
    );
    addTearDown(service.dispose);

    await service.ensureConnected(reason: 'relay_only_pc_compatibility_test');

    expect(service.state, ConnectionState.connected);
    expect(
      service.sendText(
        'relay-only compatibility',
        conversationId: 'conv-relay-only',
        clientRequestId: 'req-relay-only',
      ),
      isTrue,
    );
    final frame = await peer.nextMobileAppFrame().timeout(
      const Duration(seconds: 2),
    );
    expect(frame['type'], 'text');
    expect(frame['client_request_id'], 'req-relay-only');
  });

  test('app frame before E2E ready fails locally without plaintext', () async {
    final peer = await _LocalRelayPeer.start(token: token, holdHandshake: true);
    addTearDown(peer.close);
    final config = await _mobileConfig(peer.endpoint, token, 2);
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: token,
      autoReconnect: false,
      resolveRelay: () async => config,
    );
    addTearDown(service.dispose);

    final connect = service.ensureConnected(reason: 'pre_ready_send_test');
    await peer.mobileHelloSeen.future.timeout(const Duration(seconds: 2));

    final sent = service.sendText(
      'private pre-ready payload',
      conversationId: 'conv-pre-ready',
      clientRequestId: 'req-pre-ready',
    );
    expect(sent, isFalse);
    expect(peer.appEnvelopeTypes, isEmpty);

    peer.releaseHandshake();
    await connect;
    expect(service.state, ConnectionState.connected);
    expect(peer.appEnvelopeTypes, isEmpty);
  });

  test('wrong endpoint token produces an explicit E2E auth mismatch', () async {
    final peer = await _LocalRelayPeer.start(
      token: token,
      authenticateWithWrongToken: true,
    );
    addTearDown(peer.close);
    final config = await _mobileConfig(peer.endpoint, token, 3);
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: token,
      autoReconnect: false,
      resolveRelay: () async => config,
    );
    addTearDown(service.dispose);
    final errors = <String>[];
    final errorSub = service.errorStream.listen(errors.add);
    addTearDown(errorSub.cancel);

    await service.ensureConnected(reason: 'wrong_token_test');
    await Future<void>.delayed(Duration.zero);

    expect(service.state, ConnectionState.disconnected);
    expect(errors, contains(kRelayE2eAuthMismatchError));
  });

  for (final code in <String>['update_required', 'session_superseded']) {
    test('$code fails closed without a reconnect storm', () async {
      final peer = await _LocalRelayPeer.start(
        token: token,
        terminalErrorCode: code,
      );
      addTearDown(peer.close);
      var configCalls = 0;
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: token,
        resolveRelay: () async {
          configCalls++;
          return _mobileConfig(peer.endpoint, token, 30 + configCalls);
        },
      );
      addTearDown(service.dispose);
      final errors = <String>[];
      final errorSub = service.errorStream.listen(errors.add);
      addTearDown(errorSub.cancel);

      await service.ensureConnected(reason: '${code}_test');
      await Future<void>.delayed(const Duration(milliseconds: 800));

      expect(service.state, ConnectionState.disconnected);
      expect(configCalls, 1);
      expect(
        errors,
        contains(
          code == 'update_required'
              ? kRelayUpdateRequiredError
              : kRelayConnectionReplacedError,
        ),
      );
      expect(peer.receivedTypes, isNot(contains('RECONNECT_RESUME')));
    });
  }

  test('resume_not_supported recovers with a fresh socket only', () async {
    final peer = await _LocalRelayPeer.start(
      token: token,
      terminalErrorCode: 'resume_not_supported',
      terminalErrorConnections: 1,
    );
    addTearDown(peer.close);
    var configCalls = 0;
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: token,
      resolveRelay: () async {
        configCalls++;
        return _mobileConfig(peer.endpoint, token, 40 + configCalls);
      },
    );
    addTearDown(service.dispose);

    await service.ensureConnected(reason: 'resume_not_supported_test');
    for (var i = 0; i < 50 && service.state != ConnectionState.connected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    expect(service.state, ConnectionState.connected);
    expect(configCalls, greaterThanOrEqualTo(2));
    expect(peer.connectionCount, greaterThanOrEqualTo(2));
    expect(peer.receivedTypes, isNot(contains('RECONNECT_RESUME')));
  });

  test(
    'peer unavailable stays inside the valid handshake grace period',
    () async {
      final peer = await _LocalRelayPeer.start(
        token: token,
        holdHandshake: true,
        sendPeerUnavailable: true,
      );
      addTearDown(peer.close);
      final config = await _mobileConfig(peer.endpoint, token, 4);
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: token,
        autoReconnect: false,
        resolveRelay: () async => config,
      );
      addTearDown(service.dispose);
      final errors = <String>[];
      final errorSub = service.errorStream.listen(errors.add);
      addTearDown(errorSub.cancel);

      final connect = service.ensureConnected(reason: 'peer_grace_test');
      await peer.mobileHelloSeen.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(service.state, ConnectionState.connecting);
      expect(errors, isEmpty);
      peer.releaseHandshake();
      await connect;
      expect(service.state, ConnectionState.connected);
    },
  );

  test('E2E error is emitted only after a real handshake timeout', () async {
    final peer = await _LocalRelayPeer.start(token: token, holdHandshake: true);
    addTearDown(peer.close);
    final config = await _mobileConfig(peer.endpoint, token, 5);
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: token,
      autoReconnect: false,
      resolveRelay: () async => config,
    );
    addTearDown(service.dispose);
    final errors = <String>[];
    final errorSub = service.errorStream.listen(errors.add);
    addTearDown(errorSub.cancel);

    await service.ensureConnected(reason: 'handshake_timeout_test');
    await Future<void>.delayed(Duration.zero);

    expect(service.state, ConnectionState.disconnected);
    expect(errors, contains(kRelayE2eHandshakeTimeoutError));
  });

  test(
    'force reconnect uses fresh crypto state and one current socket',
    () async {
      final peer = await _LocalRelayPeer.start(token: token);
      addTearDown(peer.close);
      var configIndex = 0;
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: token,
        autoReconnect: false,
        resolveRelay: () async {
          configIndex++;
          return _mobileConfig(peer.endpoint, token, configIndex + 10);
        },
      );
      addTearDown(service.dispose);

      await service.ensureConnected(reason: 'first_connection');
      expect(service.state, ConnectionState.connected);
      await service.ensureConnected(
        reason: 'forced_reconnect',
        forceReconnect: true,
      );

      expect(service.state, ConnectionState.connected);
      expect(peer.connectionCount, 2);
      expect(peer.activeConnectionCount, 1);
      expect(peer.mobilePublicKeys.toSet().length, 2);
      expect(
        service.relayHandshakeStateForTest().values.every((value) => value),
        isTrue,
      );
    },
  );

  test('encrypted app frames keep monotonic outer sequence order', () async {
    final peer = await _LocalRelayPeer.start(token: token);
    addTearDown(peer.close);
    final config = await _mobileConfig(peer.endpoint, token, 20);
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: token,
      autoReconnect: false,
      resolveRelay: () async => config,
    );
    addTearDown(service.dispose);

    await service.ensureConnected(reason: 'encrypted_order_test');
    expect(
      service.sendText(
        'first encrypted frame',
        conversationId: 'conv-order-1',
        clientRequestId: 'req-order-1',
      ),
      isTrue,
    );
    expect(
      service.sendText(
        'second encrypted frame',
        conversationId: 'conv-order-2',
        clientRequestId: 'req-order-2',
      ),
      isTrue,
    );
    await peer.twoAppFramesSeen.future.timeout(const Duration(seconds: 2));

    expect(peer.appEnvelopeTypes, <String>['E2E_FRAME', 'E2E_FRAME']);
    expect(peer.appEnvelopeSeqs[1], greaterThan(peer.appEnvelopeSeqs[0]));
  });

  test(
    'different PC hello replaces keys and discards old chunk context',
    () async {
      final peer = await _LocalRelayPeer.start(token: token);
      addTearDown(peer.close);
      final config = await _mobileConfig(peer.endpoint, token, 22);
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: token,
        autoReconnect: false,
        resolveRelay: () async => config,
      );
      addTearDown(service.dispose);

      await service.ensureConnected(reason: 'peer_replacement_test');
      final staleRemainder = await peer.sendFirstEncryptedChunk(
        <String, Object?>{'type': 'response', 'content': 'stale' * 12000},
      );
      for (
        var i = 0;
        i < 20 && service.relayInflightChunksForTest() != 1;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(service.relayInflightChunksForTest(), 1);

      final readyBeforeReplacement = peer.e2eReadyCount;
      await peer.replacePcCrypto();
      for (
        var i = 0;
        i < 50 && peer.e2eReadyCount <= readyBeforeReplacement;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(peer.e2eReadyCount, greaterThan(readyBeforeReplacement));
      expect(service.relayInflightChunksForTest(), 0);

      peer.sendRawChunks(staleRemainder);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(service.relayInflightChunksForTest(), 0);

      final response = service.messageStream
          .where((message) => message is ResponseMessage)
          .cast<ResponseMessage>()
          .first;
      await peer.sendEncryptedAppFrames(<Map<String, Object?>>[
        <String, Object?>{'type': 'response', 'content': 'fresh context'},
      ]);
      expect(
        (await response.timeout(const Duration(seconds: 2))).content,
        'fresh context',
      );
    },
  );

  test(
    'peer replacement explicitly fails the active correlated request',
    () async {
      final peer = await _LocalRelayPeer.start(token: token);
      addTearDown(peer.close);
      final config = await _mobileConfig(peer.endpoint, token, 221);
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: token,
        autoReconnect: false,
        resolveRelay: () async => config,
      );
      addTearDown(service.dispose);
      final transferEvents = <RelayTransferEvent>[];
      final transferSub = service.relayTransferStream.listen(
        transferEvents.add,
      );
      addTearDown(transferSub.cancel);

      await service.ensureConnected(reason: 'replacement_pending_request_test');
      expect(
        service.sendText(
          'request interrupted by authoritative PC replacement',
          conversationId: 'conv-replacement',
          clientRequestId: 'req-replacement',
        ),
        isTrue,
      );
      expect(service.isConversationBusy('conv-replacement'), isTrue);

      await peer.replacePcCrypto();
      for (
        var i = 0;
        i < 50 && service.isConversationBusy('conv-replacement');
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(service.isConversationBusy('conv-replacement'), isFalse);
      expect(
        transferEvents.where(
          (event) =>
              event.clientRequestId == 'req-replacement' &&
              event.state == RelayTransferState.failed,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'rapid distinct PC hellos serialize onto the newest crypto context',
    () async {
      final peer = await _LocalRelayPeer.start(token: token);
      addTearDown(peer.close);
      final config = await _mobileConfig(peer.endpoint, token, 222);
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: token,
        autoReconnect: false,
        resolveRelay: () async => config,
      );
      addTearDown(service.dispose);

      await service.ensureConnected(reason: 'rapid_replacement_hello_test');
      await peer.replacePcCryptoWithRapidHellos();
      for (
        var i = 0;
        i < 50 && !service.relayHandshakeStateForTest().values.every((v) => v);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(
        service.relayHandshakeStateForTest().values.every((value) => value),
        isTrue,
      );
      final response = service.messageStream
          .where((message) => message is ResponseMessage)
          .cast<ResponseMessage>()
          .first;
      await peer.sendEncryptedAppFrames(<Map<String, Object?>>[
        <String, Object?>{
          'type': 'response',
          'content': 'newest rapid context',
        },
      ]);
      expect(
        (await response.timeout(const Duration(seconds: 2))).content,
        'newest rapid context',
      );
    },
  );

  test(
    'large mobile request chunks, then messages two and three work',
    () async {
      final peer = await _LocalRelayPeer.start(token: token);
      addTearDown(peer.close);
      final config = await _mobileConfig(peer.endpoint, token, 23);
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: token,
        autoReconnect: false,
        resolveRelay: () async => config,
      );
      addTearDown(service.dispose);
      final transferEvents = <RelayTransferEvent>[];
      final transferSub = service.relayTransferStream.listen(
        transferEvents.add,
      );
      addTearDown(transferSub.cancel);

      await service.ensureConnected(reason: 'large_mobile_request_test');
      final largeContent = 'large-mobile-request-' * 3500;
      final largeReceived = peer.nextMobileAppFrame();
      expect(
        service.sendText(
          largeContent,
          conversationId: 'conv-large-1',
          clientRequestId: 'req-large-1',
        ),
        isTrue,
      );
      expect(
        await largeReceived.timeout(const Duration(seconds: 2)),
        containsPair('content', largeContent),
      );

      final secondReceived = peer.nextMobileAppFrame();
      expect(
        service.sendText(
          'message two',
          conversationId: 'conv-large-2',
          clientRequestId: 'req-large-2',
        ),
        isTrue,
      );
      expect(
        await secondReceived.timeout(const Duration(seconds: 2)),
        containsPair('content', 'message two'),
      );

      final thirdReceived = peer.nextMobileAppFrame();
      expect(
        service.sendText(
          'message three',
          conversationId: 'conv-large-3',
          clientRequestId: 'req-large-3',
        ),
        isTrue,
      );
      expect(
        await thirdReceived.timeout(const Duration(seconds: 2)),
        containsPair('content', 'message three'),
      );

      expect(peer.appEnvelopeTypes, contains('E2E_CHUNK'));
      expect(
        peer.appEnvelopeTypes.takeWhile((type) => type == 'E2E_CHUNK'),
        isNotEmpty,
      );
      expect(
        peer.appEnvelopeTypes.sublist(peer.appEnvelopeTypes.length - 2),
        <String>['E2E_FRAME', 'E2E_FRAME'],
      );
      expect(
        List<int>.generate(
          peer.appEnvelopeSeqs.length - 1,
          (index) =>
              peer.appEnvelopeSeqs[index + 1] - peer.appEnvelopeSeqs[index],
        ).every((delta) => delta > 0),
        isTrue,
      );
      expect(
        transferEvents.any(
          (event) =>
              event.clientRequestId == 'req-large-1' &&
              event.state == RelayTransferState.started,
        ),
        isTrue,
      );
      expect(
        transferEvents.any(
          (event) =>
              event.clientRequestId == 'req-large-1' &&
              event.state == RelayTransferState.completed,
        ),
        isTrue,
      );
    },
  );

  test('large PC response chunks reassemble before mobile delivery', () async {
    final peer = await _LocalRelayPeer.start(token: token);
    addTearDown(peer.close);
    final config = await _mobileConfig(peer.endpoint, token, 24);
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: token,
      autoReconnect: false,
      resolveRelay: () async => config,
    );
    addTearDown(service.dispose);

    await service.ensureConnected(reason: 'large_pc_response_test');
    final content = 'large-pc-response-' * 4000;
    final received = service.messageStream
        .where((message) => message is TranscriptMessage)
        .cast<TranscriptMessage>()
        .firstWhere((message) => message.content == content);
    await peer.sendEncryptedAppFrames(<Map<String, Object?>>[
      <String, Object?>{'type': 'transcript', 'content': content},
    ]);

    expect(
      (await received.timeout(const Duration(seconds: 2))).content,
      content,
    );
  });

  test('encrypted inbound frames decrypt and deliver in relay order', () async {
    final peer = await _LocalRelayPeer.start(token: token);
    addTearDown(peer.close);
    final config = await _mobileConfig(peer.endpoint, token, 21);
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: token,
      autoReconnect: false,
      resolveRelay: () async => config,
    );
    addTearDown(service.dispose);
    final transcripts = <String>[];
    final received = Completer<void>();
    final subscription = service.messageStream.listen((message) {
      if (message is TranscriptMessage) {
        transcripts.add(message.content);
        if (transcripts.length == 2 && !received.isCompleted) {
          received.complete();
        }
      }
    });
    addTearDown(subscription.cancel);

    await service.ensureConnected(reason: 'encrypted_receive_order_test');
    await peer.sendEncryptedAppFrames(<Map<String, Object?>>[
      <String, Object?>{'type': 'transcript', 'content': 'first'},
      <String, Object?>{'type': 'transcript', 'content': 'second'},
    ]);
    await received.future.timeout(const Duration(seconds: 2));

    expect(transcripts, <String>['first', 'second']);
  });

  test(
    'two consecutive encrypted turns complete on the same conversation',
    () async {
      final peer = await _LocalRelayPeer.start(token: token);
      addTearDown(peer.close);
      final config = await _mobileConfig(peer.endpoint, token, 22);
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: token,
        autoReconnect: false,
        resolveRelay: () async => config,
      );
      addTearDown(service.dispose);

      await service.ensureConnected(reason: 'encrypted_multi_turn_test');
      const conversationId = 'conv-multi-turn';

      final firstOutgoing = peer.nextMobileAppFrame();
      final firstTerminal = service.convStreamStream.firstWhere(
        (event) => event.done && event.clientRequestId == 'req-turn-1',
      );
      expect(
        service.sendText(
          'first turn',
          conversationId: conversationId,
          clientRequestId: 'req-turn-1',
        ),
        isTrue,
      );
      expect(
        await firstOutgoing.timeout(const Duration(seconds: 2)),
        containsPair('client_request_id', 'req-turn-1'),
      );
      await peer.sendEncryptedAppFrames(<Map<String, Object?>>[
        <String, Object?>{
          'type': 'turn_accepted',
          'conversation_id': conversationId,
          'client_request_id': 'req-turn-1',
          'turn_id': 'turn-1',
          'persisted': true,
        },
        <String, Object?>{
          'type': 'response_chunk',
          'conversation_id': conversationId,
          'client_request_id': 'req-turn-1',
          'turn_id': 'turn-1',
          'content': 'answer one',
        },
        <String, Object?>{
          'type': 'status',
          'conversation_id': conversationId,
          'client_request_id': 'req-turn-1',
          'turn_id': 'turn-1',
          'content': 'done',
        },
      ]);
      await firstTerminal.timeout(const Duration(seconds: 2));

      expect(service.isConversationBusy(conversationId), isFalse);
      expect(service.isPending(conversationId), isFalse);
      expect(
        service.isSamePendingRequest(conversationId, 'req-turn-1'),
        isFalse,
      );

      final secondOutgoing = peer.nextMobileAppFrame();
      final secondTerminal = service.convStreamStream.firstWhere(
        (event) => event.done && event.clientRequestId == 'req-turn-2',
      );
      expect(
        service.sendText(
          'second turn',
          conversationId: conversationId,
          clientRequestId: 'req-turn-2',
        ),
        isTrue,
      );
      expect(
        await secondOutgoing.timeout(const Duration(seconds: 2)),
        containsPair('client_request_id', 'req-turn-2'),
      );

      // Late turn-1 frames must not clear or overwrite the active turn-2 state.
      // The turn-2 response deliberately arrives before turn_accepted: current
      // correlation is already authoritative from the outgoing request.
      await peer.sendEncryptedAppFrames(<Map<String, Object?>>[
        <String, Object?>{
          'type': 'response_chunk',
          'conversation_id': conversationId,
          'client_request_id': 'req-turn-1',
          'turn_id': 'turn-1',
          'content': 'stale answer',
        },
        <String, Object?>{
          'type': 'status',
          'conversation_id': conversationId,
          'client_request_id': 'req-turn-1',
          'turn_id': 'turn-1',
          'content': 'done',
        },
        <String, Object?>{
          'type': 'response_chunk',
          'conversation_id': conversationId,
          'client_request_id': 'req-turn-2',
          'turn_id': 'turn-2',
          'content': 'answer two',
        },
        <String, Object?>{
          'type': 'turn_accepted',
          'conversation_id': conversationId,
          'client_request_id': 'req-turn-2',
          'turn_id': 'turn-2',
          'persisted': true,
        },
        <String, Object?>{
          'type': 'status',
          'conversation_id': conversationId,
          'client_request_id': 'req-turn-2',
          'turn_id': 'turn-2',
          'content': 'done',
        },
      ]);
      await secondTerminal.timeout(const Duration(seconds: 2));

      expect(service.bufferedText(conversationId), 'answer two');
      expect(service.isConversationBusy(conversationId), isFalse);
      expect(service.isPending(conversationId), isFalse);
      expect(
        service.isSamePendingRequest(conversationId, 'req-turn-2'),
        isFalse,
      );
      expect(peer.appEnvelopeSeqs[1], greaterThan(peer.appEnvelopeSeqs[0]));
    },
  );
}

Future<RelayConnectionConfig> _mobileConfig(
  Uri endpoint,
  String token,
  int index,
) async {
  final credentials = RelayService.derivePairCredentials(token);
  final privateKey = generateX25519PrivateKey();
  return RelayConnectionConfig(
    endpoint: RelayService.buildEndpoint(endpoint, credentials.pairId),
    pairId: credentials.pairId,
    secret: credentials.secret,
    e2ePrivateKey: privateKey,
    e2ePublicKey: await x25519PublicKey(privateKey),
    e2eNonceBase: generateNonceBase(),
  );
}

class _LocalRelayPeer {
  _LocalRelayPeer._(
    this._server, {
    required this.token,
    required this.authenticateWithWrongToken,
    required this.sendPeerUnavailable,
    required this.terminalErrorCode,
    required this.terminalErrorConnections,
  });

  final HttpServer _server;
  final String token;
  final bool authenticateWithWrongToken;
  final bool sendPeerUnavailable;
  final String terminalErrorCode;
  final int terminalErrorConnections;
  final List<WebSocket> _sockets = <WebSocket>[];
  final List<_PeerConnection> _connections = <_PeerConnection>[];
  final List<String> receivedTypes = <String>[];
  final List<Uri> requestUris = <Uri>[];
  final List<String> appEnvelopeTypes = <String>[];
  final List<int> appEnvelopeSeqs = <int>[];
  final List<String> mobilePublicKeys = <String>[];
  final Completer<void> mobileHelloSeen = Completer<void>();
  final Completer<void> mobileReadySeen = Completer<void>();
  final Completer<void> twoAppFramesSeen = Completer<void>();
  int e2eReadyCount = 0;
  final Completer<void> _handshakeGate = Completer<void>();
  final StreamController<Map<String, Object?>> _mobileAppFrameCtrl =
      StreamController<Map<String, Object?>>.broadcast(sync: true);
  late final StreamSubscription<HttpRequest> _requests;

  int get connectionCount => _sockets.length;

  int get activeConnectionCount =>
      _sockets.where((socket) => socket.readyState == WebSocket.open).length;

  Uri get endpoint => Uri.parse(
    'ws://${InternetAddress.loopbackIPv4.address}:${_server.port}/ws',
  );

  static Future<_LocalRelayPeer> start({
    required String token,
    bool holdHandshake = false,
    bool authenticateWithWrongToken = false,
    bool sendPeerUnavailable = false,
    String terminalErrorCode = '',
    int terminalErrorConnections = 0,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final peer = _LocalRelayPeer._(
      server,
      token: token,
      authenticateWithWrongToken: authenticateWithWrongToken,
      sendPeerUnavailable: sendPeerUnavailable,
      terminalErrorCode: terminalErrorCode,
      terminalErrorConnections: terminalErrorConnections,
    );
    if (!holdHandshake) peer._handshakeGate.complete();
    peer._requests = server.listen(peer._handleRequest);
    return peer;
  }

  void releaseHandshake() {
    if (!_handshakeGate.isCompleted) _handshakeGate.complete();
  }

  Future<Map<String, Object?>> nextMobileAppFrame() =>
      _mobileAppFrameCtrl.stream.first;

  Future<void> _handleRequest(HttpRequest request) async {
    requestUris.add(request.uri);
    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    final connection = _PeerConnection(
      socket: socket,
      pairId: request.uri.queryParameters['pair_id'] ?? '',
    );
    await connection.initialize();
    _connections.add(connection);
    socket.listen((raw) {
      if (raw is String) unawaited(_handleMessage(connection, raw));
    });
  }

  Future<void> _handleMessage(_PeerConnection connection, String raw) async {
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    final type = envelope['type']?.toString() ?? '';
    receivedTypes.add(type);
    if (type == 'FRAME' ||
        type == 'BATCH' ||
        type == 'E2E_FRAME' ||
        type == 'E2E_CHUNK') {
      appEnvelopeTypes.add(type);
      final seq = envelope['seq'];
      if (seq is int) appEnvelopeSeqs.add(seq);
      if (appEnvelopeTypes.length >= 2 && !twoAppFramesSeen.isCompleted) {
        twoAppFramesSeen.complete();
      }
    }

    if (type == 'E2E_FRAME') {
      await _deliverMobileEnvelope(connection, envelope);
      return;
    }

    if (type == 'E2E_CHUNK') {
      final result = connection.mobileReassembler.accept(
        envelope.cast<String, Object?>(),
      );
      final complete = result.completeEnvelope;
      if (complete != null) {
        await _deliverMobileEnvelope(
          connection,
          complete.cast<String, dynamic>(),
        );
      }
      return;
    }

    if (type == 'PAIR_START') {
      final credentials = RelayService.derivePairCredentials(token);
      final expectedKeys = <String>{
        'v',
        'type',
        'role',
        'pair_id',
        'seq',
        'ack',
        'payload',
      };
      final payload = envelope['payload'];
      if (envelope.keys.toSet().difference(expectedKeys).isNotEmpty ||
          envelope.keys.length != expectedKeys.length ||
          envelope['v'] != 2 ||
          envelope['role'] != 'mobile' ||
          envelope['pair_id'] != connection.pairId ||
          envelope['seq'] != 1 ||
          envelope['ack'] != 0 ||
          payload is! Map ||
          payload.length != 1 ||
          payload['secret'] != credentials.secret) {
        await connection.socket.close();
        return;
      }
      final connectionNumber = _connections.indexOf(connection) + 1;
      if (terminalErrorCode.isNotEmpty &&
          (terminalErrorConnections == 0 ||
              connectionNumber <= terminalErrorConnections)) {
        _send(connection, 'ERROR', <String, Object?>{
          'code': terminalErrorCode,
          'message': 'test terminal relay error',
        });
        await connection.socket.close();
        return;
      }
      _send(connection, 'PAIR_CONFIRM', <String, Object?>{
        'relay_protocol_version': 2,
        'identity_mode': 'role_authority',
        'max_frame_bytes': 65536,
        'max_batch_items': 32,
        'e2e_chunk_version': relayE2eChunkVersion,
        'e2e_chunk_max_frame_bytes': relayE2eSafeFrameBytes,
        'e2e_chunk_max_ciphertext_chars': relayE2eChunkCiphertextChars,
        'e2e_chunk_max_total_bytes': relayE2eChunkMaxTotalBytes,
        'e2e_chunk_max_count': relayE2eChunkMaxCount,
      }, role: 'mobile');
      // Deliberately arrives before E2E_HELLO to exercise the race.
      _send(connection, 'PC_READY', <String, Object?>{'e2e': true});
      if (sendPeerUnavailable) {
        _send(connection, 'ERROR', <String, Object?>{
          'code': 'peer_unavailable',
          'message': 'peer is still joining',
        });
      }
      return;
    }
    if (type == 'E2E_READY') {
      e2eReadyCount++;
      if (!mobileReadySeen.isCompleted) mobileReadySeen.complete();
      return;
    }
    if (type != 'E2E_HELLO' || connection.handshakeSent) return;
    connection.handshakeSent = true;
    if (!mobileHelloSeen.isCompleted) mobileHelloSeen.complete();
    await _handshakeGate.future;

    final payload = (envelope['payload'] as Map).cast<String, dynamic>();
    final mobilePublicKey = b64UrlDecodeNoPadding(
      payload['public_key']?.toString() ?? '',
    );
    mobilePublicKeys.add(b64UrlEncodeNoPadding(mobilePublicKey));
    final mobileNonceBase = b64UrlDecodeNoPadding(
      payload['nonce_base']?.toString() ?? '',
    );
    connection.mobilePublicKey = mobilePublicKey;
    connection.mobileNonceBase = mobileNonceBase;
    final context = RelaySessionContext(
      pairId: connection.pairId,
      pcPublicKey: connection.pcPublicKey,
      mobilePublicKey: mobilePublicKey,
      pcNonceBase: connection.pcNonceBase,
      mobileNonceBase: mobileNonceBase,
    );
    final authToken = authenticateWithWrongToken ? 'wrong-token' : token;
    final keys = await deriveSessionKeys(
      token: authToken,
      localPrivateKey: connection.pcPrivateKey,
      peerPublicKey: mobilePublicKey,
      context: context,
    );
    connection.e2eContext = context;
    connection.e2eKeys = keys;

    // Deliberately arrives before hello; mobile must hold it by key context.
    final ready = <String, Object?>{
      'e2e_version': relayE2eVersion,
      'alg': relayCryptoAlgChacha20Poly1305,
      'kid': keys.kid,
      'tag': handshakeConfirmationTag(
        token: authToken,
        context: context,
        senderRole: 'pc',
      ),
    };
    _send(connection, 'E2E_READY', ready);
    _send(connection, 'E2E_READY', ready);
    final hello = <String, Object?>{
      'e2e_version': relayE2eVersion,
      'alg': relayCryptoAlgChacha20Poly1305,
      'e2e_chunk_version': relayE2eChunkVersion,
      'public_key': b64UrlEncodeNoPadding(connection.pcPublicKey),
      'nonce_base': b64UrlEncodeNoPadding(connection.pcNonceBase),
    };
    _send(connection, 'E2E_HELLO', hello);
    _send(connection, 'E2E_HELLO', hello);
  }

  Future<void> sendEncryptedAppFrames(List<Map<String, Object?>> frames) async {
    final connection = _connections.last;
    final context = connection.e2eContext;
    final keys = connection.e2eKeys;
    if (context == null || keys == null) {
      throw StateError('E2E handshake has not completed');
    }
    for (final frame in frames) {
      final seq = ++connection.seq;
      final encrypted = await encryptFrame(
        frame,
        keys: keys,
        direction: RelayCryptoDirection.pcToMobile,
        pairId: context.pairId,
        role: 'pc',
        priority: relayFramePriority(frame),
        finalFrame: relayFrameIsFinal(frame),
        seq: seq,
      );
      final envelope = <String, Object?>{
        'v': 2,
        'type': 'E2E_FRAME',
        'role': 'pc',
        'pair_id': context.pairId,
        'seq': seq,
        'ack': 0,
        ...encrypted,
      };
      if (relaySerializedJsonBytes(envelope) <= relayE2eSafeFrameBytes) {
        connection.socket.add(jsonEncode(envelope));
        continue;
      }
      final chunks = buildRelayE2eChunks(
        envelope,
        chunkId: generateRelayChunkId(),
        relaySeqForIndex: (index) => index == 0 ? seq : ++connection.seq,
      );
      for (final chunk in chunks) {
        connection.socket.add(jsonEncode(chunk));
      }
    }
  }

  Future<List<Map<String, Object?>>> sendFirstEncryptedChunk(
    Map<String, Object?> frame,
  ) async {
    final connection = _connections.last;
    final context = connection.e2eContext;
    final keys = connection.e2eKeys;
    if (context == null || keys == null) {
      throw StateError('E2E handshake has not completed');
    }
    final seq = ++connection.seq;
    final encrypted = await encryptFrame(
      frame,
      keys: keys,
      direction: RelayCryptoDirection.pcToMobile,
      pairId: context.pairId,
      role: 'pc',
      priority: relayFramePriority(frame),
      finalFrame: relayFrameIsFinal(frame),
      seq: seq,
    );
    final envelope = <String, Object?>{
      'v': 2,
      'type': 'E2E_FRAME',
      'role': 'pc',
      'pair_id': context.pairId,
      'seq': seq,
      'ack': 0,
      ...encrypted,
    };
    final chunks = buildRelayE2eChunks(
      envelope,
      chunkId: generateRelayChunkId(),
      relaySeqForIndex: (index) => index == 0 ? seq : ++connection.seq,
    );
    connection.socket.add(jsonEncode(chunks.first));
    return chunks.skip(1).toList(growable: false);
  }

  Future<void> replacePcCrypto() async {
    final connection = _connections.last;
    await connection.rotatePcCrypto(token);
    final context = connection.e2eContext!;
    final keys = connection.e2eKeys!;
    final hello = <String, Object?>{
      'e2e_version': relayE2eVersion,
      'alg': relayCryptoAlgChacha20Poly1305,
      'e2e_chunk_version': relayE2eChunkVersion,
      'public_key': b64UrlEncodeNoPadding(connection.pcPublicKey),
      'nonce_base': b64UrlEncodeNoPadding(connection.pcNonceBase),
    };
    _send(connection, 'E2E_HELLO', hello);
    _send(connection, 'E2E_READY', <String, Object?>{
      'e2e_version': relayE2eVersion,
      'alg': relayCryptoAlgChacha20Poly1305,
      'kid': keys.kid,
      'tag': handshakeConfirmationTag(
        token: token,
        context: context,
        senderRole: 'pc',
      ),
    });
    _send(connection, 'PC_READY', <String, Object?>{'e2e': true});
  }

  void sendSettledHandshakeDuplicates() {
    final connection = _connections.last;
    final context = connection.e2eContext;
    final keys = connection.e2eKeys;
    if (context == null || keys == null) {
      throw StateError('E2E handshake has not completed');
    }
    final hello = <String, Object?>{
      'e2e_version': relayE2eVersion,
      'alg': relayCryptoAlgChacha20Poly1305,
      'e2e_chunk_version': relayE2eChunkVersion,
      'public_key': b64UrlEncodeNoPadding(connection.pcPublicKey),
      'nonce_base': b64UrlEncodeNoPadding(connection.pcNonceBase),
    };
    final ready = <String, Object?>{
      'e2e_version': relayE2eVersion,
      'alg': relayCryptoAlgChacha20Poly1305,
      'kid': keys.kid,
      'tag': handshakeConfirmationTag(
        token: token,
        context: context,
        senderRole: 'pc',
      ),
    };
    _send(connection, 'E2E_HELLO', hello);
    _send(connection, 'E2E_READY', ready);
    _send(connection, 'PC_READY', <String, Object?>{'e2e': true});
  }

  void sendApplicationPong() {
    _send(_connections.last, 'PONG', <String, Object?>{'t': 1});
  }

  Future<void> replacePcCryptoWithRapidHellos() async {
    final connection = _connections.last;
    final firstPrivateKey = generateX25519PrivateKey();
    final firstPublicKey = await x25519PublicKey(firstPrivateKey);
    final firstNonceBase = generateNonceBase();
    final readyBefore = e2eReadyCount;
    _send(connection, 'E2E_HELLO', <String, Object?>{
      'e2e_version': relayE2eVersion,
      'alg': relayCryptoAlgChacha20Poly1305,
      'e2e_chunk_version': relayE2eChunkVersion,
      'public_key': b64UrlEncodeNoPadding(firstPublicKey),
      'nonce_base': b64UrlEncodeNoPadding(firstNonceBase),
    });

    await connection.rotatePcCrypto(token);
    final context = connection.e2eContext!;
    final keys = connection.e2eKeys!;
    _send(connection, 'E2E_HELLO', <String, Object?>{
      'e2e_version': relayE2eVersion,
      'alg': relayCryptoAlgChacha20Poly1305,
      'e2e_chunk_version': relayE2eChunkVersion,
      'public_key': b64UrlEncodeNoPadding(connection.pcPublicKey),
      'nonce_base': b64UrlEncodeNoPadding(connection.pcNonceBase),
    });
    for (var i = 0; i < 50 && e2eReadyCount < readyBefore + 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    _send(connection, 'E2E_READY', <String, Object?>{
      'e2e_version': relayE2eVersion,
      'alg': relayCryptoAlgChacha20Poly1305,
      'kid': keys.kid,
      'tag': handshakeConfirmationTag(
        token: token,
        context: context,
        senderRole: 'pc',
      ),
    });
    _send(connection, 'PC_READY', <String, Object?>{'e2e': true});
  }

  void sendRawChunks(List<Map<String, Object?>> chunks) {
    final socket = _connections.last.socket;
    for (final chunk in chunks) {
      socket.add(jsonEncode(chunk));
    }
  }

  Future<void> _deliverMobileEnvelope(
    _PeerConnection connection,
    Map<String, dynamic> envelope,
  ) async {
    if (!_mobileAppFrameCtrl.hasListener) return;
    final keys = connection.e2eKeys;
    if (keys == null) {
      throw StateError('Encrypted app frame arrived before E2E setup');
    }
    final frame = await decryptFrame(
      envelope.cast<String, Object?>(),
      keys: keys,
      direction: RelayCryptoDirection.mobileToPc,
      replayGuard: connection.mobileReplayGuard,
      replayKey: 'mobile',
    );
    _mobileAppFrameCtrl.add(frame);
  }

  void _send(
    _PeerConnection connection,
    String type,
    Map<String, Object?> payload, {
    String role = 'pc',
  }) {
    if (connection.socket.readyState != WebSocket.open) return;
    connection.seq++;
    try {
      connection.socket.add(
        jsonEncode(<String, Object?>{
          'v': 2,
          'type': type,
          'role': role,
          'pair_id': connection.pairId,
          'seq': connection.seq,
          'ack': 0,
          'payload': payload,
        }),
      );
    } on StateError {
      // The timeout test may close the socket between readyState and add().
    }
  }

  Future<void> close() async {
    releaseHandshake();
    for (final connection in _connections) {
      connection.mobileReassembler.clear();
    }
    for (final socket in _sockets) {
      await socket.close();
    }
    await _mobileAppFrameCtrl.close();
    await _requests.cancel();
    await _server.close(force: true);
  }
}

class _PeerConnection {
  _PeerConnection({required this.socket, required this.pairId})
    : pcPrivateKey = generateX25519PrivateKey(),
      pcNonceBase = generateNonceBase();

  final WebSocket socket;
  final String pairId;
  List<int> pcPrivateKey;
  List<int> pcNonceBase;
  late List<int> pcPublicKey;
  List<int>? mobilePublicKey;
  List<int>? mobileNonceBase;
  RelaySessionContext? e2eContext;
  RelaySessionKeys? e2eKeys;
  SequenceReplayGuard mobileReplayGuard = SequenceReplayGuard();
  final RelayE2eChunkReassembler mobileReassembler = RelayE2eChunkReassembler();
  int seq = 0;
  bool handshakeSent = false;

  Future<void> initialize() async {
    pcPublicKey = await x25519PublicKey(pcPrivateKey);
  }

  Future<void> rotatePcCrypto(String token) async {
    final peerPublicKey = mobilePublicKey;
    final peerNonceBase = mobileNonceBase;
    if (peerPublicKey == null || peerNonceBase == null) {
      throw StateError('mobile hello has not completed');
    }
    pcPrivateKey = generateX25519PrivateKey();
    pcNonceBase = generateNonceBase();
    pcPublicKey = await x25519PublicKey(pcPrivateKey);
    final context = RelaySessionContext(
      pairId: pairId,
      pcPublicKey: pcPublicKey,
      mobilePublicKey: peerPublicKey,
      pcNonceBase: pcNonceBase,
      mobileNonceBase: peerNonceBase,
    );
    e2eContext = context;
    e2eKeys = await deriveSessionKeys(
      token: token,
      localPrivateKey: pcPrivateKey,
      peerPublicKey: peerPublicKey,
      context: context,
    );
    mobileReplayGuard = SequenceReplayGuard();
    mobileReassembler.clear();
  }
}
