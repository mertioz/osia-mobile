import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash_crypto;
import 'package:cryptography/cryptography.dart' as crypto_lib;

const int relayE2eVersion = 1;
const String relayCryptoAlgChacha20Poly1305 = 'CHACHA20-POLY1305';
const String relayPriorityCritical = 'critical';
const String relayPriorityNormal = 'normal';
const String relayPriorityDroppable = 'droppable';
const int relayE2eChunkVersion = 1;
const int relayE2eSafeFrameBytes = 49152;
const int relayE2eChunkCiphertextChars = 40960;
const int relayE2eChunkMaxTotalBytes = 8 * 1024 * 1024;
const int relayE2eChunkMaxCount = 256;
const int relayE2eChunkMaxInflight = 4;
const Duration relayE2eChunkTimeout = Duration(seconds: 30);

const String _legacyPairSecretLabel = 'osia-relay-secret-v1';
const String _e2ePskLabel = 'osia-e2e-psk-v1';
const String _sessionInfo = 'osia-relay-e2e-session-v1';
const String _readyTagLabel = 'osia-e2e-ready-v1';
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
  'role',
  'seq',
  'priority',
  'final',
];
const Set<String> _v2ChunkFields = <String>{
  'v',
  'type',
  'role',
  'pair_id',
  'seq',
  'ack',
  'e2e_version',
  'alg',
  'kid',
  'frame_seq',
  'priority',
  'final',
  'nonce',
  'chunk_id',
  'chunk_index',
  'chunk_count',
  'total_bytes',
  'ciphertext_chunk',
};

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

class RelayChunkException extends RelayCryptoException {
  RelayChunkException(
    super.message, {
    required this.chunkId,
    required this.code,
  });

  final String chunkId;
  final String code;
}

class RelayChunkConflictException extends RelayChunkException {
  RelayChunkConflictException(super.message, {required super.chunkId})
    : super(code: 'chunk_conflict');
}

class RelayChunkLimitException extends RelayChunkException {
  RelayChunkLimitException(super.message, {required super.chunkId})
    : super(code: 'chunk_capacity');
}

class RelayChunkTimeoutEvent {
  const RelayChunkTimeoutEvent({required this.chunkId});

  final String chunkId;
}

class RelayChunkAcceptResult {
  const RelayChunkAcceptResult({
    required this.chunkId,
    this.started = false,
    this.duplicate = false,
    this.expired = false,
    this.completeEnvelope,
  });

  final String chunkId;
  final bool started;
  final bool duplicate;
  final bool expired;
  final Map<String, Object?>? completeEnvelope;

  bool get completed => completeEnvelope != null;
}

int relaySerializedJsonBytes(Map<String, Object?> envelope) =>
    utf8.encode(jsonEncode(envelope)).length;

String generateRelayChunkId() => b64UrlEncodeNoPadding(randomBytes(16));

List<Map<String, Object?>> buildRelayE2eChunks(
  Map<String, Object?> envelope, {
  required String chunkId,
  required int Function(int chunkIndex) relaySeqForIndex,
}) {
  if (envelope['type'] != 'E2E_FRAME') {
    throw RelayCryptoException('only E2E_FRAME can be chunked');
  }
  final ciphertext = _requireString('ciphertext', envelope['ciphertext']);
  final totalBytes = utf8.encode(ciphertext).length;
  if (totalBytes <= 0 || totalBytes > relayE2eChunkMaxTotalBytes) {
    throw RelayChunkLimitException(
      'chunked ciphertext exceeds the total-size limit',
      chunkId: chunkId,
    );
  }
  final chunkCount =
      (totalBytes + relayE2eChunkCiphertextChars - 1) ~/
      relayE2eChunkCiphertextChars;
  if (chunkCount > relayE2eChunkMaxCount) {
    throw RelayChunkLimitException(
      'chunk count exceeds the relay limit',
      chunkId: chunkId,
    );
  }
  final frameSeq = _requireInt('seq', envelope['seq']);
  final chunks = <Map<String, Object?>>[];
  for (var index = 0; index < chunkCount; index++) {
    final start = index * relayE2eChunkCiphertextChars;
    final end = min(start + relayE2eChunkCiphertextChars, ciphertext.length);
    final chunk = <String, Object?>{
      'v': envelope['v'],
      'type': 'E2E_CHUNK',
      'role': envelope['role'],
      'pair_id': envelope['pair_id'],
      'seq': relaySeqForIndex(index),
      'ack': envelope['ack'],
      'e2e_version': envelope['e2e_version'],
      'alg': envelope['alg'],
      'kid': envelope['kid'],
      'frame_seq': frameSeq,
      'priority': envelope['priority'],
      'final': envelope['final'],
      'nonce': envelope['nonce'],
      'chunk_id': chunkId,
      'chunk_index': index,
      'chunk_count': chunkCount,
      'total_bytes': totalBytes,
      'ciphertext_chunk': ciphertext.substring(start, end),
    };
    final serializedBytes = relaySerializedJsonBytes(chunk);
    if (serializedBytes > relayE2eSafeFrameBytes) {
      throw RelayChunkLimitException(
        'serialized E2E_CHUNK exceeds the safe frame size',
        chunkId: chunkId,
      );
    }
    chunks.add(chunk);
  }
  return chunks;
}

class RelayE2eChunkReassembler {
  RelayE2eChunkReassembler({
    this.timeout = relayE2eChunkTimeout,
    this.onTimeout,
  });

  static const int _maxTombstones = 64;

  final Duration timeout;
  final void Function(RelayChunkTimeoutEvent event)? onTimeout;
  final Map<String, _RelayChunkAssembly> _assemblies =
      <String, _RelayChunkAssembly>{};
  final Map<String, _RelayChunkTombstone> _tombstones =
      <String, _RelayChunkTombstone>{};

  int get inflightCount => _assemblies.length;

  RelayChunkAcceptResult accept(Map<String, Object?> envelope) {
    final chunk = _RelayNormalizedChunk.fromEnvelope(envelope);
    final key = chunk.assemblyKey;
    final tombstone = _tombstones[key];
    if (tombstone != null) {
      if (tombstone.stableMetadata != chunk.stableMetadata) {
        throw RelayChunkConflictException(
          'chunk metadata conflicts with a completed transfer',
          chunkId: chunk.chunkId,
        );
      }
      final expectedHash = tombstone.chunkHashes[chunk.index];
      if (expectedHash != null && expectedHash != chunk.dataHash) {
        throw RelayChunkConflictException(
          'duplicate chunk content conflicts with a completed transfer',
          chunkId: chunk.chunkId,
        );
      }
      return RelayChunkAcceptResult(
        chunkId: chunk.chunkId,
        duplicate: true,
        expired: tombstone.expired,
      );
    }

    var assembly = _assemblies[key];
    var started = false;
    if (assembly == null) {
      if (_assemblies.length >= relayE2eChunkMaxInflight) {
        throw RelayChunkLimitException(
          'too many incomplete E2E chunk transfers',
          chunkId: chunk.chunkId,
        );
      }
      started = true;
      assembly = _RelayChunkAssembly(
        chunk: chunk,
        timer: Timer(timeout, () => _expire(key)),
      );
      _assemblies[key] = assembly;
    } else if (assembly.stableMetadata != chunk.stableMetadata) {
      throw RelayChunkConflictException(
        'chunk metadata conflicts with the active transfer',
        chunkId: chunk.chunkId,
      );
    }

    final existing = assembly.parts[chunk.index];
    if (existing != null) {
      if (existing != chunk.data) {
        throw RelayChunkConflictException(
          'duplicate chunk content conflicts with the active transfer',
          chunkId: chunk.chunkId,
        );
      }
      return RelayChunkAcceptResult(chunkId: chunk.chunkId, duplicate: true);
    }
    assembly.parts[chunk.index] = chunk.data;
    assembly.chunkHashes[chunk.index] = chunk.dataHash;
    if (assembly.parts.length != chunk.count) {
      return RelayChunkAcceptResult(chunkId: chunk.chunkId, started: started);
    }

    final ciphertext = StringBuffer();
    for (var index = 0; index < chunk.count; index++) {
      final part = assembly.parts[index];
      if (part == null) {
        throw RelayChunkException(
          'chunk transfer completed with a missing index',
          chunkId: chunk.chunkId,
          code: 'chunk_invalid',
        );
      }
      ciphertext.write(part);
    }
    final joined = ciphertext.toString();
    if (utf8.encode(joined).length != chunk.totalBytes) {
      throw RelayChunkException(
        'reassembled ciphertext length does not match total_bytes',
        chunkId: chunk.chunkId,
        code: 'chunk_invalid',
      );
    }

    _assemblies.remove(key);
    assembly.timer.cancel();
    _addTombstone(
      key,
      stableMetadata: assembly.stableMetadata,
      chunkHashes: assembly.chunkHashes,
      expired: false,
    );
    return RelayChunkAcceptResult(
      chunkId: chunk.chunkId,
      started: started,
      completeEnvelope: chunk.rebuildEnvelope(joined),
    );
  }

  void clear() {
    for (final assembly in _assemblies.values) {
      assembly.timer.cancel();
    }
    for (final tombstone in _tombstones.values) {
      tombstone.timer.cancel();
    }
    _assemblies.clear();
    _tombstones.clear();
  }

  void _expire(String key) {
    final assembly = _assemblies.remove(key);
    if (assembly == null) return;
    _addTombstone(
      key,
      stableMetadata: assembly.stableMetadata,
      chunkHashes: assembly.chunkHashes,
      expired: true,
    );
    onTimeout?.call(RelayChunkTimeoutEvent(chunkId: assembly.chunkId));
  }

  void _addTombstone(
    String key, {
    required String stableMetadata,
    required Map<int, String> chunkHashes,
    required bool expired,
  }) {
    final previous = _tombstones.remove(key);
    previous?.timer.cancel();
    while (_tombstones.length >= _maxTombstones) {
      final oldestKey = _tombstones.keys.first;
      _tombstones.remove(oldestKey)?.timer.cancel();
    }
    late final Timer timer;
    timer = Timer(timeout, () {
      final current = _tombstones[key];
      if (current != null && identical(current.timer, timer)) {
        _tombstones.remove(key);
      }
    });
    _tombstones[key] = _RelayChunkTombstone(
      stableMetadata: stableMetadata,
      chunkHashes: Map<int, String>.from(chunkHashes),
      expired: expired,
      timer: timer,
    );
  }
}

class _RelayNormalizedChunk {
  _RelayNormalizedChunk({
    required this.envelope,
    required this.chunkId,
    required this.index,
    required this.count,
    required this.totalBytes,
    required this.data,
    required this.assemblyKey,
    required this.stableMetadata,
  });

  final Map<String, Object?> envelope;
  final String chunkId;
  final int index;
  final int count;
  final int totalBytes;
  final String data;
  final String assemblyKey;
  final String stableMetadata;

  String get dataHash =>
      hash_crypto.sha256.convert(utf8.encode(data)).toString();

  static _RelayNormalizedChunk fromEnvelope(Map<String, Object?> envelope) {
    if (envelope['type'] != 'E2E_CHUNK') {
      throw RelayCryptoException('expected E2E_CHUNK');
    }
    if (relaySerializedJsonBytes(envelope) > relayE2eSafeFrameBytes) {
      throw RelayChunkLimitException(
        'serialized E2E_CHUNK exceeds the safe frame size',
        chunkId: envelope['chunk_id']?.toString() ?? '',
      );
    }
    if (envelope.keys.any((field) => !_v2ChunkFields.contains(field))) {
      throw RelayChunkLimitException(
        'unexpected v2 chunk field',
        chunkId: envelope['chunk_id']?.toString() ?? '',
      );
    }
    final chunkId = _requireString('chunk_id', envelope['chunk_id']);
    if (!RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(chunkId)) {
      throw RelayChunkLimitException(
        'chunk_id has an invalid encoding',
        chunkId: chunkId,
      );
    }
    final index = _requireInt('chunk_index', envelope['chunk_index']);
    final count = _requireInt('chunk_count', envelope['chunk_count']);
    final totalBytes = _requireInt('total_bytes', envelope['total_bytes']);
    final data = _requireString(
      'ciphertext_chunk',
      envelope['ciphertext_chunk'],
    );
    if (count <= 0 || count > relayE2eChunkMaxCount) {
      throw RelayChunkLimitException('invalid chunk_count', chunkId: chunkId);
    }
    if (index < 0 || index >= count) {
      throw RelayChunkLimitException(
        'chunk_index is outside chunk_count',
        chunkId: chunkId,
      );
    }
    if (totalBytes <= 0 || totalBytes > relayE2eChunkMaxTotalBytes) {
      throw RelayChunkLimitException('invalid total_bytes', chunkId: chunkId);
    }
    final expectedCount =
        (totalBytes + relayE2eChunkCiphertextChars - 1) ~/
        relayE2eChunkCiphertextChars;
    if (count != expectedCount) {
      throw RelayChunkLimitException(
        'chunk_count does not match total_bytes',
        chunkId: chunkId,
      );
    }
    final expectedLength = index == count - 1
        ? totalBytes - (relayE2eChunkCiphertextChars * (count - 1))
        : relayE2eChunkCiphertextChars;
    if (data.length != expectedLength ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(data)) {
      throw RelayChunkLimitException(
        'ciphertext_chunk has an invalid length or encoding',
        chunkId: chunkId,
      );
    }
    final outerSeq = _requireInt('seq', envelope['seq']);
    final frameSeq = _requireInt('frame_seq', envelope['frame_seq']);
    if (outerSeq <= 0 || frameSeq <= 0 || outerSeq != frameSeq + index) {
      throw RelayChunkLimitException(
        'relay sequence does not match frame_seq and chunk_index',
        chunkId: chunkId,
      );
    }
    if (_requireInt('v', envelope['v']) != 2 ||
        _requireInt('e2e_version', envelope['e2e_version']) !=
            relayE2eChunkVersion ||
        _requireString('alg', envelope['alg']) !=
            relayCryptoAlgChacha20Poly1305) {
      throw RelayChunkLimitException(
        'unsupported chunk envelope version or algorithm',
        chunkId: chunkId,
      );
    }
    if (_requireInt('ack', envelope['ack']) < 0) {
      throw RelayChunkLimitException(
        'ack must be non-negative',
        chunkId: chunkId,
      );
    }
    _requireBool('final', envelope['final']);
    final role = _requireString('role', envelope['role']);
    if (role != 'pc' && role != 'mobile') {
      throw RelayChunkLimitException('invalid relay role', chunkId: chunkId);
    }
    if (!RegExp(
      r'^[0-9a-f]{64}$',
    ).hasMatch(_requireString('pair_id', envelope['pair_id']))) {
      throw RelayChunkLimitException('invalid pair route', chunkId: chunkId);
    }
    if (!RegExp(
          r'^[A-Za-z0-9_-]{22}$',
        ).hasMatch(_requireString('kid', envelope['kid'])) ||
        !RegExp(
          r'^[A-Za-z0-9_-]{16}$',
        ).hasMatch(_requireString('nonce', envelope['nonce']))) {
      throw RelayChunkLimitException(
        'invalid chunk crypto metadata',
        chunkId: chunkId,
      );
    }
    final priority = _requireString('priority', envelope['priority']);
    if (priority != relayPriorityCritical &&
        priority != relayPriorityNormal &&
        priority != relayPriorityDroppable) {
      throw RelayChunkLimitException(
        'invalid chunk delivery priority',
        chunkId: chunkId,
      );
    }
    final stable = <String, Object?>{
      'v': envelope['v'],
      'role': envelope['role'],
      'pair_id': envelope['pair_id'],
      'ack': envelope['ack'],
      'e2e_version': envelope['e2e_version'],
      'alg': envelope['alg'],
      'kid': envelope['kid'],
      'frame_seq': frameSeq,
      'priority': envelope['priority'],
      'final': envelope['final'],
      'nonce': envelope['nonce'],
      'chunk_id': chunkId,
      'chunk_count': count,
      'total_bytes': totalBytes,
    };
    final key = <String, Object?>{
      'role': envelope['role'],
      'pair_id': envelope['pair_id'],
      'kid': envelope['kid'],
      'frame_seq': frameSeq,
      'chunk_id': chunkId,
    };
    return _RelayNormalizedChunk(
      envelope: Map<String, Object?>.from(envelope),
      chunkId: chunkId,
      index: index,
      count: count,
      totalBytes: totalBytes,
      data: data,
      assemblyKey: canonicalJson(key),
      stableMetadata: canonicalJson(stable),
    );
  }

  Map<String, Object?> rebuildEnvelope(String ciphertext) => <String, Object?>{
    'v': envelope['v'],
    'type': 'E2E_FRAME',
    'role': envelope['role'],
    'pair_id': envelope['pair_id'],
    'seq': envelope['frame_seq'],
    'ack': envelope['ack'],
    'e2e_version': envelope['e2e_version'],
    'alg': envelope['alg'],
    'kid': envelope['kid'],
    'priority': envelope['priority'],
    'final': envelope['final'],
    'nonce': envelope['nonce'],
    'ciphertext': ciphertext,
  };
}

class _RelayChunkAssembly {
  _RelayChunkAssembly({
    required _RelayNormalizedChunk chunk,
    required this.timer,
  }) : chunkId = chunk.chunkId,
       stableMetadata = chunk.stableMetadata;

  final String chunkId;
  final String stableMetadata;
  final Timer timer;
  final Map<int, String> parts = <int, String>{};
  final Map<int, String> chunkHashes = <int, String>{};
}

class _RelayChunkTombstone {
  const _RelayChunkTombstone({
    required this.stableMetadata,
    required this.chunkHashes,
    required this.expired,
    required this.timer,
  });

  final String stableMetadata;
  final Map<int, String> chunkHashes;
  final bool expired;
  final Timer timer;
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

Uint8List generateX25519PrivateKey() => randomBytes(32);

Uint8List generateNonceBase() => randomBytes(_nonceBaseLength);

Uint8List randomBytes(int length) {
  if (length < 0) {
    throw ArgumentError.value(length, 'length', 'must be non-negative');
  }
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

Future<Uint8List> x25519PublicKey(List<int> privateKeyBytes) async {
  _requireLength('privateKeyBytes', privateKeyBytes, 32);
  final keyPair = await crypto_lib.X25519().newKeyPairFromSeed(privateKeyBytes);
  final publicKey = await keyPair.extractPublicKey();
  return Uint8List.fromList(publicKey.bytes);
}

class RelaySessionContext {
  RelaySessionContext({
    required this.pairId,
    required this.pcPublicKey,
    required this.mobilePublicKey,
    required this.pcNonceBase,
    required this.mobileNonceBase,
    this.e2eVersion = relayE2eVersion,
    this.alg = relayCryptoAlgChacha20Poly1305,
  }) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(pairId)) {
      throw ArgumentError.value(pairId, 'pairId', 'must be lowercase 64-hex');
    }
    _requireLength('pcPublicKey', pcPublicKey, 32);
    _requireLength('mobilePublicKey', mobilePublicKey, 32);
    _requireLength('pcNonceBase', pcNonceBase, _nonceBaseLength);
    _requireLength('mobileNonceBase', mobileNonceBase, _nonceBaseLength);
  }

  final String pairId;
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
    'roles': <String>['pc', 'mobile'],
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

String handshakeConfirmationTag({
  required String token,
  required RelaySessionContext context,
  required String senderRole,
}) {
  final body = <String, Object?>{
    'label': _readyTagLabel,
    'sender_role': senderRole,
    'transcript': context.transcript(),
  };
  final mac = hash_crypto.Hmac(hash_crypto.sha256, deriveE2ePsk(token));
  return b64UrlEncodeNoPadding(mac.convert(canonicalJsonBytes(body)).bytes);
}

bool verifyHandshakeConfirmation({
  required String token,
  required RelaySessionContext context,
  required String senderRole,
  required String tag,
}) {
  final expected = handshakeConfirmationTag(
    token: token,
    context: context,
    senderRole: senderRole,
  );
  return _constantListEquals(
    b64UrlDecodeNoPadding(expected),
    b64UrlDecodeNoPadding(tag),
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
  required String role,
  required int seq,
  required String priority,
  required bool finalFrame,
}) {
  if (role != 'pc' && role != 'mobile') {
    throw ArgumentError.value(role, 'role', 'must be pc or mobile');
  }
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(pairId)) {
    throw ArgumentError.value(pairId, 'pairId', 'must be lowercase 64-hex');
  }
  return <String, Object?>{
    'e2e_version': relayE2eVersion,
    'alg': relayCryptoAlgChacha20Poly1305,
    'kid': keys.kid,
    'pair_id': pairId,
    'role': role,
    'seq': seq,
    'priority': priority,
    'final': finalFrame,
  };
}

bool relayFrameIsFinal(Map<String, Object?> frame) {
  final type = frame['type']?.toString() ?? '';
  if (type == 'status') {
    final content = (frame['content'] ?? frame['status'])?.toString() ?? '';
    return content == 'done' || content == 'error';
  }
  if (type == 'turn_status') {
    final status = frame['status']?.toString() ?? '';
    return status == 'done' || status == 'error';
  }
  if (type == 'conversation_busy_changed') {
    return frame['busy'] == false;
  }
  return type == 'response_done' ||
      type == 'turn_complete' ||
      type == 'done' ||
      type == 'final' ||
      type == 'error';
}

String relayFramePriority(Map<String, Object?> frame) {
  final type = frame['type']?.toString() ?? '';
  if (relayFrameIsFinal(frame)) return relayPriorityCritical;
  if (type == 'response' ||
      type == 'turn_accepted' ||
      type == 'turn_status' ||
      type == 'conversation_busy' ||
      type == 'conversation_busy_changed' ||
      type == 'active_conversation' ||
      type == 'conversation_history' ||
      type == 'relay_chunk_error' ||
      type == 'cron_notification') {
    return relayPriorityCritical;
  }
  if (type == 'heartbeat_data' || type == 'mcp_status') {
    return relayPriorityDroppable;
  }
  if (type == 'status') return relayPriorityDroppable;
  return relayPriorityNormal;
}

Future<Map<String, Object?>> encryptFrame(
  Map<String, Object?> frame, {
  required RelaySessionKeys keys,
  required RelayCryptoDirection direction,
  required String pairId,
  required String role,
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
    role: role,
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
  if (const <String>{
    'device_id',
    'session_id',
    'from',
    'to',
    'to_session_id',
  }.any(envelope.containsKey)) {
    throw RelayCryptoException('legacy relay identity metadata is not allowed');
  }
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
      replayKey ?? _requireString('role', metadata['role']),
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

bool _requireBool(String name, Object? value) {
  if (value is! bool) {
    throw RelayCryptoException('$name must be a boolean');
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
