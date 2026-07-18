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
  DateTime? _lastResumeEnsureAt;
  Future<void>? _resumeFuture;

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
      unawaited(_ensureAfterResume());
    }
  }

  Future<void> _ensureAfterResume() {
    final inFlight = _resumeFuture;
    if (inFlight != null) return inFlight;

    final service = _service;
    if (service == null) return Future<void>.value();

    final now = DateTime.now();
    final last = _lastResumeEnsureAt;
    if (last != null && now.difference(last) < resumeThrottle) {
      return Future<void>.value();
    }
    _lastResumeEnsureAt = now;

    late final Future<void> future;
    future = _resume(service).whenComplete(() {
      if (identical(_resumeFuture, future)) {
        _resumeFuture = null;
      }
    });
    _resumeFuture = future;
    return future;
  }

  Future<void> _resume(ws.WebSocketService service) async {
    try {
      await service.ensureConnected(reason: 'app_lifecycle_resumed');
    } catch (_) {
      // The background-state reconciliation below records the failed outcome.
    }
    await backgroundConnectionService?.syncBackgroundConnectionSetting(
      reason: 'app_lifecycle_resumed',
      webSocketAlreadyEnsured: true,
    );
  }
}
