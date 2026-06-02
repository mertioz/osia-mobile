import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
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

/// One incremental sentence/chunk of the assistant's reply. Many of
/// these arrive before the final assembled [ResponseMessage].
class ResponseChunkMessage extends OsiaMessage {
  final String content;
  const ResponseChunkMessage(this.content);
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

/// A single conversation entry as sent by the server.
class Conversation {
  final String id;
  final String title;
  final DateTime? date;

  const Conversation({
    required this.id,
    required this.title,
    this.date,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] ?? json['updated_at'] ?? json['created_at'];
    DateTime? parsed;
    if (rawDate is String) {
      parsed = DateTime.tryParse(rawDate);
    } else if (rawDate is int) {
      // Unix timestamp — accept seconds or milliseconds.
      parsed = rawDate > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(rawDate)
          : DateTime.fromMillisecondsSinceEpoch(rawDate * 1000);
    }
    return Conversation(
      id: (json['id'] ?? '').toString(),
      // Untitled conversations keep an empty title here; the UI shows a
      // localized "Untitled" label instead.
      title: (json['title'] ?? '').toString(),
      date: parsed,
    );
  }
}

/// Full list of conversations sent by the server (typically after auth).
class ConversationsMessage extends OsiaMessage {
  final List<Conversation> conversations;
  const ConversationsMessage(this.conversations);
}

/// The currently active conversation on the server.
class ActiveConversationMessage extends OsiaMessage {
  final String? id;
  final String? title;
  const ActiveConversationMessage({this.id, this.title});
}

/// A single past message in a conversation history.
class HistoryMessage {
  /// "user" or "assistant".
  final String role;
  final String content;
  const HistoryMessage({required this.role, required this.content});

  factory HistoryMessage.fromJson(Map<String, dynamic> json) {
    final raw = json['content'];
    String text;
    if (raw is String) {
      text = raw;
    } else if (raw is List) {
      // OpenAI-style content parts: pick text parts only.
      text = raw
          .whereType<Map>()
          .map((p) => p['text'] ?? p['content'] ?? '')
          .join();
    } else {
      text = raw?.toString() ?? '';
    }
    return HistoryMessage(
      role: (json['role'] ?? '').toString(),
      content: text,
    );
  }
}

/// Full message history for a freshly loaded conversation.
class ConversationHistoryMessage extends OsiaMessage {
  final String? id;
  final List<HistoryMessage> messages;
  const ConversationHistoryMessage({this.id, required this.messages});
}

/// One available model exposed by the server.
class OsiaModel {
  final String id;
  final String label;
  final String? description;
  final String? provider;

  const OsiaModel({
    required this.id,
    required this.label,
    this.description,
    this.provider,
  });

  factory OsiaModel.fromJson(dynamic raw) {
    if (raw is String) {
      return OsiaModel(id: raw, label: raw);
    }
    if (raw is Map) {
      final m = raw.cast<String, dynamic>();
      final id = (m['id'] ?? m['name'] ?? m['model'] ?? '').toString();
      final label =
          (m['label'] ?? m['name'] ?? m['id'] ?? m['model'] ?? id).toString();
      final desc = m['description']?.toString();
      final provider = m['provider']?.toString();
      return OsiaModel(
          id: id, label: label, description: desc, provider: provider);
    }
    final s = raw?.toString() ?? '';
    return OsiaModel(id: s, label: s);
  }
}

/// Full list of available models sent by the server in response to
/// `{"type":"get_models"}`.
class ModelsListMessage extends OsiaMessage {
  final List<OsiaModel> models;
  final String? current;
  const ModelsListMessage({required this.models, this.current});
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
  static const Duration _connectTimeout = Duration(seconds: 10);

  // ── Streams ───────────────────────────────────────────────────────────

  final StreamController<ConnectionState> _connectionCtrl =
      StreamController<ConnectionState>.broadcast();

  final StreamController<OsiaMessage> _messageCtrl =
      StreamController<OsiaMessage>.broadcast();

  final StreamController<String> _errorCtrl =
      StreamController<String>.broadcast();

  /// Stream of connection state changes.
  Stream<ConnectionState> get connectionStream => _connectionCtrl.stream;

  /// Stream of parsed incoming messages.
  Stream<OsiaMessage> get messageStream => _messageCtrl.stream;

  /// Stream of human-readable connection error messages, for UI surfacing.
  Stream<String> get errorStream => _errorCtrl.stream;

  /// Current connection state.
  ConnectionState _state = ConnectionState.disconnected;
  ConnectionState get state => _state;

  // ── Chunk pacing ─────────────────────────────────────────────────────
  //
  // Streamed `response_chunk` frames can arrive in bursts (the server
  // pushes whole sentences as soon as they're ready). To make streaming
  // feel smooth and real-time rather than batchy, every parsed message
  // flows through an ordered queue: chunks are emitted at most one per
  // [_chunkInterval], and all other message types keep their position in
  // the stream so ordering invariants (chunks → response → status done)
  // are preserved.

  /// Minimum delay between two emitted response chunks.
  static const Duration _chunkInterval = Duration(milliseconds: 30);

  final Queue<OsiaMessage> _outQueue = Queue<OsiaMessage>();
  Timer? _drainTimer;
  bool _drainPaused = false;

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

  /// Ask the server to load a specific conversation.
  void sendLoadConversation(String id) {
    _send({'type': 'load_conversation', 'id': id});
  }

  /// Ask the server to start a new conversation.
  void sendNewConversation() {
    _send({'type': 'new_conversation'});
  }

  /// Ask the server to delete a conversation.
  void sendDeleteConversation(String id) {
    _send({'type': 'delete_conversation', 'id': id});
  }

  /// Ask the server for the list of available models.
  void sendGetModels() {
    _send({'type': 'get_models'});
  }

  /// Tell the server to switch to [model] for subsequent generations.
  void sendSetModel(String model) {
    _send({'type': 'set_model', 'model': model});
  }

  /// Ask the server to restart itself. The socket will drop shortly after;
  /// the built-in reconnection loop then brings the connection back up
  /// once the server is reachable again.
  void sendRestartServer() {
    _send({'type': 'restart_server'});
  }

  /// Upload a file as base64 bytes. The server saves it to disk and
  /// injects its path into the next user turn. When [isImage] is true,
  /// the same base64 payload is repeated under `image_base64` so the
  /// server can hand it straight to a vision model without re-reading
  /// the file from disk.
  void sendFile(String filename, String base64Data, {bool isImage = false}) {
    final msg = <String, dynamic>{
      'type': 'file',
      'filename': filename,
      'data': base64Data,
      'is_image': isImage,
    };
    if (isImage) {
      msg['image_base64'] = base64Data;
    }
    _send(msg);
  }

  /// Free all resources.
  void dispose() {
    disconnect();
    _drainTimer?.cancel();
    _drainTimer = null;
    _outQueue.clear();
    _connectionCtrl.close();
    _messageCtrl.close();
    _errorCtrl.close();
  }

  /// Strip any scheme, path, or port the user may have pasted into the
  /// settings field so we can build a clean `ws://host:8765/ws` URL.
  static String _sanitizeHost(String raw) {
    var s = raw.trim();
    s = s.replaceFirst(
        RegExp(r'^(wss?|https?)://', caseSensitive: false), '');
    final slash = s.indexOf('/');
    if (slash != -1) s = s.substring(0, slash);
    final colon = s.indexOf(':');
    if (colon != -1) s = s.substring(0, colon);
    return s;
  }

  // ── Internals ────────────────────────────────────────────────────────

  void _setState(ConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _connectionCtrl.add(newState);
  }

  /// Enqueue a parsed message for ordered, paced delivery to listeners.
  void _emit(OsiaMessage msg) {
    _outQueue.add(msg);
    _drainQueue();
  }

  /// Drain the output queue. Non-chunk messages are delivered immediately
  /// (in order); after each [ResponseChunkMessage] the drain pauses for
  /// [_chunkInterval] so the UI renders chunks smoothly instead of in
  /// batches.
  void _drainQueue() {
    if (_drainPaused) return;
    while (_outQueue.isNotEmpty) {
      if (_messageCtrl.isClosed) {
        _outQueue.clear();
        return;
      }
      final msg = _outQueue.removeFirst();
      _messageCtrl.add(msg);
      if (msg is ResponseChunkMessage) {
        _drainPaused = true;
        _drainTimer = Timer(_chunkInterval, () {
          _drainPaused = false;
          _drainQueue();
        });
        return;
      }
    }
  }

  void _send(Map<String, dynamic> json) {
    final encoded = jsonEncode(json);
    try {
      _channel?.sink.add(encoded);
    } catch (e) {
      debugPrint('[OSIA WS] Send error: $e');
    }
  }

  Future<void> _doConnect() async {
    _setState(ConnectionState.connecting);

    final host = _sanitizeHost(ip);
    // A Cloudflare Tunnel hostname is fronted by HTTPS on 443, so use wss://
    // with no explicit port. A raw IP (Tailscale) still goes to the local
    // server on port 8765 over plain ws://.
    final isDomain = RegExp(r'[a-zA-Z]').hasMatch(host);
    final url = isDomain ? 'wss://$host/ws' : 'ws://$host:8765/ws';
    debugPrint('[OSIA WS] Connecting to $url (timeout ${_connectTimeout.inSeconds}s)');

    try {
      final socket = await WebSocket.connect(url).timeout(_connectTimeout);

      // Socket is open — we're connected. Don't wait for any server message
      // to flip state, or the badge stays on "Connexion…" forever.
      _channel = IOWebSocketChannel(socket);
      _setState(ConnectionState.connected);
      _reconnectAttempt = 0;
      debugPrint('[OSIA WS] Socket open, sending auth (token length ${token.length})');

      // Auth is the first message after the socket opens.
      _send({'type': 'auth', 'token': token});

      _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } on TimeoutException {
      final msg = 'Connexion expirée après ${_connectTimeout.inSeconds}s ($url)';
      debugPrint('[OSIA WS] $msg');
      _errorCtrl.add(msg);
      _setState(ConnectionState.disconnected);
      _scheduleReconnect();
    } on SocketException catch (e) {
      final msg = 'Réseau injoignable: ${e.message} ($url)';
      debugPrint('[OSIA WS] $msg');
      _errorCtrl.add(msg);
      _setState(ConnectionState.disconnected);
      _scheduleReconnect();
    } on WebSocketException catch (e) {
      final msg = 'WebSocket refusé: ${e.message} ($url)';
      debugPrint('[OSIA WS] $msg');
      _errorCtrl.add(msg);
      _setState(ConnectionState.disconnected);
      _scheduleReconnect();
    } catch (e) {
      final msg = 'Échec de connexion: $e ($url)';
      debugPrint('[OSIA WS] $msg');
      _errorCtrl.add(msg);
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
            _emit(TranscriptMessage(content));
          }
        case 'response':
          if (content != null) {
            _emit(ResponseMessage(content));
          }
        case 'response_chunk':
          if (content != null && content.isNotEmpty) {
            _emit(ResponseChunkMessage(content));
          }
        case 'audio':
          if (data != null) {
            _emit(AudioMessage(data));
          }
        case 'status':
          if (content != null) {
            _emit(StatusMessage(content));
          }
        case 'conversations':
          final raw = json['items'] ?? json['conversations'];
          if (raw is List) {
            final list = raw
                .whereType<Map>()
                .map((e) =>
                    Conversation.fromJson(e.cast<String, dynamic>()))
                .toList();
            debugPrint(
                '[OSIA WS] conversations received: ${list.length} item(s)');
            if (list.isNotEmpty) {
              debugPrint(
                  '[OSIA WS]   first: id=${list.first.id} title="${list.first.title}" date=${list.first.date}');
            }
            _emit(ConversationsMessage(list));
          } else {
            debugPrint(
                '[OSIA WS] conversations message had no list payload: keys=${json.keys.toList()}');
          }
        case 'active_conversation':
          final id = json['id']?.toString();
          final title = json['title']?.toString();
          debugPrint(
              '[OSIA WS] active_conversation: id=$id title="$title"');
          _emit(ActiveConversationMessage(id: id, title: title));
        case 'models_list':
          final rawModels = json['models'] ?? json['items'];
          final list = rawModels is List
              ? rawModels.map(OsiaModel.fromJson).toList()
              : <OsiaModel>[];
          final current =
              (json['current'] ?? json['selected'])?.toString();
          debugPrint(
              '[OSIA WS] models_list: ${list.length} model(s), current=$current');
          _emit(ModelsListMessage(models: list, current: current));
        case 'conversation_history':
          final raw = json['messages'];
          final list = raw is List
              ? raw
                  .whereType<Map>()
                  .map((m) =>
                      HistoryMessage.fromJson(m.cast<String, dynamic>()))
                  .toList()
              : <HistoryMessage>[];
          debugPrint(
              '[OSIA WS] conversation_history: ${list.length} message(s) for id=${json['id']}');
          _emit(ConversationHistoryMessage(
            id: json['id']?.toString(),
            messages: list,
          ));
        default:
          debugPrint(
              '[OSIA WS] unhandled message type="$type" keys=${json.keys.toList()}');
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
