import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'relay_crypto_service.dart';
import 'storage_service.dart';

class RelayConnectionConfig {
  final Uri endpoint;
  final String pairId;
  final String secret;
  final List<int> e2ePrivateKey;
  final List<int> e2ePublicKey;
  final List<int> e2eNonceBase;

  const RelayConnectionConfig({
    required this.endpoint,
    required this.pairId,
    required this.secret,
    required this.e2ePrivateKey,
    required this.e2ePublicKey,
    required this.e2eNonceBase,
  });
}

class RelayPairCredentials {
  final String pairId;
  final String secret;

  const RelayPairCredentials({required this.pairId, required this.secret});
}

class RelayService {
  static final Uri defaultEndpoint = Uri.parse('wss://relay.osia.space/ws');

  final StorageService storage;
  final Uri endpoint;

  RelayService({required this.storage, Uri? endpoint})
    : endpoint = endpoint ?? defaultEndpoint;

  static RelayPairCredentials derivePairCredentials(String token) {
    final secret = Hmac(
      sha256,
      utf8.encode(token),
    ).convert(utf8.encode('osia-relay-secret-v1')).toString();
    final pairId = sha256.convert(utf8.encode(secret)).toString();
    return RelayPairCredentials(pairId: pairId, secret: secret);
  }

  Future<RelayConnectionConfig> connectionConfig(String token) async {
    final creds = derivePairCredentials(token);
    final e2ePrivateKey = generateX25519PrivateKey();
    final e2ePublicKey = await x25519PublicKey(e2ePrivateKey);
    return RelayConnectionConfig(
      endpoint: buildEndpoint(endpoint, creds.pairId),
      pairId: creds.pairId,
      secret: creds.secret,
      e2ePrivateKey: e2ePrivateKey,
      e2ePublicKey: e2ePublicKey,
      e2eNonceBase: generateNonceBase(),
    );
  }

  static Uri buildEndpoint(Uri base, String pairId) {
    if ((base.scheme != 'ws' && base.scheme != 'wss') ||
        !base.hasAuthority ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(pairId) ||
        (base.path.isNotEmpty && base.path != '/' && base.path != '/ws')) {
      throw const FormatException(
        'Relay URL must be a credential-free ws/wss base without query or fragment',
      );
    }
    return base.replace(path: '/ws', queryParameters: {'pair_id': pairId});
  }
}
