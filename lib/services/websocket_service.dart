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

  /// Why the server sent this audio: 'response' for a reply's auto-TTS,
  /// 'speak' for an explicit read-aloud request. Null when the server
  /// doesn't tag its audio frames (older server versions).
  final String? source;
  const AudioMessage(this.data, {this.source});
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

// ── Full config snapshot (mirror of the PC settings) ──────────────────────
//
// `ConfigData` and `ConfigSkill` are deliberately NOT part of the sealed
// [OsiaMessage] hierarchy: chat_screen.dart switches over OsiaMessage
// exhaustively (no default), so introducing a new sealed subtype would break
// its compile. Config is instead delivered on its own [configStream], which
// keeps the streaming/message path used by the chat screen untouched.

/// One skill file as reported by the server (`~/.osia/skills/<name>.md`).
class ConfigSkill {
  /// Filename including the `.md` suffix, e.g. `weather.md`.
  final String name;
  final bool enabled;

  /// The Markdown prose of the skill.
  final String text;

  const ConfigSkill({
    required this.name,
    required this.enabled,
    required this.text,
  });

  factory ConfigSkill.fromJson(Map<String, dynamic> json) => ConfigSkill(
        name: (json['name'] ?? '').toString(),
        enabled: json['enabled'] == true,
        text: (json['text'] ?? '').toString(),
      );
}

/// The full configuration snapshot sent by the server in response to
/// `{"type":"get_config"}` as `{"type":"config","config":{...}}`.
///
/// Mirrors the PC's settings. Note the server never ships raw API keys — it
/// exposes only [apiKeysSet] (which providers have a key configured). The two
/// AI-hierarchy fallback chains arrive under their flat names
/// (`heavy_chain` / `medium_chain`) as ordered `"provider:model"` strings.
class ConfigData {
  /// `{provider: hasKey}` — which providers currently have a key on the PC.
  final Map<String, bool> apiKeysSet;

  /// Scheduled tasks. Each entry keeps its raw shape
  /// (`{task, schedule, enabled, conversation_id?}`) so it round-trips
  /// losslessly when written back via `set_setting cron_jobs`.
  final List<Map<String, dynamic>> cronJobs;

  /// Ordered `"provider:model"` fallback chain for heavy tasks.
  final List<String> heavyChain;

  /// Ordered `"provider:model"` fallback chain for medium tasks.
  final List<String> mediumChain;

  /// Master switch for the AI task hierarchy.
  final bool aiHierarchyEnabled;

  /// The personality document (`~/.osia/personality.md`).
  final String personality;

  /// All skill files, in server order.
  final List<ConfigSkill> skills;

  /// Raw mirror of the PC's `settings.json` values, for pre-filling toggles
  /// that have no dedicated typed field above (e.g. `time_format`,
  /// `heartbeat_enabled`, `heartbeat_interval_seconds`). The server may nest
  /// these under a `settings` key or inline them at the config top level — we
  /// accept either. Values keep their JSON types (bool / int / String).
  final Map<String, dynamic> settings;

  const ConfigData({
    required this.apiKeysSet,
    required this.cronJobs,
    required this.heavyChain,
    required this.mediumChain,
    required this.aiHierarchyEnabled,
    required this.personality,
    required this.skills,
    required this.settings,
  });

  factory ConfigData.fromJson(Map<String, dynamic> config) {
    Map<String, bool> readKeysSet(dynamic raw) {
      final out = <String, bool>{};
      if (raw is Map) {
        raw.forEach((k, v) => out[k.toString()] = v == true);
      }
      return out;
    }

    List<String> readChain(dynamic raw) => raw is List
        ? raw.whereType<String>().where((s) => s.isNotEmpty).toList()
        : <String>[];

    List<Map<String, dynamic>> readJobs(dynamic raw) => raw is List
        ? raw
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList()
        : <Map<String, dynamic>>[];

    List<ConfigSkill> readSkills(dynamic raw) => raw is List
        ? raw
            .whereType<Map>()
            .map((e) => ConfigSkill.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <ConfigSkill>[];

    Map<String, dynamic> readSettings(Map<String, dynamic> cfg) {
      final nested = cfg['settings'];
      if (nested is Map) return nested.cast<String, dynamic>();
      // Server inlines settings at the config top level — expose the whole
      // snapshot so individual keys (time_format, heartbeat_*) stay reachable.
      return Map<String, dynamic>.from(cfg);
    }

    return ConfigData(
      apiKeysSet: readKeysSet(config['api_keys_set']),
      cronJobs: readJobs(config['cron_jobs']),
      heavyChain: readChain(config['heavy_chain']),
      mediumChain: readChain(config['medium_chain']),
      aiHierarchyEnabled: config['ai_hierarchy_enabled'] == true,
      personality: (config['personality'] ?? '').toString(),
      skills: readSkills(config['skills']),
      settings: readSettings(config),
    );
  }
}

// ── API keys & heartbeat (own streams, like config) ──────────────────────
//
// Like [ConfigData], [ApiKeysMessage] and [HeartbeatDataMessage] are
// deliberately NOT part of the sealed [OsiaMessage] hierarchy. chat_screen.dart
// switches over OsiaMessage exhaustively with no `default`, so adding a sealed
// subtype would break its compile (and CLAUDE.md forbids touching it). Each
// rides its own dedicated stream instead, exactly like config.

/// Raw API keys per provider, sent by the PC in reply to
/// `{"type":"get_api_keys"}` as `{"type":"api_keys","keys":{provider:key}}`.
///
/// Unlike `ConfigData.apiKeysSet` (booleans only), this carries the actual key
/// strings so an editor can pre-fill its field. Delivered on
/// [WebSocketService.apiKeysStream].
class ApiKeysMessage {
  /// `{provider: key}` — the real keys currently stored on the PC.
  final Map<String, String> keys;
  const ApiKeysMessage(this.keys);

  factory ApiKeysMessage.fromJson(Map<String, dynamic> json) {
    final out = <String, String>{};
    final raw = json['keys'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v != null) out[k.toString()] = v.toString();
      });
    }
    return ApiKeysMessage(out);
  }
}

/// One live system-metrics push from the PC, sent as
/// `{"type":"heartbeat_data", ...}` while heartbeat monitoring is enabled.
///
/// Delivered on [WebSocketService.heartbeatStream]. Every metric is nullable —
/// CPU/RAM/disk are percentages (0–100); temperatures are in °C and only
/// present when the PC can read them.
class HeartbeatDataMessage {
  final double? cpuPercent;
  final double? ramPercent;
  final double? diskPercent;
  final double? cpuTemp;
  final double? gpuTemp;
  const HeartbeatDataMessage({
    this.cpuPercent,
    this.ramPercent,
    this.diskPercent,
    this.cpuTemp,
    this.gpuTemp,
  });

  factory HeartbeatDataMessage.fromJson(Map<String, dynamic> json) {
    // Read the first present alias and coerce to double, accepting numbers or
    // numeric strings. Returns null when none of the aliases are present.
    double? pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is num) return v.toDouble();
        if (v is String) {
          final parsed = double.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    return HeartbeatDataMessage(
      cpuPercent: pick(['cpu_percent', 'cpu', 'cpu_pct']),
      ramPercent: pick(
          ['ram_percent', 'ram', 'memory_percent', 'mem_percent', 'memory']),
      diskPercent: pick(['disk_percent', 'disk', 'disk_pct']),
      cpuTemp: pick(['cpu_temp', 'cpu_temp_c', 'cpu_temperature']),
      gpuTemp: pick(['gpu_temp', 'gpu_temp_c', 'gpu_temperature']),
    );
  }
}

/// A "start a new chat" signal pushed by the PC as `{"type":"new_chat"}`
/// (WOR-10). Like [ConfigData], [ApiKeysMessage] and [HeartbeatDataMessage],
/// this is deliberately NOT part of the sealed [OsiaMessage] hierarchy:
/// chat_screen.dart switches over OsiaMessage exhaustively with no `default`,
/// so adding a sealed subtype would break its compile (and CLAUDE.md forbids
/// touching that path). It rides its own [WebSocketService.newChatStream]
/// instead, exactly like config/api_keys/heartbeat.
///
/// The frame carries no payload today; the class exists so the stream has a
/// typed event.
class NewChatMessage {
  const NewChatMessage();
}

/// One conversation entry (id + title) for the cron editor's "linked
/// conversation" picker (WOR-24). Carries only what the picker needs — distinct
/// from the richer [Conversation] used by the chat sidebar.
class ConversationItem {
  final String id;
  final String title;
  const ConversationItem(this.id, this.title);

  factory ConversationItem.fromJson(Map<String, dynamic> json) =>
      ConversationItem(
        (json['id'] ?? '').toString(),
        (json['title'] ?? '').toString(),
      );
}

/// Compact id+title conversation list sent by the PC in reply to
/// `{"type":"get_conversations"}` as
/// `{"type":"conversations_list","conversations":[{id,title}, ...]}` (WOR-24).
///
/// Like [ConfigData], [ApiKeysMessage], [HeartbeatDataMessage] and
/// [NewChatMessage], this is deliberately NOT part of the sealed [OsiaMessage]
/// hierarchy: chat_screen.dart switches over OsiaMessage exhaustively with no
/// `default`, so adding a sealed subtype would break its compile (and CLAUDE.md
/// forbids touching that path). It rides its own
/// [WebSocketService.conversationsListStream] instead.
class ConversationsListMessage {
  final List<ConversationItem> conversations;
  const ConversationsListMessage(this.conversations);
}

/// One `autonomous_progress` frame broadcast by the PC while an autonomous run
/// is active (WOR-45 Phase 5). Like [ConfigData], [ApiKeysMessage],
/// [HeartbeatDataMessage], [NewChatMessage] and [ConversationsListMessage],
/// this is deliberately NOT part of the sealed [OsiaMessage] hierarchy:
/// chat_screen.dart switches over OsiaMessage exhaustively with no `default`,
/// so adding a sealed subtype would break its compile (and CLAUDE.md forbids
/// touching that path). It rides its own [WebSocketService.autonomousStream]
/// instead, exactly like config/api_keys/heartbeat/new_chat/conversations_list.
///
/// [event] is the lifecycle marker the UI keys off
/// (e.g. `planning`, `phase`, `progress`, `done`, `failed`, `aborted`,
/// `interrupted`, `idle`, `busy`). Every other field is optional and only
/// present on the frames that carry it.
class AutonomousProgressMessage {
  /// Lifecycle marker for this frame (planning / phase / progress / done /
  /// failed / aborted / interrupted / idle / busy …).
  final String? event;

  /// Human-readable name of the current phase, when the run reports phases.
  final String? phaseName;

  /// Completed / total task counts for the live "X / Y" progress line.
  final int? tasksDone;
  final int? tasksTotal;

  /// Free-form status line describing the active step.
  final String? status;

  /// The objective the run is working on, echoed back so a client that
  /// reconnects mid-run can render it without local state.
  final String? objective;

  /// Server-side id of the run / current task, when provided.
  final String? taskId;

  /// Why the run ended or paused (carried on terminal / interrupt frames).
  final String? reason;

  const AutonomousProgressMessage({
    this.event,
    this.phaseName,
    this.tasksDone,
    this.tasksTotal,
    this.status,
    this.objective,
    this.taskId,
    this.reason,
  });

  factory AutonomousProgressMessage.fromJson(Map<String, dynamic> json) {
    // Read the first present alias as a non-empty string, or null when none of
    // the aliases carry a value. (Tolerates snake_case / camelCase server keys.)
    String? pickStr(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null) {
          final s = v.toString();
          if (s.isNotEmpty) return s;
        }
      }
      return null;
    }

    // Read the first present alias as an int, accepting numbers or numeric
    // strings; null when absent / unparseable.
    int? pickInt(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is num) return v.toInt();
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    return AutonomousProgressMessage(
      event: pickStr(['event']),
      phaseName: pickStr(['phase_name', 'phaseName', 'phase']),
      tasksDone: pickInt(['tasks_done', 'tasksDone']),
      tasksTotal: pickInt(['tasks_total', 'tasksTotal']),
      status: pickStr(['status', 'message']),
      objective: pickStr(['objective']),
      taskId: pickStr(['task_id', 'taskId']),
      reason: pickStr(['reason']),
    );
  }
}

/// One streamed-response event for a single conversation (WOR-53). Like
/// [AutonomousProgressMessage] and the other standalone stream messages
/// (`ConfigData`, `ApiKeysMessage`, `HeartbeatDataMessage`, `NewChatMessage`,
/// `ConversationsListMessage`), this is deliberately NOT part of the sealed
/// [OsiaMessage] hierarchy: chat_screen.dart switches over OsiaMessage
/// exhaustively with no `default`, so adding a sealed subtype would break its
/// compile (and CLAUDE.md forbids touching that path). It rides its own
/// [WebSocketService.convStreamStream], exactly like the others.
///
/// Carries the [conversationId] the frame belongs to (the server tags
/// `response_chunk` / `response` / `status` frames with `conversation_id`) so a
/// client viewing one conversation can let another conversation's reply keep
/// streaming in the background and render it on return. [delta] is the text
/// just accrued into that conversation's buffer (null on the terminal frame);
/// [done] / [error] mark the turn's end (status `done` / `error`).
class ConvStreamEvent {
  final String conversationId;
  final String? delta;
  final bool done;
  final bool error;
  const ConvStreamEvent(
    this.conversationId, {
    this.delta,
    this.done = false,
    this.error = false,
  });
}

/// Per-conversation accumulation of a streamed reply (WOR-53). Holds the text
/// streamed so far for one conversation plus whether its turn is still live, so
/// a backgrounded conversation's reply survives a screen switch and can be
/// hydrated on return (see [WebSocketService.bufferedText] / [isStreaming]).
class _ConvStreamState {
  final StringBuffer text = StringBuffer();
  bool streaming = false;
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

  /// Whether the service silently reconnects after an unexpected close.
  ///
  /// The chat screen wants this (a flaky network shouldn't kill the
  /// session). The connection screen's token *probe* sets it to `false`:
  /// there, a server-initiated close is the definitive "token rejected"
  /// signal and must surface immediately instead of being masked by an
  /// endless connect/close/reconnect loop.
  final bool autoReconnect;

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

  final StreamController<ConfigData> _configCtrl =
      StreamController<ConfigData>.broadcast();

  final StreamController<ApiKeysMessage> _apiKeysCtrl =
      StreamController<ApiKeysMessage>.broadcast();

  final StreamController<HeartbeatDataMessage> _heartbeatCtrl =
      StreamController<HeartbeatDataMessage>.broadcast();

  final StreamController<NewChatMessage> _newChatCtrl =
      StreamController<NewChatMessage>.broadcast();

  final StreamController<ConversationsListMessage> _conversationsListCtrl =
      StreamController<ConversationsListMessage>.broadcast();

  final StreamController<AutonomousProgressMessage> _autonomousCtrl =
      StreamController<AutonomousProgressMessage>.broadcast();

  // ── Per-conversation stream buffers (WOR-53) ──────────────────────────
  //
  // A parallel sink to the paced [messageStream]: every streamed
  // `response_chunk` / `response` / terminal `status` frame is ALSO accrued
  // here, keyed by conversation id, and broadcast on [convStreamStream]. This
  // lets a conversation's reply keep streaming in the background while the
  // user views another conversation — its tokens land in [_streamBuffers] and
  // hydrate on return. Entirely additive: it does not touch the paced queue,
  // the reconnect logic, or the sealed message path.

  /// Streamed-reply buffers keyed by conversation id. Reset at the start of
  /// each turn (so replies don't accrete across turns), removed on
  /// delete/new (see [clearConvBuffer]), capped at [_maxConvBuffers] (a
  /// backstop that evicts the oldest FINISHED buffer — never a live stream),
  /// and dropped wholesale when the service is disposed — so the map can't
  /// grow unbounded.
  final Map<String, _ConvStreamState> _streamBuffers = {};

  /// Hard cap on retained per-conversation buffers (WOR-53) — a backstop for
  /// buffers the user never explicitly leaves or deletes (e.g. a server-streamed
  /// id absent from the local list). Live streams are never evicted.
  static const int _maxConvBuffers = 32;

  final StreamController<ConvStreamEvent> _convStreamCtrl =
      StreamController<ConvStreamEvent>.broadcast();

  /// Stream of connection state changes.
  Stream<ConnectionState> get connectionStream => _connectionCtrl.stream;

  /// Stream of parsed incoming messages.
  Stream<OsiaMessage> get messageStream => _messageCtrl.stream;

  /// Stream of human-readable connection error messages, for UI surfacing.
  Stream<String> get errorStream => _errorCtrl.stream;

  /// Stream of full config snapshots (one per `get_config` reply). Kept off
  /// [messageStream] so the chat screen's sealed-message switch is untouched.
  Stream<ConfigData> get configStream => _configCtrl.stream;

  /// Stream of raw API-key snapshots (one per `get_api_keys` reply). Kept off
  /// [messageStream] for the same reason as [configStream].
  Stream<ApiKeysMessage> get apiKeysStream => _apiKeysCtrl.stream;

  /// Stream of live system-metrics pushes (`heartbeat_data`). Kept off
  /// [messageStream] for the same reason as [configStream].
  Stream<HeartbeatDataMessage> get heartbeatStream => _heartbeatCtrl.stream;

  /// Stream of "new chat" signals (`new_chat`, WOR-10). Kept off
  /// [messageStream] for the same reason as [configStream].
  Stream<NewChatMessage> get newChatStream => _newChatCtrl.stream;

  /// Stream of compact conversation lists (`conversations_list`, WOR-24). Kept
  /// off [messageStream] for the same reason as [configStream].
  Stream<ConversationsListMessage> get conversationsListStream =>
      _conversationsListCtrl.stream;

  /// Stream of autonomous-run progress frames (`autonomous_progress`, WOR-45
  /// Phase 5). Kept off [messageStream] for the same reason as [configStream].
  Stream<AutonomousProgressMessage> get autonomousStream =>
      _autonomousCtrl.stream;

  /// Stream of per-conversation streamed-reply events (`response_chunk` /
  /// `response` / terminal `status`, WOR-53). Kept off [messageStream] for the
  /// same reason as [configStream]; carries the conversation id so a client can
  /// route a backgrounded stream to the right conversation.
  Stream<ConvStreamEvent> get convStreamStream => _convStreamCtrl.stream;

  /// The reply text streamed so far for conversation [id] (WOR-53), for
  /// hydrating the chat when switching to a conversation whose reply streamed
  /// while it was backgrounded. Empty when nothing has streamed for [id].
  String bufferedText(String id) => _streamBuffers[id]?.text.toString() ?? '';

  /// Whether conversation [id]'s reply is still streaming (WOR-53) — i.e. its
  /// turn hasn't hit a terminal `status` (`done` / `error`) yet. Drives
  /// restoring the streaming bubble on switch.
  bool isStreaming(String id) => _streamBuffers[id]?.streaming ?? false;

  /// Drop conversation [id]'s streamed-reply buffer (WOR-53). Called when a
  /// conversation is deleted or the chat is reset to a new conversation, so the
  /// buffer map can't grow unbounded. Never closes [convStreamStream] — that
  /// happens only in [dispose].
  void clearConvBuffer(String id) {
    _streamBuffers.remove(id);
  }

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

  /// Optional async host resolver (WOR-64 token→URL rendezvous). When provided
  /// it is invoked on every connect AND reconnect to obtain the server host
  /// fresh — so a PC restart that rotates its tunnel URL is picked up — and its
  /// result is fed into the same [_sanitizeHost]/URL path as [ip]. When null,
  /// [ip] is used directly (the original behaviour). A failure of this callback
  /// (PC offline / network) is funnelled into the existing error stream and
  /// reconnect path, exactly like a socket-level failure.
  final Future<String> Function()? resolveHost;

  WebSocketService({
    required this.ip,
    required this.token,
    this.autoReconnect = true,
    this.resolveHost,
  });

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

  /// Send the WOR-10 "new chat" signal (`{"type":"new_chat"}`) to the server.
  void sendNewChat() {
    _send({'type': 'new_chat'});
  }

  /// Ask the server to delete a conversation.
  void sendDeleteConversation(String id) {
    _send({'type': 'delete_conversation', 'id': id});
    // WOR-53: the conversation is gone — drop any streamed-reply buffer for it.
    clearConvBuffer(id);
  }

  /// Ask the server for the list of available models.
  void sendGetModels() {
    _send({'type': 'get_models'});
  }

  /// Tell the server to switch to [model] for subsequent generations.
  void sendSetModel(String model) {
    _send({'type': 'set_model', 'model': model});
  }

  /// Ask the server to synthesize [text] over TTS and send the audio back
  /// (the speaker button under an assistant message). Works regardless of
  /// the auto-TTS preference.
  void sendSpeak(String text) {
    final preview = text.length > 50 ? '${text.substring(0, 50)}…' : text;
    debugPrint('[OSIA WS] sendSpeak: state=$_state, text="$preview"');
    _send({'type': 'speak', 'text': text});
  }

  /// Ask the server to restart itself. The socket will drop shortly after;
  /// the built-in reconnection loop then brings the connection back up
  /// once the server is reachable again.
  void sendRestartServer() {
    _send({'type': 'restart_server'});
  }

  /// Save (or clear) the API key for a provider on the PC. An empty [key]
  /// clears the stored key. The server persists it to its provider config.
  void sendSetApiKey(String provider, String key) {
    _send({'type': 'set_api_key', 'provider': provider, 'key': key});
  }

  /// Remove a provider's API key entirely from the PC's key store
  /// (`config/api_keys.json`) — the dedicated delete path, distinct from
  /// `sendSetApiKey(provider, '')`.
  void sendDeleteApiKey(String provider) {
    _send({'type': 'delete_api_key', 'provider': provider});
  }

  /// Set (or replace) a fallback API key for a provider — one slot in the
  /// ordered backup-key list the server keeps under `settings.json`
  /// `api_key_fallbacks[provider]` (the agent rotates through these when the
  /// primary key is rate-limited/exhausted). An [index] of -1 appends a new
  /// key; an in-range index replaces that slot. (WOR-29)
  void sendSetApiFallbackKey(String provider, int index, String key) {
    _send({
      'type': 'set_api_fallback_key',
      'provider': provider,
      'index': index,
      'key': key,
    });
  }

  /// Remove the fallback API key at [index] from a provider's backup-key list.
  /// The server drops the provider entry entirely once its last key is gone.
  /// (WOR-29)
  void sendDeleteApiFallbackKey(String provider, int index) {
    _send({
      'type': 'delete_api_fallback_key',
      'provider': provider,
      'index': index,
    });
  }

  /// Set a single whitelisted settings.json key/value pair on the PC
  /// (e.g. `liveapi_enabled`). [value] may be a bool, string, number, or a
  /// JSON-serializable list/map (e.g. `cron_jobs`, `heavy_chain`).
  void sendSetSetting(String key, Object? value) {
    _send({'type': 'set_setting', 'key': key, 'value': value});
  }

  /// Ask the PC for the full configuration snapshot. The reply arrives on
  /// [configStream] as a [ConfigData].
  void sendGetConfig() {
    _send({'type': 'get_config'});
  }

  /// Ask the PC for the raw API keys, to pre-fill the provider editors. The
  /// reply arrives on [apiKeysStream] as an [ApiKeysMessage].
  void sendGetApiKeys() {
    _send({'type': 'get_api_keys'});
  }

  /// Ask the PC for a compact id+title list of stored conversations, to fill
  /// the cron editor's "linked conversation" picker (WOR-24). The reply arrives
  /// on [conversationsListStream] as a [ConversationsListMessage].
  void sendGetConversations() {
    _send({'type': 'get_conversations'});
  }

  // ── Autonomous runs (WOR-45 Phase 5) ──
  //
  // The PC accepts these commands and broadcasts `autonomous_progress` frames
  // (surfaced on [autonomousStream]). Purely additive: they reuse the same
  // [_send] path as every other command and touch nothing on the chat /
  // streaming path.

  /// Start an autonomous run working toward [objective] using [model]
  /// (a configured `"provider:model"` / model id). Progress arrives on
  /// [autonomousStream].
  void sendAutonomousStart(String objective, String model) {
    _send({'type': 'autonomous_start', 'objective': objective, 'model': model});
  }

  /// Pause the current autonomous run (resumable — the server keeps its state).
  void sendAutonomousInterrupt() {
    _send({'type': 'autonomous_interrupt'});
  }

  /// Resume a paused autonomous run (the server continues from its kept state).
  void sendAutonomousResume() {
    _send({'type': 'autonomous_resume'});
  }

  /// Abandon the current autonomous run entirely (not resumable).
  void sendAutonomousAbort() {
    _send({'type': 'autonomous_abort'});
  }

  /// Ask the PC for the current autonomous-run status, so a client that
  /// reconnects mid-run can render live progress. The reply arrives on
  /// [autonomousStream] as an [AutonomousProgressMessage] (a snapshot of the
  /// active run, or an `event:"idle"` frame when nothing is running).
  void sendGetAutonomousStatus() {
    _send({'type': 'get_autonomous_status'});
  }

  /// Persist the personality document (`~/.osia/personality.md`) on the PC.
  void sendSetPersonality(String text) {
    _send({'type': 'set_personality', 'text': text});
  }

  /// Update an existing skill's prose and/or its enabled flag. Both are
  /// optional — pass only what changed (a lone toggle or a lone text edit).
  void sendSetSkill(String name, {String? text, bool? enabled}) {
    final msg = <String, dynamic>{'type': 'set_skill', 'name': name};
    if (text != null) msg['text'] = text;
    if (enabled != null) msg['enabled'] = enabled;
    _send(msg);
  }

  /// Create a new skill `<name>.md` from the template (starts enabled).
  void sendCreateSkill(String name) {
    _send({'type': 'create_skill', 'name': name});
  }

  /// Delete a skill and drop its enabled flag on the PC.
  void sendDeleteSkill(String name) {
    _send({'type': 'delete_skill', 'name': name});
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
    _configCtrl.close();
    _apiKeysCtrl.close();
    _heartbeatCtrl.close();
    _newChatCtrl.close();
    _conversationsListCtrl.close();
    _autonomousCtrl.close();
    _convStreamCtrl.close();
    _streamBuffers.clear();
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

  // ── Per-conversation stream buffering (WOR-53) ────────────────────────
  //
  // These run alongside (never instead of) the paced [_emit] above — they
  // accrue the same streamed text into [_streamBuffers] and broadcast on
  // [convStreamStream]. Nothing here touches the queue, its pacing, or the
  // reconnect path.

  /// Accrue a streamed [delta] into conversation [convId]'s buffer and
  /// broadcast a [ConvStreamEvent]. A new turn (buffer not currently
  /// streaming) starts fresh so replies don't accrete across turns. The
  /// space-aware joining mirrors the chat screen's chunk handling so hydrated
  /// text reads the same as live text.
  void _appendConvDelta(String? convId, String delta) {
    if (convId == null || convId.isEmpty || _convStreamCtrl.isClosed) return;
    final st = _streamBuffers.putIfAbsent(convId, () => _ConvStreamState());
    // First chunk of a fresh turn: drop the previous turn's text.
    if (!st.streaming) st.text.clear();
    final existing = st.text.toString();
    final needsSpace = existing.isNotEmpty &&
        !existing.endsWith(' ') &&
        !existing.endsWith('\n') &&
        !delta.startsWith(' ');
    if (needsSpace) st.text.write(' ');
    st.text.write(delta);
    st.streaming = true;
    _capConvBuffers();
    _convStreamCtrl.add(ConvStreamEvent(convId, delta: delta));
  }

  /// Replace conversation [convId]'s buffer with the canonical full reply
  /// [text] (the `response` frame) and broadcast it. Keeps the buffer's
  /// hydration text in sync with the assembled reply rather than the
  /// chunk-concatenation.
  void _replaceConvText(String? convId, String text) {
    if (convId == null || convId.isEmpty || _convStreamCtrl.isClosed) return;
    final st = _streamBuffers.putIfAbsent(convId, () => _ConvStreamState());
    st.text
      ..clear()
      ..write(text);
    st.streaming = true;
    _capConvBuffers();
    _convStreamCtrl.add(ConvStreamEvent(convId, delta: text));
  }

  /// Mark conversation [convId]'s turn finished (terminal `status`) and
  /// broadcast a terminal [ConvStreamEvent]. The buffered text is kept (for
  /// hydration on return) until the next turn resets it or [clearConvBuffer]
  /// drops it.
  void _finishConvStream(String? convId, {required bool error}) {
    if (convId == null || convId.isEmpty || _convStreamCtrl.isClosed) return;
    final st = _streamBuffers[convId];
    if (st != null) st.streaming = false;
    _convStreamCtrl.add(ConvStreamEvent(convId, done: !error, error: error));
  }

  /// Evict the oldest FINISHED buffer when the map exceeds [_maxConvBuffers].
  /// Never drops a buffer whose turn is still streaming, so the WOR-53
  /// background-stream guarantee holds. Called only after the just-touched
  /// buffer has been marked streaming, so it can never evict the live one.
  void _capConvBuffers() {
    if (_streamBuffers.length <= _maxConvBuffers) return;
    String? victim;
    // Insertion order (Dart's default Map) → the first non-streaming entry is
    // the oldest finished one.
    for (final entry in _streamBuffers.entries) {
      if (!entry.value.streaming) {
        victim = entry.key;
        break;
      }
    }
    if (victim != null) _streamBuffers.remove(victim);
  }

  void _send(Map<String, dynamic> json) {
    // Surface dropped sends loudly — a null channel means the socket is
    // down and the message silently goes nowhere otherwise.
    if (_channel == null) {
      debugPrint(
          '[OSIA WS] Send DROPPED (socket not connected): type=${json['type']}');
      return;
    }
    final encoded = jsonEncode(json);
    try {
      _channel?.sink.add(encoded);
    } catch (e) {
      debugPrint('[OSIA WS] Send error: $e');
    }
  }

  Future<void> _doConnect() async {
    _setState(ConnectionState.connecting);

    // Host acquisition (WOR-64). With a [resolveHost] callback we fetch the
    // PC's current server host fresh on every connect AND reconnect (handling a
    // restarted PC's rotated tunnel URL); otherwise we fall back to the literal
    // [ip]. A resolve failure (PC offline / network) is funnelled into the SAME
    // error stream + reconnect path as a socket-level failure. Nothing below
    // this block — protocol, auth handshake, streaming, reconnect/backoff — is
    // affected.
    final String host;
    if (resolveHost != null) {
      try {
        host = _sanitizeHost(await resolveHost!());
      } catch (e) {
        debugPrint('[OSIA WS] Host resolution failed: $e');
        _errorCtrl.add('$e');
        _setState(ConnectionState.disconnected);
        _scheduleReconnect();
        return;
      }
    } else {
      host = _sanitizeHost(ip);
    }
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
      // The socket is open and healthy: kill any reconnect timer left pending
      // from an earlier failed attempt. Otherwise that stale timer fires while
      // we're already connected and calls _doConnect() directly (it bypasses
      // connect()'s connecting/connected guard), opening a *duplicate* socket.
      // The orphaned socket's onDone then looks like a drop and schedules yet
      // another reconnect — the open→close→reconnect loop seen after the WOR-47
      // server change, even though every auth succeeds. Cancelling here keeps
      // the connection stable indefinitely once it's up.
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
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
      // WOR-53: optional per-turn conversation-id routing hint. The server tags
      // the streaming frames (response_chunk / response / status) with
      // `conversation_id`; conversation_history mirrors it onto `id`, so read
      // conversation_id with an id fallback. Only the streaming cases below use
      // it — it routes a backgrounded stream to its conversation buffer.
      final convId = (json['conversation_id'] ?? json['id'])?.toString();

      switch (type) {
        case 'transcript':
          if (content != null) {
            _emit(TranscriptMessage(content));
          }
        case 'response':
          if (content != null) {
            _emit(ResponseMessage(content));
            // WOR-53: also replace this conversation's buffer with the
            // canonical full reply (parallel sink — no change to pacing).
            _replaceConvText(convId, content);
          }
        case 'response_chunk':
          if (content != null && content.isNotEmpty) {
            _emit(ResponseChunkMessage(content));
            // WOR-53: also accrue the delta into this conversation's buffer so
            // its reply survives a screen switch and hydrates on return.
            _appendConvDelta(convId, content);
          }
        case 'audio':
          if (data != null) {
            final source = json['source'] as String?;
            debugPrint(
                '[OSIA WS] audio frame received: ${data.length} b64 chars, '
                'source=$source');
            _emit(AudioMessage(data, source: source));
          }
        case 'status':
          if (content != null) {
            _emit(StatusMessage(content));
            // WOR-53: a terminal turn status finalizes the conversation's
            // background stream (marks it not-streaming + terminal event).
            // Early error frames without a conversation_id are ignored by
            // [_finishConvStream]'s null guard.
            if (content == 'done' || content == 'error') {
              _finishConvStream(convId, error: content == 'error');
            }
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
        case 'config':
          // Full config snapshot. Delivered on its own [configStream] (NOT
          // through the paced message queue) so it can't interleave with or
          // disturb response-chunk streaming.
          final cfg = json['config'];
          if (cfg is Map) {
            final data = ConfigData.fromJson(cfg.cast<String, dynamic>());
            debugPrint(
                '[OSIA WS] config received: ${data.skills.length} skill(s), '
                '${data.cronJobs.length} cron job(s), '
                'heavy=${data.heavyChain.length} medium=${data.mediumChain.length}');
            if (!_configCtrl.isClosed) _configCtrl.add(data);
          } else {
            debugPrint('[OSIA WS] config message had no config payload');
          }
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
        case 'api_keys':
          // Raw provider keys for pre-filling editors. Delivered on its own
          // [apiKeysStream] (NOT the paced message queue) so it can't disturb
          // response-chunk streaming.
          final keysMsg = ApiKeysMessage.fromJson(json);
          debugPrint(
              '[OSIA WS] api_keys received: ${keysMsg.keys.length} key(s)');
          if (!_apiKeysCtrl.isClosed) _apiKeysCtrl.add(keysMsg);
        case 'heartbeat_data':
          // Live system metrics. Own [heartbeatStream], same rationale.
          final hb = HeartbeatDataMessage.fromJson(json);
          if (!_heartbeatCtrl.isClosed) _heartbeatCtrl.add(hb);
        case 'new_chat':
          // "Start a new chat" signal (WOR-10). Delivered on its own
          // [newChatStream] (NOT the paced message queue) so it can't disturb
          // response-chunk streaming.
          debugPrint('[OSIA WS] new_chat received');
          if (!_newChatCtrl.isClosed) {
            _newChatCtrl.add(const NewChatMessage());
          }
        case 'conversations_list':
          // Compact id+title list for the cron editor's linked-conversation
          // picker (WOR-24). Delivered on its own [conversationsListStream]
          // (NOT the paced message queue) so it can't disturb response-chunk
          // streaming.
          final rawList = json['conversations'];
          final convs = rawList is List
              ? rawList
                  .whereType<Map>()
                  .map((e) =>
                      ConversationItem.fromJson(e.cast<String, dynamic>()))
                  .toList()
              : <ConversationItem>[];
          debugPrint('[OSIA WS] conversations_list: ${convs.length} item(s)');
          if (!_conversationsListCtrl.isClosed) {
            _conversationsListCtrl.add(ConversationsListMessage(convs));
          }
        case 'autonomous_progress':
          // Live progress for an autonomous run (WOR-45 Phase 5). Delivered on
          // its own [autonomousStream] (NOT the paced message queue) so it can't
          // disturb response-chunk streaming.
          final prog = AutonomousProgressMessage.fromJson(json);
          debugPrint(
              '[OSIA WS] autonomous_progress: event=${prog.event} '
              'phase="${prog.phaseName}" ${prog.tasksDone}/${prog.tasksTotal}');
          if (!_autonomousCtrl.isClosed) {
            _autonomousCtrl.add(prog);
          }
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
    // The close code/reason (if any) helps tell an auth rejection from a
    // network drop when reading logs.
    final code = _channel?.closeCode;
    final reason = _channel?.closeReason;
    debugPrint(
        '[OSIA WS] Connection closed (code=$code, reason="$reason", '
        'intentional=$_intentionalClose, autoReconnect=$autoReconnect).');
    _channel = null;
    _setState(ConnectionState.disconnected);
    if (!_intentionalClose) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    // A probe (autoReconnect == false) must NOT reconnect: the disconnect it
    // just saw is the answer it was waiting for. Reconnecting would hide a
    // rejected token behind a perpetual "Connecting…" loop.
    if (!autoReconnect) {
      debugPrint('[OSIA WS] autoReconnect disabled — staying disconnected.');
      return;
    }
    _reconnectTimer?.cancel();

    final delayMs =
        _baseReconnectMs * pow(2, min(_reconnectAttempt, 6)).toInt();
    _reconnectAttempt++;
    debugPrint(
        '[OSIA WS] Reconnecting in ${delayMs}ms (attempt $_reconnectAttempt)...');

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      // Only reconnect if we're still actually down. A connection may have come
      // back up via connect() (e.g. the user's "Retry") between this timer being
      // scheduled and firing; reconnecting then would open a duplicate socket
      // and restart the open→close loop.
      if (!_intentionalClose && _state == ConnectionState.disconnected) {
        _doConnect();
      }
    });
  }
}
