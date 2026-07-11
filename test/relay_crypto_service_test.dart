import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash_crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/relay_crypto_service.dart';

void main() {
  late Map<String, Object?> vector;
  late Map<String, Object?> plaintextFrame;
  late Uint8List pcPrivateKey;
  late Uint8List mobilePrivateKey;
  late Uint8List pcPublicKey;
  late Uint8List mobilePublicKey;
  late RelaySessionContext context;
  late RelaySessionKeys pcKeys;
  late RelaySessionKeys mobileKeys;

  setUpAll(() async {
    vector = _readVector();
    plaintextFrame = _map(vector['plaintext_frame']);
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
  });

  test('derives matching session keys and vector ids', () {
    expect(b64UrlEncodeNoPadding(pcPublicKey), vector['pc_public_key_b64']);
    expect(
      b64UrlEncodeNoPadding(mobilePublicKey),
      vector['mobile_public_key_b64'],
    );
    expect(
      _bytesToHex(derivePairSecret(vector['token'] as String)),
      vector['relay_proof_hex'],
    );
    expect(
      hash_crypto.sha256
          .convert(utf8.encode(vector['relay_proof_hex'] as String))
          .toString(),
      vector['pair_id'],
    );
    expect(context.transcript(), equals(_map(vector['transcript'])));
    expect(
      b64UrlEncodeNoPadding(context.transcriptBytes()),
      vector['transcript_utf8_b64'],
    );
    expect(
      b64UrlEncodeNoPadding(deriveE2ePsk(vector['token'] as String)),
      vector['e2e_psk_b64'],
    );
    expect(
      hash_crypto.sha256.convert(context.transcriptBytes()).toString(),
      vector['transcript_sha256_hex'],
    );
    expect(pcKeys.kid, mobileKeys.kid);
    expect(pcKeys.kid, vector['kid']);
    expect(
      pcKeys.pcToMobileKey,
      equals(_hexToBytes(vector['pc_to_mobile_key_hex'] as String)),
    );
    expect(
      pcKeys.mobileToPcKey,
      equals(_hexToBytes(vector['mobile_to_pc_key_hex'] as String)),
    );
    expect(
      handshakeConfirmationTag(
        token: vector['token'] as String,
        context: context,
        senderRole: 'pc',
      ),
      vector['pc_ready_tag'],
    );
    expect(
      handshakeConfirmationTag(
        token: vector['token'] as String,
        context: context,
        senderRole: 'mobile',
      ),
      vector['mobile_ready_tag'],
    );
  });

  test('mobile encrypt vector decrypts', () async {
    final envelope = await _encryptMobileToPc(
      vector: vector,
      frame: plaintextFrame,
      keys: mobileKeys,
      seq: 4,
    );
    expect(envelope, equals(_map(vector['mobile_to_pc_envelope'])));
    expect(
      await decryptFrame(
        envelope,
        keys: pcKeys,
        direction: RelayCryptoDirection.mobileToPc,
      ),
      equals(plaintextFrame),
    );
  });

  test('PC vector decryptable by mobile', () async {
    expect(
      await decryptFrame(
        _map(vector['pc_to_mobile_envelope']),
        keys: mobileKeys,
        direction: RelayCryptoDirection.pcToMobile,
      ),
      equals(plaintextFrame),
    );
  });

  test('large chunk vector matches Python ciphertext', () async {
    final template = _map(vector['large_frame_template']);
    final expected = _map(vector['large_pc_to_mobile']);
    final frame = <String, Object?>{
      'type': template['type'],
      'client_request_id': template['client_request_id'],
      'turn_id': template['turn_id'],
      'conversation_id': template['conversation_id'],
      'content':
          (template['content_char'] as String) *
          (template['content_count'] as int),
    };
    final envelope = await encryptFrame(
      frame,
      keys: pcKeys,
      direction: RelayCryptoDirection.pcToMobile,
      pairId: vector['pair_id'] as String,
      role: 'pc',
      seq: expected['seq'] as int,
      priority: expected['priority'] as String,
      finalFrame: expected['final'] as bool,
    );
    final ciphertext = envelope['ciphertext'] as String;
    expect(envelope['nonce'], expected['nonce']);
    expect(ciphertext.length, expected['ciphertext_chars']);
    expect(
      hash_crypto.sha256.convert(ascii.encode(ciphertext)).toString(),
      expected['ciphertext_sha256_hex'],
    );
    final chunks = buildRelayE2eChunks(
      <String, Object?>{
        'v': 2,
        'type': 'E2E_FRAME',
        'role': 'pc',
        'pair_id': vector['pair_id'],
        'seq': expected['seq'],
        'ack': 0,
        ...envelope,
      },
      chunkId: expected['chunk_id'] as String,
      relaySeqForIndex: (index) => (expected['seq'] as int) + index,
    );
    expect(chunks.length, expected['chunk_count']);
    expect(
      (chunks.first['ciphertext_chunk'] as String).length,
      expected['first_chunk_chars'],
    );
    expect(
      (chunks.last['ciphertext_chunk'] as String).length,
      expected['last_chunk_chars'],
    );
  });

  test('large mobile chunk vector matches Python ciphertext', () async {
    final template = _map(vector['large_frame_template']);
    final expected = _map(vector['large_mobile_to_pc']);
    final frame = <String, Object?>{
      'type': template['type'],
      'client_request_id': template['client_request_id'],
      'turn_id': template['turn_id'],
      'conversation_id': template['conversation_id'],
      'content':
          (template['content_char'] as String) *
          (template['content_count'] as int),
    };
    final envelope = await _encryptMobileToPc(
      vector: vector,
      frame: frame,
      keys: mobileKeys,
      seq: expected['seq'] as int,
    );
    final ciphertext = envelope['ciphertext'] as String;
    expect(envelope['nonce'], expected['nonce']);
    expect(ciphertext.length, expected['ciphertext_chars']);
    expect(
      hash_crypto.sha256.convert(ascii.encode(ciphertext)).toString(),
      expected['ciphertext_sha256_hex'],
    );
    final chunks = buildRelayE2eChunks(
      <String, Object?>{
        'v': 2,
        'type': 'E2E_FRAME',
        'role': 'mobile',
        'pair_id': vector['pair_id'],
        'seq': expected['seq'],
        'ack': 0,
        ...envelope,
      },
      chunkId: expected['chunk_id'] as String,
      relaySeqForIndex: (index) => (expected['seq'] as int) + index,
    );
    expect(chunks.length, expected['chunk_count']);
    expect(
      (chunks.first['ciphertext_chunk'] as String).length,
      expected['first_chunk_chars'],
    );
    expect(
      (chunks.last['ciphertext_chunk'] as String).length,
      expected['last_chunk_chars'],
    );
  });

  test(
    'changed transcript field changes keys and rejects fixed vector',
    () async {
      final changedContext = RelaySessionContext(
        pairId: context.pairId,
        pcPublicKey: context.pcPublicKey,
        mobilePublicKey: context.mobilePublicKey,
        pcNonceBase: context.pcNonceBase,
        mobileNonceBase: <int>[0xb0, 0xb1, 0xb2, 0xb4],
      );
      final changedKeys = await deriveSessionKeys(
        token: vector['token'] as String,
        localPrivateKey: mobilePrivateKey,
        peerPublicKey: pcPublicKey,
        context: changedContext,
      );

      expect(changedKeys.kid, isNot(mobileKeys.kid));
      expect(
        handshakeConfirmationTag(
          token: vector['token'] as String,
          context: changedContext,
          senderRole: 'mobile',
        ),
        isNot(vector['mobile_ready_tag']),
      );
      await expectLater(
        decryptFrame(
          _map(vector['mobile_to_pc_envelope']),
          keys: changedKeys,
          direction: RelayCryptoDirection.mobileToPc,
        ),
        throwsA(isA<RelayCryptoException>()),
      );
      for (final field in <String>[
        'device_id',
        'session_id',
        'from',
        'to',
        'to_session_id',
      ]) {
        expect(changedContext.transcript(), isNot(contains(field)));
      }
    },
  );

  test('wrong token fails', () async {
    final wrong = await deriveSessionKeys(
      token: 'wrong-token',
      localPrivateKey: pcPrivateKey,
      peerPublicKey: mobilePublicKey,
      context: context,
    );
    expect(wrong.kid, isNot(pcKeys.kid));
    await expectLater(
      decryptFrame(
        _map(vector['pc_to_mobile_envelope']),
        keys: wrong,
        direction: RelayCryptoDirection.pcToMobile,
      ),
      throwsA(isA<RelayCryptoException>()),
    );

    final wrongSameKid = RelaySessionKeys(
      pcToMobileKey: wrong.pcToMobileKey,
      mobileToPcKey: wrong.mobileToPcKey,
      pcNonceBase: wrong.pcNonceBase,
      mobileNonceBase: wrong.mobileNonceBase,
      kid: pcKeys.kid,
    );
    await expectLater(
      decryptFrame(
        _map(vector['pc_to_mobile_envelope']),
        keys: wrongSameKid,
        direction: RelayCryptoDirection.pcToMobile,
      ),
      throwsA(isA<RelayCryptoException>()),
    );
  });

  test('wrong AAD fails', () async {
    final envelope = _map(vector['pc_to_mobile_envelope']);
    envelope['priority'] = 'normal';
    await expectLater(
      decryptFrame(
        envelope,
        keys: mobileKeys,
        direction: RelayCryptoDirection.pcToMobile,
      ),
      throwsA(isA<RelayCryptoException>()),
    );
  });

  test('wrong role, pair, and legacy identity fail', () async {
    for (final entry in <String, Object?>{
      'role': 'pc',
      'pair_id': '0' * 64,
    }.entries) {
      final envelope = _map(vector['mobile_to_pc_envelope']);
      envelope[entry.key] = entry.value;
      await expectLater(
        decryptFrame(
          envelope,
          keys: pcKeys,
          direction: RelayCryptoDirection.mobileToPc,
        ),
        throwsA(isA<RelayCryptoException>()),
      );
    }
    final legacy = _map(vector['mobile_to_pc_envelope']);
    legacy['device_id'] = 'mobile-stable-id';
    await expectLater(
      decryptFrame(
        legacy,
        keys: pcKeys,
        direction: RelayCryptoDirection.mobileToPc,
      ),
      throwsA(isA<RelayCryptoException>()),
    );
  });

  test('tampered ciphertext fails', () async {
    final envelope = _map(vector['pc_to_mobile_envelope']);
    final ciphertext = b64UrlDecodeNoPadding(envelope['ciphertext'] as String);
    ciphertext[ciphertext.length - 1] ^= 0x01;
    envelope['ciphertext'] = b64UrlEncodeNoPadding(ciphertext);
    await expectLater(
      decryptFrame(
        envelope,
        keys: mobileKeys,
        direction: RelayCryptoDirection.pcToMobile,
      ),
      throwsA(isA<RelayCryptoException>()),
    );
  });

  test('replayed sequence rejected', () async {
    final guard = SequenceReplayGuard();
    final envelope = _map(vector['pc_to_mobile_envelope']);
    await decryptFrame(
      envelope,
      keys: mobileKeys,
      direction: RelayCryptoDirection.pcToMobile,
      replayGuard: guard,
      replayKey: 'pc',
    );
    await expectLater(
      decryptFrame(
        envelope,
        keys: mobileKeys,
        direction: RelayCryptoDirection.pcToMobile,
        replayGuard: guard,
        replayKey: 'pc',
      ),
      throwsA(isA<RelayReplayException>()),
    );
  });

  test('same sequence not allowed for normal encryptor', () async {
    final sequence = OutboundSequence();
    await _encryptMobileToPc(
      vector: vector,
      frame: plaintextFrame,
      keys: mobileKeys,
      outboundSequence: sequence,
    );
    await expectLater(
      _encryptMobileToPc(
        vector: vector,
        frame: plaintextFrame,
        keys: mobileKeys,
        seq: 1,
        outboundSequence: sequence,
      ),
      throwsA(isA<RelayReplayException>()),
    );
  });

  test('canonical JSON is stable', () {
    final value = <String, Object?>{
      'z': [
        <String, Object?>{'b': 2, 'a': 1},
      ],
      'a': true,
      'm': null,
    };
    expect(canonicalJson(value), '{"a":true,"m":null,"z":[{"a":1,"b":2}]}');
  });

  test('large encrypted frame chunks stay below the safe JSON limit', () async {
    final frame = <String, Object?>{
      'type': 'text',
      'content': 'x' * 80000,
      'client_request_id': 'req-large-mobile',
    };
    final envelope = await _mobileOuterEnvelope(
      vector: vector,
      frame: frame,
      keys: mobileKeys,
      seq: 41,
    );
    expect(relaySerializedJsonBytes(envelope), greaterThan(49152));

    final chunks = buildRelayE2eChunks(
      envelope,
      chunkId: 'A' * 22,
      relaySeqForIndex: (index) => 41 + index,
    );

    expect(chunks, hasLength(greaterThan(1)));
    expect(chunks.first['frame_seq'], 41);
    expect(chunks.first['seq'], 41);
    expect(chunks[1]['seq'], 42);
    expect(chunks.every((chunk) => chunk['type'] == 'E2E_CHUNK'), isTrue);
    expect(
      chunks.every(
        (chunk) => relaySerializedJsonBytes(chunk) <= relayE2eSafeFrameBytes,
      ),
      isTrue,
    );
    expect(
      chunks
          .take(chunks.length - 1)
          .every(
            (chunk) =>
                (chunk['ciphertext_chunk'] as String).length ==
                relayE2eChunkCiphertextChars,
          ),
      isTrue,
    );
  });

  test('out-of-order chunks reassemble and decrypt exactly once', () async {
    final frame = <String, Object?>{
      'type': 'text',
      'content': 'large-payload-' * 6000,
      'client_request_id': 'req-out-of-order',
    };
    final envelope = await _mobileOuterEnvelope(
      vector: vector,
      frame: frame,
      keys: mobileKeys,
      seq: 51,
    );
    final chunks = buildRelayE2eChunks(
      envelope,
      chunkId: 'B' * 22,
      relaySeqForIndex: (index) => 51 + index,
    );
    final reassembler = RelayE2eChunkReassembler();
    addTearDown(reassembler.clear);

    Map<String, Object?>? rebuilt;
    for (final chunk in chunks.reversed) {
      rebuilt = reassembler.accept(chunk).completeEnvelope ?? rebuilt;
    }

    expect(rebuilt, isNotNull);
    expect(rebuilt!.containsKey('to_session_id'), isFalse);
    final decrypted = await decryptFrame(
      rebuilt,
      keys: pcKeys,
      direction: RelayCryptoDirection.mobileToPc,
    );
    expect(decrypted, equals(frame));
  });

  test('duplicate chunks are idempotent and conflicts fail safely', () async {
    final envelope = await _mobileOuterEnvelope(
      vector: vector,
      frame: <String, Object?>{
        'type': 'text',
        'content': 'duplicate-check-' * 5000,
      },
      keys: mobileKeys,
      seq: 61,
    );
    final chunks = buildRelayE2eChunks(
      envelope,
      chunkId: 'C' * 22,
      relaySeqForIndex: (index) => 61 + index,
    );
    final reassembler = RelayE2eChunkReassembler();
    addTearDown(reassembler.clear);

    final first = reassembler.accept(chunks.first);
    expect(first.started, isTrue);
    final duplicate = reassembler.accept(chunks.first);
    expect(duplicate.duplicate, isTrue);

    final conflicting = Map<String, Object?>.from(chunks.first);
    final body = conflicting['ciphertext_chunk'] as String;
    conflicting['ciphertext_chunk'] =
        '${body.substring(0, body.length - 1)}${body.endsWith('A') ? 'B' : 'A'}';
    expect(
      () => reassembler.accept(conflicting),
      throwsA(isA<RelayChunkConflictException>()),
    );

    final wrongOuterSequence = Map<String, Object?>.from(chunks[1]);
    wrongOuterSequence['seq'] = (wrongOuterSequence['seq'] as int) + 1;
    expect(
      () => RelayE2eChunkReassembler().accept(wrongOuterSequence),
      throwsA(isA<RelayChunkLimitException>()),
    );
  });

  test('missing chunk expires with a transfer-specific timeout', () async {
    final envelope = await _mobileOuterEnvelope(
      vector: vector,
      frame: <String, Object?>{
        'type': 'text',
        'content': 'timeout-check-' * 5000,
      },
      keys: mobileKeys,
      seq: 71,
    );
    final chunks = buildRelayE2eChunks(
      envelope,
      chunkId: 'D' * 22,
      relaySeqForIndex: (index) => 71 + index,
    );
    final timeout = Completer<RelayChunkTimeoutEvent>();
    final reassembler = RelayE2eChunkReassembler(
      timeout: const Duration(milliseconds: 20),
      onTimeout: timeout.complete,
    );
    addTearDown(reassembler.clear);

    reassembler.accept(chunks.first);
    final event = await timeout.future.timeout(const Duration(seconds: 1));
    expect(event.chunkId, 'D' * 22);
    expect(reassembler.inflightCount, 0);
    expect(reassembler.accept(chunks.first).expired, isTrue);
  });
}

Future<Map<String, Object?>> _mobileOuterEnvelope({
  required Map<String, Object?> vector,
  required Map<String, Object?> frame,
  required RelaySessionKeys keys,
  required int seq,
}) async {
  final encrypted = await _encryptMobileToPc(
    vector: vector,
    frame: frame,
    keys: keys,
    seq: seq,
  );
  return <String, Object?>{
    'v': 2,
    'type': 'E2E_FRAME',
    'role': 'mobile',
    'pair_id': vector['pair_id'],
    'seq': seq,
    'ack': 0,
    ...encrypted,
  };
}

Future<Map<String, Object?>> _encryptMobileToPc({
  required Map<String, Object?> vector,
  required Map<String, Object?> frame,
  required RelaySessionKeys keys,
  int? seq,
  OutboundSequence? outboundSequence,
}) {
  return encryptFrame(
    frame,
    keys: keys,
    direction: RelayCryptoDirection.mobileToPc,
    pairId: vector['pair_id'] as String,
    role: 'mobile',
    priority: 'critical',
    finalFrame: false,
    seq: seq,
    outboundSequence: outboundSequence,
  );
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

String _bytesToHex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
