import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/background_connection_service.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;

class _FakeWebSocketService extends ws.WebSocketService {
  _FakeWebSocketService()
    : super(ip: '127.0.0.1', token: 'token', autoReconnect: false);

  final List<String> ensureReasons = [];
  final List<bool> ensureResults = [];
  bool connected = true;

  @override
  ws.ConnectionState get state => connected
      ? ws.ConnectionState.connected
      : ws.ConnectionState.disconnected;

  @override
  Future<void> ensureConnected({
    String reason = 'unspecified',
    bool forceReconnect = false,
  }) async {
    ensureReasons.add(reason);
    if (ensureResults.isNotEmpty) {
      connected = ensureResults.removeAt(0);
    }
  }
}

class _FakeBackgroundPlatform
    implements
        BackgroundConnectionPlatform,
        BackgroundConnectionTimeoutPlatform {
  bool running = false;
  bool startResult = true;
  bool runningAfterStart = true;
  bool timedOut = false;
  Completer<bool>? startGate;
  Completer<void>? stopGate;
  int startCount = 0;
  int stopCount = 0;
  int isRunningCount = 0;
  int consumeTimeoutCount = 0;

  @override
  Future<bool> start() async {
    startCount++;
    final result = await (startGate?.future ?? Future<bool>.value(startResult));
    running = result && runningAfterStart;
    return result;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    await (stopGate?.future ?? Future<void>.value());
    running = false;
  }

  @override
  Future<bool> isRunning() async {
    isRunningCount++;
    return running;
  }

  @override
  Future<bool> consumeStoppedByTimeout() async {
    consumeTimeoutCount++;
    final result = timedOut;
    timedOut = false;
    return result;
  }
}

class _FakeNotificationPermission
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

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('method-channel foreground service is disabled on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final platform = MethodChannelBackgroundConnectionPlatform();

    expect(await platform.start(), isFalse);
    await platform.stop();
    expect(await platform.isRunning(), isFalse);
    expect(await platform.consumeStoppedByTimeout(), isFalse);
  });

  Future<
    ({
      StorageService storage,
      BackgroundConnectionService service,
      _FakeWebSocketService wsService,
      _FakeBackgroundPlatform platform,
      _FakeNotificationPermission permission,
    })
  >
  buildHarness() async {
    final storage = StorageService();
    final platform = _FakeBackgroundPlatform();
    final permission = _FakeNotificationPermission();
    final service = BackgroundConnectionService(
      storage: storage,
      platform: platform,
      notificationPermission: permission,
    );
    final wsService = _FakeWebSocketService();
    service.attachWebSocketService(wsService);
    await Future<void>.delayed(Duration.zero);
    addTearDown(wsService.dispose);
    return (
      storage: storage,
      service: service,
      wsService: wsService,
      platform: platform,
      permission: permission,
    );
  }

  test('background connection defaults off', () async {
    final harness = await buildHarness();

    expect(await harness.storage.getBackgroundConnectionEnabled(), isFalse);
  });

  test('failed relay connection does not report background success', () async {
    final harness = await buildHarness();
    harness.wsService.connected = false;

    expect(await harness.service.startBackgroundConnection(), isFalse);
    expect(harness.platform.startCount, 0);
  });

  test('start checks relay once and confirms native service state', () async {
    final harness = await buildHarness();
    harness.platform.runningAfterStart = false;

    expect(await harness.service.startBackgroundConnection(), isFalse);
    expect(harness.platform.startCount, 1);
    expect(harness.wsService.ensureReasons, hasLength(1));
    expect(harness.platform.isRunningCount, 2);
  });

  test('enabling persists true and starts foreground service', () async {
    final harness = await buildHarness();

    final enabled = await harness.service
        .setBackgroundConnectionEnabledFromSettings(true);

    expect(enabled, isTrue);
    expect(await harness.storage.getBackgroundConnectionEnabled(), isTrue);
    expect(harness.permission.requestCount, 1);
    expect(harness.platform.startCount, 1);
    expect(
      harness.wsService.ensureReasons,
      contains('background_connection_enabled'),
    );
  });

  test('disabling persists false and stops foreground service', () async {
    final harness = await buildHarness();
    await harness.storage.setBackgroundConnectionEnabled(true);
    harness.platform.running = true;

    final enabled = await harness.service
        .setBackgroundConnectionEnabledFromSettings(false);

    expect(enabled, isFalse);
    expect(await harness.storage.getBackgroundConnectionEnabled(), isFalse);
    expect(harness.platform.stopCount, greaterThanOrEqualTo(1));
  });

  test('start is idempotent while service is already running', () async {
    final harness = await buildHarness();

    expect(await harness.service.startBackgroundConnection(), isTrue);
    expect(await harness.service.startBackgroundConnection(), isTrue);

    expect(harness.platform.startCount, 1);
    expect(harness.platform.isRunningCount, 3);
  });

  test(
    'repeated enable does not start duplicate foreground services',
    () async {
      final harness = await buildHarness();

      expect(
        await harness.service.setBackgroundConnectionEnabledFromSettings(true),
        isTrue,
      );
      expect(
        await harness.service.setBackgroundConnectionEnabledFromSettings(true),
        isTrue,
      );

      expect(harness.permission.requestCount, 2);
      expect(harness.platform.startCount, 1);
      expect(await harness.storage.getBackgroundConnectionEnabled(), isTrue);
    },
  );

  test(
    'permission denied disables gracefully without starting service',
    () async {
      final harness = await buildHarness();
      harness.permission.requestResult = false;

      final enabled = await harness.service
          .setBackgroundConnectionEnabledFromSettings(true);

      expect(enabled, isFalse);
      expect(await harness.storage.getBackgroundConnectionEnabled(), isFalse);
      expect(harness.platform.startCount, 0);
      expect(harness.platform.stopCount, greaterThanOrEqualTo(1));
    },
  );

  test(
    'timeout disables the stored setting and stops deterministically',
    () async {
      final harness = await buildHarness();
      final initialStopCount = harness.platform.stopCount;
      await harness.storage.setBackgroundConnectionEnabled(true);
      harness.platform.timedOut = true;

      expect(
        await harness.service.syncBackgroundConnectionSetting(
          reason: 'timeout_reconcile',
        ),
        isFalse,
      );

      expect(await harness.storage.getBackgroundConnectionEnabled(), isFalse);
      expect(harness.platform.consumeTimeoutCount, greaterThanOrEqualTo(1));
      expect(harness.platform.stopCount, initialStopCount + 1);
      expect(harness.wsService.ensureReasons, isEmpty);
    },
  );

  test(
    'stale enabled setting does not claim a stopped service is active',
    () async {
      final harness = await buildHarness();
      await harness.storage.setBackgroundConnectionEnabled(true);
      harness.platform.running = false;

      expect(await harness.service.backgroundConnectionEnabled(), isFalse);
      expect(await harness.storage.getBackgroundConnectionEnabled(), isFalse);
    },
  );

  test('stop waits for an in-flight start and wins the transition', () async {
    final harness = await buildHarness();
    final initialStopCount = harness.platform.stopCount;
    final startGate = Completer<bool>();
    harness.platform.startGate = startGate;

    final start = harness.service.startBackgroundConnection();
    await Future<void>.delayed(Duration.zero);
    final stop = harness.service.stopBackgroundConnection();
    await Future<void>.delayed(Duration.zero);

    expect(harness.platform.startCount, 1);
    expect(harness.platform.stopCount, initialStopCount);

    startGate.complete(true);
    expect(await start, isTrue);
    await stop;

    expect(harness.platform.stopCount, initialStopCount + 1);
    expect(harness.platform.running, isFalse);
  });

  test('start waits for an in-flight stop and restores one service', () async {
    final harness = await buildHarness();
    final stopGate = Completer<void>();
    harness.platform.running = true;
    harness.platform.stopGate = stopGate;

    final stop = harness.service.stopBackgroundConnection();
    await Future<void>.delayed(Duration.zero);
    final start = harness.service.startBackgroundConnection();
    await Future<void>.delayed(Duration.zero);

    expect(harness.platform.startCount, 0);

    stopGate.complete();
    await stop;
    expect(await start, isTrue);

    expect(harness.platform.startCount, 1);
    expect(harness.platform.running, isTrue);
  });
}
