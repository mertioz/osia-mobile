import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/guide_content.dart';
import 'package:osia_mobile/guide_progress.dart';
import 'package:osia_mobile/motion.dart';
import 'package:osia_mobile/screens/guide_screen.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/theme.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  Future<StorageService> pumpGuide(
    WidgetTester tester, {
    required GuideProgress progress,
    bool automatic = false,
    bool reducedMotion = false,
    String languageCode = 'en',
    VoidCallback? onAutomaticClosed,
  }) async {
    final storage = StorageService();
    await GuideProgressService(storage).save(progress);
    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPaletteViolet,
        child: MaterialApp(
          theme: buildOsiaTheme(),
          builder: reducedMotion
              ? (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                )
              : null,
          home: GuideScreen(
            storage: storage,
            languageCode: languageCode,
            automatic: automatic,
            initialProgress: progress,
            onAutomaticClosed: onAutomaticClosed,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return storage;
  }

  testWidgets('automatic guide starts on essential slide one and can skip', (
    tester,
  ) async {
    var closed = 0;
    final storage = await pumpGuide(
      tester,
      progress: GuideProgress.freshPresentation(),
      automatic: true,
      onAutomaticClosed: () => closed++,
    );

    expect(find.byKey(const Key('guide-screen')), findsOneWidget);
    expect(find.byKey(const Key('guide-page-view')), findsOneWidget);
    expect(find.text('Slide 1 of 9'), findsOneWidget);
    expect(find.text('OSIA, from your phone'), findsOneWidget);

    await tester.tap(find.byKey(const Key('guide-skip')));
    await tester.pumpAndSettle();
    expect(closed, 1);
    final progress = GuideProgress.tryDecode(await storage.getGuideState())!;
    expect(progress.skipped, isTrue);
    expect(progress.outcome, 'skipped');
  });

  testWidgets('horizontal swipe directions synchronize progress and storage', (
    tester,
  ) async {
    final storage = await pumpGuide(
      tester,
      progress: GuideProgress.freshPresentation(),
      automatic: true,
      onAutomaticClosed: () {},
    );
    final pages = find.byKey(const Key('guide-page-view'));

    await tester.drag(pages, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Slide 2 of 9'), findsOneWidget);
    var saved = GuideProgress.tryDecode(await storage.getGuideState())!;
    expect(saved.currentLessonId, 'essential.before-pairing');
    expect(saved.essentialCompleted, contains('essential.what-is-mobile'));

    await tester.drag(pages, const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Slide 1 of 9'), findsOneWidget);
    saved = GuideProgress.tryDecode(await storage.getGuideState())!;
    expect(saved.currentLessonId, 'essential.what-is-mobile');
  });

  testWidgets('Previous and Next remain synchronized with swipes', (
    tester,
  ) async {
    await pumpGuide(
      tester,
      progress: GuideProgress.freshPresentation(),
      automatic: true,
      onAutomaticClosed: () {},
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('guide-previous')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('guide-next')));
    await tester.pumpAndSettle();
    expect(find.text('Slide 2 of 9'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('guide-previous')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('guide-previous')));
    await tester.pumpAndSettle();
    expect(find.text('Slide 1 of 9'), findsOneWidget);
  });

  testWidgets('rapid repeated navigation cannot skip or desynchronize slides', (
    tester,
  ) async {
    final storage = await pumpGuide(
      tester,
      progress: GuideProgress.freshPresentation(),
      automatic: true,
      onAutomaticClosed: () {},
    );
    final next = find.byKey(const Key('guide-next'));
    await tester.tap(next);
    await tester.tap(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Slide 2 of 9'), findsOneWidget);
    final saved = GuideProgress.tryDecode(await storage.getGuideState())!;
    expect(saved.currentLessonId, 'essential.before-pairing');
    expect(saved.essentialCompleted, <String>{'essential.what-is-mobile'});
  });

  testWidgets('rapid repeated swipes settle on the persisted visible slide', (
    tester,
  ) async {
    final storage = await pumpGuide(
      tester,
      progress: GuideProgress.freshPresentation(),
      automatic: true,
      onAutomaticClosed: () {},
    );
    final pageViewFinder = find.byKey(const Key('guide-page-view'));
    await tester.fling(pageViewFinder, const Offset(-600, 0), 5000);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.fling(pageViewFinder, const Offset(-600, 0), 5000);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final pageView = tester.widget<PageView>(pageViewFinder);
    final settledIndex = pageView.controller!.page!.round();
    expect(settledIndex, inInclusiveRange(1, 2));
    expect(find.text('Slide ${settledIndex + 1} of 9'), findsOneWidget);
    final saved = GuideProgress.tryDecode(await storage.getGuideState())!;
    expect(
      saved.currentLessonId,
      guideLessonsForCategory(guideEssentialCategoryId)[settledIndex].id,
    );
  });

  testWidgets('manual opening shows two cards then a compact category list', (
    tester,
  ) async {
    await pumpGuide(tester, progress: GuideProgress.migrated());
    expect(find.byKey(const Key('guide-home')), findsOneWidget);
    expect(find.text('Choose your journey'), findsOneWidget);
    expect(
      find.byKey(const Key('guide-category-getting-started')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('guide-category-master-osia-mobile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('guide-toc-essential.what-is-mobile')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('guide-category-getting-started')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guide-table-of-contents')), findsOneWidget);
    expect(
      find.byKey(const Key('guide-toc-essential.what-is-mobile')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('guide-category-master-osia-mobile')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('guide-toc-advanced.connection-hierarchy')),
      findsOneWidget,
    );
    expect(find.textContaining('15 slides'), findsWidgets);
  });

  testWidgets(
    'manual resume preserves saved advanced slide and unrelated state',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'osia_token': 'kept-token',
        'osia_theme_key': 'rose',
        'osia_notifications_enabled': 'true',
      });
      final progress = GuideProgress.migrated().copyWith(
        currentLessonId: 'advanced.models',
      );
      final storage = await pumpGuide(tester, progress: progress);

      await tester.tap(
        find.byKey(const Key('guide-category-master-osia-mobile')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('guide-resume')));
      await tester.pumpAndSettle();
      expect(find.text('Slide 11 of 15'), findsOneWidget);
      expect(find.text('Models and AI selection'), findsOneWidget);

      await tester.tap(find.byKey(const Key('guide-close')));
      await tester.pumpAndSettle();
      expect(await storage.getToken(), 'kept-token');
      expect(await storage.getThemeKey(), 'rose');
      expect(await storage.getNotificationsEnabled(), isTrue);
    },
  );

  testWidgets('finishing the last essential slide completes onboarding', (
    tester,
  ) async {
    var closed = 0;
    final lessons = guideLessonsForCategory(guideEssentialCategoryId);
    final progress = GuideProgress.freshPresentation().copyWith(
      currentLessonId: lessons.last.id,
      essentialCompleted: lessons
          .take(lessons.length - 1)
          .map((e) => e.id)
          .toSet(),
    );
    final storage = await pumpGuide(
      tester,
      progress: progress,
      automatic: true,
      onAutomaticClosed: () => closed++,
    );

    await tester.tap(find.byKey(const Key('guide-finish')));
    await tester.pumpAndSettle();
    final saved = GuideProgress.tryDecode(await storage.getGuideState())!;
    expect(saved.finished, isTrue);
    expect(saved.outcome, 'completed');
    expect(saved.essentialCompleted, hasLength(lessons.length));
    expect(closed, 1);
  });

  testWidgets('slide content exposes only guide navigation actions', (
    tester,
  ) async {
    await pumpGuide(
      tester,
      progress: GuideProgress.freshPresentation(),
      automatic: true,
      onAutomaticClosed: () {},
    );
    final buttons = find.byWidgetPredicate(
      (widget) =>
          widget is TextButton ||
          widget is OutlinedButton ||
          widget is FilledButton ||
          widget is IconButton,
    );
    final keys = buttons
        .evaluate()
        .map((element) => element.widget.key)
        .whereType<Key>()
        .toSet();
    expect(keys, <Key>{
      const Key('guide-close'),
      const Key('guide-toc'),
      const Key('guide-skip'),
      const Key('guide-previous'),
      const Key('guide-next'),
    });
    for (final forbidden in <String>[
      'Start pairing',
      'Connect now',
      'Enable microphone',
      'Retry connection',
      'Go to diagnostics',
    ]) {
      expect(
        find.descendant(of: buttons, matching: find.text(forbidden)),
        findsNothing,
      );
    }
  });

  testWidgets('motion uses OSIA timing and collapses under reduced motion', (
    tester,
  ) async {
    expect(guidePageTransitionDuration, MotionDurations.medium);
    expect(guideContentTransitionDuration, MotionDurations.fast);
    expect(guideProgressTransitionDuration, MotionDurations.medium);
    expect(guidePageTransitionCurve, MotionCurves.enter);
    expect(guideContentTransitionCurve, MotionCurves.enter);
    expect(guideProgressTransitionCurve, MotionCurves.loop);

    await pumpGuide(
      tester,
      progress: GuideProgress.freshPresentation(),
      automatic: true,
      onAutomaticClosed: () {},
    );
    expect(
      tester
          .widget<TweenAnimationBuilder<double>>(
            find.byKey(const Key('guide-slide-progress')),
          )
          .duration,
      guideProgressTransitionDuration,
    );
    expect(
      tester
          .widget<TweenAnimationBuilder<double>>(
            find.byKey(
              const Key('guide-slide-motion-essential.what-is-mobile'),
            ),
          )
          .duration,
      guideContentTransitionDuration,
    );

    await pumpGuide(
      tester,
      progress: GuideProgress.freshPresentation(),
      automatic: true,
      reducedMotion: true,
      onAutomaticClosed: () {},
    );
    expect(
      tester
          .widget<TweenAnimationBuilder<double>>(
            find.byKey(const Key('guide-slide-progress')),
          )
          .duration,
      Duration.zero,
    );
    expect(
      tester
          .widget<TweenAnimationBuilder<double>>(
            find.byKey(
              const Key('guide-slide-motion-essential.what-is-mobile'),
            ),
          )
          .duration,
      Duration.zero,
    );
    await tester.drag(
      find.byKey(const Key('guide-page-view')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Slide 2 of 9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'controls remain reachable across mobile layouts and text scales',
    (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewInsets();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final cases =
          <
            ({
              String name,
              Size size,
              double scale,
              FakeViewPadding padding,
              FakeViewPadding insets,
              String language,
            })
          >[
            (
              name: 'small Android',
              size: const Size(320, 640),
              scale: 1,
              padding: const FakeViewPadding(top: 24, bottom: 24),
              insets: FakeViewPadding.zero,
              language: 'en',
            ),
            (
              name: 'common Android keyboard',
              size: const Size(390, 844),
              scale: 1.25,
              padding: const FakeViewPadding(top: 24, bottom: 24),
              insets: const FakeViewPadding(bottom: 220),
              language: 'en',
            ),
            (
              name: 'large Android',
              size: const Size(430, 932),
              scale: 1.5,
              padding: const FakeViewPadding(top: 24, bottom: 34),
              insets: FakeViewPadding.zero,
              language: 'en',
            ),
            (
              name: 'compact iPhone',
              size: const Size(375, 667),
              scale: 1,
              padding: const FakeViewPadding(top: 20),
              insets: FakeViewPadding.zero,
              language: 'en',
            ),
            (
              name: 'modern iPhone',
              size: const Size(390, 844),
              scale: 1.25,
              padding: const FakeViewPadding(top: 47, bottom: 34),
              insets: FakeViewPadding.zero,
              language: 'en',
            ),
            (
              name: 'large iPhone French accessibility',
              size: const Size(430, 932),
              scale: 2,
              padding: const FakeViewPadding(top: 59, bottom: 34),
              insets: FakeViewPadding.zero,
              language: 'fr',
            ),
            (
              name: 'landscape',
              size: const Size(844, 390),
              scale: 1.5,
              padding: const FakeViewPadding(left: 44, right: 44, bottom: 21),
              insets: FakeViewPadding.zero,
              language: 'fr',
            ),
          ];

      for (final testCase in cases) {
        tester.view.physicalSize = testCase.size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = testCase.padding;
        tester.view.viewInsets = testCase.insets;
        tester.platformDispatcher.textScaleFactorTestValue = testCase.scale;
        await pumpGuide(
          tester,
          progress: GuideProgress.freshPresentation(),
          automatic: true,
          languageCode: testCase.language,
          onAutomaticClosed: () {},
        );
        expect(tester.takeException(), isNull, reason: testCase.name);
        expect(find.byKey(const Key('guide-close')), findsOneWidget);
        expect(find.byKey(const Key('guide-next')), findsOneWidget);
        expect(find.byKey(const Key('guide-previous')), findsOneWidget);
      }
    },
  );

  testWidgets('screenshots scale, scroll and expose accessible semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final progress = GuideProgress.freshPresentation().copyWith(
      currentLessonId: 'essential.pair-token',
    );
    await pumpGuide(
      tester,
      progress: progress,
      automatic: true,
      onAutomaticClosed: () {},
    );
    final screenshot = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/guide/pc-pairing.png',
    );
    expect(screenshot, findsOneWidget);
    final rect = tester.getRect(screenshot);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(
      find.bySemanticsLabel(
        RegExp('OSIA PC mobile-pairing settings with a completely masked'),
      ),
      findsOneWidget,
    );
    expect(find.byType(FocusTraversalGroup), findsAtLeastNWidgets(1));
    semantics.dispose();
  });

  testWidgets('disposing during a transition leaves no active guide ticker', (
    tester,
  ) async {
    await pumpGuide(
      tester,
      progress: GuideProgress.freshPresentation(),
      automatic: true,
      onAutomaticClosed: () {},
    );
    await tester.tap(find.byKey(const Key('guide-next')));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
