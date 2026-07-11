import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/relay_crypto_service.dart';
import 'package:osia_mobile/services/relay_service.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  final token = Platform.environment['OSIA_RELAY_LIVE_TOKEN'];

  test(
    'public relay completes the authenticated E2E handshake',
    () async {
      final privateKey = generateX25519PrivateKey();
      final credentials = RelayService.derivePairCredentials(token!);
      final config = RelayConnectionConfig(
        endpoint: RelayService.buildEndpoint(
          RelayService.defaultEndpoint,
          credentials.pairId,
        ),
        pairId: credentials.pairId,
        secret: credentials.secret,
        e2ePrivateKey: privateKey,
        e2ePublicKey: await x25519PublicKey(privateKey),
        e2eNonceBase: generateNonceBase(),
      );
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

      await service.ensureConnected(reason: 'live_e2e_diagnostic');
      await Future<void>.delayed(Duration.zero);

      expect(
        service.state,
        ConnectionState.connected,
        reason:
            'handshake=${service.relayHandshakeStateForTest()} errors=$errors',
      );
    },
    skip: token == null || token.isEmpty
        ? 'Set OSIA_RELAY_LIVE_TOKEN for the opt-in live relay diagnostic.'
        : false,
  );
}
