import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/guide_content.dart';
import 'package:osia_mobile/guide_progress.dart';
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
    String languageCode = 'en',
    VoidCallback? onAutomaticClosed,
  }) async {
    final storage = StorageService();
    await GuideProgressService(storage).save(progress);
    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPaletteViolet,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
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

  testWidgets('automatic guide starts first, persists Next, and can skip', (
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
    expect(
      find.byKey(const Key('guide-lesson-essential.what-is-mobile')),
      findsOneWidget,
    );
    expect(find.text('Chapter 1 of 9'), findsOneWidget);

    await tester.tap(find.byKey(const Key('guide-next')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('guide-lesson-essential.before-pairing')),
      findsOneWidget,
    );

    var progress = GuideProgress.tryDecode(await storage.getGuideState())!;
    expect(progress.essentialCompleted, contains('essential.what-is-mobile'));
    expect(progress.currentLessonId, 'essential.before-pairing');

    await tester.tap(find.byKey(const Key('guide-skip')));
    await tester.pumpAndSettle();
    expect(closed, 1);
    progress = GuideProgress.tryDecode(await storage.getGuideState())!;
    expect(progress.skipped, isTrue);
    expect(progress.outcome, 'skipped');
  });

  testWidgets(
    'manual guide exposes both contents and preserves unrelated state',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'osia_token': 'kept-token',
        'osia_theme_key': 'rose',
        'osia_notifications_enabled': 'true',
      });
      final storage = await pumpGuide(
        tester,
        progress: GuideProgress.migrated(),
      );

      expect(find.byKey(const Key('guide-home')), findsOneWidget);
      expect(find.text('Getting started'), findsWidgets);
      expect(find.text('Master OSIA Mobile'), findsOneWidget);
      expect(find.byKey(const Key('guide-skip')), findsNothing);

      await tester.tap(
        find.byKey(const Key('guide-toc-essential.what-is-mobile')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guide-toc')), findsOneWidget);
      await tester.tap(find.byKey(const Key('guide-toc')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('guide-category-master-osia-mobile')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('guide-toc-advanced.connection-hierarchy')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('guide-close')));
      await tester.pumpAndSettle();
      expect(await storage.getToken(), 'kept-token');
      expect(await storage.getThemeKey(), 'rose');
      expect(await storage.getNotificationsEnabled(), isTrue);
      expect(
        GuideProgress.tryDecode(await storage.getGuideState())!.outcome,
        'migrated',
      );
    },
  );

  testWidgets('finishing the last essential chapter completes onboarding', (
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

  testWidgets('manual resume and Previous return to the saved chapter', (
    tester,
  ) async {
    final progress = GuideProgress.freshPresentation().copyWith(
      currentLessonId: 'essential.before-pairing',
    );
    await pumpGuide(tester, progress: progress);

    await tester.tap(find.byKey(const Key('guide-resume')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('guide-lesson-essential.before-pairing')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('guide-previous')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('guide-lesson-essential.what-is-mobile')),
      findsOneWidget,
    );
  });

  testWidgets('manual reopen resumes an advanced chapter from advanced home', (
    tester,
  ) async {
    final progress = GuideProgress.migrated().copyWith(
      currentLessonId: 'advanced.models',
    );
    await pumpGuide(tester, progress: progress);

    expect(find.byKey(const Key('guide-home')), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('guide-category-master-osia-mobile')),
          )
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('guide-resume')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('guide-lesson-advanced.models')),
      findsOneWidget,
    );
  });

  testWidgets('content exposes only guide navigation buttons', (tester) async {
    await pumpGuide(
      tester,
      progress: GuideProgress.freshPresentation(),
      automatic: true,
      onAutomaticClosed: () {},
    );
    final guideButtons = find.byWidgetPredicate(
      (widget) =>
          widget is TextButton ||
          widget is OutlinedButton ||
          widget is FilledButton,
    );
    final keys = guideButtons
        .evaluate()
        .map((element) => element.widget.key)
        .toSet();
    expect(keys, <Key?>{
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
        find.descendant(of: guideButtons, matching: find.text(forbidden)),
        findsNothing,
      );
    }
  });

  testWidgets('lesson controls remain usable across phone and wide layouts', (
    tester,
  ) async {
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
            FakeViewPadding viewInsets,
            String language,
          })
        >[
          (
            name: 'small Android',
            size: const Size(320, 568),
            scale: 1.0,
            padding: const FakeViewPadding(top: 24, bottom: 24),
            viewInsets: FakeViewPadding.zero,
            language: 'en',
          ),
          (
            name: 'common Android with keyboard inset',
            size: const Size(390, 844),
            scale: 1.25,
            padding: const FakeViewPadding(top: 24, bottom: 24),
            viewInsets: const FakeViewPadding(bottom: 220),
            language: 'en',
          ),
          (
            name: 'large Android',
            size: const Size(430, 932),
            scale: 1.5,
            padding: const FakeViewPadding(top: 24, bottom: 34),
            viewInsets: FakeViewPadding.zero,
            language: 'en',
          ),
          (
            name: 'compact iPhone',
            size: const Size(375, 667),
            scale: 1.0,
            padding: const FakeViewPadding(top: 20),
            viewInsets: FakeViewPadding.zero,
            language: 'en',
          ),
          (
            name: 'standard iPhone',
            size: const Size(390, 844),
            scale: 1.25,
            padding: const FakeViewPadding(top: 47, bottom: 34),
            viewInsets: FakeViewPadding.zero,
            language: 'en',
          ),
          (
            name: 'large iPhone with accessibility text',
            size: const Size(430, 932),
            scale: 2.0,
            padding: const FakeViewPadding(top: 59, bottom: 34),
            viewInsets: FakeViewPadding.zero,
            language: 'fr',
          ),
          (
            name: 'landscape phone',
            size: const Size(844, 390),
            scale: 1.0,
            padding: const FakeViewPadding(left: 44, right: 44, bottom: 21),
            viewInsets: FakeViewPadding.zero,
            language: 'en',
          ),
          (
            name: 'wide layout',
            size: const Size(1024, 768),
            scale: 1.25,
            padding: FakeViewPadding.zero,
            viewInsets: FakeViewPadding.zero,
            language: 'en',
          ),
        ];

    for (final testCase in cases) {
      tester.view.physicalSize = testCase.size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = testCase.padding;
      tester.view.viewInsets = testCase.viewInsets;
      tester.platformDispatcher.textScaleFactorTestValue = testCase.scale;
      await pumpGuide(
        tester,
        progress: GuideProgress.freshPresentation(),
        automatic: true,
        languageCode: testCase.language,
        onAutomaticClosed: () {},
      );
      expect(tester.takeException(), isNull, reason: testCase.name);
      expect(find.byKey(const Key('guide-next')), findsOneWidget);
      expect(find.byKey(const Key('guide-close')), findsOneWidget);
    }
  });

  testWidgets('screenshot scales, scrolls, and exposes accessible semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 568);
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
    await tester.scrollUntilVisible(
      screenshot,
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('guide-lesson-essential.pair-token')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    final rect = tester.getRect(screenshot);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(rect.height, lessThanOrEqualTo(600));
    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel(
        RegExp('OSIA PC mobile-pairing settings with a completely masked'),
      ),
      findsOneWidget,
    );
    expect(find.byType(FocusTraversalGroup), findsAtLeastNWidgets(1));
    semantics.dispose();
  });

  testWidgets('French guide localizes navigation and remains fully offline', (
    tester,
  ) async {
    await pumpGuide(
      tester,
      progress: GuideProgress.freshPresentation(),
      automatic: true,
      languageCode: 'fr',
      onAutomaticClosed: () {},
    );
    expect(find.text('Chapitre 1 sur 9'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });
}
