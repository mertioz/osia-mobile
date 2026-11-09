import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/notification_service.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;

class _ShownNotification {
  final int id;
  final String title;
  final String body;
  final String? payload;

  const _ShownNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });
}

class _FakeNotificationClient implements OsiaNotificationClient {
  bool requestResult = true;
  bool allowed = true;
  bool throwOnRequest = false;
  int requestCount = 0;
  int allowedCheckCount = 0;
  final List<_ShownNotification> shown = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    requestCount++;
    if (throwOnRequest) throw StateError('permission failed');
    return requestResult;
  }

  @override
  Future<bool> notificationsAllowed() async {
    allowedCheckCount++;
    return allowed;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shown.add(
      _ShownNotification(id: id, title: title, body: body, payload: payload),
    );
  }
}

ws.CronNotificationMessage _note({
  String id = 'note-1',
  String title = 'Daily check',
  String status = 'completed',
  String conversationId = 'conv-a',
}) {
  return ws.CronNotificationMessage(
    id: id,
    taskId: 'cron-a',
    title: title,
    status: status,
    conversationId: conversationId,
    createdAt: '2026-07-08T10:00:00+02:00',
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'cron notification shows when enabled and permission is granted',
    () async {
      final storage = StorageService();
      await storage.setNotificationsEnabled(true);
      final client = _FakeNotificationClient();
      final service = OsiaNotificationService(storage: storage, client: client);

      final result = await service.showCronNotification(
        _note(),
        completedLabel: 'Scheduled task completed',
        failedLabel: 'Scheduled task failed',
        reminderLabel: 'OSIA reminder',
      );

      expect(result, OsiaNotificationResult.shown);
      expect(client.shown, hasLength(1));
      expect(client.shown.single.title, 'OSIA');
      expect(client.shown.single.body, 'Scheduled task completed: Daily check');
      expect(client.shown.single.payload, 'conv-a');
    },
  );

  test(
    'disabled setting suppresses system notification and records id',
    () async {
      final storage = StorageService();
      final client = _FakeNotificationClient();
      final service = OsiaNotificationService(storage: storage, client: client);

      final result = await service.showCronNotification(
        _note(),
        completedLabel: 'Scheduled task completed',
        failedLabel: 'Scheduled task failed',
        reminderLabel: 'OSIA reminder',
      );

      expect(result, OsiaNotificationResult.disabled);
      expect(client.shown, isEmpty);
      expect(client.allowedCheckCount, 0);
      expect(await storage.getShownNotificationIds(), contains('note-1'));
    },
  );

  test('duplicate event id is shown once across service instances', () async {
    final storage = StorageService();
    await storage.setNotificationsEnabled(true);
    final client = _FakeNotificationClient();

    final first = OsiaNotificationService(storage: storage, client: client);
    final second = OsiaNotificationService(storage: storage, client: client);

    final firstResult = await first.showCronNotification(
      _note(),
      completedLabel: 'Scheduled task completed',
      failedLabel: 'Scheduled task failed',
      reminderLabel: 'OSIA reminder',
    );
    final secondResult = await second.showCronNotification(
      _note(),
      completedLabel: 'Scheduled task completed',
      failedLabel: 'Scheduled task failed',
      reminderLabel: 'OSIA reminder',
    );

    expect(firstResult, OsiaNotificationResult.shown);
    expect(secondResult, OsiaNotificationResult.duplicate);
    expect(client.shown, hasLength(1));
  });

  test('denied platform permission does not crash and records id', () async {
    final storage = StorageService();
    await storage.setNotificationsEnabled(true);
    final client = _FakeNotificationClient()..allowed = false;
    final service = OsiaNotificationService(storage: storage, client: client);

    final result = await service.showCronNotification(
      _note(),
      completedLabel: 'Scheduled task completed',
      failedLabel: 'Scheduled task failed',
      reminderLabel: 'OSIA reminder',
    );

    expect(result, OsiaNotificationResult.permissionDenied);
    expect(client.shown, isEmpty);
    expect(await storage.getShownNotificationIds(), contains('note-1'));
  });

  test('settings permission result controls persisted toggle', () async {
    final storage = StorageService();
    final client = _FakeNotificationClient()..requestResult = false;
    final service = OsiaNotificationService(storage: storage, client: client);

    expect(await service.setNotificationsEnabledFromSettings(true), isFalse);
    expect(await storage.getNotificationsEnabled(), isFalse);

    client.requestResult = true;
    expect(await service.setNotificationsEnabledFromSettings(true), isTrue);
    expect(await storage.getNotificationsEnabled(), isTrue);

    expect(await service.setNotificationsEnabledFromSettings(false), isFalse);
    expect(await storage.getNotificationsEnabled(), isFalse);
  });

  test('settings disabled path does not request platform permission', () async {
    final storage = StorageService();
    await storage.setNotificationsEnabled(true);
    final client = _FakeNotificationClient();
    final service = OsiaNotificationService(storage: storage, client: client);

    expect(await service.setNotificationsEnabledFromSettings(false), isFalse);

    expect(client.requestCount, 0);
    expect(await storage.getNotificationsEnabled(), isFalse);
  });

  test(
    'settings permission failure does not crash and persists disabled',
    () async {
      final storage = StorageService();
      final client = _FakeNotificationClient()..throwOnRequest = true;
      final service = OsiaNotificationService(storage: storage, client: client);

      expect(await service.setNotificationsEnabledFromSettings(true), isFalse);

      expect(client.requestCount, 1);
      expect(await storage.getNotificationsEnabled(), isFalse);
    },
  );

  test('failed and reminder bodies stay short and avoid unsafe titles', () {
    expect(
      OsiaNotificationService.cronNotificationBody(
        _note(status: 'failed', title: 'API key sk-1234567890abcdef'),
        completedLabel: 'Scheduled task completed',
        failedLabel: 'Scheduled task failed',
        reminderLabel: 'OSIA reminder',
      ),
      'Scheduled task failed',
    );

    expect(
      OsiaNotificationService.cronNotificationBody(
        _note(title: 'Reminder: stand up'),
        completedLabel: 'Scheduled task completed',
        failedLabel: 'Scheduled task failed',
        reminderLabel: 'OSIA reminder',
      ),
      'OSIA reminder: Reminder: stand up',
    );
  });

  test('a cancelled reminder keeps its cancellation label', () {
    final note = ws.CronNotificationMessage.fromJson({
      'id': 'note-cancelled',
      'title': 'Reminder: stand up',
      'status': 'failed',
      'outcome': 'user_cancelled',
    });
    expect(
      OsiaNotificationService.cronNotificationBody(
        note,
        completedLabel: 'Scheduled task completed',
        failedLabel: 'Scheduled task failed',
        reminderLabel: 'OSIA reminder',
        outcomeLabel: 'Scheduled task cancelled',
      ),
      'Scheduled task cancelled: Reminder: stand up',
    );
  });
}
