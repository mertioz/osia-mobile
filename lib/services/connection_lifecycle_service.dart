import 'dart:async';

import 'package:flutter/widgets.dart';

import 'background_connection_service.dart';
import 'websocket_service.dart' as ws;

/// App-level owner for WebSocket lifecycle nudges.
///
/// Screens still own their UI subscriptions, but app resume reconnects are
/// routed here so reconnect is not dependent on visiting the chat route.
class ConnectionLifecycleService with WidgetsBindingObserver {
  ConnectionLifecycleService({
    this.resumeThrottle = const Duration(seconds: 2),
    this.backgroundConnectionService,
  });

  final Duration resumeThrottle;
  final BackgroundConnectionService? backgroundConnectionService;

  ws.WebSocketService? _service;
  bool _wasBackgrounded = false;
  DateTime? _lastResumeEnsureAt;

  @visibleForTesting
  ws.WebSocketService? get currentService => _service;

  void attach(ws.WebSocketService service) {
    if (identical(_service, service)) return;
    _service = service;
    backgroundConnectionService?.attachWebSocketService(service);
  }

  void detach(ws.WebSocketService service) {
    if (identical(_service, service)) {
      _service = null;
    }
    backgroundConnectionService?.detachWebSocketService(service);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureAfterResume(forceReconnect: _wasBackgrounded);
      final background = backgroundConnectionService;
      if (background != null) {
        unawaited(
          background
              .syncBackgroundConnectionSetting(reason: 'app_lifecycle_resumed')
              .then<void>((_) {}),
        );
      }
      _wasBackgrounded = false;
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _wasBackgrounded = true;
    }
  }

  void _ensureAfterResume({required bool forceReconnect}) {
    final service = _service;
    if (service == null) return;

    final now = DateTime.now();
    final last = _lastResumeEnsureAt;
    if (last != null && now.difference(last) < resumeThrottle) {
      return;
    }
    _lastResumeEnsureAt = now;

    unawaited(
      service.ensureConnected(
        reason: 'app_lifecycle_resumed',
        forceReconnect: forceReconnect,
      ),
    );
  }
}
