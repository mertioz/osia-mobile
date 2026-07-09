import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash_crypto;
import 'package:cryptography/cryptography.dart' as crypto_lib;

const int relayE2eVersion = 1;
const String relayCryptoAlgChacha20Poly1305 = 'CHACHA20-POLY1305';

const String _legacyPairSecretLabel = 'osia-relay-secret-v1';
const String _e2ePskLabel = 'osia-e2e-psk-v1';
const String _sessionInfo = 'osia-relay-e2e-session-v1';
const int _keyMaterialLength = 80;
const int _keyLength = 32;
const int _kidLength = 16;
const int _nonceBaseLength = 4;
const int _tagLength = 16;
final BigInt _maxUint64Exclusive = BigInt.one << 64;

const List<String> _aadFields = [
  'e2e_version',
  'alg',
  'kid',
  'pair_id',
  'from',
  'to',
  'session_id',
  'seq',
  'priority',
  'final',
];

enum RelayCryptoDirection { pcToMobile, mobileToPc }

class RelayCryptoException implements Exception {
  RelayCryptoException(this.message);

  final String message;

  @override
  String toString() => 'RelayCryptoException: $message';
}

class RelayReplayException extends RelayCryptoException {
  RelayReplayException(super.message);
}

String canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

List<int> canonicalJsonBytes(Object? value) =>
    utf8.encode(canonicalJson(value));

String b64UrlEncodeNoPadding(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List b64UrlDecodeNoPadding(String value) {
  final padding = '=' * ((4 - value.length % 4) % 4);
  return Uint8List.fromList(base64Url.decode('$value$padding'));
}

Uint8List derivePairSecret(String token) =>
    _hmacSha256(token, _legacyPairSecretLabel);

Uint8List deriveE2ePsk(String token) => _hmacSha256(token, _e2ePskLabel);

Future<Uint8List> x25519PublicKey(List<int> privateKeyBytes) async {
  _requireLength('privateKeyBytes', privateKeyBytes, 32);
  final keyPair = await crypto_lib.X25519().newKeyPairFromSeed(privateKeyBytes);
  final publicKey = await keyPair.extractPublicKey();
  return Uint8List.fromList(publicKey.bytes);
}

class RelaySessionContext {
  RelaySessionContext({
    required this.pairId,
    required this.pcDeviceId,
    required this.mobileDeviceId,
    required this.pcSessionId,
    required this.mobileSessionId,
    required this.pcPublicKey,
    required this.mobilePublicKey,
    required this.pcNonceBase,
    required this.mobileNonceBase,
    this.e2eVersion = relayE2eVersion,
    this.alg = relayCryptoAlgChacha20Poly1305,
  }) {
    _requireLength('pcPublicKey', pcPublicKey, 32);
    _requireLength('mobilePublicKey', mobilePublicKey, 32);
    _requireLength('pcNonceBase', pcNonceBase, _nonceBaseLength);
    _requireLength('mobileNonceBase', mobileNonceBase, _nonceBaseLength);
  }

  final String pairId;
  final String pcDeviceId;
  final String mobileDeviceId;
  final String pcSessionId;
  final String mobileSessionId;
  final List<int> pcPublicKey;
  final List<int> mobilePublicKey;
  final List<int> pcNonceBase;
  final List<int> mobileNonceBase;
  final int e2eVersion;
  final String alg;

  Map<String, Object?> transcript() => <String, Object?>{
    'e2e_version': e2eVersion,
    'alg': alg,
    'pair_id': pairId,
    'pc_device_id': pcDeviceId,
    'mobile_device_id': mobileDeviceId,
    'pc_session_id': pcSessionId,
    'mobile_session_id': mobileSessionId,
    'pc_public_key': b64UrlEncodeNoPadding(pcPublicKey),
    'mobile_public_key': b64UrlEncodeNoPadding(mobilePublicKey),
    'pc_nonce_base': b64UrlEncodeNoPadding(pcNonceBase),
    'mobile_nonce_base': b64UrlEncodeNoPadding(mobileNonceBase),
  };

  List<int> transcriptBytes() => canonicalJsonBytes(transcript());
}

class RelaySessionKeys {
  RelaySessionKeys({
    required this.pcToMobileKey,
    required this.mobileToPcKey,
    required this.pcNonceBase,
    required this.mobileNonceBase,
    required this.kid,
  });

  final List<int> pcToMobileKey;
  final List<int> mobileToPcKey;
  final List<int> pcNonceBase;
  final List<int> mobileNonceBase;
  final String kid;

  List<int> directionKey(RelayCryptoDirection direction) {
    switch (direction) {
      case RelayCryptoDirection.pcToMobile:
        return pcToMobileKey;
      case RelayCryptoDirection.mobileToPc:
        return mobileToPcKey;
    }
  }

  List<int> directionNonceBase(RelayCryptoDirection direction) {
    switch (direction) {
      case RelayCryptoDirection.pcToMobile:
        return pcNonceBase;
      case RelayCryptoDirection.mobileToPc:
        return mobileNonceBase;
    }
  }
}

Future<RelaySessionKeys> deriveSessionKeys({
  required String token,
  required List<int> localPrivateKey,
  required List<int> peerPublicKey,
  required RelaySessionContext context,
}) async {
  _requireLength('localPrivateKey', localPrivateKey, 32);
  _requireLength('peerPublicKey', peerPublicKey, 32);

  final x25519 = crypto_lib.X25519();
  final keyPair = await x25519.newKeyPairFromSeed(localPrivateKey);
  final sharedSecret = await x25519.sharedSecretKey(
    keyPair: keyPair,
    remotePublicKey: crypto_lib.SimplePublicKey(
      peerPublicKey,
      type: crypto_lib.KeyPairType.x25519,
    ),
  );
  final sharedSecretBytes = await sharedSecret.extractBytes();
  final transcriptHash = hash_crypto.sha256.convert(context.transcriptBytes());
  final ikm = <int>[...sharedSecretBytes, ...deriveE2ePsk(token)];
  final keyMaterial =
      await crypto_lib.Hkdf(
        hmac: crypto_lib.Hmac.sha256(),
        outputLength: _keyMaterialLength,
      ).deriveKey(
        secretKey: crypto_lib.SecretKey(ikm),
        nonce: transcriptHash.bytes,
        info: utf8.encode(_sessionInfo),
      );
  final keyBytes = await keyMaterial.extractBytes();
  return RelaySessionKeys(
    pcToMobileKey: Uint8List.fromList(keyBytes.sublist(0, _keyLength)),
    mobileToPcKey: Uint8List.fromList(
      keyBytes.sublist(_keyLength, _keyLength * 2),
    ),
    pcNonceBase: Uint8List.fromList(context.pcNonceBase),
    mobileNonceBase: Uint8List.fromList(context.mobileNonceBase),
    kid: b64UrlEncodeNoPadding(
      keyBytes.sublist(_keyLength * 2, _keyLength * 2 + _kidLength),
    ),
  );
}

Uint8List nonceForSeq(List<int> nonceBase, int seq) {
  _requireLength('nonceBase', nonceBase, _nonceBaseLength);
  if (seq < 0 || BigInt.from(seq) >= _maxUint64Exclusive) {
    throw ArgumentError.value(seq, 'seq', 'must fit uint64');
  }
  final nonce = Uint8List(_nonceBaseLength + 8);
  nonce.setRange(0, _nonceBaseLength, nonceBase);
  ByteData.view(nonce.buffer).setUint64(_nonceBaseLength, seq, Endian.big);
  return nonce;
}

class SequenceReplayGuard {
  final Map<String, int> _lastSeen = <String, int>{};

  void accept(String key, int seq) {
    final lastSeen = _lastSeen[key] ?? -1;
    if (seq <= lastSeen) {
      throw RelayReplayException('replayed or old sequence: $seq');
    }
    _lastSeen[key] = seq;
  }
}

class OutboundSequence {
  OutboundSequence({int start = 0}) : _last = start {
    if (start < 0) {
      throw ArgumentError.value(start, 'start', 'must be non-negative');
    }
  }

  int _last;

  int next() => reserve(_last + 1);

  int reserve(int seq) {
    if (seq <= _last) {
      throw RelayReplayException('sequence already used: $seq');
    }
    if (BigInt.from(seq) >= _maxUint64Exclusive) {
      throw ArgumentError.value(seq, 'seq', 'must fit uint64');
    }
    _last = seq;
    return seq;
  }
}

Map<String, Object?> aadMetadata({
  required RelaySessionKeys keys,
  required String pairId,
  required String fromDeviceId,
  required String toDeviceId,
  required String sessionId,
  required int seq,
  required String priority,
  required bool finalFrame,
}) => <String, Object?>{
  'e2e_version': relayE2eVersion,
  'alg': relayCryptoAlgChacha20Poly1305,
  'kid': keys.kid,
  'pair_id': pairId,
  'from': fromDeviceId,
  'to': toDeviceId,
  'session_id': sessionId,
  'seq': seq,
  'priority': priority,
  'final': finalFrame,
};

Future<Map<String, Object?>> encryptFrame(
  Map<String, Object?> frame, {
  required RelaySessionKeys keys,
  required RelayCryptoDirection direction,
  required String pairId,
  required String fromDeviceId,
  required String toDeviceId,
  required String sessionId,
  required String priority,
  required bool finalFrame,
  int? seq,
  OutboundSequence? outboundSequence,
}) async {
  if (outboundSequence != null) {
    seq = seq == null ? outboundSequence.next() : outboundSequence.reserve(seq);
  }
  if (seq == null) {
    throw ArgumentError('seq is required without an outbound sequence');
  }

  final metadata = aadMetadata(
    keys: keys,
    pairId: pairId,
    fromDeviceId: fromDeviceId,
    toDeviceId: toDeviceId,
    sessionId: sessionId,
    seq: seq,
    priority: priority,
    finalFrame: finalFrame,
  );
  final nonce = nonceForSeq(keys.directionNonceBase(direction), seq);
  final box = await crypto_lib.Chacha20.poly1305Aead().encrypt(
    canonicalJsonBytes(frame),
    secretKey: crypto_lib.SecretKey(keys.directionKey(direction)),
    nonce: nonce,
    aad: canonicalJsonBytes(metadata),
  );
  return <String, Object?>{
    ...metadata,
    'nonce': b64UrlEncodeNoPadding(nonce),
    'ciphertext': b64UrlEncodeNoPadding([...box.cipherText, ...box.mac.bytes]),
  };
}

Future<Map<String, Object?>> decryptFrame(
  Map<String, Object?> envelope, {
  required RelaySessionKeys keys,
  required RelayCryptoDirection direction,
  SequenceReplayGuard? replayGuard,
  String? replayKey,
}) async {
  final metadata = _metadataFromEnvelope(envelope);
  if (metadata['kid'] != keys.kid) {
    throw RelayCryptoException('unknown key id');
  }
  final seq = _requireInt('seq', metadata['seq']);
  final nonce = b64UrlDecodeNoPadding(
    _requireString('nonce', envelope['nonce']),
  );
  final ciphertext = b64UrlDecodeNoPadding(
    _requireString('ciphertext', envelope['ciphertext']),
  );
  final expectedNonce = nonceForSeq(keys.directionNonceBase(direction), seq);
  if (!_constantListEquals(nonce, expectedNonce)) {
    throw RelayCryptoException('nonce does not match sequence');
  }
  if (ciphertext.length < _tagLength) {
    throw RelayCryptoException('ciphertext is too short');
  }

  final box = crypto_lib.SecretBox(
    ciphertext.sublist(0, ciphertext.length - _tagLength),
    nonce: nonce,
    mac: crypto_lib.Mac(ciphertext.sublist(ciphertext.length - _tagLength)),
  );
  try {
    final plaintext = await crypto_lib.Chacha20.poly1305Aead().decrypt(
      box,
      secretKey: crypto_lib.SecretKey(keys.directionKey(direction)),
      aad: canonicalJsonBytes(metadata),
    );
    final decoded = jsonDecode(utf8.decode(plaintext));
    if (decoded is! Map) {
      throw RelayCryptoException('decrypted frame is not an object');
    }
    final frame = decoded.map<String, Object?>(
      (Object? key, Object? value) =>
          MapEntry(_requireString('key', key), value),
    );
    replayGuard?.accept(
      replayKey ?? _requireString('from', metadata['from']),
      seq,
    );
    return frame;
  } on crypto_lib.SecretBoxAuthenticationError {
    throw RelayCryptoException('frame authentication failed');
  }
}

Map<String, Object?> _metadataFromEnvelope(Map<String, Object?> envelope) {
  final metadata = <String, Object?>{};
  for (final field in _aadFields) {
    if (!envelope.containsKey(field)) {
      throw RelayCryptoException('missing AAD field: $field');
    }
    metadata[field] = envelope[field];
  }
  return metadata;
}

Object? _canonicalize(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Map) {
    final keys = value.keys.map((Object? key) {
      if (key is! String) {
        throw ArgumentError('JSON object keys must be strings');
      }
      return key;
    }).toList()..sort();
    final result = <String, Object?>{};
    for (final key in keys) {
      result[key] = _canonicalize(value[key]);
    }
    return result;
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  throw ArgumentError('Unsupported JSON value: ${value.runtimeType}');
}

Uint8List _hmacSha256(String token, String label) {
  final mac = hash_crypto.Hmac(hash_crypto.sha256, utf8.encode(token));
  return Uint8List.fromList(mac.convert(utf8.encode(label)).bytes);
}

void _requireLength(String name, List<int> value, int expected) {
  if (value.length != expected) {
    throw ArgumentError.value(value.length, name, 'must be $expected bytes');
  }
}

int _requireInt(String name, Object? value) {
  if (value is! int) {
    throw RelayCryptoException('$name must be an integer');
  }
  return value;
}

String _requireString(String name, Object? value) {
  if (value is! String) {
    throw RelayCryptoException('$name must be a string');
  }
  return value;
}

bool _constantListEquals(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  var mismatch = 0;
  for (var i = 0; i < a.length; i++) {
    mismatch |= a[i] ^ b[i];
  }
  return mismatch == 0;
}
