import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:osia_mobile/legal_manifest.dart';
import 'package:osia_mobile/main.dart' as app;
import 'package:osia_mobile/services/storage_service.dart';

Finder keyed(String name) => find.byKey(Key(name));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture the built-in review experience on iPad', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = StorageService();
    await storage.setLanguageCode('en');
    await storage.recordTermsAcceptance(
      currentLegalManifest.termsVersion,
      DateTime.utc(2026, 11, 8),
    );
    await storage.recordPrivacySeen(currentLegalManifest.privacyVersion);

    await app.main();
    await tester.pumpAndSettle();
    final closeGuide = keyed('onboarding-close');
    if (closeGuide.evaluate().isNotEmpty) {
      await tester.tap(closeGuide);
      await tester.pumpAndSettle();
    }
    await tester.tap(keyed('review-mode-entry-tap-target'));
    await tester.pumpAndSettle();
    expect(keyed('review-mode-indicator'), findsOneWidget);

    await tester.tap(keyed('review-navigation-button'));
    await tester.pumpAndSettle();
    await tester.tap(keyed('review-nav-conversations'));
    await tester.pumpAndSettle();
    expect(keyed('review-conversation-review-walk'), findsOneWidget);
    await binding.takeScreenshot('02-Conversations');

    await tester.tap(keyed('review-conversation-review-walk'));
    await tester.pumpAndSettle();
    expect(find.text('Can you help me plan a short walk?'), findsOneWidget);
    await binding.takeScreenshot('01-Chat');

    await tester.tap(keyed('review-model-shortcut'));
    await tester.pumpAndSettle();
    expect(find.text('Sample Balanced'), findsOneWidget);
    await binding.takeScreenshot('03-Models');
  });
}
