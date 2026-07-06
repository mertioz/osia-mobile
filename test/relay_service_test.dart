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

  test('relay device id is generated once and then reused', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = StorageService();

    final first = await storage.getOrCreateRelayDeviceId();
    final second = await storage.getOrCreateRelayDeviceId();

    expect(first, startsWith('mobile-'));
    expect(second, first);
  });
}
