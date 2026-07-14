import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/storage_service.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('terms acceptance version and timestamp stay local', () async {
    final storage = StorageService();
    final acceptedAt = DateTime.utc(2026, 8, 1, 12, 30);
    await storage.recordTermsAcceptance('2026-08-01.1', acceptedAt);
    await storage.recordPrivacySeen('2026-08-01.1');

    expect(await storage.getAcceptedTermsVersion(), '2026-08-01.1');
    expect(await storage.getAcceptedTermsAt(), acceptedAt);
    expect(await storage.getSeenPrivacyVersion(), '2026-08-01.1');
  });

  test('disconnect preserves legal record and user preferences', () async {
    final storage = StorageService();
    await storage.setToken('token');
    await storage.recordTermsAcceptance(
      '2026-08-01.1',
      DateTime.utc(2026, 8, 1),
    );
    await storage.clearCredentials();

    expect(await storage.getToken(), isNull);
    expect(await storage.getAcceptedTermsVersion(), '2026-08-01.1');
  });
}
