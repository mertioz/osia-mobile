import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:osia_mobile/main.dart';
import 'package:osia_mobile/guide/onboarding_content.dart';
import 'package:osia_mobile/guide_progress.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/screens/connection_screen.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  testWidgets('fresh app presents onboarding once before connection', (
    tester,
  ) async {
    await tester.pumpWidget(const OsiaApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('onboarding-screen')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-title-welcome')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ConnectionScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const OsiaApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('onboarding-screen')), findsNothing);
    expect(find.byType(ConnectionScreen), findsOneWidget);
  });

  testWidgets('existing app state suppresses automatic onboarding', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'osia_language': 'en',
    });
    await tester.pumpWidget(const OsiaApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('onboarding-screen')), findsNothing);
    expect(find.byType(ConnectionScreen), findsOneWidget);
  });

  Future<void> startApp(WidgetTester tester) async {
    await tester.pumpWidget(const OsiaApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final deviceLanguage in [...osiaSupportedLanguages, 'it']) {
    testWidgets(
      'fresh app stays English on a $deviceLanguage device and restart',
      (tester) async {
        tester.platformDispatcher.localeTestValue = Locale(deviceLanguage);
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await startApp(tester);
        expect(find.text('Welcome to OSIA'), findsOneWidget);
        expect(find.byTooltip('Next step'), findsOneWidget);
        expect(
          OsiaL10n.of(
            tester.element(find.byKey(const Key('onboarding-screen'))),
          ).languageCode,
          'en',
        );
        await tester.tap(find.byKey(const Key('onboarding-close')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(osiaStringsEn.enterYourToken), findsOneWidget);
        // A default is not saved as though the user explicitly chose it.
        expect(await StorageService().getLanguageCode(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await startApp(tester);
        expect(find.byKey(const Key('onboarding-screen')), findsNothing);
        expect(find.text(osiaStringsEn.enterYourToken), findsOneWidget);
        expect(await StorageService().getLanguageCode(), isNull);
      },
    );
  }

  for (final language in osiaSupportedLanguages) {
    testWidgets(
      '$language preference survives bootstrap, onboarding and restart',
      (tester) async {
        // A saved choice can coexist with a pending presentation claim.
        final storage = StorageService();
        await storage.setLanguageCode(language);
        await GuideProgressService(storage).save(
          GuideProgress.freshPresentation().copyWith(
            automaticPresentationHandled: false,
          ),
        );
        tester.platformDispatcher.localeTestValue = Locale(
          language == 'fr' ? 'ja' : 'fr',
        );
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await startApp(tester);
        expect(
          find.text(onboardingSlides.first.title.resolve(language)),
          findsOneWidget,
        );
        expect(
          find.byTooltip(OnboardingLabels.next.resolve(language)),
          findsOneWidget,
        );
        expect(
          OsiaL10n.of(
            tester.element(find.byKey(const Key('onboarding-screen'))),
          ).languageCode,
          language,
        );
        await tester.tap(find.byKey(const Key('onboarding-close')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.text(osiaStringsForCode(language).enterYourToken),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await startApp(tester);
        expect(find.byKey(const Key('onboarding-screen')), findsNothing);
        expect(
          find.text(osiaStringsForCode(language).enterYourToken),
          findsOneWidget,
        );
        expect(await storage.getLanguageCode(), language);
      },
    );

    testWidgets(
      '$language existing user keeps language without replaying onboarding',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({'osia_language': language});
        await startApp(tester);
        expect(find.byKey(const Key('onboarding-screen')), findsNothing);
        expect(
          find.text(osiaStringsForCode(language).enterYourToken),
          findsOneWidget,
        );
        expect(await StorageService().getLanguageCode(), language);
      },
    );
  }
}
