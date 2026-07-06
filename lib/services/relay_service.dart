import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'storage_service.dart';

class RelayConnectionConfig {
  final Uri endpoint;
  final String pairId;
  final String secret;
  final String deviceId;
  final String sessionId;

  const RelayConnectionConfig({
    required this.endpoint,
    required this.pairId,
    required this.secret,
    required this.deviceId,
    required this.sessionId,
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
    final deviceId = await storage.getOrCreateRelayDeviceId();
    return RelayConnectionConfig(
      endpoint: endpoint,
      pairId: creds.pairId,
      secret: creds.secret,
      deviceId: deviceId,
      sessionId: 'mobile-${_randomHex(16)}',
    );
  }

  static String _randomHex(int bytes) {
    final random = Random.secure();
    final values = List<int>.generate(bytes, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
