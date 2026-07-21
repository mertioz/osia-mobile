import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/guide_content.dart';
import 'package:osia_mobile/guide_progress.dart';
import 'package:osia_mobile/screens/guide_screen.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/theme.dart';

/// Generates the uncommitted WOR-154 review evidence under build/.
///
///   flutter test --update-goldens tool/guide_review_capture_test.dart
void main() {
  setUpAll(() async {
    final separator = Platform.pathSeparator;
    var flutterCache = File(Platform.resolvedExecutable).parent;
    while (flutterCache.path.split(separator).last.toLowerCase() != 'cache' &&
        flutterCache.parent.path != flutterCache.path) {
      flutterCache = flutterCache.parent;
    }
    for (final entry in <(String, String)>[
      ('GuideRoboto', 'roboto-regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final file = File(
        '${flutterCache.path}${separator}artifacts${separator}material_fonts'
        '$separator${entry.$2}',
      );
      final bytes = await file.readAsBytes();
      await (FontLoader(
        entry.$1,
      )..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)))).load();
    }
  });

  Future<void> capture(
    WidgetTester tester, {
    required String name,
    String? lessonId,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = name == '03-pairing'
        ? 1.25
        : 1.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final progress = lessonId == null
        ? GuideProgress.migrated()
        : GuideProgress.freshPresentation().copyWith(currentLessonId: lessonId);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('review-capture-boundary'),
        child: OsiaTheme(
          palette: osiaPaletteViolet,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(useMaterial3: true).copyWith(
              scaffoldBackgroundColor: osiaPaletteViolet.background,
              textTheme: ThemeData.dark().textTheme.apply(
                fontFamily: 'GuideRoboto',
              ),
            ),
            home: GuideScreen(
              storage: StorageService(),
              languageCode: 'en',
              automatic: lessonId != null,
              initialProgress: progress,
              onAutomaticClosed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byKey(const Key('guide-screen')));
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/osia_logo_mark.png'),
        context,
      );
      final lessonAsset = guideLessonById(lessonId)?.asset;
      if (lessonAsset != null) {
        await precacheImage(AssetImage(lessonAsset), context);
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    final boundaryFinder = find.byKey(const Key('review-capture-boundary'));
    void repaintBoundaries(RenderObject object) {
      if (object is RenderRepaintBoundary) object.markNeedsPaint();
      object.visitChildren(repaintBoundaries);
    }

    repaintBoundaries(tester.renderObject(boundaryFinder));
    await tester.pump();
    final warmup = await captureImage(tester.element(boundaryFinder));
    warmup.dispose();
    await expectLater(
      boundaryFinder,
      matchesGoldenFile('../build/wor154-review/$name.png'),
    );
  }

  testWidgets('generate all exact WOR-154 review captures', (tester) async {
    for (final scene in <({String name, String? lessonId})>[
      (name: '01-home', lessonId: null),
      (name: '02-essential-introduction', lessonId: 'essential.what-is-mobile'),
      (name: '03-pairing', lessonId: 'essential.pair-token'),
      (name: '04-mobile-navigation', lessonId: 'essential.mobile-pages'),
      (name: '05-first-message', lessonId: 'essential.first-message'),
      (name: '06-voice', lessonId: 'essential.voice'),
      (
        name: '07-advanced-connection',
        lessonId: 'advanced.connection-hierarchy',
      ),
      (name: '08-android-background', lessonId: 'advanced.android-background'),
      (name: '09-ios-background', lessonId: 'advanced.ios-background'),
      (name: '10-troubleshooting', lessonId: 'advanced.troubleshooting'),
    ]) {
      await capture(tester, name: scene.name, lessonId: scene.lessonId);
    }
  });
}
