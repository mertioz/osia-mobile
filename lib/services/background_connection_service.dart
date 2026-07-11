import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'notification_service.dart';
import 'storage_service.dart';
import 'websocket_service.dart' as ws;

abstract class BackgroundConnectionPlatform {
  Future<bool> start();

  Future<void> stop();

  Future<bool> isRunning();
}

class MethodChannelBackgroundConnectionPlatform
    implements BackgroundConnectionPlatform {
  static const _channel = MethodChannel('space.osia.app/background_connection');

  @override
  Future<bool> start() async {
    try {
      return await _channel.invokeMethod<bool>('start') ?? false;
    } on MissingPluginException catch (e) {
      debugPrint('[OSIA Background] foreground service unavailable: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('[OSIA Background] foreground service start failed: $e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException catch (e) {
      debugPrint('[OSIA Background] foreground service unavailable: $e');
    } on PlatformException catch (e) {
      debugPrint('[OSIA Background] foreground service stop failed: $e');
    }
  }

  @override
  Future<bool> isRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isRunning') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('[OSIA Background] foreground service state check failed: $e');
      return false;
    }
  }
}

abstract class BackgroundNotificationPermissionClient {
  Future<bool> requestPermission();

  Future<bool> notificationsAllowed();
}

class OsiaBackgroundNotificationPermissionClient
    implements BackgroundNotificationPermissionClient {
  OsiaBackgroundNotificationPermissionClient({OsiaNotificationClient? client})
    : _client = client ?? FlutterOsiaNotificationClient();

  final OsiaNotificationClient _client;

  @override
  Future<bool> requestPermission() => _client.requestPermission();

  @override
  Future<bool> notificationsAllowed() => _client.notificationsAllowed();
}

class BackgroundConnectionService {
  BackgroundConnectionService({
    required this.storage,
    BackgroundConnectionPlatform? platform,
    BackgroundNotificationPermissionClient? notificationPermission,
  }) : _platform = platform ?? MethodChannelBackgroundConnectionPlatform(),
       _notificationPermission =
           notificationPermission ??
           OsiaBackgroundNotificationPermissionClient();

  final StorageService storage;
  final BackgroundConnectionPlatform _platform;
  final BackgroundNotificationPermissionClient _notificationPermission;

  ws.WebSocketService? _wsService;
  Future<bool>? _startFuture;
  Future<void>? _stopFuture;

  Future<bool> backgroundConnectionEnabled() =>
      storage.getBackgroundConnectionEnabled();

  void attachWebSocketService(ws.WebSocketService service) {
    if (identical(_wsService, service)) return;
    _wsService = service;
    unawaited(
      syncBackgroundConnectionSetting(
        reason: 'background_ws_attach',
      ).then<void>((_) {}),
    );
  }

  void detachWebSocketService(ws.WebSocketService service) {
    if (identical(_wsService, service)) {
      _wsService = null;
    }
  }

  Future<bool> setBackgroundConnectionEnabledFromSettings(bool enabled) async {
    if (!enabled) {
      await storage.setBackgroundConnectionEnabled(false);
      await stopBackgroundConnection();
      return false;
    }

    final allowed = await _requestNotificationPermission();
    if (!allowed) {
      await storage.setBackgroundConnectionEnabled(false);
      await stopBackgroundConnection();
      return false;
    }

    final started = await startBackgroundConnection(
      reason: 'background_connection_enabled',
    );
    await storage.setBackgroundConnectionEnabled(started);
    if (!started) {
      await stopBackgroundConnection();
    }
    return started;
  }

  Future<bool> syncBackgroundConnectionSetting({
    String reason = 'background_connection_sync',
  }) async {
    final enabled = await storage.getBackgroundConnectionEnabled();
    if (!enabled) {
      await stopBackgroundConnection();
      return false;
    }

    final allowed = await _notificationsAllowed();
    if (!allowed) {
      await storage.setBackgroundConnectionEnabled(false);
      await stopBackgroundConnection();
      return false;
    }

    final started = await startBackgroundConnection(reason: reason);
    if (!started) {
      await storage.setBackgroundConnectionEnabled(false);
      await stopBackgroundConnection();
    }
    return started;
  }

  Future<bool> startBackgroundConnection({
    String reason = 'background_connection_start',
  }) {
    final inFlight = _startFuture;
    if (inFlight != null) return inFlight;

    late final Future<bool> future;
    future = _startBackgroundConnection(reason).whenComplete(() {
      if (identical(_startFuture, future)) {
        _startFuture = null;
      }
    });
    _startFuture = future;
    return future;
  }

  Future<void> stopBackgroundConnection() {
    final inFlight = _stopFuture;
    if (inFlight != null) return inFlight;

    late final Future<void> future;
    future = _platform.stop().whenComplete(() {
      if (identical(_stopFuture, future)) {
        _stopFuture = null;
      }
    });
    _stopFuture = future;
    return future;
  }

  Future<bool> _startBackgroundConnection(String reason) async {
    if (!await _ensureWebSocketConnected(reason)) {
      return false;
    }

    if (await _platform.isRunning()) {
      return true;
    }

    final started = await _platform.start();
    if (!started) return false;

    return _ensureWebSocketConnected(reason);
  }

  Future<bool> _requestNotificationPermission() async {
    try {
      return await _notificationPermission.requestPermission();
    } catch (e) {
      debugPrint(
        '[OSIA Background] notification permission request failed: $e',
      );
      return false;
    }
  }

  Future<bool> _notificationsAllowed() async {
    try {
      return await _notificationPermission.notificationsAllowed();
    } catch (e) {
      debugPrint('[OSIA Background] notification permission check failed: $e');
      return false;
    }
  }

  Future<bool> _ensureWebSocketConnected(String reason) async {
    final service = _wsService;
    if (service == null) {
      debugPrint('[OSIA Background] no WebSocketService attached');
      return false;
    }
    try {
      await service.ensureConnected(reason: reason);
      return service.state == ws.ConnectionState.connected;
    } catch (e) {
      debugPrint('[OSIA Background] ensureConnected failed: $e');
      return false;
    }
  }
}
