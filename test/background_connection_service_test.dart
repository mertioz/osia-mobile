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

  test('post-start relay failure remains authoritative', () async {
    final harness = await buildHarness();
    harness.wsService.ensureResults.addAll(<bool>[true, false]);

    expect(await harness.service.startBackgroundConnection(), isFalse);
    expect(harness.platform.startCount, 1);
    expect(harness.wsService.ensureReasons, hasLength(2));
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
    expect(harness.platform.isRunningCount, 2);
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
}
