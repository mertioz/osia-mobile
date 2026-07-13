import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/storage_service.dart';

void main() {
  group('StorageService server host migration', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('defaults new installs to the app endpoint', () {
      expect(StorageService.defaultHost, 'app.osia.space');
    });

    test('migrates the exact legacy default host', () async {
      FlutterSecureStorage.setMockInitialValues({
        'osia_tailscale_ip': 'osia.space',
      });

      final storage = StorageService();

      expect(await storage.getTailscaleIp(), 'app.osia.space');
      expect(
        await const FlutterSecureStorage().read(key: 'osia_tailscale_ip'),
        'app.osia.space',
      );
    });

    test('preserves custom hosts', () async {
      FlutterSecureStorage.setMockInitialValues({
        'osia_tailscale_ip': 'custom.example.com',
      });

      final storage = StorageService();

      expect(await storage.getTailscaleIp(), 'custom.example.com');
    });

    test('preserves legacy-like custom URL forms', () async {
      FlutterSecureStorage.setMockInitialValues({
        'osia_tailscale_ip': 'https://osia.space',
      });

      final storage = StorageService();

      expect(await storage.getTailscaleIp(), 'https://osia.space');
    });
  });

  group('StorageService authenticated LAN pairing', () {
    const pairId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const pin =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const alias = '0123456789abcdef';

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('stores and reloads the authenticated alias and pin', () async {
      final storage = StorageService();
      await storage.setLanPairing(
        pairId,
        const LanPairingIdentity(instanceAlias: alias, certificateSha256: pin),
      );

      final restored = await storage.getLanPairing(pairId);

      expect(restored, isNotNull);
      expect(restored!.instanceAlias, alias);
      expect(restored.certificateSha256, pin);
    });

    test('invalid pairing identity fails closed', () async {
      final storage = StorageService();

      expect(await storage.getLanPairing('invalid'), isNull);
      expect(
        () => storage.setLanPairing(
          pairId,
          const LanPairingIdentity(
            instanceAlias: 'invalid',
            certificateSha256: pin,
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'model clearing preserves pairing but credential clearing removes it',
      () async {
        final storage = StorageService();
        await storage.setLanPairing(
          pairId,
          const LanPairingIdentity(
            instanceAlias: alias,
            certificateSha256: pin,
          ),
        );

        await storage.clearSelectedModel();
        expect(await storage.getLanPairing(pairId), isNotNull);

        await storage.clearCredentials();
        expect(await storage.getLanPairing(pairId), isNull);
      },
    );
  });
}
