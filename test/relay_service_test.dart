import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/relay_service.dart';
import 'package:osia_mobile/services/storage_service.dart';

void main() {
  test('relay pair derivation is stable and does not expose the token', () {
    final a = RelayService.derivePairCredentials('osia-demo-token');
    final b = RelayService.derivePairCredentials('osia-demo-token');

    expect(a.pairId, b.pairId);
    expect(a.secret, b.secret);
    expect(a.pairId, hasLength(64));
    expect(a.secret, hasLength(64));
    expect(a.pairId, isNot(contains('osia-demo-token')));
    expect(a.secret, isNot(contains('osia-demo-token')));
  });

  test('production relay derivation matches the shared route fixture', () {
    final vector =
        jsonDecode(
              File('test/fixtures/relay_v2_vectors.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final credentials = RelayService.derivePairCredentials(
      vector['token'] as String,
    );

    expect(credentials.secret, vector['relay_proof_hex']);
    expect(credentials.pairId, vector['pair_id']);
  });

  test(
    'v2 config emits pair-only URL and leaves legacy device storage inert',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'osia_relay_device_id': 'mobile-existing-legacy-id',
      });
      final storage = StorageService();
      final config = await RelayService(
        storage: storage,
      ).connectionConfig('osia-demo-token');

      expect(
        config.endpoint.toString(),
        'wss://relay.osia.space/ws?pair_id=${config.pairId}',
      );
      expect(config.endpoint.queryParameters.keys, <String>['pair_id']);
      expect(
        await const FlutterSecureStorage().read(key: 'osia_relay_device_id'),
        'mobile-existing-legacy-id',
      );
    },
  );

  test('custom relay bases fail closed on metadata-bearing shapes', () {
    const pairId =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    for (final raw in <String>[
      'https://relay.test',
      'wss://user:pass@relay.test',
      'wss://relay.test/ws?role=mobile',
      'wss://relay.test/ws#fragment',
      'wss://relay.test/other',
    ]) {
      expect(
        () => RelayService.buildEndpoint(Uri.parse(raw), pairId),
        throwsFormatException,
        reason: raw,
      );
    }
  });
}
