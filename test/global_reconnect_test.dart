import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/settings_screen.dart';
import 'package:osia_mobile/services/background_connection_service.dart';
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

class _ControlledConnectAttempts {
  _ControlledConnectAttempts(int count)
    : results = List<Completer<bool>>.generate(count, (_) => Completer<bool>()),
      started = List<Completer<void>>.generate(count, (_) => Completer<void>());

  final List<Completer<bool>> results;
  final List<Completer<void>> started;
  int calls = 0;

  Future<bool> call() {
    final index = calls++;
    started[index].complete();
    return results[index].future;
  }
}

class _LifecycleBackgroundPlatform implements BackgroundConnectionPlatform {
  bool running = false;
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<bool> start() async {
    startCount++;
    running = true;
    return true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    running = false;
  }

  @override
  Future<bool> isRunning() async => running;
}

class _AllowedBackgroundNotifications
    implements BackgroundNotificationPermissionClient {
  @override
  Future<bool> notificationsAllowed() async => true;

  @override
  Future<bool> requestPermission() async => true;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'WebSocketService ensureConnected shares one in-flight attempt',
    () async {
      final hostCompleter = Completer<String>();
      final resolveStarted = Completer<void>();
      var resolveCalls = 0;
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
        resolveHost: () {
          resolveCalls++;
          resolveStarted.complete();
          return hostCompleter.future;
        },
      );
      addTearDown(service.dispose);

      final first = service.ensureConnected(reason: 'settings_open');
      final second = service.ensureConnected(reason: 'app_resume');

      expect(identical(first, second), isTrue);
      expect(service.state, ws.ConnectionState.connecting);
      expect(service.debugConnectAttemptCount, 1);
      await resolveStarted.future;
      expect(resolveCalls, 1);

      hostCompleter.completeError(StateError('offline'));
      await Future.wait([first, second]);

      expect(service.debugConnectAttemptCount, 1);
      expect(service.state, ws.ConnectionState.disconnected);
    },
  );

  test(
    'fifty concurrent ensureConnected calls share one successful attempt',
    () async {
      final attempts = _ControlledConnectAttempts(1);
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
        connectAttemptForTest: attempts.call,
      );
      addTearDown(service.dispose);
      final notifications = <ws.ConnectionState>[];
      final connectedNotified = Completer<void>();
      final subscription = service.connectionStream.listen((state) {
        notifications.add(state);
        if (state == ws.ConnectionState.connected &&
            !connectedNotified.isCompleted) {
          connectedNotified.complete();
        }
      });
      addTearDown(subscription.cancel);

      final futures = List<Future<void>>.generate(
        50,
        (index) => service.ensureConnected(reason: 'concurrent_$index'),
      );

      expect(
        futures.every((future) => identical(future, futures.first)),
        isTrue,
      );
      expect(service.state, ws.ConnectionState.connecting);
      expect(service.debugConnectAttemptCount, 1);
      await attempts.started.single.future;
      expect(attempts.calls, 1);

      attempts.results.single.complete(true);
      await Future.wait(futures);
      await connectedNotified.future;

      expect(service.state, ws.ConnectionState.connected);
      expect(notifications, <ws.ConnectionState>[
        ws.ConnectionState.connecting,
        ws.ConnectionState.connected,
      ]);
      expect(service.hasPendingConnectAttemptForTest, isFalse);
      expect(service.hasReconnectTimerForTest, isFalse);
    },
  );

  test(
    'failed attempt clears once and a later retry starts one new attempt',
    () async {
      final attempts = _ControlledConnectAttempts(2);
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
        connectAttemptForTest: attempts.call,
      );
      addTearDown(service.dispose);
      final notifications = <ws.ConnectionState>[];
      final subscription = service.connectionStream.listen(notifications.add);
      addTearDown(subscription.cancel);

      final first = service.ensureConnected(reason: 'first_failure');
      await attempts.started[0].future;
      attempts.results[0].complete(false);
      await first;

      expect(service.state, ws.ConnectionState.disconnected);
      expect(service.hasPendingConnectAttemptForTest, isFalse);

      final retry = service.ensureConnected(reason: 'retry_after_failure');
      await attempts.started[1].future;
      attempts.results[1].complete(false);
      await retry;

      expect(attempts.calls, 2);
      expect(service.debugConnectAttemptCount, 2);
      expect(service.state, ws.ConnectionState.disconnected);
      expect(notifications, <ws.ConnectionState>[
        ws.ConnectionState.connecting,
        ws.ConnectionState.disconnected,
        ws.ConnectionState.connecting,
        ws.ConnectionState.disconnected,
      ]);
      expect(service.hasPendingConnectAttemptForTest, isFalse);
      expect(service.hasReconnectTimerForTest, isFalse);
    },
  );

  test(
    'stale failure cannot overwrite a newer successful generation',
    () async {
      final attempts = _ControlledConnectAttempts(2);
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
        connectAttemptForTest: attempts.call,
      );
      addTearDown(service.dispose);

      final stale = service.ensureConnected(reason: 'stale_generation');
      await attempts.started[0].future;
      service.disconnect();
      await stale;
      expect(service.hasPendingConnectAttemptForTest, isFalse);

      final current = service.ensureConnected(reason: 'current_generation');
      await attempts.started[1].future;
      attempts.results[1].complete(true);
      await current;
      expect(service.state, ws.ConnectionState.connected);

      attempts.results[0].complete(false);
      await Future<void>.microtask(() {});
      await Future<void>.microtask(() {});

      expect(service.state, ws.ConnectionState.connected);
      expect(service.debugConnectAttemptCount, 2);
    },
  );

  test(
    'disconnect during connecting completes waiters and rejects late success',
    () async {
      final attempts = _ControlledConnectAttempts(1);
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
        connectAttemptForTest: attempts.call,
      );
      addTearDown(service.dispose);

      final pending = service.ensureConnected(
        reason: 'disconnect_during_connect',
      );
      await attempts.started.single.future;
      service.disconnect();
      await pending;

      expect(service.state, ws.ConnectionState.disconnected);
      expect(service.hasPendingConnectAttemptForTest, isFalse);
      attempts.results.single.complete(true);
      await Future<void>.microtask(() {});
      await Future<void>.microtask(() {});
      expect(service.state, ws.ConnectionState.disconnected);
      expect(service.hasReconnectTimerForTest, isFalse);
    },
  );

  test('dispose during connecting completes all shared waiters', () async {
    final attempts = _ControlledConnectAttempts(1);
    final service = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
      connectAttemptForTest: attempts.call,
    );

    final first = service.ensureConnected(reason: 'dispose_first');
    final second = service.ensureConnected(reason: 'dispose_second');
    await attempts.started.single.future;
    service.dispose();
    await Future.wait(<Future<void>>[first, second]);

    expect(identical(first, second), isTrue);
    expect(service.state, ws.ConnectionState.disconnected);
    expect(service.hasPendingConnectAttemptForTest, isFalse);
    expect(service.hasReconnectTimerForTest, isFalse);
    attempts.results.single.complete(true);
    await Future<void>.microtask(() {});
  });

  test(
    'background resume during connecting does not start a parallel attempt',
    () async {
      final attempts = _ControlledConnectAttempts(1);
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
        connectAttemptForTest: attempts.call,
      );
      addTearDown(service.dispose);
      final lifecycle = ConnectionLifecycleService(
        resumeThrottle: Duration.zero,
      )..attach(service);

      final pending = service.ensureConnected(reason: 'foreground_connect');
      await attempts.started.single.future;
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(service.state, ws.ConnectionState.connecting);
      expect(service.debugConnectAttemptCount, 1);
      expect(attempts.calls, 1);

      attempts.results.single.complete(false);
      await pending;
      expect(service.state, ws.ConnectionState.disconnected);
      expect(service.hasPendingConnectAttemptForTest, isFalse);
    },
  );

  test('app resume preserves a healthy current service', () async {
    final service = _FakeWebSocketService();
    addTearDown(service.dispose);
    service.emitConnection(ws.ConnectionState.connected);
    final lifecycle = ConnectionLifecycleService(resumeThrottle: Duration.zero)
      ..attach(service);

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(service.ensureReasons, ['app_lifecycle_resumed']);
    expect(service.forceReconnects, [false]);
  });

  test('app resume asks a disconnected service to reconnect once', () async {
    final service = _FakeWebSocketService();
    addTearDown(service.dispose);
    final lifecycle = ConnectionLifecycleService(resumeThrottle: Duration.zero)
      ..attach(service);

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(service.ensureReasons, ['app_lifecycle_resumed']);
    expect(service.forceReconnects, [false]);
  });

  test(
    'resume coalesces direct reconnect and background reconciliation',
    () async {
      final storage = StorageService();
      final platform = _LifecycleBackgroundPlatform();
      final background = BackgroundConnectionService(
        storage: storage,
        platform: platform,
        notificationPermission: _AllowedBackgroundNotifications(),
      );
      final service = _FakeWebSocketService();
      addTearDown(service.dispose);
      final lifecycle = ConnectionLifecycleService(
        resumeThrottle: Duration.zero,
        backgroundConnectionService: background,
      )..attach(service);
      await Future<void>.delayed(Duration.zero);
      await storage.setBackgroundConnectionEnabled(true);
      service.emitConnection(ws.ConnectionState.connected);
      service.ensureReasons.clear();

      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(service.ensureReasons, ['app_lifecycle_resumed']);
      expect(platform.startCount, 1);
      expect(platform.running, isTrue);
    },
  );

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
      // Connector status belongs to the connector screen, not Settings startup.
      expect(service.sentTypes, isNot(contains('mcp_status')));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
