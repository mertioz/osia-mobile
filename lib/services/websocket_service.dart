import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ── Connection state ──────────────────────────────────────────────────────

/// Possible states of the WebSocket connection.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
}

// ── Incoming message types ────────────────────────────────────────────────

/// Parsed incoming message from the OSIA server.
sealed class OsiaMessage {
  const OsiaMessage();
}

class TranscriptMessage extends OsiaMessage {
  final String content;
  const TranscriptMessage(this.content);
}

class ResponseMessage extends OsiaMessage {
  final String content;
  const ResponseMessage(this.content);
}

class AudioMessage extends OsiaMessage {
  /// Base64-encoded MP3 data.
  final String data;
  const AudioMessage(this.data);
}

class StatusMessage extends OsiaMessage {
  /// One of: "thinking", "done", "error".
  final String content;
  const StatusMessage(this.content);
}

// ── WebSocket service ─────────────────────────────────────────────────────

/// Manages the WebSocket connection to the OSIA PC server.
///
/// Usage:
/// ```dart
/// final ws = WebSocketService(ip: '100.x.y.z', token: 'abc123');
/// ws.messageStream.listen((msg) { ... });
/// ws.connectionStream.listen((state) { ... });
/// ws.connect();
/// ws.sendText('Bonjour');
/// ws.sendAudio(base64Wav);
/// ```
class WebSocketService {
  final String ip;
  final String token;

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _intentionalClose = false;

  static const int _baseReconnectMs = 500;

  // ── Streams ───────────────────────────────────────────────────────────

  final StreamController<ConnectionState> _connectionCtrl =
      StreamController<ConnectionState>.broadcast();

  final StreamController<OsiaMessage> _messageCtrl =
      StreamController<OsiaMessage>.broadcast();

  /// Stream of connection state changes.
  Stream<ConnectionState> get connectionStream => _connectionCtrl.stream;

  /// Stream of parsed incoming messages.
  Stream<OsiaMessage> get messageStream => _messageCtrl.stream;

  /// Current connection state.
  ConnectionState _state = ConnectionState.disconnected;
  ConnectionState get state => _state;

  // ── Constructor ──────────────────────────────────────────────────────

  WebSocketService({required this.ip, required this.token});

  // ── Public API ───────────────────────────────────────────────────────

  /// Open the WebSocket connection. Safe to call multiple times.
  void connect() {
    if (_state == ConnectionState.connecting ||
        _state == ConnectionState.connected) {
      return;
    }
    _intentionalClose = false;
    _doConnect();
  }

  /// Close the connection and stop reconnection attempts.
  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _channel?.sink.close();
    _channel = null;
    _setState(ConnectionState.disconnected);
  }

  /// Send a text command.
  void sendText(String content) {
    _send({'type': 'text', 'content': content});
  }

  /// Send a base64-encoded WAV audio command.
  void sendAudio(String base64Data) {
    _send({'type': 'audio', 'format': 'wav', 'data': base64Data});
  }

  /// Free all resources.
  void dispose() {
    disconnect();
    _connectionCtrl.close();
    _messageCtrl.close();
  }

  // ── Internals ────────────────────────────────────────────────────────

  void _setState(ConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _connectionCtrl.add(newState);
  }

  void _send(Map<String, dynamic> json) {
    final encoded = jsonEncode(json);
    try {
      _channel?.sink.add(encoded);
    } catch (e) {
      debugPrint('[OSIA WS] Send error: $e');
    }
  }

  void _doConnect() {
    _setState(ConnectionState.connecting);

    final uri = Uri.parse('ws://$ip:8765/ws');
    debugPrint('[OSIA WS] Connecting to $uri...');

    try {
      _channel = IOWebSocketChannel.connect(uri);

      // Auth is the first message
      _send({'type': 'auth', 'token': token});

      // Listen to incoming messages
      _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[OSIA WS] Connection failed: $e');
      _setState(ConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      final Map<String, dynamic> json =
          (raw is String) ? jsonDecode(raw) as Map<String, dynamic> : raw;

      final type = json['type'] as String?;
      final content = json['content'] as String?;
      final data = json['data'] as String?;

      switch (type) {
        case 'transcript':
          if (content != null) {
            _messageCtrl.add(TranscriptMessage(content));
          }
        case 'response':
          if (content != null) {
            _messageCtrl.add(ResponseMessage(content));
          }
        case 'audio':
          if (data != null) {
            _messageCtrl.add(AudioMessage(data));
          }
        case 'status':
          if (content != null) {
            _messageCtrl.add(StatusMessage(content));
            // On the first "done" after auth, we are fully connected
            if (_state == ConnectionState.connecting && content == 'done') {
              _setState(ConnectionState.connected);
              _reconnectAttempt = 0; // reset backoff
            }
          }
      }
    } catch (e) {
      debugPrint('[OSIA WS] Parse error: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('[OSIA WS] Error: $error');
    // The onDone callback will fire after this; schedule reconnect there.
  }

  void _onDone() {
    debugPrint('[OSIA WS] Connection closed.');
    _channel = null;
    _setState(ConnectionState.disconnected);
    if (!_intentionalClose) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    final delayMs =
        _baseReconnectMs * pow(2, min(_reconnectAttempt, 6)).toInt();
    _reconnectAttempt++;
    debugPrint(
        '[OSIA WS] Reconnecting in ${delayMs}ms (attempt $_reconnectAttempt)...');

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_intentionalClose) {
        _doConnect();
      }
    });
  }
}
