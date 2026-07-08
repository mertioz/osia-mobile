import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'storage_service.dart';
import 'websocket_service.dart' as ws;

const String osiaNotificationChannelId = 'osia_scheduled_tasks';
const String osiaNotificationChannelName = 'OSIA reminders and scheduled tasks';
const String osiaNotificationChannelDescription =
    'Scheduled task completion, failure, and reminder notifications from OSIA.';

const int _maxShownNotificationIds = 200;

final RegExp _secretHintRe = RegExp(
  r'\b(?:api[_-]?key|secret|token|password|passwd|bearer)\b|'
  r'\b(?:sk|pk)-[A-Za-z0-9_-]{16,}\b',
  caseSensitive: false,
);

final RegExp _pathHintRe = RegExp(r'(^|\s)(?:[A-Za-z]:[\\/]|\\\\|/[^\s]+/)');

enum OsiaNotificationResult {
  shown,
  duplicate,
  disabled,
  permissionDenied,
  failed,
}

abstract class OsiaNotificationClient {
  Future<void> initialize();

  Future<bool> requestPermission();

  Future<bool> notificationsAllowed();

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });
}

class FlutterOsiaNotificationClient implements OsiaNotificationClient {
  FlutterOsiaNotificationClient({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('ic_launcher_foreground');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    await _plugin.initialize(settings: settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        osiaNotificationChannelId,
        osiaNotificationChannelName,
        description: osiaNotificationChannelDescription,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      return await androidPlugin.requestNotificationsPermission() ?? false;
    }

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      return await iosPlugin.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          ) ??
          false;
    }

    final macosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macosPlugin != null) {
      return await macosPlugin.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  @override
  Future<bool> notificationsAllowed() async {
    await initialize();

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      return await androidPlugin.areNotificationsEnabled() ?? false;
    }

    return true;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    const android = AndroidNotificationDetails(
      osiaNotificationChannelId,
      osiaNotificationChannelName,
      channelDescription: osiaNotificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
    );
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}

class OsiaNotificationService {
  OsiaNotificationService({
    required this.storage,
    OsiaNotificationClient? client,
  }) : _client = client ?? FlutterOsiaNotificationClient();

  final StorageService storage;
  final OsiaNotificationClient _client;
  Set<String>? _shownIds;

  Future<bool> notificationsEnabled() => storage.getNotificationsEnabled();

  Future<bool> setNotificationsEnabledFromSettings(bool enabled) async {
    if (!enabled) {
      await storage.setNotificationsEnabled(false);
      return false;
    }

    try {
      final granted = await _client.requestPermission();
      await storage.setNotificationsEnabled(granted);
      return granted;
    } catch (e) {
      debugPrint('[OSIA Notifications] permission request failed: $e');
      await storage.setNotificationsEnabled(false);
      return false;
    }
  }

  Future<OsiaNotificationResult> showCronNotification(
    ws.CronNotificationMessage event, {
    required String completedLabel,
    required String failedLabel,
    required String reminderLabel,
  }) async {
    final eventId = _eventIdFor(event);
    if (eventId.isEmpty) return OsiaNotificationResult.failed;
    if (await _hasHandled(eventId)) {
      return OsiaNotificationResult.duplicate;
    }

    final enabled = await storage.getNotificationsEnabled();
    if (!enabled) {
      await _rememberHandled(eventId);
      return OsiaNotificationResult.disabled;
    }

    try {
      final allowed = await _client.notificationsAllowed();
      if (!allowed) {
        await _rememberHandled(eventId);
        return OsiaNotificationResult.permissionDenied;
      }

      final body = cronNotificationBody(
        event,
        completedLabel: completedLabel,
        failedLabel: failedLabel,
        reminderLabel: reminderLabel,
      );
      await _client.show(
        id: _stableNotificationId(eventId),
        title: 'OSIA',
        body: body,
        payload: event.conversationId.isEmpty ? null : event.conversationId,
      );
      await _rememberHandled(eventId);
      return OsiaNotificationResult.shown;
    } catch (e) {
      debugPrint('[OSIA Notifications] show failed: $e');
      return OsiaNotificationResult.failed;
    }
  }

  static String cronNotificationBody(
    ws.CronNotificationMessage event, {
    required String completedLabel,
    required String failedLabel,
    required String reminderLabel,
  }) {
    final base = event.failed
        ? failedLabel
        : (_looksLikeReminder(event.title) ? reminderLabel : completedLabel);
    final title = safeNotificationTitle(event.title);
    return title == null ? base : '$base: $title';
  }

  static String? safeNotificationTitle(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return null;
    if (_secretHintRe.hasMatch(normalized)) return null;
    if (_pathHintRe.hasMatch(normalized)) return null;
    return normalized.length <= 80
        ? normalized
        : normalized.substring(0, 80).trimRight();
  }

  static bool _looksLikeReminder(String value) {
    final text = value.toLowerCase();
    return text.contains('reminder') ||
        text.contains('remind me') ||
        text.contains('rappel') ||
        text.contains('rappelle');
  }

  Future<bool> _hasHandled(String id) async {
    final ids = await _loadShownIds();
    return ids.contains(id);
  }

  Future<void> _rememberHandled(String id) async {
    final ids = await _loadShownIds();
    ids.remove(id);
    ids.add(id);
    while (ids.length > _maxShownNotificationIds) {
      ids.remove(ids.first);
    }
    await storage.setShownNotificationIds(ids);
  }

  Future<Set<String>> _loadShownIds() async {
    final cached = _shownIds;
    if (cached != null) return cached;
    final loaded = (await storage.getShownNotificationIds()).toSet();
    _shownIds = loaded;
    return loaded;
  }

  static String _eventIdFor(ws.CronNotificationMessage event) {
    final explicit = event.id.trim();
    if (explicit.isNotEmpty) return explicit;
    return [
      'cron',
      event.taskId.trim(),
      event.status.trim(),
      event.createdAt.trim(),
    ].where((part) => part.isNotEmpty).join(':');
  }

  static int _stableNotificationId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
