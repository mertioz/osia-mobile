import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/settings_screen.dart';
import 'package:osia_mobile/services/notification_service.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

class _FakeWebSocketService extends ws.WebSocketService {
  _FakeWebSocketService()
    : super(ip: '127.0.0.1', token: 'token', autoReconnect: false);

  final StreamController<ws.ConnectionState> _connCtrl =
      StreamController<ws.ConnectionState>.broadcast();

  final List<String> sentTypes = [];
  final List<String> ensureReasons = [];

  @override
  ws.ConnectionState get state => ws.ConnectionState.connected;

  @override
  Stream<ws.ConnectionState> get connectionStream => _connCtrl.stream;

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
  void dispose() {
    _connCtrl.close();
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

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<
    ({
      StorageService storage,
      _FakeWebSocketService wsService,
      _FakeNotificationClient notificationClient,
    })
  >
  pumpSettings(
    WidgetTester tester, {
    bool requestResult = true,
    bool notificationsEnabled = false,
  }) async {
    final storage = StorageService();
    await storage.setNotificationsEnabled(notificationsEnabled);
    final wsService = _FakeWebSocketService();
    final notificationClient = _FakeNotificationClient()
      ..requestResult = requestResult;
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
    );
  }

  testWidgets('shows notification toggle in the requested Settings order', (
    tester,
  ) async {
    await pumpSettings(tester);
    final strings = osiaStringsForCode('en');

    expect(find.text(strings.osiaNotifications), findsOneWidget);

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
}
