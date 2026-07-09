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
      pcDeviceId: vector['pc_device_id'] as String,
      mobileDeviceId: vector['mobile_device_id'] as String,
      pcSessionId: vector['pc_session_id'] as String,
      mobileSessionId: vector['mobile_session_id'] as String,
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
      b64UrlEncodeNoPadding(derivePairSecret(vector['token'] as String)),
      vector['pair_secret_b64'],
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
  });

  test('mobile encrypt vector decrypts', () async {
    final envelope = await _encryptMobileToPc(
      vector: vector,
      frame: plaintextFrame,
      keys: mobileKeys,
      seq: 1,
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
      replayKey: 'pc-test-device',
    );
    await expectLater(
      decryptFrame(
        envelope,
        keys: mobileKeys,
        direction: RelayCryptoDirection.pcToMobile,
        replayGuard: guard,
        replayKey: 'pc-test-device',
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
    fromDeviceId: vector['mobile_device_id'] as String,
    toDeviceId: vector['pc_device_id'] as String,
    sessionId: vector['mobile_session_id'] as String,
    priority: 'critical',
    finalFrame: false,
    seq: seq,
    outboundSequence: outboundSequence,
  );
}

Map<String, Object?> _readVector() {
  final value = jsonDecode(
    File('test/fixtures/relay_e2e_vectors.json').readAsStringSync(),
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
