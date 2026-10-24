import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:osia_mobile/guide/onboarding_content.dart';
import 'package:osia_mobile/guide_progress.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/onboarding_screen.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/theme.dart';

import '../test/widget_test.dart' as startup;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Android debug uses space.osia.app.test. The native storage probe uses its
  // own preference namespace; UI tests never open the production app's store.
  testWidgets('native secure storage retains every selected language', (
    tester,
  ) async {
    const native = FlutterSecureStorage(
      aOptions: AndroidOptions(
        sharedPreferencesName: 'osia_onboarding_validation',
        preferencesKeyPrefix: 'onboarding_validation_',
      ),
      iOptions: IOSOptions(accountName: 'osia_onboarding_validation'),
    );
    final storage = StorageService(storage: native);
    final original = await storage.getLanguageCode();
    try {
      for (final language in osiaSupportedLanguages) {
        await storage.setLanguageCode(language);
        final restored = StorageService(storage: native);
        expect(await restored.getLanguageCode(), language);
      }
    } finally {
      if (original == null) {
        await native.delete(key: 'osia_language');
      } else {
        await storage.setLanguageCode(original);
      }
    }
  });

  // Rendering, font fallback, input and OS safe areas run on the real device.
  group('app startup and preference projection', startup.main);

  for (final language in osiaSupportedLanguages) {
    for (final compact in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('device $language: compact=$compact, ${scale * 100}% text', (
          tester,
        ) async {
          FlutterSecureStorage.setMockInitialValues({});
          final controller = LanguageController(
            initial: osiaStringsForCode(language),
          );
          addTearDown(controller.dispose);
          var closed = 0;
          await tester.pumpWidget(
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) => OsiaTheme(
                palette: osiaPalette,
                child: OsiaL10n(
                  strings: controller.strings,
                  child: MaterialApp(
                    theme: buildOsiaTheme(),
                    home: Builder(
                      builder: (context) => Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: compact ? 320 : null,
                          height: compact ? 568 : null,
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaler: TextScaler.linear(scale),
                              size: compact ? const Size(320, 568) : null,
                              padding: compact
                                  ? const EdgeInsets.symmetric(vertical: 24)
                                  : null,
                            ),
                            child: RepaintBoundary(
                              key: const Key('device-onboarding-capture'),
                              child: OnboardingScreen(
                                storage: StorageService(),
                                initialProgress:
                                    GuideProgress.freshPresentation(),
                                onClosed: () => closed++,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final semantics = tester.ensureSemantics();
          for (var index = 0; index < onboardingSlides.length; index++) {
            final slide = onboardingSlides[index];
            final body = find.byKey(Key('onboarding-body-${slide.id}'));
            final title = find.byKey(Key('onboarding-title-${slide.id}'));
            expect(
              tester.widget<Text>(body).data,
              slide.body.resolve(language),
            );
            expect(
              tester.widget<Text>(title).data,
              slide.title.resolve(language),
            );
            expect(
              find.byKey(Key('onboarding-image-${slide.id}')),
              findsOneWidget,
            );
            expect(
              find.byTooltip(OnboardingLabels.close.resolve(language)),
              findsOneWidget,
            );
            final nextLabel =
                (index == 9 ? OnboardingLabels.start : OnboardingLabels.next)
                    .resolve(language);
            expect(find.byTooltip(nextLabel), findsOneWidget);
            expect(find.text('${index + 1} / 10'), findsOneWidget);
            expect(
              tester
                  .getSemantics(find.byKey(const Key('onboarding-semantics')))
                  .label,
              '${OnboardingLabels.progress(language, index + 1, 10)}: ${slide.title.resolve(language)}',
            );

            final paragraph = tester.renderObject<RenderParagraph>(body);
            if (scale == 1) {
              final painter = TextPainter(
                text: paragraph.text,
                textDirection: TextDirection.ltr,
                textScaler: paragraph.textScaler,
                locale: Locale(language),
              )..layout(maxWidth: paragraph.size.width);
              expect(
                painter.computeLineMetrics(),
                hasLength(2),
                reason: '$language ${slide.id} native fonts',
              );
              painter.dispose();
            }
            await tester.ensureVisible(body);
            await tester.pumpAndSettle();
            final arrow = tester.getRect(
              find.byKey(const Key('onboarding-next')),
            );
            final media = MediaQuery.of(
              tester.element(find.byKey(const Key('onboarding-screen'))),
            );
            expect(tester.getRect(body).bottom, lessThanOrEqualTo(arrow.top));
            expect(
              arrow.bottom,
              lessThanOrEqualTo(media.size.height - media.padding.bottom),
            );
            expect(arrow.size.shortestSide, greaterThanOrEqualTo(48));
            expect(
              tester.takeException(),
              isNull,
              reason: '$language ${slide.id}',
            );
            if (const bool.fromEnvironment('OSIA_ONBOARDING_CAPTURE') &&
                !compact &&
                scale == 1) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('device-onboarding-capture')),
              );
              final image = await boundary.toImage();
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final directory = Directory(
                '${(await getTemporaryDirectory()).path}/onboarding-review',
              );
              await directory.create(recursive: true);
              await File(
                '${directory.path}/$language-${index + 1}.png',
              ).writeAsBytes(bytes.buffer.asUint8List());
              image.dispose();
            }
            if (index < 9) {
              // Exercise real swipe input and the arrow alternately.
              if (index.isEven) {
                await tester.drag(
                  find.byKey(const Key('onboarding-pages')),
                  Offset(-media.size.width * 0.75, 0),
                );
              } else {
                await tester.tap(find.byKey(const Key('onboarding-next')));
              }
              await tester.pumpAndSettle();
            }
          }
          await tester.tap(find.byKey(const Key('onboarding-next')));
          await tester.pumpAndSettle();
          expect(closed, 1);
          semantics.dispose();
        });
      }
    }
  }
}
