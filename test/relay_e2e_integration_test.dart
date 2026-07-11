import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/relay_crypto_service.dart';
import 'package:osia_mobile/services/relay_service.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  late Map<String, Object?> vector;
  late Uint8List pcPrivateKey;
  late Uint8List mobilePrivateKey;
  late Uint8List pcPublicKey;
  late Uint8List mobilePublicKey;
  late RelaySessionContext context;
  late RelaySessionKeys pcKeys;
  late RelaySessionKeys mobileKeys;
  late RelayConnectionConfig mobileConfig;

  setUpAll(() async {
    vector = _readVector();
    pcPrivateKey = _hexToBytes(vector['pc_private_key_hex'] as String);
    mobilePrivateKey = _hexToBytes(vector['mobile_private_key_hex'] as String);
    pcPublicKey = await x25519PublicKey(pcPrivateKey);
    mobilePublicKey = await x25519PublicKey(mobilePrivateKey);
    context = RelaySessionContext(
      pairId: vector['pair_id'] as String,
      pcPublicKey: pcPublicKey,
      mobilePublicKey: mobilePublicKey,
      pcNonceBase: _hexToBytes(vector['pc_nonce_base_hex'] as String),
      mobileNonceBase: _hexToBytes(vector['mobile_nonce_base_hex'] as String),
    );
    pcKeys = await deriveSessionKeys(
      token: vector['token'] as String,
      localPrivateKey: pcPrivateKey,
      peerPublicKey: mobilePublicKey,
      context: context,
    );
    mobileKeys = await deriveSessionKeys(
      token: vector['token'] as String,
      localPrivateKey: mobilePrivateKey,
      peerPublicKey: pcPublicKey,
      context: context,
    );
    mobileConfig = RelayConnectionConfig(
      endpoint: Uri.parse('wss://relay.test/ws?pair_id=${vector['pair_id']}'),
      pairId: vector['pair_id'] as String,
      secret: vector['relay_proof_hex'] as String,
      e2ePrivateKey: mobilePrivateKey,
      e2ePublicKey: mobilePublicKey,
      e2eNonceBase: _hexToBytes(vector['mobile_nonce_base_hex'] as String),
    );
  });

  test('WebSocketService builds opaque encrypted relay envelope', () async {
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: vector['token'] as String,
      autoReconnect: false,
    );
    addTearDown(service.dispose);

    final frame = _map(vector['plaintext_frame']).cast<String, dynamic>();
    final envelope = await service.buildRelayEncryptedEnvelopeForTest(
      frame,
      config: mobileConfig,
      keys: mobileKeys,
      seq: 7,
    );

    expect(envelope['type'], 'E2E_FRAME');
    expect(envelope.containsKey('payload'), isFalse);
    expect(envelope['role'], 'mobile');
    for (final field in <String>{
      'device_id',
      'session_id',
      'from',
      'to',
      'to_session_id',
    }) {
      expect(envelope.containsKey(field), isFalse);
    }
    expect(envelope['priority'], 'normal');
    expect(envelope['final'], isFalse);
    expect(jsonEncode(envelope), isNot(contains('hello encrypted osia')));

    final decrypted = await decryptFrame(
      envelope,
      keys: pcKeys,
      direction: RelayCryptoDirection.mobileToPc,
    );
    expect(decrypted, equals(frame));
  });

  test(
    'exact UTF-8 JSON boundary keeps the last safe frame unchunked',
    () async {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: vector['token'] as String,
        autoReconnect: false,
      );
      addTearDown(service.dispose);

      Future<Map<String, Object?>> envelopeFor(int contentLength) =>
          service.buildRelayEncryptedEnvelopeForTest(
            <String, dynamic>{
              'type': 'text',
              'content': 'x' * contentLength,
              'client_request_id': 'req-boundary',
            },
            config: mobileConfig,
            keys: mobileKeys,
            seq: 81,
          );

      var low = 0;
      var high = 100000;
      while (low < high) {
        final middle = (low + high + 1) ~/ 2;
        final envelope = await envelopeFor(middle);
        if (relaySerializedJsonBytes(envelope) <= relayE2eSafeFrameBytes) {
          low = middle;
        } else {
          high = middle - 1;
        }
      }
      final safe = await envelopeFor(low);
      var firstOversizedLength = low + 1;
      var oversized = await envelopeFor(firstOversizedLength);
      while (relaySerializedJsonBytes(oversized) <= relayE2eSafeFrameBytes) {
        firstOversizedLength++;
        oversized = await envelopeFor(firstOversizedLength);
      }

      expect(relaySerializedJsonBytes(safe), lessThanOrEqualTo(49152));
      expect(relaySerializedJsonBytes(oversized), greaterThan(49152));
      expect(safe['type'], 'E2E_FRAME');
      expect(safe.containsKey('to_session_id'), isFalse);
    },
  );

  test(
    'WebSocketService decrypts incoming E2E envelope and rejects replay',
    () async {
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: vector['token'] as String,
        autoReconnect: false,
      );
      addTearDown(service.dispose);

      final frame = <String, Object?>{
        'type': 'cron_notification',
        'id': 'note-1',
        'title': 'Daily check',
      };
      final encrypted = await encryptFrame(
        frame,
        keys: pcKeys,
        direction: RelayCryptoDirection.pcToMobile,
        pairId: vector['pair_id'] as String,
        role: 'pc',
        priority: relayFramePriority(frame),
        finalFrame: relayFrameIsFinal(frame),
        seq: 11,
      );
      final envelope = <String, Object?>{
        'v': 2,
        'type': 'E2E_FRAME',
        'role': 'pc',
        'pair_id': vector['pair_id'],
        'seq': 11,
        'ack': 0,
        ...encrypted,
      }.cast<String, dynamic>();
      final guard = SequenceReplayGuard();

      final decrypted = await service.decryptRelayEnvelopeForTest(
        envelope,
        keys: mobileKeys,
        replayGuard: guard,
      );
      expect(decrypted, equals(frame));

      final replay = await service.decryptRelayEnvelopeForTest(
        envelope,
        keys: mobileKeys,
        replayGuard: guard,
      );
      expect(replay, isNull);
    },
  );

  test('wrong key fails safely for incoming relay envelope', () async {
    final service = WebSocketService(
      ip: '127.0.0.1',
      token: vector['token'] as String,
      autoReconnect: false,
    );
    addTearDown(service.dispose);

    final wrongKeys = await deriveSessionKeys(
      token: 'wrong-token',
      localPrivateKey: mobilePrivateKey,
      peerPublicKey: pcPublicKey,
      context: context,
    );
    final decrypted = await service.decryptRelayEnvelopeForTest(
      _map(vector['pc_to_mobile_envelope']).cast<String, dynamic>(),
      keys: wrongKeys,
    );
    expect(decrypted, isNull);
  });

  test('relay plaintext rejection error is surfaced clearly', () {
    expect(
      relayErrorMessageForTest('e2e_required'),
      contains('E2E encryption is required'),
    );
    expect(
      relayErrorMessageForTest('update_required'),
      contains('Update OSIA'),
    );
    expect(
      relayErrorMessageForTest('pair_secret_mismatch'),
      kRelayE2eAuthMismatchError,
    );
    expect(
      relayErrorMessageForTest('replay_rejected'),
      kRelayE2eStaleSessionError,
    );
    expect(relayErrorMessageForTest('peer_unavailable'), 'peer_unavailable');
  });

  test(
    'relay failure does not fall back to legacy rendezvous by default',
    () async {
      expect(allowLegacyRendezvousFallbackForTest(), isFalse);
      var legacyHostLookups = 0;
      final service = WebSocketService(
        ip: '127.0.0.1',
        token: vector['token'] as String,
        autoReconnect: false,
        resolveRelay: () => Future<RelayConnectionConfig>.error(
          StateError('relay setup unavailable'),
        ),
        resolveHost: () async {
          legacyHostLookups++;
          return 'legacy.example.com';
        },
      );
      addTearDown(service.dispose);
      final errors = <String>[];
      final errorSub = service.errorStream.listen(errors.add);
      addTearDown(errorSub.cancel);

      await service.ensureConnected(reason: 'test_relay_release_policy');
      await Future<void>.delayed(Duration.zero);

      expect(legacyHostLookups, 0);
      expect(errors, contains(kRelayUnreachableError));
      expect(service.state, ConnectionState.disconnected);
    },
  );

  test('relay priority and final metadata mapping is stable', () {
    final cases = <Map<String, Object?>>[
      {'type': 'response_chunk', 'priority': 'normal', 'final': false},
      {
        'type': 'turn_status',
        'status': 'running',
        'priority': 'critical',
        'final': false,
      },
      {
        'type': 'turn_status',
        'status': 'done',
        'priority': 'critical',
        'final': true,
      },
      {
        'type': 'status',
        'content': 'error',
        'priority': 'critical',
        'final': true,
      },
      {'type': 'cron_notification', 'priority': 'critical', 'final': false},
      {'type': 'mcp_status', 'priority': 'droppable', 'final': false},
    ];

    for (final testCase in cases) {
      final frame = Map<String, Object?>.from(testCase)
        ..remove('priority')
        ..remove('final');
      expect(relayFramePriority(frame), testCase['priority']);
      expect(relayFrameIsFinal(frame), testCase['final']);
    }
  });
}

Map<String, Object?> _readVector() {
  final value = jsonDecode(
    File('test/fixtures/relay_v2_vectors.json').readAsStringSync(),
  );
  return _map(value);
}

Map<String, Object?> _map(Object? value) {
  final map = value as Map;
  return map.map<String, Object?>(
    (Object? key, Object? value) => MapEntry(key as String, value),
  );
}

Uint8List _hexToBytes(String hex) {
  if (hex.length.isOdd) {
    throw ArgumentError.value(hex, 'hex', 'must have an even length');
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
