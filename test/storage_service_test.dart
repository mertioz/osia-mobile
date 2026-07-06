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
}
