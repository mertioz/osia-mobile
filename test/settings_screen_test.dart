import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/settings_screen.dart';
import 'package:osia_mobile/services/background_connection_service.dart';
import 'package:osia_mobile/services/notification_service.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

class _FakeWebSocketService extends ws.WebSocketService {
  _FakeWebSocketService()
    : super(ip: '127.0.0.1', token: 'token', autoReconnect: false);

  final StreamController<ws.ConnectionState> _connCtrl =
      StreamController<ws.ConnectionState>.broadcast();
  final StreamController<ws.ConfigData> _configCtrl =
      StreamController<ws.ConfigData>.broadcast();

  final List<String> sentTypes = [];
  final List<String> ensureReasons = [];

  @override
  ws.ConnectionState get state => ws.ConnectionState.connected;

  @override
  Stream<ws.ConnectionState> get connectionStream => _connCtrl.stream;

  @override
  Stream<ws.ConfigData> get configStream => _configCtrl.stream;

  @override
  Future<void> ensureConnected({
    String reason = 'unspecified',
    bool forceReconnect = false,
  }) {
    ensureReasons.add(reason);
    return Future<void>.value();
  }

  @override
  void sendGetConfig() {
    sentTypes.add('get_config');
  }

  @override
  void sendGetModels() {
    sentTypes.add('get_models');
  }

  @override
  void sendMcpStatus([String? id]) {
    sentTypes.add('mcp_status');
  }

  @override
  void sendGetApiKeys() {
    sentTypes.add('get_api_keys');
  }

  void emitConfig([Map<String, dynamic>? settings]) {
    _configCtrl.add(
      ws.ConfigData.fromJson({
        'settings': {'time_format': '24h', ...?settings},
      }),
    );
  }

  @override
  void dispose() {
    _connCtrl.close();
    _configCtrl.close();
    super.dispose();
  }
}

class _FakeNotificationClient implements OsiaNotificationClient {
  bool requestResult = true;
  int requestCount = 0;
  int showCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    requestCount++;
    return requestResult;
  }

  @override
  Future<bool> notificationsAllowed() async => requestResult;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    showCount++;
  }
}

class _FakeBackgroundPlatform implements BackgroundConnectionPlatform {
  bool running = false;
  bool startResult = true;
  int startCount = 0;
  int stopCount = 0;
  int isRunningCount = 0;

  @override
  Future<bool> start() async {
    startCount++;
    running = startResult;
    return startResult;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    running = false;
  }

  @override
  Future<bool> isRunning() async {
    isRunningCount++;
    return running;
  }
}

class _FakeBackgroundPermission
    implements BackgroundNotificationPermissionClient {
  bool requestResult = true;
  bool allowedResult = true;
  int requestCount = 0;
  int allowedCount = 0;

  @override
  Future<bool> requestPermission() async {
    requestCount++;
    return requestResult;
  }

  @override
  Future<bool> notificationsAllowed() async {
    allowedCount++;
    return allowedResult;
  }
}

class _RecordingBackgroundConnectionService
    extends BackgroundConnectionService {
  _RecordingBackgroundConnectionService({
    required super.storage,
    required super.platform,
    required super.notificationPermission,
  });

  ws.WebSocketService? attachedService;
  int attachCount = 0;
  int detachCount = 0;

  @override
  void attachWebSocketService(ws.WebSocketService service) {
    attachCount++;
    attachedService = service;
    super.attachWebSocketService(service);
  }

  @override
  void detachWebSocketService(ws.WebSocketService service) {
    detachCount++;
    if (identical(attachedService, service)) attachedService = null;
    super.detachWebSocketService(service);
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<
    ({
      StorageService storage,
      _FakeWebSocketService wsService,
      _FakeNotificationClient notificationClient,
      _FakeBackgroundPlatform backgroundPlatform,
      _FakeBackgroundPermission backgroundPermission,
      _RecordingBackgroundConnectionService backgroundService,
    })
  >
  pumpSettings(
    WidgetTester tester, {
    bool requestResult = true,
    bool notificationsEnabled = false,
    bool backgroundEnabled = false,
    bool backgroundPermissionResult = true,
  }) async {
    final storage = StorageService();
    await storage.setNotificationsEnabled(notificationsEnabled);
    await storage.setBackgroundConnectionEnabled(backgroundEnabled);
    final wsService = _FakeWebSocketService();
    final notificationClient = _FakeNotificationClient()
      ..requestResult = requestResult;
    final backgroundPlatform = _FakeBackgroundPlatform();
    final backgroundPermission = _FakeBackgroundPermission()
      ..requestResult = backgroundPermissionResult
      ..allowedResult = backgroundPermissionResult;
    final backgroundService = _RecordingBackgroundConnectionService(
      storage: storage,
      platform: backgroundPlatform,
      notificationPermission: backgroundPermission,
    );
    addTearDown(wsService.dispose);

    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPaletteViolet,
        child: OsiaL10n(
          strings: osiaStringsForCode('en'),
          child: MaterialApp(
            home: SettingsScreen(
              storage: storage,
              themeController: ThemeController(),
              languageController: LanguageController(),
              wsService: wsService,
              notificationService: OsiaNotificationService(
                storage: storage,
                client: notificationClient,
              ),
              backgroundConnectionService: backgroundService,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    return (
      storage: storage,
      wsService: wsService,
      notificationClient: notificationClient,
      backgroundPlatform: backgroundPlatform,
      backgroundPermission: backgroundPermission,
      backgroundService: backgroundService,
    );
  }

  testWidgets(
    'disposing Settings keeps an injected app-level background attachment',
    (tester) async {
      final harness = await pumpSettings(tester);
      final startCount = harness.backgroundPlatform.startCount;
      final stopCount = harness.backgroundPlatform.stopCount;

      expect(harness.backgroundService.attachedService, harness.wsService);
      expect(harness.backgroundService.attachCount, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(harness.backgroundService.attachedService, harness.wsService);
      expect(harness.backgroundService.detachCount, 0);
      expect(harness.backgroundPlatform.startCount, startCount);
      expect(harness.backgroundPlatform.stopCount, stopCount);
    },
  );

  testWidgets('shows notification toggle in the requested Settings order', (
    tester,
  ) async {
    final harness = await pumpSettings(tester);
    harness.wsService.emitConfig();
    await tester.pump();
    final strings = osiaStringsForCode('en');

    expect(find.text(strings.osiaNotifications), findsOneWidget);
    expect(find.text(strings.backgroundConnection), findsOneWidget);

    final headers = [
      strings.language,
      strings.sectionGeneral,
      strings.memoryTitle,
      strings.providersTitle,
      strings.colorTheme,
      strings.legal,
      strings.connectionSection,
    ].map((label) => label.toUpperCase()).toList();

    for (final header in headers) {
      expect(find.text(header), findsOneWidget);
    }

    final topPositions = [
      for (final header in headers) tester.getTopLeft(find.text(header)).dy,
    ];
    for (var i = 1; i < topPositions.length; i++) {
      expect(topPositions[i], greaterThan(topPositions[i - 1]));
    }

    final connectorsTop = tester
        .getTopLeft(find.text(strings.catConnectors))
        .dy;
    final timeFormatTop = tester
        .getTopLeft(find.text(strings.timeFormatLabel))
        .dy;
    final memoryTop = tester
        .getTopLeft(find.text(strings.memoryTitle.toUpperCase()))
        .dy;

    expect(connectorsTop, lessThan(timeFormatTop));
    expect(timeFormatTop, lessThan(memoryTop));
  });

  testWidgets('enabling OSIA notifications requests permission and persists', (
    tester,
  ) async {
    final harness = await pumpSettings(tester);
    final strings = osiaStringsForCode('en');

    await tester.tap(find.text(strings.osiaNotifications));
    await tester.pump();
    await tester.pump();

    expect(harness.notificationClient.requestCount, 1);
    expect(await harness.storage.getNotificationsEnabled(), isTrue);
  });

  testWidgets(
    'disabling OSIA notifications persists without permission prompt',
    (tester) async {
      final harness = await pumpSettings(tester, notificationsEnabled: true);
      final strings = osiaStringsForCode('en');
      await tester.pump();

      await tester.tap(find.text(strings.osiaNotifications));
      await tester.pump();
      await tester.pump();

      expect(harness.notificationClient.requestCount, 0);
      expect(await harness.storage.getNotificationsEnabled(), isFalse);
    },
  );

  testWidgets('permission denied leaves notifications disabled without crash', (
    tester,
  ) async {
    final harness = await pumpSettings(tester, requestResult: false);
    final strings = osiaStringsForCode('en');

    await tester.tap(find.text(strings.osiaNotifications));
    await tester.pump();
    await tester.pump();

    expect(harness.notificationClient.requestCount, 1);
    expect(await harness.storage.getNotificationsEnabled(), isFalse);
    expect(find.text(strings.notificationPermissionDenied), findsOneWidget);
  });

  testWidgets('background connection defaults off', (tester) async {
    final harness = await pumpSettings(tester);

    expect(await harness.storage.getBackgroundConnectionEnabled(), isFalse);
    expect(find.text(osiaStringsForCode('en').backgroundConnection), findsOne);
  });

  testWidgets('enabling background connection persists and starts service', (
    tester,
  ) async {
    final harness = await pumpSettings(tester);
    final strings = osiaStringsForCode('en');

    await tester.tap(find.text(strings.backgroundConnection));
    await tester.pump();
    await tester.pump();

    expect(harness.backgroundPermission.requestCount, 1);
    expect(harness.backgroundPlatform.startCount, 1);
    expect(await harness.storage.getBackgroundConnectionEnabled(), isTrue);
    expect(
      harness.wsService.ensureReasons,
      contains('background_connection_enabled'),
    );
  });

  testWidgets('disabling background connection persists and stops service', (
    tester,
  ) async {
    final harness = await pumpSettings(tester, backgroundEnabled: true);
    final strings = osiaStringsForCode('en');
    await tester.pump();

    await tester.tap(find.text(strings.backgroundConnection));
    await tester.pump();
    await tester.pump();

    expect(await harness.storage.getBackgroundConnectionEnabled(), isFalse);
    expect(harness.backgroundPlatform.stopCount, greaterThanOrEqualTo(1));
  });

  testWidgets(
    'background connection permission denied disables without crash',
    (tester) async {
      final harness = await pumpSettings(
        tester,
        backgroundPermissionResult: false,
      );
      final strings = osiaStringsForCode('en');

      await tester.tap(find.text(strings.backgroundConnection));
      await tester.pump();
      await tester.pump();

      expect(harness.backgroundPermission.requestCount, 1);
      expect(harness.backgroundPlatform.startCount, 0);
      expect(await harness.storage.getBackgroundConnectionEnabled(), isFalse);
      expect(
        find.text(strings.backgroundConnectionUnavailable),
        findsOneWidget,
      );
    },
  );
}
