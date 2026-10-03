import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/guide/guide_catalog.dart';
import 'package:osia_mobile/guide_progress.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/guide_screen.dart';
import 'package:osia_mobile/screens/settings_screen.dart';
import 'package:osia_mobile/services/background_connection_service.dart';
import 'package:osia_mobile/services/notification_service.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

class _ReviewWebSocketService extends ws.WebSocketService {
  _ReviewWebSocketService()
    : super(ip: 'localhost', token: 'DEMO-CODE', autoReconnect: false);

  final StreamController<ws.ConnectionState> _connection =
      StreamController<ws.ConnectionState>.broadcast();
  final StreamController<ws.ConfigData> _config =
      StreamController<ws.ConfigData>.broadcast();

  @override
  ws.ConnectionState get state => ws.ConnectionState.connected;

  @override
  Stream<ws.ConnectionState> get connectionStream => _connection.stream;

  @override
  Stream<ws.ConfigData> get configStream => _config.stream;

  @override
  Future<void> ensureConnected({
    String reason = 'unspecified',
    bool forceReconnect = false,
  }) async {}

  @override
  void sendGetConfig() {}

  @override
  void sendGetModels() {}

  @override
  void sendGetApiKeys() {}

  void emitConfig() {
    _config.add(
      ws.ConfigData.fromJson(<String, dynamic>{
        'settings': <String, dynamic>{'time_format': '24h'},
      }),
    );
  }

  @override
  void dispose() {
    _connection.close();
    _config.close();
    super.dispose();
  }
}

class _ReviewNotificationClient implements OsiaNotificationClient {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> notificationsAllowed() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}
}

class _ReviewBackgroundPlatform implements BackgroundConnectionPlatform {
  @override
  Future<bool> isRunning() async => false;

  @override
  Future<bool> start() async => true;

  @override
  Future<void> stop() async {}
}

class _ReviewBackgroundPermission
    implements BackgroundNotificationPermissionClient {
  @override
  Future<bool> notificationsAllowed() async => true;

  @override
  Future<bool> requestPermission() async => true;
}

enum _SceneKind { guide, menu }

typedef _Scene = ({
  String name,
  _SceneKind kind,
  Size size,
  double textScale,
  String? lessonId,
  bool reducedMotion,
});

/// Generates uncommitted WOR-154 refinement review evidence under build/.
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

  Future<void> capture(WidgetTester tester, _Scene scene) async {
    await tester.binding.setSurfaceSize(scene.size);
    tester.platformDispatcher.textScaleFactorTestValue = scene.textScale;
    addTearDown(() async {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final storage = StorageService();
    _ReviewWebSocketService? reviewWebSocket;
    late Widget screen;
    if (scene.kind == _SceneKind.menu) {
      reviewWebSocket = _ReviewWebSocketService();
      final background = BackgroundConnectionService(
        storage: storage,
        platform: _ReviewBackgroundPlatform(),
        notificationPermission: _ReviewBackgroundPermission(),
      );
      screen = OsiaL10n(
        strings: osiaStringsEn,
        child: SettingsScreen(
          storage: storage,
          themeController: ThemeController(),
          languageController: LanguageController(),
          wsService: reviewWebSocket,
          notificationService: OsiaNotificationService(
            storage: storage,
            client: _ReviewNotificationClient(),
          ),
          backgroundConnectionService: background,
        ),
      );
    } else {
      final progress = scene.lessonId == null
          ? GuideProgress.migrated()
          : GuideProgress.freshPresentation().copyWith(
              currentLessonId: scene.lessonId,
            );
      screen = GuideScreen(
        storage: storage,
        languageCode: 'en',
        automatic: scene.lessonId != null,
        initialProgress: progress,
        onAutomaticClosed: () {},
      );
    }

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
            builder: scene.reducedMotion
                ? (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: true),
                    child: child!,
                  )
                : null,
            home: screen,
          ),
        ),
      ),
    );
    await tester.pump();
    if (reviewWebSocket != null) {
      reviewWebSocket.emitConfig();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-connection-section')),
        350,
      );
    }

    final boundaryFinder = find.byKey(const Key('review-capture-boundary'));
    final context = tester.element(boundaryFinder);
    await tester.runAsync(() async {
      if (scene.kind == _SceneKind.guide) {
        await precacheImage(
          const AssetImage('assets/osia_logo_mark.png'),
          context,
        );
        final lessonAsset = guideLessonById(scene.lessonId)?.asset;
        if (lessonAsset != null) {
          await precacheImage(AssetImage(lessonAsset), context);
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: scene.name);
    if (scene.kind == _SceneKind.menu) {
      expect(find.byKey(const Key('settings-help-section')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-connection-section')),
        findsOneWidget,
      );
    }

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
      matchesGoldenFile('../build/wor154-refinement-review/${scene.name}.png'),
    );
    reviewWebSocket?.dispose();
  }

  testWidgets('generate all exact WOR-154 refinement captures', (tester) async {
    for (final scene in <_Scene>[
      (
        name: '01-guide-home',
        kind: _SceneKind.guide,
        size: const Size(390, 844),
        textScale: 1,
        lessonId: null,
        reducedMotion: false,
      ),
      (
        name: '02-getting-started-card-320',
        kind: _SceneKind.guide,
        size: const Size(320, 640),
        textScale: 1,
        lessonId: null,
        reducedMotion: false,
      ),
      (
        name: '03-first-essential-iphone',
        kind: _SceneKind.guide,
        size: const Size(393, 852),
        textScale: 1,
        lessonId: 'essential.osia-role',
        reducedMotion: false,
      ),
      (
        name: '04-token-pairing-125',
        kind: _SceneKind.guide,
        size: const Size(390, 844),
        textScale: 1.25,
        lessonId: 'essential.pairing-token',
        reducedMotion: false,
      ),
      (
        name: '05-successful-connection',
        kind: _SceneKind.guide,
        size: const Size(390, 844),
        textScale: 1,
        lessonId: 'essential.pairing-connect',
        reducedMotion: false,
      ),
      (
        name: '06-first-message',
        kind: _SceneKind.guide,
        size: const Size(430, 932),
        textScale: 1,
        lessonId: 'essential.first-request',
        reducedMotion: false,
      ),
      (
        name: '07-voice',
        kind: _SceneKind.guide,
        size: const Size(390, 844),
        textScale: 1,
        lessonId: 'essential.voice',
        reducedMotion: false,
      ),
      (
        name: '08-connection-landscape',
        kind: _SceneKind.guide,
        size: const Size(844, 390),
        textScale: 1,
        lessonId: 'advanced.transport-overview',
        reducedMotion: false,
      ),
      (
        name: '09a-stt',
        kind: _SceneKind.guide,
        size: const Size(390, 844),
        textScale: 1,
        lessonId: 'mastery.voice-stt',
        reducedMotion: false,
      ),
      (
        name: '09b-tts',
        kind: _SceneKind.guide,
        size: const Size(390, 844),
        textScale: 1,
        lessonId: 'mastery.voice-tts',
        reducedMotion: false,
      ),
      (
        name: '10-troubleshooting-150',
        kind: _SceneKind.guide,
        size: const Size(320, 640),
        textScale: 1.5,
        lessonId: 'mastery.diagnostic-layers',
        reducedMotion: false,
      ),
      (
        name: '11-menu-help-before-connection',
        kind: _SceneKind.menu,
        size: const Size(390, 844),
        textScale: 1,
        lessonId: null,
        reducedMotion: false,
      ),
      (
        name: '12-reduced-motion-150',
        kind: _SceneKind.guide,
        size: const Size(390, 844),
        textScale: 1.5,
        lessonId: 'essential.ready',
        reducedMotion: true,
      ),
    ]) {
      await capture(tester, scene);
    }
  });
}
