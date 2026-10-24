import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  ws.ConnectionState connection = ws.ConnectionState.connected;
  @override
  ws.ConnectionState get state => connection;

  void emitConnection(ws.ConnectionState value) {
    connection = value;
    _connCtrl.add(value);
  }

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
    PackageInfo.setMockInitialValues(
      appName: 'OSIA',
      packageName: 'space.osia.app',
      version: '0.9.51',
      buildNumber: '24',
      buildSignature: 'test',
    );
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
    String languageCode = 'en',
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
    final languageController = LanguageController(
      initial: osiaStringsForCode(languageCode),
    );

    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPaletteViolet,
        child: AnimatedBuilder(
          animation: languageController,
          builder: (context, _) => OsiaL10n(
            strings: languageController.strings,
            child: MaterialApp(
              home: SettingsScreen(
                storage: storage,
                themeController: ThemeController(),
                languageController: languageController,
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

  testWidgets('Settings asks for one config and leaves local controls usable', (
    tester,
  ) async {
    final h = await pumpSettings(tester);
    expect(h.wsService.sentTypes.where((x) => x == 'get_config'), hasLength(1));
    expect(h.wsService.sentTypes.where((x) => x == 'get_models'), hasLength(1));
    expect(h.wsService.sentTypes, isNot(contains('mcp_status')));
    expect(
      find.text(osiaStringsForCode('en').language.toUpperCase()),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 8));
    expect(
      find.text(osiaStringsForCode('en').pcSettingsUnavailable),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text(osiaStringsForCode('en').retry));
    await tester.tap(find.text(osiaStringsForCode('en').retry));
    await tester.pump();
    expect(h.wsService.sentTypes.where((x) => x == 'get_config'), hasLength(2));
    h.wsService.emitConfig();
    await tester.pump();
    expect(find.byKey(const Key('pc-settings-state')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disconnect invalidates remote values and reconnect refreshes', (
    tester,
  ) async {
    final h = await pumpSettings(tester);
    h.wsService.emitConfig();
    await tester.pump();
    h.wsService.emitConnection(ws.ConnectionState.disconnected);
    await tester.pump();
    expect(find.text(osiaStringsForCode('en').disconnected), findsOneWidget);
    h.wsService.emitConfig();
    await tester.pump();
    expect(find.byKey(const Key('pc-settings-state')), findsOneWidget);
    h.wsService.emitConnection(ws.ConnectionState.connected);
    await tester.pump();
    expect(h.wsService.sentTypes.where((x) => x == 'get_config'), hasLength(2));
    h.wsService.emitConfig();
    await tester.pump();
    expect(find.byKey(const Key('pc-settings-state')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'footer uses installed metadata and exposes no development history',
    (tester) async {
      await pumpSettings(tester);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.textContaining('Development history'), findsNothing);
      expect(find.text('OSIA 0.9.51 — Beta'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

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

  testWidgets('iOS footer omits Beta and external developer tips', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pumpSettings(tester);
    expect(find.text('OSIA 0.9.51'), findsOneWidget);
    expect(find.textContaining('Beta'), findsNothing);
    expect(find.byKey(const Key('support-osia')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('legacy permission center is absent from canonical Settings', (
    tester,
  ) async {
    await pumpSettings(tester);
    expect(find.byKey(const Key('settings-permissions-entry')), findsNothing);
    expect(find.byKey(const Key('permissions-screen')), findsNothing);
  });

  testWidgets('Settings keeps one bounded scroll viewport below its app bar', (
    tester,
  ) async {
    final harness = await pumpSettings(tester);
    harness.wsService.emitConfig();
    await tester.pump();

    final scrollView = find.byType(SingleChildScrollView);
    expect(scrollView, findsOneWidget);
    final settingsScrollables = find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(Scrollable),
    );
    expect(settingsScrollables, findsOneWidget);
    final scrollable = find.descendant(
      of: scrollView,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable.first).position;
    expect(position.maxScrollExtent, greaterThan(0));
    final appBar = find.byType(AppBar).first;
    final appBarRect = tester.getRect(appBar);

    await tester.drag(scrollView, const Offset(0, -5000));
    await tester.pumpAndSettle();

    expect(tester.getRect(appBar), appBarRect);
    expect(position.pixels, position.maxScrollExtent);

    final contentBottom = tester
        .getBottomLeft(find.byKey(const Key('settings-sections')))
        .dy;
    final viewportBottom = tester.getBottomLeft(scrollView).dy;
    expect(contentBottom, closeTo(viewportBottom - 32, 10));

    for (var i = 0; i < 8; i++) {
      await tester.drag(scrollView, const Offset(0, -1000));
      await tester.pump();
    }
    expect(position.pixels, position.maxScrollExtent);
    expect(tester.getRect(appBar), appBarRect);
    expect(
      tester.getBottomLeft(find.byKey(const Key('settings-sections'))).dy,
      closeTo(viewportBottom - 32, 10),
    );
  });

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

  testWidgets('background connection control is hidden on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpSettings(tester);

      expect(
        find.text(osiaStringsForCode('en').backgroundConnection),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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

  testWidgets('Help opens the offline guide without changing app settings', (
    tester,
  ) async {
    final harness = await pumpSettings(tester, notificationsEnabled: true);
    await harness.storage.setToken('preserved-token');
    await harness.storage.setThemeKey('rose');
    await harness.storage.setAutoTts(true);
    await harness.storage.setSelectedModel('demo-provider/demo-model');
    final settingsMessageCount = harness.wsService.sentTypes.length;

    await tester.scrollUntilVisible(
      find.byKey(const Key('show-mobile-guide')),
      300,
    );
    await tester.tap(find.byKey(const Key('show-mobile-guide')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('guide-screen')), findsOneWidget);
    expect(find.text('OSIA Mobile guide'), findsOneWidget);

    await tester.tap(find.byKey(const Key('guide-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(await harness.storage.getToken(), 'preserved-token');
    expect(await harness.storage.getThemeKey(), 'rose');
    expect(await harness.storage.getAutoTts(), isTrue);
    expect(await harness.storage.getNotificationsEnabled(), isTrue);
    expect(
      await harness.storage.getSelectedModel(),
      'demo-provider/demo-model',
    );
    expect(harness.wsService.sentTypes, hasLength(settingsMessageCount));
  });

  for (final languageCode in osiaSupportedLanguages) {
    testWidgets('language picker applies and saves $languageCode', (
      tester,
    ) async {
      final harness = await pumpSettings(
        tester,
        languageCode: languageCode == 'en' ? 'fr' : 'en',
      );
      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsOneWidget);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(osiaStringsForCode(languageCode).languageName).last,
      );
      await tester.pumpAndSettle();
      expect(await harness.storage.getLanguageCode(), languageCode);
      final context = tester.element(find.byType(SettingsScreen));
      expect(OsiaL10n.of(context).languageCode, languageCode);
      expect(
        find.text(osiaStringsForCode(languageCode).settingsTitle),
        findsOneWidget,
      );
      final selected = tester.widget<DropdownButtonFormField<String>>(dropdown);
      expect(selected.initialValue, languageCode);
      expect(tester.takeException(), isNull);
    });
  }

  for (final languageCode in <String>['en', 'fr']) {
    testWidgets(
      'Help is unique and immediately before Connection in $languageCode',
      (tester) async {
        final harness = await pumpSettings(tester, languageCode: languageCode);
        harness.wsService.emitConfig();
        await tester.pump();

        final help = find.byKey(const Key('settings-help-section'));
        final connection = find.byKey(const Key('settings-connection-section'));
        expect(help, findsOneWidget);
        expect(connection, findsOneWidget);
        expect(find.byKey(const Key('show-mobile-guide')), findsOneWidget);

        final sections = tester.widget<Column>(
          find.byKey(const Key('settings-sections')),
        );
        final helpIndex = sections.children.indexWhere(
          (child) => child.key == const Key('settings-help-section'),
        );
        final connectionIndex = sections.children.indexWhere(
          (child) => child.key == const Key('settings-connection-section'),
        );
        expect(helpIndex, greaterThan(0));
        expect(connectionIndex, helpIndex + 2);

        expect(
          find.descendant(
            of: help,
            matching: find.text(languageCode == 'fr' ? 'AIDE' : 'HELP'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: connection,
            matching: find.text(
              languageCode == 'fr' ? 'CONNEXION' : 'CONNECTION',
            ),
          ),
          findsOneWidget,
        );
      },
    );
  }
}
