import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/settings_screen.dart';
import 'package:osia_mobile/services/connection_lifecycle_service.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

class _FakeWebSocketService extends ws.WebSocketService {
  _FakeWebSocketService()
    : super(ip: '127.0.0.1', token: 'token', autoReconnect: false);

  final StreamController<ws.ConnectionState> _connCtrl =
      StreamController<ws.ConnectionState>.broadcast();

  final List<String> ensureReasons = [];
  final List<bool> forceReconnects = [];
  final List<String> sentTypes = [];

  ws.ConnectionState _state = ws.ConnectionState.disconnected;

  @override
  ws.ConnectionState get state => _state;

  @override
  Stream<ws.ConnectionState> get connectionStream => _connCtrl.stream;

  @override
  Future<void> ensureConnected({
    String reason = 'unspecified',
    bool forceReconnect = false,
  }) {
    ensureReasons.add(reason);
    forceReconnects.add(forceReconnect);
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

  void emitConnection(ws.ConnectionState state) {
    _state = state;
    _connCtrl.add(state);
  }

  @override
  void dispose() {
    _connCtrl.close();
    super.dispose();
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'WebSocketService ensureConnected shares one in-flight attempt',
    () async {
      final hostCompleter = Completer<String>();
      var resolveCalls = 0;
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
        resolveHost: () {
          resolveCalls++;
          return hostCompleter.future;
        },
      );
      addTearDown(service.dispose);

      final first = service.ensureConnected(reason: 'settings_open');
      final second = service.ensureConnected(reason: 'app_resume');

      expect(identical(first, second), isTrue);
      expect(service.state, ws.ConnectionState.connecting);
      expect(service.debugConnectAttemptCount, 1);
      expect(resolveCalls, 1);

      hostCompleter.completeError(StateError('offline'));
      await Future.wait([first, second]);

      expect(service.debugConnectAttemptCount, 1);
      expect(service.state, ws.ConnectionState.disconnected);
    },
  );

  test('app resume ensures the current service without ChatScreen', () async {
    final service = _FakeWebSocketService();
    addTearDown(service.dispose);
    final lifecycle = ConnectionLifecycleService(resumeThrottle: Duration.zero)
      ..attach(service);

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(service.ensureReasons, ['app_lifecycle_resumed']);
    expect(service.forceReconnects, [true]);
  });

  testWidgets(
    'Settings open ensures connection and refreshes after reconnect',
    (tester) async {
      final service = _FakeWebSocketService();
      addTearDown(service.dispose);

      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPaletteViolet,
          child: OsiaL10n(
            strings: osiaStringsForCode('en'),
            child: MaterialApp(
              home: SettingsScreen(
                storage: StorageService(),
                themeController: ThemeController(),
                languageController: LanguageController(),
                wsService: service,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(service.ensureReasons, contains('settings_open'));

      service.emitConnection(ws.ConnectionState.connected);
      await tester.pump();

      expect(service.sentTypes, contains('get_config'));
      expect(service.sentTypes, contains('get_models'));
      expect(service.sentTypes, contains('mcp_status'));
    },
  );
}
