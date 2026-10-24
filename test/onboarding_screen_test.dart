import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:osia_mobile/guide/onboarding_content.dart';
import 'package:osia_mobile/guide_progress.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/onboarding_screen.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Use the bundled production font, not the test-only Ahem square font,
    // when measuring line lengths and reviewing rendered screenshots.
    await (FontLoader('OnboardingInter')
          ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf')))
        .load();
    var cache = File(Platform.resolvedExecutable).parent;
    while (cache.path.split(Platform.pathSeparator).last != 'cache' &&
        cache.parent.path != cache.path) {
      cache = cache.parent;
    }
    final icons = File(
      '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(ByteData.sublistView(await icons.readAsBytes())),
        ))
        .load();
  });

  setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

  Future<StorageService> pumpOnboarding(
    WidgetTester tester, {
    String language = 'en',
    bool reducedMotion = false,
    LanguageController? controller,
    VoidCallback? onClosed,
  }) async {
    final storage = StorageService();
    final launch = await GuideProgressService(storage).prepareLaunch();
    final theme = buildOsiaTheme();
    final languageController =
        controller ?? LanguageController(initial: osiaStringsForCode(language));
    if (controller == null) addTearDown(languageController.dispose);
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: languageController,
        builder: (context, _) => OsiaL10n(
          strings: languageController.strings,
          child: OsiaTheme(
            palette: osiaPalette,
            child: MaterialApp(
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'OnboardingInter'),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reducedMotion),
                child: child!,
              ),
              home: RepaintBoundary(
                key: const Key('onboarding-capture'),
                child: OnboardingScreen(
                  storage: storage,
                  initialProgress: launch.progress,
                  onClosed: onClosed ?? () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return storage;
  }

  Future<void> next(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('onboarding-pages')),
      Offset(
        -tester.getSize(find.byKey(const Key('onboarding-pages'))).width * 0.75,
        0,
      ),
    );
    await tester.pumpAndSettle();
  }

  void resetView(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }

  test('ten slides and all controls have explicit complete translations', () {
    expect(onboardingSlides, hasLength(10));
    expect(onboardingSlides.map((s) => s.id).toSet(), hasLength(10));
    for (final slide in onboardingSlides) {
      expect(
        slide.title.translations.keys,
        unorderedEquals(osiaSupportedLanguages),
      );
      expect(
        slide.body.translations.keys,
        unorderedEquals(osiaSupportedLanguages),
      );
      expect(
        slide.title.translations.values.toSet(),
        hasLength(osiaSupportedLanguages.length),
      );
      expect(
        slide.body.translations.values.toSet(),
        hasLength(osiaSupportedLanguages.length),
      );
      for (final lang in osiaSupportedLanguages) {
        expect(slide.title.resolve(lang).trim(), isNotEmpty);
        expect(slide.body.resolve(lang).split('\n'), hasLength(2));
        expect(slide.body.resolve(lang).length, lessThanOrEqualTo(80));
      }
    }
    for (final label in [
      OnboardingLabels.close,
      OnboardingLabels.next,
      OnboardingLabels.start,
      OnboardingLabels.swipe,
      OnboardingLabels.step,
    ]) {
      expect(label.translations.keys, unorderedEquals(osiaSupportedLanguages));
      expect(
        label.translations.values.toSet(),
        hasLength(osiaSupportedLanguages.length),
      );
      for (final lang in osiaSupportedLanguages) {
        expect(label.resolve(lang).trim(), isNotEmpty);
        expect(OnboardingLabels.progress(lang, 2, 10), isNot(contains('{')));
      }
    }
    expect(
      () => onboardingSlides.first.title.resolve('xx'),
      throwsArgumentError,
    );
  });

  for (final language in osiaSupportedLanguages) {
    testWidgets(
      '$language: every slide fits two body lines on a 320px screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(() => resetView(tester));
        await pumpOnboarding(tester, language: language);
        for (var index = 0; index < onboardingSlides.length; index++) {
          final slide = onboardingSlides[index];
          final allowedText = <String>{
            'OSIA',
            '${index + 1} / 10',
            OnboardingLabels.swipe.resolve(language),
            for (final s in onboardingSlides) ...[
              s.title.resolve(language),
              s.body.resolve(language),
            ],
          };
          for (final text in tester.widgetList<Text>(
            find.descendant(
              of: find.byType(OnboardingScreen),
              matching: find.byType(Text),
            ),
          )) {
            expect(
              allowedText,
              contains(text.data),
              reason: '$language unexpected UI copy',
            );
          }
          final body = find.byKey(Key('onboarding-body-${slide.id}'));
          expect(tester.widget<Text>(body).data, slide.body.resolve(language));
          expect(
            tester
                .widget<Text>(find.byKey(Key('onboarding-title-${slide.id}')))
                .data,
            slide.title.resolve(language),
          );
          expect(
            find.byTooltip(OnboardingLabels.close.resolve(language)),
            findsOneWidget,
          );
          expect(
            find.byTooltip(
              (index == 9 ? OnboardingLabels.start : OnboardingLabels.next)
                  .resolve(language),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(Key('onboarding-image-${slide.id}')),
            findsOneWidget,
          );
          final paragraph = tester.renderObject<RenderParagraph>(body);
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: TextDirection.ltr,
            textScaler: paragraph.textScaler,
          )..layout(maxWidth: paragraph.size.width);
          expect(
            painter.computeLineMetrics(),
            hasLength(2),
            reason: '$language ${slide.id}',
          );
          painter.dispose();
          final image = tester.getRect(
            find.byKey(Key('onboarding-image-${slide.id}')),
          );
          final title = tester.getRect(
            find.byKey(Key('onboarding-title-${slide.id}')),
          );
          final bodyRect = tester.getRect(body);
          final arrow = tester.getRect(
            find.byKey(const Key('onboarding-next')),
          );
          expect(image.bottom, lessThan(title.top));
          expect(image.height, greaterThan(title.height + bodyRect.height));
          expect(bodyRect.bottom, lessThan(arrow.top));
          expect(arrow.bottom, lessThanOrEqualTo(568 - 24));
          expect(arrow.right, greaterThan(280));
          expect(arrow.size.shortestSide, greaterThanOrEqualTo(48));
          expect(tester.widget<Text>(body).maxLines, isNull);
          expect(
            tester.takeException(),
            isNull,
            reason: '$language ${slide.id}',
          );
          if (index < onboardingSlides.length - 1) await next(tester);
        }
      },
    );
  }

  testWidgets(
    'swipe both ways, arrow, semantics and rapid input stay in sync',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOnboarding(tester);
      await next(tester);
      expect(find.text('2 / 10'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('onboarding-pages')),
        const Offset(600, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 10'), findsOneWidget);
      final node = tester.getSemantics(
        find.byKey(const Key('onboarding-semantics')),
      );
      expect(
        node.getSemanticsData().hasAction(ui.SemanticsAction.increase),
        isTrue,
      );
      tester.semantics.increase(
        find.semantics.byLabel(RegExp('^Step 1 of 10:')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 10'), findsOneWidget);
      tester.semantics.decrease(
        find.semantics.byLabel(RegExp('^Step 2 of 10:')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 10'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 10'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'final check closes, keeps claim and does not complete the manual',
    (tester) async {
      var closed = 0;
      final storage = await pumpOnboarding(tester, onClosed: () => closed++);
      for (var i = 1; i < onboardingSlides.length; i++) {
        await next(tester);
      }
      expect(closed, 0);
      expect(find.byTooltip('Start using OSIA'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      final saved = GuideProgress.tryDecode(await storage.getGuideState())!;
      expect(saved.finished, isTrue);
      expect(saved.outcome, 'completed');
      expect(saved.essentialCompleted, isEmpty);
      expect(closed, 1);
      expect(
        (await GuideProgressService(storage).prepareLaunch()).showAutomatically,
        isFalse,
      );
    },
  );

  testWidgets('closing early records closed and never reopens automatically', (
    tester,
  ) async {
    var closed = 0;
    final storage = await pumpOnboarding(tester, onClosed: () => closed++);
    await next(tester);
    await tester.tap(find.byKey(const Key('onboarding-close')));
    await tester.pumpAndSettle();
    final progress = await GuideProgressService(storage).load();
    expect(progress.outcome, 'closed');
    expect(progress.finished, isFalse);
    expect(closed, 1);
    expect(
      (await GuideProgressService(storage).prepareLaunch()).showAutomatically,
      isFalse,
    );
  });

  testWidgets(
    'close and system back preserve first-launch handling and preferences',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({'osia_theme_key': 'rose'});
      var closed = 0;
      final storage = await pumpOnboarding(tester, onClosed: () => closed++);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(closed, 1);
      expect(await storage.getThemeKey(), 'rose');
      expect((await GuideProgressService(storage).load()).outcome, 'migrated');
      expect(
        (await GuideProgressService(storage).prepareLaunch()).showAutomatically,
        isFalse,
      );
    },
  );

  testWidgets('French labels and reduced-motion arrow work', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpOnboarding(tester, language: 'fr', reducedMotion: true);
    expect(find.byTooltip('Étape suivante'), findsOneWidget);
    expect(find.byTooltip('Fermer l’introduction'), findsOneWidget);
    expect(find.text('Glissez vers la gauche'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    expect(find.text('2 / 10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
    semantics.dispose();
  });

  for (final language in osiaSupportedLanguages) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      testWidgets(
        '$language: safe controls and scrollable text at 200% on $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = size.width > size.height
              ? const FakeViewPadding(left: 44, right: 44, bottom: 21)
              : const FakeViewPadding(top: 47, bottom: 34);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(() => resetView(tester));
          await pumpOnboarding(tester, language: language);
          for (var index = 0; index < onboardingSlides.length; index++) {
            final slide = onboardingSlides[index];
            final body = find.byKey(Key('onboarding-body-${slide.id}'));
            await tester.ensureVisible(body);
            await tester.pumpAndSettle();
            final bodyRect = tester.getRect(body);
            final arrow = tester.getRect(
              find.byKey(const Key('onboarding-next')),
            );
            expect(bodyRect.bottom, lessThanOrEqualTo(arrow.top));
            expect(
              arrow.bottom,
              lessThanOrEqualTo(size.height - tester.view.padding.bottom),
            );
            expect(tester.takeException(), isNull, reason: slide.id);
            if (index < onboardingSlides.length - 1) await next(tester);
          }
        },
      );
    }
  }

  testWidgets(
    'onboarding follows the app controller live without losing the page',
    (tester) async {
      final controller = LanguageController();
      addTearDown(controller.dispose);
      await pumpOnboarding(tester, controller: controller);
      await next(tester);
      for (final language in osiaSupportedLanguages.reversed) {
        controller.setLanguageByCode(language);
        await tester.pumpAndSettle();
        final context = tester.element(
          find.byKey(const Key('onboarding-screen')),
        );
        expect(OsiaL10n.of(context).languageCode, language);
        expect(
          find.text(onboardingSlides[1].title.resolve(language)),
          findsOneWidget,
        );
        expect(
          find.byTooltip(OnboardingLabels.next.resolve(language)),
          findsOneWidget,
        );
        expect(find.text('2 / 10'), findsOneWidget);
      }
    },
  );

  // Optional review captures use actual Flutter rendering and stay outside Git.
  final captureDir = Platform.environment['OSIA_ONBOARDING_CAPTURE_DIR'];
  if (captureDir != null) {
    for (final language in osiaSupportedLanguages) {
      testWidgets('capture $language onboarding for visual review', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 20, bottom: 24);
        addTearDown(() => resetView(tester));
        await pumpOnboarding(tester, language: language);
        for (var index = 0; index < onboardingSlides.length; index++) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('onboarding-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final output = File('$captureDir/$language-${index + 1}.png');
            await output.parent.create(recursive: true);
            await output.writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
          if (index < onboardingSlides.length - 1) await next(tester);
        }
      });
    }
  }
}
