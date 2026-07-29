import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'lan_direct_transport.dart';
import 'lan_discovery_service.dart';
import 'relay_crypto_service.dart';
import 'relay_service.dart';
import 'storage_service.dart';
import 'transport_coordinator.dart';
import 'webrtc_direct_transport.dart';
import 'webrtc_signaling.dart';

// ── WOR-75 diagnostic flag ────────────────────────────────────────────────

/// TEMPORARY instrumentation (WOR-75): when true, the background-work
/// placeholder lifecycle — pending set/clear, the load-conversation gate, the
/// render branch, and stream terminals — is traced via `debugPrint` under the
/// `[OSIA WOR-75]` tag. Shared with chat_screen.dart (referenced there as
/// `ws.kOsiaDebugPlaceholder`). Flip to `false` (or delete) to silence. Adds
/// NO behaviour — logging only.
const bool kOsiaDebugPlaceholder = false;
const bool kAllowLegacyRendezvousFallback = bool.fromEnvironment(
  'OSIA_ALLOW_LEGACY_RENDEZVOUS_FALLBACK',
);
const bool kRelayFallbackV1 = bool.fromEnvironment(
  'relay_fallback_v1',
  defaultValue: true,
);
const bool kWebRtcDirectV1 = bool.fromEnvironment(
  'webrtc_direct_v1',
  defaultValue: true,
);
const Set<String> _relayControlFields = <String>{
  'v',
  'type',
  'role',
  'pair_id',
  'seq',
  'ack',
  'payload',
};
const Set<String> _relayHelloPayloadFields = <String>{
  'e2e_version',
  'alg',
  'public_key',
  'nonce_base',
  'e2e_chunk_version',
};
const Set<String> _relayReadyPayloadFields = <String>{
  'e2e_version',
  'alg',
  'kid',
  'tag',
};
const Set<String> _relayE2eFrameFields = <String>{
  'v',
  'type',
  'role',
  'pair_id',
  'seq',
  'ack',
  'e2e_version',
  'alg',
  'kid',
  'priority',
  'final',
  'nonce',
  'ciphertext',
};
const String kRelayE2eUnavailableError =
    'Relay E2E connection unavailable. Update OSIA on PC and mobile, '
    'or retry when the public relay is reachable.';
const String kRelayUnreachableError =
    'The public relay is unreachable. Check the network and retry.';
const String kRelayE2eHandshakeTimeoutError =
    'The relay E2E handshake timed out before both devices were ready.';
const String kRelayE2eAuthMismatchError =
    'Relay E2E authentication failed. Verify the pairing token on both devices.';
const String kRelayE2eStaleSessionError =
    'The relay E2E session is stale or was replaced. Reconnect both devices.';
const String kRelayE2eRequiredError =
    'Relay E2E encryption is required. Update OSIA on PC and mobile.';
const String kRelayUpdateRequiredError =
    'The public relay protocol is incompatible. Update OSIA on PC and mobile.';
const String kRelayConnectionReplacedError =
    'This relay connection was replaced by a newer mobile connection.';
const String kRelayPairingConfigurationError =
    'Relay pairing proof or route is invalid. Pair both devices again.';
const String kRelayChunkUnsupportedError =
    'Encrypted relay chunking is not supported by the PC or relay. '
    'Update OSIA and retry.';
const String kRelayFrameTooLargeError =
    'The encrypted relay frame is too large.';
const String kRelayChunkTransferFailedError =
    'The encrypted relay chunk transfer failed.';
const String kRelayE2eDecryptFailedError =
    'Relay E2E authentication or decryption failed.';

String _relayErrorMessage(String code) {
  if (code == 'e2e_required') return kRelayE2eRequiredError;
  if (code == 'update_required') return kRelayUpdateRequiredError;
  if (code == 'session_superseded') return kRelayConnectionReplacedError;
  if (code == 'pair_proof_mismatch' || code == 'invalid_pair_route') {
    return kRelayPairingConfigurationError;
  }
  if (code == 'resume_not_supported') return kRelayE2eStaleSessionError;
  if (code == 'unsupported_chunk') return kRelayChunkUnsupportedError;
  if (code == 'frame_too_large') return kRelayFrameTooLargeError;
  if (code.startsWith('chunk_')) return kRelayChunkTransferFailedError;
  if (code == 'e2e_decrypt_failed' || code == 'e2e_auth_failed') {
    return kRelayE2eDecryptFailedError;
  }
  if (code == 'pair_secret_mismatch' || code == 'e2e_auth_mismatch') {
    return kRelayE2eAuthMismatchError;
  }
  if (code == 'replay_rejected' ||
      code == 'session_superseded' ||
      code == 'stale_session') {
    return kRelayE2eStaleSessionError;
  }
  return code.isEmpty ? 'relay_error' : code;
}

bool isRelayConnectionError(String error) => <String>{
  kRelayE2eUnavailableError,
  kRelayUnreachableError,
  kRelayE2eHandshakeTimeoutError,
  kRelayE2eAuthMismatchError,
  kRelayE2eStaleSessionError,
  kRelayE2eRequiredError,
  kRelayUpdateRequiredError,
  kRelayConnectionReplacedError,
  kRelayPairingConfigurationError,
  kRelayE2eDecryptFailedError,
}.contains(error);

enum RelayTransferDirection { outbound, inbound }

enum RelayTransferState { started, completed, failed }

enum RelayTransferErrorKind {
  unsupportedChunk,
  frameTooLarge,
  chunkFailed,
  e2eDecryptFailed,
  relayUnreachable,
}

/// Local-only relay transport progress. App-level ids are never placed in
/// relay chunk metadata; [clientRequestId] exists only inside this process so
/// the chat watchdog can correlate a transfer with its pending WOR-111 turn.
class RelayTransferEvent {
  const RelayTransferEvent({
    required this.direction,
    required this.state,
    required this.chunkId,
    this.clientRequestId = '',
    this.errorKind,
  });

  final RelayTransferDirection direction;
  final RelayTransferState state;
  final String chunkId;
  final String clientRequestId;
  final RelayTransferErrorKind? errorKind;
}

/// Attachment lifecycle traffic is deliberately kept outside the sealed
/// [OsiaMessage] hierarchy. It is a pre-turn transaction, not chat content, and
/// adding it to the sealed switch would couple composer upload state to every
/// chat-message consumer.
class AttachmentProtocolMessage {
  final Map<String, dynamic> data;

  const AttachmentProtocolMessage(this.data);
}

@visibleForTesting
String relayErrorMessageForTest(String code) => _relayErrorMessage(code);

@visibleForTesting
bool allowLegacyRendezvousFallbackForTest() => kAllowLegacyRendezvousFallback;

// ── Connection state ──────────────────────────────────────────────────────

/// Possible states of the WebSocket connection.
enum ConnectionState { disconnected, connecting, connected }

// ── Incoming message types ────────────────────────────────────────────────

/// Parsed incoming message from the OSIA server.
sealed class OsiaMessage {
  const OsiaMessage();
}

class TranscriptMessage extends OsiaMessage {
  final String content;
  final String conversationId;
  final String clientRequestId;
  final String turnId;
  final String messageId;

  const TranscriptMessage(
    this.content, {
    this.conversationId = '',
    this.clientRequestId = '',
    this.turnId = '',
    this.messageId = '',
  });
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
  final String conversationId;
  final String clientRequestId;
  final String turnId;
  final String messageId;
  const AudioMessage(
    this.data, {
    this.source,
    this.conversationId = '',
    this.clientRequestId = '',
    this.turnId = '',
    this.messageId = '',
  });
}

class StatusMessage extends OsiaMessage {
  /// One of: "thinking", "done", "error".
  final String content;
  final String conversationId;
  final String clientRequestId;
  final String turnId;
  const StatusMessage(
    this.content, {
    this.conversationId = '',
    this.clientRequestId = '',
    this.turnId = '',
  });
}

class TurnAcceptedMessage extends OsiaMessage {
  final String clientRequestId;
  final String turnId;
  final String conversationId;
  final bool persisted;
  final String status;

  const TurnAcceptedMessage({
    required this.clientRequestId,
    required this.turnId,
    required this.conversationId,
    required this.persisted,
    required this.status,
  });
}

/// A single conversation entry as sent by the server.
class Conversation {
  final String id;
  final String title;
  final DateTime? date;

  const Conversation({required this.id, required this.title, this.date});

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
  final String conversationId;
  final String clientRequestId;
  final String turnId;
  final String messageId;
  const HistoryMessage({
    required this.role,
    required this.content,
    this.conversationId = '',
    this.clientRequestId = '',
    this.turnId = '',
    this.messageId = '',
  });

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
      conversationId: (json['conversation_id'] ?? '').toString(),
      clientRequestId: (json['request_id'] ?? json['client_request_id'] ?? '')
          .toString(),
      turnId: (json['turn_id'] ?? '').toString(),
      messageId: (json['message_id'] ?? '').toString(),
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
  final List<String> inputModalities;
  final bool selectable;
  final List<OsiaModelReasoningOption> reasoningOptions;
  final String selectedReasoning;

  const OsiaModel({
    required this.id,
    required this.label,
    this.description,
    this.provider,
    this.inputModalities = const ['text'],
    this.selectable = true,
    this.reasoningOptions = const [],
    this.selectedReasoning = 'auto',
  });

  factory OsiaModel.fromJson(dynamic raw) {
    if (raw is String) {
      return OsiaModel(id: raw, label: raw);
    }
    if (raw is Map) {
      final m = raw.cast<String, dynamic>();
      final id = (m['id'] ?? m['name'] ?? m['model'] ?? '').toString();
      final label = (m['label'] ?? m['name'] ?? m['id'] ?? m['model'] ?? id)
          .toString();
      final desc = m['description']?.toString();
      final provider = (m['providerId'] ?? m['provider'])?.toString();
      final rawModalities = m['inputModalities'];
      final modalities = rawModalities is List
          ? rawModalities
                .map((value) => value.toString().trim().toLowerCase())
                .where((value) => value.isNotEmpty)
                .toList()
          : const <String>['text'];
      final rawReasoning = m['reasoning'];
      final reasoning = rawReasoning is Map
          ? rawReasoning.cast<String, dynamic>()
          : const <String, dynamic>{};
      final rawOptions = reasoning['options'];
      final options = rawOptions is List
          ? rawOptions
                .whereType<Map>()
                .map(
                  (value) => OsiaModelReasoningOption.fromJson(
                    value.cast<String, dynamic>(),
                  ),
                )
                .where((option) => option.id.isNotEmpty)
                .toList()
          : const <OsiaModelReasoningOption>[];
      return OsiaModel(
        id: id,
        label: label,
        description: desc,
        provider: provider,
        inputModalities: modalities,
        selectable: m['selectable'] != false && m['usable'] != false,
        reasoningOptions: options,
        selectedReasoning: (reasoning['selected'] ?? 'auto')
            .toString()
            .trim()
            .toLowerCase(),
      );
    }
    final s = raw?.toString() ?? '';
    return OsiaModel(id: s, label: s);
  }
}

class OsiaModelReasoningOption {
  final String id;
  final String label;
  final bool isDefault;

  const OsiaModelReasoningOption({
    required this.id,
    required this.label,
    this.isDefault = false,
  });

  factory OsiaModelReasoningOption.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim().toLowerCase();
    return OsiaModelReasoningOption(
      id: id,
      label: (json['label'] ?? id).toString(),
      isDefault: json['default'] == true,
    );
  }
}

class ModelProviderCatalogueEntry {
  final String id;
  final String displayName;
  final String kind;
  final List<OsiaModel> models;

  const ModelProviderCatalogueEntry({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.models,
  });

  factory ModelProviderCatalogueEntry.fromJson(Map<String, dynamic> json) {
    final id = (json['providerId'] ?? json['id'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final rawModels = json['models'];
    final seen = <String>{};
    final models = rawModels is List
        ? rawModels
              .map(OsiaModel.fromJson)
              .where(
                (model) =>
                    model.id.trim().isNotEmpty &&
                    model.selectable &&
                    seen.add('${model.provider ?? id}\u0000${model.id}'),
              )
              .toList()
        : <OsiaModel>[];
    return ModelProviderCatalogueEntry(
      id: id,
      displayName: (json['displayName'] ?? id).toString(),
      kind: (json['kind'] ?? 'api').toString(),
      models: models,
    );
  }
}

/// Sanitized ChatGPT-account state. Credentials and raw App Server payloads
/// are deliberately not represented by this type.
class ChatGptAccountState {
  final bool runtimeAvailable;
  final bool connected;
  final bool connecting;
  final bool loginCancellable;
  final bool available;
  final String error;
  final String email;
  final String plan;
  final int? usagePercent;
  final String selectedModel;
  final String verificationUrl;
  final String userCode;

  const ChatGptAccountState({
    this.runtimeAvailable = false,
    this.connected = false,
    this.connecting = false,
    this.loginCancellable = false,
    this.available = false,
    this.error = '',
    this.email = '',
    this.plan = '',
    this.usagePercent,
    this.selectedModel = '',
    this.verificationUrl = '',
    this.userCode = '',
  });

  factory ChatGptAccountState.fromJson(Object? raw) {
    if (raw is! Map) return const ChatGptAccountState();
    final json = raw.cast<String, dynamic>();
    final login = json['login'] is Map
        ? (json['login'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final usage = json['usagePercent'];
    return ChatGptAccountState(
      runtimeAvailable: json['runtimeAvailable'] == true,
      connected: json['connected'] == true,
      connecting: json['connecting'] == true,
      loginCancellable: json['loginCancellable'] == true,
      available: json['available'] == true,
      error: (json['error'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      plan: (json['plan'] ?? '').toString(),
      usagePercent: usage is int && usage >= 0 && usage <= 100 ? usage : null,
      selectedModel: (json['selectedModel'] ?? '').toString(),
      verificationUrl: (login['verificationUrl'] ?? '').toString(),
      userCode: (login['userCode'] ?? '').toString(),
    );
  }

  ChatGptAccountState withoutEphemeralLogin() => ChatGptAccountState(
    runtimeAvailable: runtimeAvailable,
    connected: connected,
    connecting: false,
    loginCancellable: false,
    available: available,
    error: error,
    email: email,
    plan: plan,
    usagePercent: usagePercent,
    selectedModel: selectedModel,
  );
}

/// Full list of available models sent by the server in response to
/// `{"type":"get_models"}`.
class ModelsListMessage extends OsiaMessage {
  final List<OsiaModel> models;
  final List<ModelProviderCatalogueEntry> providers;
  final String? current;
  final String? currentProvider;
  final ChatGptAccountState account;
  const ModelsListMessage({
    required this.models,
    this.providers = const [],
    this.current,
    this.currentProvider,
    this.account = const ChatGptAccountState(),
  });
}

/// Per-provider/per-model reasoning settings from `config.reasoning`.
///
/// This mirrors the backend WOR-77 schema additively. Old servers may omit the
/// field entirely; in that case mobile treats reasoning as provider defaults.
class OsiaReasoningConfig {
  static const Set<String> _validLevels = {
    'auto',
    'off',
    'minimal',
    'low',
    'medium',
    'high',
    'xhigh',
    'normal',
    'max',
  };

  final String defaultLevel;
  final Map<String, String> providers;
  final Map<String, String> models;

  const OsiaReasoningConfig({
    this.defaultLevel = 'auto',
    this.providers = const {},
    this.models = const {},
  });

  factory OsiaReasoningConfig.fromJson(Object? raw) {
    if (raw is! Map) return const OsiaReasoningConfig();
    final json = <String, dynamic>{};
    raw.forEach((key, value) => json[key.toString()] = value);
    return OsiaReasoningConfig(
      defaultLevel: _normalizeLevel(json['default']),
      providers: _readLevelMap(json['providers'], lowercaseKeys: true),
      models: _readLevelMap(json['models']),
    );
  }

  static String _normalizeLevel(Object? raw) {
    if (raw is String) {
      final level = raw.trim().toLowerCase();
      if (level == 'default') return 'auto';
      if (level == 'none') return 'off';
      if (_validLevels.contains(level)) return level;
    }
    return 'auto';
  }

  static Map<String, String> _readLevelMap(
    Object? raw, {
    bool lowercaseKeys = false,
  }) {
    final out = <String, String>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (key is! String) return;
        final cleanKey = (lowercaseKeys ? key.toLowerCase() : key).trim();
        if (cleanKey.isEmpty) return;
        out[cleanKey] = _normalizeLevel(value);
      });
    }
    return out;
  }

  OsiaReasoningConfig withModelOverride(String modelId, String optionId) {
    final cleanModel = modelId.trim();
    if (cleanModel.isEmpty) return this;
    final nextModels = Map<String, String>.from(models);
    nextModels[cleanModel] = _normalizeLevel(optionId);
    return OsiaReasoningConfig(
      defaultLevel: defaultLevel,
      providers: Map<String, String>.from(providers),
      models: nextModels,
    );
  }

  Map<String, dynamic> toJson() => {
    'default': defaultLevel,
    'providers': Map<String, String>.from(providers),
    'models': Map<String, String>.from(models),
  };
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

/// Capability flags for the server-side native Gmail REST integration.
class GmailRestCapabilities {
  final bool readonly;
  final bool compose;
  final bool modify;

  const GmailRestCapabilities({
    this.readonly = false,
    this.compose = false,
    this.modify = false,
  });

  factory GmailRestCapabilities.fromJson(Map<String, dynamic> json) {
    bool readBool(Object? raw) {
      if (raw is bool) return raw;
      if (raw is String) return raw.toLowerCase() == 'true';
      return false;
    }

    return GmailRestCapabilities(
      readonly: readBool(json['readonly']),
      compose: readBool(json['compose']),
      modify: readBool(json['modify']),
    );
  }
}

/// Mirror of `config.gmail_rest`; Gmail REST itself stays server-side.
class GmailRestConfig {
  final bool connected;
  final bool connecting;
  final bool canConnect;
  final bool canCancel;
  final bool canReconnect;
  final bool canDisconnect;
  final bool canDisconnectProvided;
  final bool oauthClientConfigured;
  final bool mobileOAuthConfigured;
  final bool userActionRequired;
  final bool configureOnPc;
  final bool elevateOnPc;
  final bool guideAvailable;
  final String? status;
  final String? errorCategory;
  final String? message;
  final String? emailAddress;
  final String? reason;
  final String? attemptId;
  final double? attemptExpiresAt;
  final GmailRestCapabilities capabilities;

  const GmailRestConfig({
    required this.connected,
    this.connecting = false,
    this.canConnect = false,
    this.canCancel = false,
    this.canReconnect = false,
    this.canDisconnect = false,
    this.canDisconnectProvided = false,
    this.oauthClientConfigured = false,
    this.mobileOAuthConfigured = false,
    this.userActionRequired = false,
    this.configureOnPc = false,
    this.elevateOnPc = false,
    this.guideAvailable = false,
    this.status,
    this.errorCategory,
    this.message,
    this.emailAddress,
    this.reason,
    this.attemptId,
    this.attemptExpiresAt,
    this.capabilities = const GmailRestCapabilities(),
  });

  static GmailRestConfig? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = <String, dynamic>{};
    raw.forEach((key, value) => json[key.toString()] = value);

    bool readBool(Object? value) {
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return false;
    }

    String? readString(Object? value) {
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final rawCapabilities = json['capabilities'];
    final capabilityJson = <String, dynamic>{};
    if (rawCapabilities is Map) {
      rawCapabilities.forEach((key, value) {
        capabilityJson[key.toString()] = value;
      });
    }
    final capabilities = capabilityJson.isEmpty
        ? const GmailRestCapabilities()
        : GmailRestCapabilities.fromJson(capabilityJson);

    return GmailRestConfig(
      connected: readBool(json['connected']),
      connecting: readBool(json['connecting']),
      canConnect: readBool(json['canConnect']),
      canCancel: readBool(json['canCancel']),
      canReconnect: readBool(json['canReconnect']),
      canDisconnect: readBool(json['canDisconnect']),
      canDisconnectProvided: json.containsKey('canDisconnect'),
      oauthClientConfigured: readBool(json['oauthClientConfigured']),
      mobileOAuthConfigured: readBool(json['mobileOAuthConfigured']),
      userActionRequired: readBool(json['userActionRequired']),
      configureOnPc: readBool(json['configureOnPc']),
      elevateOnPc: readBool(json['elevateOnPc']),
      guideAvailable: readBool(json['guideAvailable']),
      status: readString(json['status']),
      errorCategory: readString(json['errorCategory']),
      message: readString(json['message']),
      emailAddress: readString(json['emailAddress']),
      reason: readString(json['reason']),
      attemptId: readString(json['attemptId']),
      attemptExpiresAt: json['attemptExpiresAt'] is num
          ? (json['attemptExpiresAt'] as num).toDouble()
          : null,
      capabilities: capabilities,
    );
  }
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

  /// Native Gmail REST state mirrored from the PC. This is display-only on
  /// mobile; Gmail auth and REST calls remain server-side.
  final GmailRestConfig? gmailRest;

  /// Per-provider/per-model reasoning controls mirrored from the PC.
  final OsiaReasoningConfig reasoning;

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
    this.gmailRest,
    this.reasoning = const OsiaReasoningConfig(),
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
        ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
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

    final settings = readSettings(config);
    return ConfigData(
      apiKeysSet: readKeysSet(config['api_keys_set']),
      cronJobs: readJobs(config['cron_jobs']),
      heavyChain: readChain(config['heavy_chain']),
      mediumChain: readChain(config['medium_chain']),
      aiHierarchyEnabled: config['ai_hierarchy_enabled'] == true,
      personality: (config['personality'] ?? '').toString(),
      skills: readSkills(config['skills']),
      gmailRest: GmailRestConfig.tryParse(config['gmail_rest']),
      reasoning: OsiaReasoningConfig.fromJson(
        config['reasoning'] ?? settings['reasoning'],
      ),
      settings: settings,
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

/// One local OSIA memory entry, carried inside a [MemorySnapshot].
///
/// Delivered on [WebSocketService.memoryStream], outside the sealed
/// [OsiaMessage] hierarchy so the chat stream remains untouched.
class MemoryEntryData {
  final String id;
  final String type;
  final String category;
  final String key;
  final String title;
  final Map<String, dynamic> value;
  final double confidence;
  final String source;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastUsedAt;
  final List<String> tags;
  final Map<String, dynamic> device;
  final DateTime? expiresAt;

  const MemoryEntryData({
    required this.id,
    required this.type,
    required this.category,
    required this.key,
    required this.title,
    required this.value,
    required this.confidence,
    required this.source,
    this.createdAt,
    this.updatedAt,
    this.lastUsedAt,
    this.tags = const [],
    this.device = const {},
    this.expiresAt,
  });

  factory MemoryEntryData.fromJson(Map<String, dynamic> json) {
    DateTime? readDate(Object? raw) =>
        raw is String ? DateTime.tryParse(raw) : null;

    return MemoryEntryData(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      value: json['value'] is Map
          ? (json['value'] as Map).cast<String, dynamic>()
          : <String, dynamic>{},
      confidence: json['confidence'] is num
          ? (json['confidence'] as num).toDouble()
          : 1.0,
      source: (json['source'] ?? '').toString(),
      createdAt: readDate(json['created_at']),
      updatedAt: readDate(json['updated_at']),
      lastUsedAt: readDate(json['last_used_at']),
      tags: json['tags'] is List
          ? (json['tags'] as List).map((e) => e.toString()).toList()
          : const <String>[],
      device: json['device'] is Map
          ? (json['device'] as Map).cast<String, dynamic>()
          : <String, dynamic>{},
      expiresAt: readDate(json['expires_at']),
    );
  }

  String get valueKind => (value['kind'] ?? '').toString();

  Object? get valueData => value['data'];

  Map<String, dynamic> toJson({String? sourceOverride}) => {
    if (id.isNotEmpty) 'id': id,
    'type': type,
    'category': category,
    'key': key,
    'title': title,
    'value': Map<String, dynamic>.from(value),
    'confidence': confidence,
    'source': sourceOverride ?? source,
    if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    if (lastUsedAt != null)
      'last_used_at': lastUsedAt!.toUtc().toIso8601String(),
    'tags': List<String>.from(tags),
    'device': Map<String, dynamic>.from(device),
    if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
  };
}

/// Full local-memory snapshot from the PC server.
class MemorySnapshot {
  final int schemaVersion;
  final DateTime? updatedAt;
  final List<MemoryEntryData> entries;

  const MemorySnapshot({
    required this.schemaVersion,
    this.updatedAt,
    required this.entries,
  });

  factory MemorySnapshot.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    return MemorySnapshot(
      schemaVersion: json['schema_version'] is num
          ? (json['schema_version'] as num).toInt()
          : 1,
      updatedAt: json['updated_at'] is String
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      entries: rawEntries is List
          ? rawEntries
                .whereType<Map>()
                .map((e) => MemoryEntryData.fromJson(e.cast<String, dynamic>()))
                .toList()
          : const <MemoryEntryData>[],
    );
  }
}

/// Validation/storage error from the PC memory store.
class MemoryErrorMessage {
  final String code;
  final String message;

  const MemoryErrorMessage({required this.code, required this.message});

  factory MemoryErrorMessage.fromJson(Map<String, dynamic> json) =>
      MemoryErrorMessage(
        code: (json['code'] ?? 'unknown').toString(),
        message: (json['message'] ?? '').toString(),
      );
}

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
      ramPercent: pick([
        'ram_percent',
        'ram',
        'memory_percent',
        'mem_percent',
        'memory',
      ]),
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

/// In-app fallback notification for a scheduled task completion/failure.
/// Delivered on its own stream so the sealed chat message switch remains
/// unchanged, like config/new_chat/conversations_list.
class CronNotificationMessage {
  final String id;
  final String taskId;
  final String title;
  final String status;
  final String conversationId;
  final String createdAt;
  final String requestId;
  final String turnId;
  final String messageId;
  final String eventId;
  final String eventType;
  final int sequence;
  final bool terminal;

  const CronNotificationMessage({
    required this.id,
    required this.taskId,
    required this.title,
    required this.status,
    required this.conversationId,
    required this.createdAt,
    this.requestId = '',
    this.turnId = '',
    this.messageId = '',
    this.eventId = '',
    this.eventType = '',
    this.sequence = 0,
    this.terminal = false,
  });

  bool get failed => status == 'failed';

  factory CronNotificationMessage.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? '').toString().trim().toLowerCase();
    return CronNotificationMessage(
      id: (json['id'] ?? '').toString(),
      taskId: (json['task_id'] ?? json['taskId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      status: rawStatus == 'failed' || rawStatus == 'error'
          ? 'failed'
          : 'completed',
      conversationId: (json['conversation_id'] ?? json['conversationId'] ?? '')
          .toString(),
      createdAt: (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      requestId: (json['request_id'] ?? json['client_request_id'] ?? '')
          .toString(),
      turnId: (json['turn_id'] ?? '').toString(),
      messageId: (json['message_id'] ?? '').toString(),
      eventId: (json['event_id'] ?? '').toString(),
      eventType: (json['event_type'] ?? '').toString(),
      sequence: json['sequence'] is int ? json['sequence'] as int : 0,
      terminal: json['terminal'] == true,
    );
  }
}

/// Sanitized scheduled-task authorization event from the PC authority.
/// Instructions, normalized scopes, grant references, and tool arguments are
/// deliberately not represented by this mobile model.
class ScheduledTaskAuthorizationEvent {
  final String eventType;
  final bool ok;
  final String code;
  final String taskId;
  final String authorizationStatus;
  final Map<String, dynamic>? request;

  const ScheduledTaskAuthorizationEvent({
    required this.eventType,
    required this.ok,
    required this.code,
    required this.taskId,
    required this.authorizationStatus,
    this.request,
  });

  factory ScheduledTaskAuthorizationEvent.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString();
    final rawTask = json['task'];
    final task = rawTask is Map
        ? rawTask.cast<String, dynamic>()
        : const <String, dynamic>{};
    Map<String, dynamic>? request;
    if (type == 'scheduled_task_authorization_request') {
      final rawCapabilities = json['capabilities'];
      final capabilities = rawCapabilities is List
          ? rawCapabilities.whereType<Map>().map((raw) {
              final item = raw.cast<String, dynamic>();
              return <String, dynamic>{
                'id': (item['id'] ?? '').toString(),
                'tool_category': (item['tool_category'] ?? '').toString(),
                'effect_class': (item['effect_class'] ?? '').toString(),
                'safe_category': (item['safe_category'] ?? '').toString(),
              };
            }).toList()
          : <Map<String, dynamic>>[];
      request = <String, dynamic>{
        'protocol_version': json['protocol_version'],
        'request_id': json['request_id'],
        'task_id': json['task_id'],
        'task_revision': json['task_revision'],
        'definition_hash': json['definition_hash'],
        'authorization_revision': json['authorization_revision'],
        'policy_epoch': json['policy_epoch'],
        'expiration': json['expiration'],
        'request_expires_at': json['request_expires_at'],
        'origin_ref': json['origin_ref'],
        'capabilities': capabilities,
        'max_executions': json['max_executions'],
      };
    }
    return ScheduledTaskAuthorizationEvent(
      eventType: type,
      ok: json['ok'] == true,
      code: (json['code'] ?? '').toString(),
      taskId: (json['task_id'] ?? task['task_id'] ?? '').toString(),
      authorizationStatus:
          (json['authorization_status'] ?? task['authorization_status'] ?? '')
              .toString(),
      request: request,
    );
  }
}

enum AutonomousFailureStage {
  planning('planning'),
  taskExecution('task_execution'),
  verification('verification'),
  retry('retry'),
  replan('replan'),
  resume('resume'),
  control('control'),
  persistence('persistence'),
  orchestrator('orchestrator'),
  unknown('unknown');

  const AutonomousFailureStage(this.wireValue);
  final String wireValue;

  static AutonomousFailureStage fromWire(String value) {
    return AutonomousFailureStage.values.firstWhere(
      (stage) => stage.wireValue == value,
      orElse: () => AutonomousFailureStage.unknown,
    );
  }
}

enum AutonomousFailureCategory {
  planningProviderFailure('planning_provider_failure'),
  planningAuthenticationFailure('planning_authentication_failure'),
  planningRateLimit('planning_rate_limit'),
  planningTimeout('planning_timeout'),
  invalidPlanningOutput('invalid_planning_output'),
  taskExecutionFailure('task_execution_failure'),
  taskTimeout('task_timeout'),
  verificationError('verification_error'),
  verificationNotCompleted('verification_not_completed'),
  taskAttemptsExhausted('task_attempts_exhausted'),
  replanFailure('replan_failure'),
  replansExhausted('replans_exhausted'),
  invalidResumeState('invalid_resume_state'),
  interrupted('interrupted'),
  aborted('aborted'),
  orchestratorFailure('orchestrator_failure'),
  checkpointFailure('checkpoint_failure'),
  unknownFailure('unknown_failure');

  const AutonomousFailureCategory(this.wireValue);
  final String wireValue;

  static AutonomousFailureCategory fromWire(String value) {
    return AutonomousFailureCategory.values.firstWhere(
      (category) => category.wireValue == value,
      orElse: () => AutonomousFailureCategory.unknownFailure,
    );
  }
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
  final int? schemaVersion;
  final String? eventId;
  final int? sequence;
  final String? serverId;
  final String? sessionId;
  final String? safeOperationPhase;
  final String? safeSiteDisplay;
  final String? safeProgressText;
  final String? finalAnswer;
  final Map<String, dynamic>? artifactSafeSummary;
  final bool? terminal;

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

  /// WOR-173 additive, sanitized diagnostic metadata. Older servers omit it;
  /// future enum values fail closed to `unknown` / `unknownFailure`.
  final AutonomousFailureStage? stage;
  final AutonomousFailureCategory? errorCategory;
  final int? attempt;
  final int? maxAttempts;
  final int? replanCount;
  final int? maxReplans;
  final String? provider;
  final String? model;
  final bool? resumable;
  final bool? checkpointPresent;
  final String? reasonCode;
  final String? runRef;
  final String? diagnosticTimestamp;
  final int? protocolVersion;
  final String? runId;
  final int? planRevision;
  final int? authorizationRevision;
  final int? policyEpoch;
  final String? runState;
  final String? authorizationStatus;
  final String? authorizationSource;
  final int? grantCount;
  final List<Map<String, dynamic>> capabilitySummary;
  final List<Map<String, dynamic>> planSummary;
  final Map<String, dynamic>? authorizationRequest;
  final Map<String, dynamic>? pendingScopeExtension;

  const AutonomousProgressMessage({
    this.schemaVersion,
    this.eventId,
    this.sequence,
    this.serverId,
    this.sessionId,
    this.safeOperationPhase,
    this.safeSiteDisplay,
    this.safeProgressText,
    this.finalAnswer,
    this.artifactSafeSummary,
    this.terminal,
    this.event,
    this.phaseName,
    this.tasksDone,
    this.tasksTotal,
    this.status,
    this.objective,
    this.taskId,
    this.reason,
    this.stage,
    this.errorCategory,
    this.attempt,
    this.maxAttempts,
    this.replanCount,
    this.maxReplans,
    this.provider,
    this.model,
    this.resumable,
    this.checkpointPresent,
    this.reasonCode,
    this.runRef,
    this.diagnosticTimestamp,
    this.protocolVersion,
    this.runId,
    this.planRevision,
    this.authorizationRevision,
    this.policyEpoch,
    this.runState,
    this.authorizationStatus,
    this.authorizationSource,
    this.grantCount,
    this.capabilitySummary = const [],
    this.planSummary = const [],
    this.authorizationRequest,
    this.pendingScopeExtension,
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

    bool? pickBool(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is bool) return v;
        if (v is String) {
          if (v.toLowerCase() == 'true') return true;
          if (v.toLowerCase() == 'false') return false;
        }
      }
      return null;
    }

    final stageCode = pickStr(['stage']);
    final categoryCode = pickStr(['error_category', 'errorCategory']);
    List<Map<String, dynamic>> pickMaps(String key) {
      final value = json[key];
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    Map<String, dynamic>? pickMap(String key) {
      final value = json[key];
      return value is Map ? Map<String, dynamic>.from(value) : null;
    }

    return AutonomousProgressMessage(
      schemaVersion: pickInt(['schema_version']),
      eventId: pickStr(['event_id']),
      sequence: pickInt(['sequence']),
      serverId: pickStr(['server_id']),
      sessionId: pickStr(['session_id']),
      safeOperationPhase: pickStr(['safe_operation_phase']),
      safeSiteDisplay: pickStr(['safe_site_display']),
      safeProgressText: pickStr(['safe_progress_text']),
      finalAnswer: pickStr(['final_answer']),
      artifactSafeSummary: pickMap('artifact_safe_summary'),
      terminal: pickBool(['terminal']),
      event: pickStr(['event']),
      phaseName: pickStr(['phase_name', 'phaseName', 'phase']),
      tasksDone: pickInt(['tasks_done', 'tasksDone']),
      tasksTotal: pickInt(['tasks_total', 'tasksTotal']),
      status: pickStr(['status', 'message']),
      objective: pickStr(['objective']),
      taskId: pickStr(['task_id', 'taskId']),
      reason: pickStr(['reason']),
      stage: stageCode == null
          ? null
          : AutonomousFailureStage.fromWire(stageCode),
      errorCategory: categoryCode == null
          ? null
          : AutonomousFailureCategory.fromWire(categoryCode),
      attempt: pickInt(['attempt']),
      maxAttempts: pickInt(['max_attempts', 'maxAttempts']),
      replanCount: pickInt(['replan_count', 'replanCount']),
      maxReplans: pickInt(['max_replans', 'maxReplans']),
      provider: pickStr(['provider']),
      model: pickStr(['model']),
      resumable: pickBool(['resumable']),
      checkpointPresent: pickBool(['checkpoint_present', 'checkpointPresent']),
      reasonCode: pickStr(['reason_code', 'reasonCode']),
      runRef: pickStr(['run_ref', 'runRef']),
      diagnosticTimestamp: pickStr(['transition_at', 'diagnosticTimestamp']),
      protocolVersion: pickInt(['protocol_version', 'protocolVersion']),
      runId: pickStr(['run_id', 'runId']),
      planRevision: pickInt(['plan_revision', 'planRevision']),
      authorizationRevision: pickInt([
        'authorization_revision',
        'authorizationRevision',
      ]),
      policyEpoch: pickInt(['policy_epoch', 'policyEpoch']),
      runState: pickStr(['run_state', 'runState']),
      authorizationStatus: pickStr([
        'authorization_status',
        'authorizationStatus',
      ]),
      authorizationSource: pickStr([
        'authorization_source',
        'authorizationSource',
      ]),
      grantCount: pickInt(['grant_count', 'grantCount']),
      capabilitySummary: pickMaps('capability_summary'),
      planSummary: pickMaps('plan_summary'),
      authorizationRequest: pickMap('authorization_request'),
      pendingScopeExtension: pickMap('pending_scope_extension'),
    );
  }
}

/// Sanitized document-processing state. The strict parser has no field for a
/// source capability, artifact id, path, filename, content, query or parser.
class DocumentProgressMessage {
  const DocumentProgressMessage({
    required this.eventId,
    required this.serverId,
    required this.sessionId,
    required this.scopeType,
    required this.scopeId,
    required this.planRevision,
    required this.sequence,
    required this.itemId,
    required this.documentType,
    required this.phase,
    required this.terminal,
    required this.failureCategory,
    required this.snapshot,
    this.completedCount,
    this.totalCount,
  });

  final String eventId;
  final String serverId;
  final String sessionId;
  final String scopeType;
  final String scopeId;
  final int planRevision;
  final int sequence;
  final String itemId;
  final String documentType;
  final String phase;
  final bool terminal;
  final String failureCategory;
  final bool snapshot;
  final int? completedCount;
  final int? totalCount;

  static DocumentProgressMessage? tryParse(Map<String, dynamic> json) {
    const keys = <String>{
      'type',
      'schema_version',
      'event_id',
      'server_id',
      'session_id',
      'scope_type',
      'scope_id',
      'plan_revision',
      'sequence',
      'item_id',
      'document_type',
      'phase',
      'terminal',
      'failure_category',
      'counts',
      'snapshot',
    };
    if (!_hasExactStringKeys(json, keys) ||
        json['type'] != 'document_progress' ||
        json['schema_version'] != 1 ||
        json['event_id'] is! String ||
        json['server_id'] is! String ||
        json['session_id'] is! String ||
        json['scope_type'] is! String ||
        json['scope_id'] is! String ||
        json['plan_revision'] is! int ||
        json['sequence'] is! int ||
        json['item_id'] is! String ||
        json['document_type'] is! String ||
        json['phase'] is! String ||
        json['terminal'] is! bool ||
        json['failure_category'] is! String ||
        json['snapshot'] is! bool) {
      return null;
    }
    final eventId = json['event_id'] as String;
    final serverId = json['server_id'] as String;
    final sessionId = json['session_id'] as String;
    final scopeType = json['scope_type'] as String;
    final scopeId = json['scope_id'] as String;
    final planRevision = json['plan_revision'] as int;
    final sequence = json['sequence'] as int;
    final itemId = json['item_id'] as String;
    final documentType = json['document_type'] as String;
    final phase = json['phase'] as String;
    final terminal = json['terminal'] as bool;
    final failureCategory = json['failure_category'] as String;
    final counts = json['counts'];
    int? completed;
    int? total;
    if (counts != null) {
      if (counts is! Map ||
          !_hasExactStringKeys(counts, const {'completed', 'total'}) ||
          counts['completed'] is! int ||
          counts['total'] is! int) {
        return null;
      }
      completed = counts['completed'] as int;
      total = counts['total'] as int;
      if (completed < 0 || total < completed || total > 1000000) return null;
    }
    const phases = <String>{
      'identifying',
      'inspecting',
      'extracting',
      'indexing',
      'ready',
      'failed',
    };
    const failures = <String>{
      'active_content_detected',
      'corrupted_document',
      'drm_protected',
      'encrypted_document',
      'expired_source',
      'external_reference_detected',
      'extraction_failure',
      'file_identity_mismatch',
      'invalid_source_reference',
      'missing_source',
      'ocr_unavailable',
      'protected_document',
      'resource_limit_exceeded',
      'source_changed',
      'source_unavailable',
      'unauthorized_source',
      'unsupported_format',
      'unsupported_legacy_format',
    };
    if (eventId.isEmpty ||
        eventId.length > 128 ||
        serverId.isEmpty ||
        sessionId.isEmpty ||
        sessionId.length > 128 ||
        !const {'chat', 'autonomous'}.contains(scopeType) ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,255}$').hasMatch(scopeId) ||
        planRevision < 0 ||
        sequence < 1 ||
        !RegExp(r'^item_[0-9a-f]{24}$').hasMatch(itemId) ||
        !RegExp(r'^[a-z0-9][a-z0-9.+-]{0,31}$').hasMatch(documentType) ||
        !phases.contains(phase) ||
        terminal != const {'ready', 'failed'}.contains(phase) ||
        (phase == 'failed'
            ? !failures.contains(failureCategory)
            : failureCategory.isNotEmpty)) {
      return null;
    }
    return DocumentProgressMessage(
      eventId: eventId,
      serverId: serverId,
      sessionId: sessionId,
      scopeType: scopeType,
      scopeId: scopeId,
      planRevision: planRevision,
      sequence: sequence,
      itemId: itemId,
      documentType: documentType,
      phase: phase,
      terminal: terminal,
      failureCategory: failureCategory,
      snapshot: json['snapshot'] as bool,
      completedCount: completed,
      totalCount: total,
    );
  }
}

/// Strict, value-free progress from the browser subsystem. The parser accepts
/// only the allowlisted protocol projection; page content, selectors, paths,
/// filenames and query strings have no fields through which to enter the UI.
class BrowserProgressMessage {
  const BrowserProgressMessage({
    required this.eventId,
    required this.sequence,
    required this.serverId,
    required this.sessionId,
    required this.runId,
    required this.planRevision,
    required this.authorizationRevision,
    required this.phase,
    required this.safeSiteDisplay,
    required this.safeProgressText,
    required this.terminal,
    this.browserSessionId = '',
    this.artifactSafeSummary,
  });

  final String eventId;
  final int sequence;
  final String serverId;
  final String sessionId;
  final String browserSessionId;
  final String runId;
  final int planRevision;
  final int authorizationRevision;
  final String phase;
  final String safeSiteDisplay;
  final String safeProgressText;
  final Map<String, dynamic>? artifactSafeSummary;
  final bool terminal;

  static BrowserProgressMessage? tryParse(Map<String, dynamic> json) {
    const keys = <String>{
      'type',
      'schema_version',
      'event_id',
      'sequence',
      'server_id',
      'session_id',
      'browser_session_id',
      'run_id',
      'plan_revision',
      'authorization_revision',
      'safe_operation_phase',
      'safe_site_display',
      'safe_progress_text',
      'artifact_safe_summary',
      'terminal',
    };
    if (!_hasExactStringKeys(json, keys) ||
        json['type'] != 'browser_progress' ||
        json['schema_version'] != 1 ||
        json['event_id'] is! String ||
        json['sequence'] is! int ||
        json['server_id'] is! String ||
        json['session_id'] is! String ||
        json['browser_session_id'] is! String ||
        json['run_id'] is! String ||
        json['plan_revision'] is! int ||
        json['authorization_revision'] is! int ||
        json['safe_operation_phase'] is! String ||
        json['safe_site_display'] is! String ||
        json['safe_progress_text'] is! String ||
        json['terminal'] is! bool) {
      return null;
    }
    final eventId = json['event_id'] as String;
    final sequence = json['sequence'] as int;
    final serverId = json['server_id'] as String;
    final sessionId = json['session_id'] as String;
    final browserSessionId = json['browser_session_id'] as String;
    final runId = json['run_id'] as String;
    final planRevision = json['plan_revision'] as int;
    final authorizationRevision = json['authorization_revision'] as int;
    final phase = json['safe_operation_phase'] as String;
    final site = json['safe_site_display'] as String;
    final progress = json['safe_progress_text'] as String;
    if (eventId.isEmpty ||
        eventId.length > 128 ||
        sequence < 1 ||
        serverId.isEmpty ||
        sessionId.isEmpty ||
        sessionId.length > 128 ||
        browserSessionId.length > 128 ||
        runId.isEmpty ||
        runId.length > 256 ||
        planRevision < 0 ||
        authorizationRevision < 0 ||
        !const <String>{
          'snapshot',
          'waiting',
          'downloading',
          'finalizing',
          'complete',
          'failed',
          'cancelled',
        }.contains(phase) ||
        site.length > 512 ||
        progress.isEmpty ||
        progress.length > 300 ||
        !const <String>{
          'Browser state refreshed',
          'Waiting for the download',
          'Downloading to private storage',
          'Finalizing the private artifact',
          'Private artifact ready',
          'Browser operation needs attention',
          'Browser operation cancelled',
        }.contains(progress) ||
        !_isSafeProgressSiteDisplay(site)) {
      return null;
    }
    final rawArtifact = json['artifact_safe_summary'];
    Map<String, dynamic>? artifact;
    if (rawArtifact != null) {
      if (rawArtifact is! Map) return null;
      const artifactKeys = <String>{
        'artifact_id',
        'size',
        'mime_type',
        'classification',
        'private',
      };
      if (rawArtifact.keys.any(
            (key) => key is! String || !artifactKeys.contains(key),
          ) ||
          rawArtifact['private'] != true) {
        return null;
      }
      final size = rawArtifact['size'];
      if (size != null && (size is! int || size < 0)) return null;
      if (!_isSafeArtifactMetadata(rawArtifact)) return null;
      artifact = Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(rawArtifact),
      );
    }
    return BrowserProgressMessage(
      eventId: eventId,
      sequence: sequence,
      serverId: serverId,
      sessionId: sessionId,
      browserSessionId: browserSessionId,
      runId: runId,
      planRevision: planRevision,
      authorizationRevision: authorizationRevision,
      phase: phase,
      safeSiteDisplay: site,
      safeProgressText: progress,
      artifactSafeSummary: artifact,
      terminal: json['terminal'] as bool,
    );
  }
}

bool _isSafeProgressSiteDisplay(String value) {
  if (value.isEmpty) return true;
  if (value.contains('?') || value.contains('#')) return false;
  final uri = Uri.tryParse(value);
  return uri != null &&
      const <String>{'http', 'https'}.contains(uri.scheme) &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/');
}

bool _isSafeArtifactMetadata(Map<dynamic, dynamic> value) {
  final artifactId = value['artifact_id'];
  if (artifactId != null &&
      (artifactId is! String ||
          !RegExp(r'^web_[0-9a-f]{32}$').hasMatch(artifactId))) {
    return false;
  }
  final mime = value['mime_type'];
  if (mime != null &&
      (mime is! String ||
          mime.length > 160 ||
          !RegExp(r'^[a-z0-9.+-]+/[a-z0-9.+-]+$').hasMatch(mime))) {
    return false;
  }
  final classification = value['classification'];
  if (classification != null &&
      (classification is! String ||
          !const <String>{
            'opaque_content',
            'active_content',
            'archive_content',
          }.contains(classification))) {
    return false;
  }
  return true;
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
  final String clientRequestId;
  final String turnId;
  final String messageId;
  final String? delta;
  final bool done;
  final bool error;

  /// Legacy marker for a terminal (done/error) frame that arrived WITHOUT a
  /// conversation_id. Current correlation rules ignore those ambiguous frames
  /// before they can clear pending state; [conversationId] is empty if one ever
  /// reaches listeners.
  final bool untagged;
  const ConvStreamEvent(
    this.conversationId, {
    this.clientRequestId = '',
    this.turnId = '',
    this.messageId = '',
    this.delta,
    this.done = false,
    this.error = false,
    this.untagged = false,
  });
}

/// Busy-state update for one conversation (WOR-103). Delivered on its own
/// stream so the sealed chat message switch remains unchanged.
class ConversationBusyEvent {
  final String conversationId;
  final bool busy;
  final String message;
  final String clientRequestId;
  final String turnId;

  const ConversationBusyEvent({
    required this.conversationId,
    required this.busy,
    this.message = '',
    this.clientRequestId = '',
    this.turnId = '',
  });
}

/// Per-conversation accumulation of a streamed reply (WOR-53). Holds the text
/// streamed so far for one conversation plus whether its turn is still live, so
/// a backgrounded conversation's reply survives a screen switch and can be
/// hydrated on return (see [WebSocketService.bufferedText] / [isStreaming]).
class _ConvStreamState {
  final StringBuffer text = StringBuffer();
  bool streaming = false;
  String messageId = '';
}

class _MediaCorrelation {
  const _MediaCorrelation({
    required this.requestId,
    required this.turnId,
    required this.messageId,
  });

  final String requestId;
  final String turnId;
  final String messageId;
}

/// Live status of a single MCP server (WOR-44 Phase 4), one entry of an
/// `mcp_status` frame's `servers` map. [status] is one of `disconnected`,
/// `connecting`, `connected`, `failed`; [error] is a short failure message
/// (`''` when none); [tools] is the count of tools the server exposes.
class McpServerStatus {
  final String status;
  final String error;
  final int tools;
  const McpServerStatus({
    required this.status,
    this.error = '',
    this.tools = 0,
  });

  factory McpServerStatus.fromJson(Map<String, dynamic> json) {
    final raw = (json['status'] ?? '').toString().trim();
    return McpServerStatus(
      status: raw.isEmpty ? 'disconnected' : raw,
      error: (json['error'] ?? '').toString(),
      tools: json['tools'] is num ? (json['tools'] as num).toInt() : 0,
    );
  }
}

/// A live MCP connector status push (`mcp_status`, WOR-44 Phase 4). Like
/// [ConfigData], [HeartbeatDataMessage] and the other standalone stream
/// messages, this is deliberately NOT part of the sealed [OsiaMessage]
/// hierarchy: chat_screen.dart switches over OsiaMessage exhaustively with no
/// `default`, so adding a sealed subtype would break its compile (and CLAUDE.md
/// forbids touching that path). It rides its own
/// [WebSocketService.mcpStatusStream], exactly like config/heartbeat.
///
/// The server pushes a frame on every status transition (scoped to the
/// changing server) and replies with the full set to a `mcp_status` request,
/// so consumers MERGE [servers] into their local view rather than replacing it.
class McpStatusMessage {
  /// `{serverId: status}` for the servers this frame reports.
  final Map<String, McpServerStatus> servers;
  const McpStatusMessage(this.servers);

  factory McpStatusMessage.fromJson(Map<String, dynamic> json) {
    final out = <String, McpServerStatus>{};
    final raw = json['servers'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) {
          out[k.toString()] = McpServerStatus.fromJson(
            v.cast<String, dynamic>(),
          );
        }
      });
    }
    return McpStatusMessage(out);
  }
}

/// An OAuth authorization URL for an MCP connector (`mcp_oauth_url`, WOR-96
/// PART 2b). The server sends this to the requesting connection ONLY (never
/// broadcast) after an `mcp_connect` on an OAuth connector, carrying the
/// connector [id] and the provider authorization [url]. The URL is public (no
/// secret) — safe to open in an external browser. Delivered on its own
/// [WebSocketService.mcpOauthUrlStream], NOT through the sealed [OsiaMessage]
/// hierarchy, exactly like `mcp_status` / `config`.
class McpOauthUrl {
  final String id;
  final String url;
  final String? requestId;
  final String? attemptId;
  final double? expiresAt;
  const McpOauthUrl({
    required this.id,
    required this.url,
    this.requestId,
    this.attemptId,
    this.expiresAt,
  });
}

/// A write-tool confirmation request (`mcp_confirm_request`, WOR-44 Phase 5).
/// The server sends this to the originating client when a *write* MCP tool is
/// about to run on a mobile-initiated turn, and BLOCKS the agent until the
/// client replies with [WebSocketService.sendMcpConfirmResponse] carrying the
/// SAME [id]. On timeout (120s) / disconnect / no-response the server denies.
///
/// Like [ConfigData], [McpStatusMessage] and the other standalone stream
/// messages, this is deliberately NOT part of the sealed [OsiaMessage]
/// hierarchy: chat_screen.dart switches over OsiaMessage exhaustively with no
/// `default`, so adding a sealed subtype would break its compile (and CLAUDE.md
/// forbids touching that path). It rides its own
/// [WebSocketService.mcpConfirmStream], exactly like config/heartbeat/mcp_status.
class McpConfirmRequest {
  /// Correlation id — echoed back verbatim in the response so the server can
  /// match the reply to the blocked tool call.
  final String id;

  /// MCP server (connector) the tool belongs to, for display.
  final String server;

  /// The write tool about to run, for display.
  final String tool;

  /// A human-readable, secret-free summary of the call — argument NAMES only,
  /// never values. Coerced to a single line: the server may send a string, a
  /// list of arg names, or a `{arg: …}` map.
  final String summary;

  /// Additive WOR-193 discriminator.  The only reinforced value understood by
  /// mobile is PC-only and is never approvable here.
  final String confirmationKind;
  final bool canApprove;
  final int filesCount;
  final int foldersCount;
  final int totalBytes;
  final int rootCount;
  final String safeReason;
  final double? expiresAt;

  bool get isPcOnlyColossalDeletion =>
      confirmationKind == 'colossal_deletion_pc_only';

  const McpConfirmRequest({
    required this.id,
    required this.server,
    required this.tool,
    required this.summary,
    this.confirmationKind = 'ordinary',
    this.canApprove = true,
    this.filesCount = 0,
    this.foldersCount = 0,
    this.totalBytes = 0,
    this.rootCount = 0,
    this.safeReason = '',
    this.expiresAt,
  });

  factory McpConfirmRequest.fromJson(Map<String, dynamic> json) {
    String coerceSummary(dynamic raw) {
      if (raw is String) return raw;
      if (raw is List) {
        return raw
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .join(', ');
      }
      if (raw is Map) {
        return raw.keys
            .map((k) => k.toString())
            .where((s) => s.isNotEmpty)
            .join(', ');
      }
      return raw?.toString() ?? '';
    }

    int safeCount(dynamic raw) {
      if (raw is! num || !raw.isFinite) return 0;
      final value = raw.toInt();
      return value < 0 ? 0 : value;
    }

    final kind = (json['confirmation_kind'] ?? 'ordinary').toString();
    final pcOnly = kind == 'colossal_deletion_pc_only';
    return McpConfirmRequest(
      id: (json['id'] ?? '').toString(),
      server: (json['server'] ?? '').toString(),
      tool: (json['tool'] ?? '').toString(),
      summary: coerceSummary(json['summary']),
      confirmationKind: kind,
      // A reinforced request is fail-closed regardless of a contradictory
      // server field. Unknown kinds still honor an explicit non-approvable bit.
      canApprove: pcOnly ? false : json['can_approve'] != false,
      filesCount: safeCount(json['files_count']),
      foldersCount: safeCount(json['folders_count']),
      totalBytes: safeCount(json['total_bytes']),
      rootCount: safeCount(json['root_count']),
      safeReason: (json['safe_reason'] ?? '').toString(),
      expiresAt: json['expires_at'] is num
          ? (json['expires_at'] as num).toDouble()
          : null,
    );
  }
}

// ── WebSocket service ─────────────────────────────────────────────────────

const int permissionSnapshotSchemaVersion = 1;
const Set<String> permissionCategoryKeys = <String>{
  'files_modify',
  'files_delete',
  'commands',
  'browser_account',
  'connectors',
  'send_publish_submit',
  'purchases_payments',
  'autonomous_actions',
  'scheduled_actions',
};

bool _hasExactStringKeys(Map<Object?, Object?> value, Set<String> keys) =>
    value.length == keys.length && value.keys.every(keys.contains);

bool _isPermissionOpaqueId(Object? value) =>
    value is String &&
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$').hasMatch(value);

String _newPermissionDeviceId() =>
    'permission-device-${WebSocketService.newClientRequestId()}';

enum PermissionRevocationOperation {
  revokeTemporaryPermission('revoke_temporary_permission'),
  revokeAutonomousRun('revoke_autonomous_run'),
  revokeScheduledTask('revoke_scheduled_task'),
  revokeAllDelegatedAuthority('revoke_all_delegated_authority'),
  disableFullAccess('disable_full_access');

  const PermissionRevocationOperation(this.wireValue);
  final String wireValue;
}

class PermissionTemporaryItem {
  const PermissionTemporaryItem({
    required this.actionLabel,
    required this.context,
    required this.expiresAt,
    required this.remainingUses,
    required this.mobileItemId,
    required this.revocable,
  });

  final String actionLabel;
  final String context;
  final double? expiresAt;
  final int? remainingUses;
  final String mobileItemId;
  final bool revocable;
}

class PermissionHistoryEvent {
  const PermissionHistoryEvent({
    required this.timestamp,
    required this.event,
    required this.context,
  });

  final double timestamp;
  final String event;
  final String context;
}

class PermissionPendingRequestState {
  const PermissionPendingRequestState({
    required this.requestId,
    required this.status,
  });

  final String requestId;
  final String status;
}

class PermissionSnapshot {
  const PermissionSnapshot({
    required this.snapshotId,
    required this.serverId,
    required this.sessionId,
    required this.policyEpoch,
    required this.sequence,
    required this.generatedAt,
    required this.preset,
    required this.categories,
    required this.fullAccessActive,
    required this.protectedStoreAvailable,
    required this.temporaryPermissions,
    required this.history,
    required this.pendingRequests,
  });

  final String snapshotId;
  final String serverId;
  final String sessionId;
  final int policyEpoch;
  final int sequence;
  final double generatedAt;
  final String preset;
  final Map<String, bool> categories;
  final bool fullAccessActive;
  final bool protectedStoreAvailable;
  final List<PermissionTemporaryItem> temporaryPermissions;
  final List<PermissionHistoryEvent> history;
  final List<PermissionPendingRequestState> pendingRequests;

  static PermissionSnapshot? tryParse(Map<String, dynamic> json) {
    const topKeys = <String>{
      'type',
      'schema_version',
      'snapshot_id',
      'server_id',
      'session_id',
      'policy_epoch',
      'sequence',
      'generated_at',
      'preset',
      'categories',
      'full_access_active',
      'protected_store',
      'temporary_permissions',
      'history',
      'pending_requests',
    };
    if (!_hasExactStringKeys(json, topKeys) ||
        json['type'] != 'permission_snapshot' ||
        json['schema_version'] != permissionSnapshotSchemaVersion ||
        !_isPermissionOpaqueId(json['snapshot_id']) ||
        !_isPermissionOpaqueId(json['server_id']) ||
        !_isPermissionOpaqueId(json['session_id'])) {
      return null;
    }
    final epoch = json['policy_epoch'];
    final sequence = json['sequence'];
    final generatedAt = json['generated_at'];
    final preset = json['preset'];
    final protectedStore = json['protected_store'];
    if (epoch is! int ||
        epoch < 0 ||
        sequence is! int ||
        sequence < 1 ||
        generatedAt is! num ||
        !generatedAt.toDouble().isFinite ||
        generatedAt < 0 ||
        !const <String>{
          'default_access',
          'full_access',
          'mixed',
        }.contains(preset) ||
        !const <String>{'available', 'unavailable'}.contains(protectedStore) ||
        json['full_access_active'] is! bool) {
      return null;
    }
    final rawCategories = json['categories'];
    if (rawCategories is! Map ||
        !_hasExactStringKeys(rawCategories, permissionCategoryKeys) ||
        rawCategories.values.any((value) => value is! bool)) {
      return null;
    }
    final categories = <String, bool>{
      for (final key in permissionCategoryKeys) key: rawCategories[key] as bool,
    };

    final rawPermissions = json['temporary_permissions'];
    if (rawPermissions is! List) return null;
    final permissions = <PermissionTemporaryItem>[];
    const permissionKeys = <String>{
      'action_label',
      'context',
      'expires_at',
      'remaining_uses',
      'mobile_item_id',
      'revocable',
    };
    for (final raw in rawPermissions) {
      if (raw is! Map || !_hasExactStringKeys(raw, permissionKeys)) return null;
      final actionLabel = raw['action_label'];
      final context = raw['context'];
      final expiresAt = raw['expires_at'];
      final remainingUses = raw['remaining_uses'];
      if (!_isPermissionOpaqueId(actionLabel) ||
          !const <String>{
            'chat',
            'autonomous',
            'scheduled',
          }.contains(context) ||
          !_isPermissionOpaqueId(raw['mobile_item_id']) ||
          raw['revocable'] is! bool ||
          (expiresAt != null &&
              (expiresAt is! num || !expiresAt.toDouble().isFinite)) ||
          (remainingUses != null &&
              (remainingUses is! int || remainingUses < 0))) {
        return null;
      }
      permissions.add(
        PermissionTemporaryItem(
          actionLabel: actionLabel as String,
          context: context as String,
          expiresAt: expiresAt == null ? null : (expiresAt as num).toDouble(),
          remainingUses: remainingUses as int?,
          mobileItemId: raw['mobile_item_id'] as String,
          revocable: raw['revocable'] as bool,
        ),
      );
    }

    final rawHistory = json['history'];
    if (rawHistory is! List) return null;
    final history = <PermissionHistoryEvent>[];
    const historyKeys = <String>{'timestamp', 'event', 'context'};
    for (final raw in rawHistory) {
      if (raw is! Map || !_hasExactStringKeys(raw, historyKeys)) return null;
      final timestamp = raw['timestamp'];
      if (timestamp is! num ||
          !timestamp.toDouble().isFinite ||
          !_isPermissionOpaqueId(raw['event']) ||
          raw['context'] is! String ||
          !const <String>{
            '',
            'chat',
            'autonomous',
            'scheduled',
          }.contains(raw['context'])) {
        return null;
      }
      history.add(
        PermissionHistoryEvent(
          timestamp: timestamp.toDouble(),
          event: raw['event'] as String,
          context: raw['context'] as String,
        ),
      );
    }

    final rawPending = json['pending_requests'];
    if (rawPending is! List) return null;
    final pending = <PermissionPendingRequestState>[];
    const pendingKeys = <String>{'request_id', 'status'};
    for (final raw in rawPending) {
      if (raw is! Map ||
          !_hasExactStringKeys(raw, pendingKeys) ||
          !_isPermissionOpaqueId(raw['request_id']) ||
          !const <String>{
            'pending',
            'applied',
            'idempotent',
            'rejected',
            'unknown',
          }.contains(raw['status'])) {
        return null;
      }
      pending.add(
        PermissionPendingRequestState(
          requestId: raw['request_id'] as String,
          status: raw['status'] as String,
        ),
      );
    }

    return PermissionSnapshot(
      snapshotId: json['snapshot_id'] as String,
      serverId: json['server_id'] as String,
      sessionId: json['session_id'] as String,
      policyEpoch: epoch,
      sequence: sequence,
      generatedAt: generatedAt.toDouble(),
      preset: preset as String,
      categories: Map<String, bool>.unmodifiable(categories),
      fullAccessActive: json['full_access_active'] as bool,
      protectedStoreAvailable: protectedStore == 'available',
      temporaryPermissions: List<PermissionTemporaryItem>.unmodifiable(
        permissions,
      ),
      history: List<PermissionHistoryEvent>.unmodifiable(history),
      pendingRequests: List<PermissionPendingRequestState>.unmodifiable(
        pending,
      ),
    );
  }
}

class PermissionRevocationAck {
  const PermissionRevocationAck({
    required this.requestId,
    required this.serverId,
    required this.sessionId,
    required this.basePolicyEpoch,
    required this.baseSnapshotSequence,
    required this.status,
    required this.reason,
    required this.policyEpoch,
  });

  final String requestId;
  final String serverId;
  final String sessionId;
  final int basePolicyEpoch;
  final int baseSnapshotSequence;
  final String status;
  final String reason;
  final int policyEpoch;

  bool get succeeded => status == 'applied' || status == 'idempotent';

  static PermissionRevocationAck? tryParse(Map<String, dynamic> json) {
    const keys = <String>{
      'type',
      'schema_version',
      'request_id',
      'server_id',
      'session_id',
      'base_policy_epoch',
      'base_snapshot_sequence',
      'status',
      'reason',
      'policy_epoch',
    };
    if (!_hasExactStringKeys(json, keys) ||
        json['type'] != 'permission_revocation_ack' ||
        json['schema_version'] != permissionSnapshotSchemaVersion ||
        !_isPermissionOpaqueId(json['request_id']) ||
        !_isPermissionOpaqueId(json['server_id']) ||
        !_isPermissionOpaqueId(json['session_id']) ||
        !_isPermissionOpaqueId(json['reason']) ||
        !const <String>{
          'applied',
          'idempotent',
          'rejected',
        }.contains(json['status'])) {
      return null;
    }
    final baseEpoch = json['base_policy_epoch'];
    final baseSequence = json['base_snapshot_sequence'];
    final epoch = json['policy_epoch'];
    if (baseEpoch is! int ||
        baseEpoch < 0 ||
        baseSequence is! int ||
        baseSequence < 1 ||
        epoch is! int ||
        epoch < 0) {
      return null;
    }
    return PermissionRevocationAck(
      requestId: json['request_id'] as String,
      serverId: json['server_id'] as String,
      sessionId: json['session_id'] as String,
      basePolicyEpoch: baseEpoch,
      baseSnapshotSequence: baseSequence,
      status: json['status'] as String,
      reason: json['reason'] as String,
      policyEpoch: epoch,
    );
  }
}

class _PendingPermissionRevocation {
  const _PendingPermissionRevocation({
    required this.sessionId,
    required this.policyEpoch,
    required this.snapshotSequence,
    required this.targetId,
  });

  final String sessionId;
  final int policyEpoch;
  final int snapshotSequence;
  final String targetId;
}

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
  String _clientLocale = '';
  String _autonomousAuthorizationOrigin = '';
  String _scheduledAuthorizationOrigin = '';
  final String _permissionDeviceId = _newPermissionDeviceId();
  String _permissionSessionId = '';
  final Set<String> _retiredPermissionSessionIds = <String>{};
  int _lastPermissionSequence = 0;
  int _lastPermissionEpoch = -1;
  bool _permissionsLive = false;
  PermissionSnapshot? _permissionSnapshot;
  final Map<String, _PendingPermissionRevocation>
  _pendingPermissionRevocations = <String, _PendingPermissionRevocation>{};
  String _autonomousProgressSessionId = '';
  String _autonomousProgressRunId = '';
  final Set<String> _retiredAutonomousProgressSessions = <String>{};
  int _lastAutonomousProgressSequence = 0;
  int _lastAutonomousPlanRevision = -1;
  int _lastAutonomousAuthorizationRevision = -1;
  bool _autonomousTerminalSeen = false;
  bool _autonomousProgressLive = false;
  bool _awaitingAutonomousSnapshot = true;
  bool _expectNewAutonomousRun = false;
  AutonomousProgressMessage? _autonomousProgress;
  String _browserProgressSessionId = '';
  String _browserProgressRunId = '';
  final Set<String> _retiredBrowserProgressSessions = <String>{};
  int _lastBrowserProgressSequence = 0;
  int _lastBrowserPlanRevision = -1;
  int _lastBrowserAuthorizationRevision = -1;
  bool _browserTerminalSeen = false;
  bool _browserProgressLive = false;
  BrowserProgressMessage? _browserProgress;
  String _documentProgressSessionId = '';
  final Set<String> _retiredDocumentProgressSessions = <String>{};
  final Map<String, int> _lastDocumentSequence = <String, int>{};
  final Map<String, int> _lastDocumentRevision = <String, int>{};
  final Map<String, int> _lastDocumentPhaseRank = <String, int>{};
  final Set<String> _terminalDocumentItems = <String>{};
  final Set<String> _knownDocumentScopes = <String>{};
  final Set<String> _canonicalTerminalDocumentScopes = <String>{};
  final Map<String, DocumentProgressMessage> _documentProgress =
      <String, DocumentProgressMessage>{};
  bool _documentProgressLive = false;
  bool _awaitingDocumentSnapshot = true;
  final Set<String> _seenProgressEventIds = <String>{};
  final Queue<String> _progressEventOrder = Queue<String>();

  /// Set the optional UI locale carried by subsequent user-turn frames.
  /// The server remains authoritative and safely ignores unsupported values.
  void setClientLocale(String? locale) {
    final candidate = (locale ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('_', '-')
        .split(RegExp(r'[.@]'))
        .first;
    if (!RegExp(r'^[a-z]{2,3}(?:-[a-z0-9]{2,8})*$').hasMatch(candidate)) {
      _clientLocale = '';
      return;
    }
    _clientLocale = candidate;
  }

  /// Whether the service silently reconnects after an unexpected close.
  ///
  /// The chat screen wants this (a flaky network shouldn't kill the
  /// session). The connection screen's token *probe* sets it to `false`:
  /// there, a server-initiated close is the definitive "token rejected"
  /// signal and must surface immediately instead of being masked by an
  /// endless connect/close/reconnect loop.
  final bool autoReconnect;

  WebSocketChannel? _channel;
  LanDirectTransport? _lanTransport;
  WebRtcDirectTransport? _webRtcTransport;
  bool _connectedViaLan = false;
  bool _connectedViaWebRtc = false;
  final ApplicationTransportCoordinator _transportCoordinator =
      applicationTransportCoordinator;
  ApplicationTransportLease? _transportLease;
  ApplicationTransportKind? _lastTransportKind;
  Timer? _reconnectTimer;
  Future<void>? _connectFuture;
  Completer<void>? _connectCompleter;
  Future<void> _transportCleanup = Future<void>.value();
  int _reconnectAttempt = 0;
  int _connectGeneration = 0;
  int _socketGeneration = 0;
  bool _intentionalClose = false;
  bool _suppressReconnectOnce = false;
  bool _disposed = false;
  int _debugConnectAttemptCount = 0;

  static const int _baseReconnectMs = 500;
  static const Duration _connectTimeout = Duration(seconds: 10);
  static const Duration _relayReadyTimeout = Duration(seconds: 5);
  static const Duration _relayNativePingInterval = Duration(seconds: 25);

  // ── Streams ───────────────────────────────────────────────────────────

  final StreamController<ConnectionState> _connectionCtrl =
      StreamController<ConnectionState>.broadcast();

  final StreamController<OsiaMessage> _messageCtrl =
      StreamController<OsiaMessage>.broadcast();

  final StreamController<String> _errorCtrl =
      StreamController<String>.broadcast();

  final StreamController<RelayTransferEvent> _relayTransferCtrl =
      StreamController<RelayTransferEvent>.broadcast();

  final StreamController<ConfigData> _configCtrl =
      StreamController<ConfigData>.broadcast();

  final StreamController<PermissionSnapshot> _permissionSnapshotCtrl =
      StreamController<PermissionSnapshot>.broadcast();

  final StreamController<PermissionRevocationAck> _permissionAckCtrl =
      StreamController<PermissionRevocationAck>.broadcast();

  final StreamController<ChatGptAccountState> _chatGptAccountCtrl =
      StreamController<ChatGptAccountState>.broadcast();

  ChatGptAccountState _chatGptAccountState = const ChatGptAccountState();
  bool _hasChatGptAccountState = false;
  bool _awaitingAuthenticatedInitialSync = false;

  final StreamController<ApiKeysMessage> _apiKeysCtrl =
      StreamController<ApiKeysMessage>.broadcast();

  final StreamController<MemorySnapshot> _memoryCtrl =
      StreamController<MemorySnapshot>.broadcast();

  final StreamController<MemoryErrorMessage> _memoryErrorCtrl =
      StreamController<MemoryErrorMessage>.broadcast();

  final StreamController<HeartbeatDataMessage> _heartbeatCtrl =
      StreamController<HeartbeatDataMessage>.broadcast();

  final StreamController<NewChatMessage> _newChatCtrl =
      StreamController<NewChatMessage>.broadcast();

  final StreamController<ConversationsListMessage> _conversationsListCtrl =
      StreamController<ConversationsListMessage>.broadcast();

  final StreamController<CronNotificationMessage> _cronNotificationCtrl =
      StreamController<CronNotificationMessage>.broadcast();

  final StreamController<ScheduledTaskAuthorizationEvent>
  _scheduledAuthorizationCtrl =
      StreamController<ScheduledTaskAuthorizationEvent>.broadcast();

  final StreamController<AutonomousProgressMessage> _autonomousCtrl =
      StreamController<AutonomousProgressMessage>.broadcast();

  final StreamController<BrowserProgressMessage> _browserProgressCtrl =
      StreamController<BrowserProgressMessage>.broadcast();

  final StreamController<DocumentProgressMessage> _documentProgressCtrl =
      StreamController<DocumentProgressMessage>.broadcast();

  final StreamController<McpStatusMessage> _mcpStatusCtrl =
      StreamController<McpStatusMessage>.broadcast();

  final StreamController<McpConfirmRequest> _mcpConfirmCtrl =
      StreamController<McpConfirmRequest>.broadcast();

  final StreamController<McpOauthUrl> _mcpOauthUrlCtrl =
      StreamController<McpOauthUrl>.broadcast();

  final StreamController<ConversationBusyEvent> _conversationBusyCtrl =
      StreamController<ConversationBusyEvent>.broadcast();

  final StreamController<AttachmentProtocolMessage> _attachmentProtocolCtrl =
      StreamController<AttachmentProtocolMessage>.broadcast();

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

  /// Conversations with an in-flight turn (WOR-75/WOR-53/WOR-62, simplified):
  /// a message was sent / chunks are arriving for the conversation and no
  /// terminal `done` / `error` has been received yet. Lives in the long-lived
  /// service so it survives screen switches and reconnects, letting the chat
  /// show an "OSIA is working in the background" placeholder for a pending
  /// conversation the user isn't watching stream live. Added on send
  /// ([markPending]) and on the first streamed frame
  /// ([_appendConvDelta]/[_replaceConvText]); removed on the terminal frame
  /// ([_finishConvStream]) and on delete/new ([clearConvBuffer]). Superset of
  /// [isStreaming]: it can be set at send time, before the first chunk lands.
  final Set<String> _pendingConvs = {};

  /// Conversations the server/local send path says are currently busy
  /// (WOR-103). This is separate from [_pendingConvs]: pending drives recovery
  /// and stream hydration, while busy gates new sends for the same conversation.
  final Set<String> _busyConvs = {};

  /// Active client_request_id by conversation. This lets a retry of the SAME
  /// request reattach while a genuinely new request stays blocked by busy.
  final Map<String, String> _activeRequestByConv = {};
  final Map<String, String> _activeConvByRequest = {};
  final Set<String> _acceptedRequests = {};
  final Map<String, String> _turnByRequest = <String, String>{};
  final Set<String> _unboundRequestIds = <String>{};
  final Set<String> _seenCronNotifications = {};
  final Set<String> _respondedScheduledAuthorizationRequests = {};
  final Set<String> _seenApplicationEventIds = <String>{};
  final Queue<String> _applicationEventOrder = Queue<String>();
  final Map<String, int> _lastApplicationSequence = <String, int>{};
  final Map<String, _MediaCorrelation> _mediaByConversation =
      <String, _MediaCorrelation>{};

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

  /// Local-only progress/failure events for oversized encrypted relay frames.
  /// Kept outside [messageStream] so the sealed app-message hierarchy and PC
  /// WebSocket protocol remain unchanged.
  Stream<RelayTransferEvent> get relayTransferStream =>
      _relayTransferCtrl.stream;

  /// Stream of full config snapshots (one per `get_config` reply). Kept off
  /// [messageStream] so the chat screen's sealed-message switch is untouched.
  Stream<ConfigData> get configStream => _configCtrl.stream;

  /// Strict, sanitized snapshots from the currently authenticated PC.
  Stream<PermissionSnapshot> get permissionSnapshotStream =>
      _permissionSnapshotCtrl.stream;

  /// Typed PC acknowledgements for locally pending revocation requests.
  Stream<PermissionRevocationAck> get permissionRevocationAckStream =>
      _permissionAckCtrl.stream;

  /// Last accepted canonical state. It is display-only while offline.
  PermissionSnapshot? get permissionSnapshot => _permissionSnapshot;

  /// True only after this connection has accepted a fresh session snapshot.
  bool get permissionsLive =>
      _permissionsLive && _state == ConnectionState.connected;

  Set<String> get pendingPermissionRequestIds =>
      Set<String>.unmodifiable(_pendingPermissionRevocations.keys);

  bool isPermissionItemPending(String mobileItemId) =>
      _pendingPermissionRevocations.values.any(
        (pending) => pending.targetId == mobileItemId,
      );

  /// Sanitized ChatGPT-account status and ephemeral device-code updates.
  Stream<ChatGptAccountState> get chatGptAccountStream =>
      _chatGptAccountCtrl.stream;

  /// Last valid non-sensitive account snapshot, retained across reconnects so
  /// Settings never flashes a fabricated disconnected state while refreshing.
  ChatGptAccountState get chatGptAccountState => _chatGptAccountState;

  /// Stream of raw API-key snapshots (one per `get_api_keys` reply). Kept off
  /// [messageStream] for the same reason as [configStream].
  Stream<ApiKeysMessage> get apiKeysStream => _apiKeysCtrl.stream;

  /// Stream of local OSIA memory snapshots (`memory` / `memory_updated`).
  /// Kept off [messageStream] for the same reason as [configStream].
  Stream<MemorySnapshot> get memoryStream => _memoryCtrl.stream;

  /// Stream of memory validation/storage errors (`memory_error`).
  Stream<MemoryErrorMessage> get memoryErrorStream => _memoryErrorCtrl.stream;

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

  /// Stream of scheduled-task completion/failure notifications.
  Stream<CronNotificationMessage> get cronNotificationStream =>
      _cronNotificationCtrl.stream;

  /// Sanitized scheduled-task authorization requests and state transitions.
  Stream<ScheduledTaskAuthorizationEvent> get scheduledAuthorizationStream =>
      _scheduledAuthorizationCtrl.stream;

  /// Stream of autonomous-run progress frames (`autonomous_progress`, WOR-45
  /// Phase 5). Kept off [messageStream] for the same reason as [configStream].
  Stream<AutonomousProgressMessage> get autonomousStream =>
      _autonomousCtrl.stream;

  /// Latest canonical Autonomous snapshot for screens opened after the
  /// authenticated initial sync has already completed.
  AutonomousProgressMessage? get autonomousProgress => _autonomousProgress;

  /// Strict live browser progress. The cached value is display-only while
  /// [browserProgressLive] is false during reconnect reconciliation.
  Stream<BrowserProgressMessage> get browserProgressStream =>
      _browserProgressCtrl.stream;

  Stream<DocumentProgressMessage> get documentProgressStream =>
      _documentProgressCtrl.stream;

  bool get documentProgressLive =>
      _documentProgressLive && _state == ConnectionState.connected;

  List<DocumentProgressMessage> documentProgressForScope(
    String scopeType,
    String scopeId,
  ) => _documentProgress.values
      .where((item) => item.scopeType == scopeType && item.scopeId == scopeId)
      .toList(growable: false);

  BrowserProgressMessage? get browserProgress => _browserProgress;

  bool get browserProgressLive =>
      _browserProgressLive && _state == ConnectionState.connected;

  bool get autonomousProgressLive =>
      _autonomousProgressLive && _state == ConnectionState.connected;

  /// Stream of live MCP connector status pushes (`mcp_status`, WOR-44 Phase 4).
  /// Kept off [messageStream] for the same reason as [configStream]. Each event
  /// reports a subset of servers (a transition broadcast is scoped to the
  /// changing server; a `mcp_status` request reply carries the full set), so
  /// listeners merge events into their local view.
  Stream<McpStatusMessage> get mcpStatusStream => _mcpStatusCtrl.stream;

  /// Stream of write-tool confirmation requests (`mcp_confirm_request`, WOR-44
  /// Phase 5). Kept off [messageStream] for the same reason as [configStream].
  /// Each event MUST be answered with [sendMcpConfirmResponse] (matching its
  /// id); the server blocks the agent until then, and denies on timeout (120s)
  /// / disconnect.
  Stream<McpConfirmRequest> get mcpConfirmStream => _mcpConfirmCtrl.stream;

  /// Stream of OAuth authorization URLs (`mcp_oauth_url`, WOR-96 PART 2b).
  /// Kept off [messageStream] for the same reason as [configStream] — and so
  /// it never reaches the sealed [OsiaMessage] switch. Each event carries the
  /// connector id and the (public) provider auth URL; the UI opens it in an
  /// external browser. Completion is observed via [mcpStatusStream], not here.
  Stream<McpOauthUrl> get mcpOauthUrlStream => _mcpOauthUrlCtrl.stream;

  /// Stream of per-conversation streamed-reply events (`response_chunk` /
  /// `response` / terminal `status`, WOR-53). Kept off [messageStream] for the
  /// same reason as [configStream]; carries the conversation id so a client can
  /// route a backgrounded stream to the right conversation.
  Stream<ConvStreamEvent> get convStreamStream => _convStreamCtrl.stream;

  /// Stream of per-conversation busy-state changes (WOR-103).
  Stream<ConversationBusyEvent> get conversationBusyStream =>
      _conversationBusyCtrl.stream;

  Stream<AttachmentProtocolMessage> get attachmentProtocolStream =>
      _attachmentProtocolCtrl.stream;

  /// The reply text streamed so far for conversation [id] (WOR-53), for
  /// hydrating the chat when switching to a conversation whose reply streamed
  /// while it was backgrounded. Empty when nothing has streamed for [id].
  String bufferedText(String id) => _streamBuffers[id]?.text.toString() ?? '';

  /// Whether conversation [id]'s reply is still streaming (WOR-53) — i.e. its
  /// turn hasn't hit a terminal `status` (`done` / `error`) yet. Drives
  /// restoring the streaming bubble on switch.
  bool isStreaming(String id) => _streamBuffers[id]?.streaming ?? false;

  /// Whether conversation [id] has an in-flight turn (WOR-75/WOR-53/WOR-62):
  /// a turn was sent / is streaming and hasn't hit a terminal `done` / `error`
  /// yet. Drives the "OSIA is working in the background" placeholder shown for
  /// a pending conversation the user switched back to, or returned to after a
  /// disconnect/sleep. See [markPending] / [_pendingConvs].
  bool isPending(String id) => _pendingConvs.contains(id);

  /// Whether conversation [id] is currently blocked for another send
  /// (WOR-103).
  bool isConversationBusy(String id) => _busyConvs.contains(id);

  static String newClientRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'mobile-${DateTime.now().microsecondsSinceEpoch}-$hex';
  }

  bool isSamePendingRequest(String? conversationId, String clientRequestId) {
    if (clientRequestId.isEmpty) return false;
    final id = conversationId ?? '';
    if (id.isNotEmpty && _activeRequestByConv[id] == clientRequestId) {
      return true;
    }
    return _activeConvByRequest[clientRequestId] != null;
  }

  bool isRequestAccepted(String clientRequestId) =>
      _acceptedRequests.contains(clientRequestId);

  void _rememberRequest(String? conversationId, String clientRequestId) {
    if (clientRequestId.isEmpty) return;
    final id = conversationId ?? '';
    if (id.isNotEmpty) {
      _activeRequestByConv[id] = clientRequestId;
      _activeConvByRequest[clientRequestId] = id;
    } else {
      _unboundRequestIds.add(clientRequestId);
    }
  }

  void _forgetConversationRequest(String conversationId) {
    final req = _activeRequestByConv.remove(conversationId);
    if (req != null) {
      _activeConvByRequest.remove(req);
      _acceptedRequests.remove(req);
      _turnByRequest.remove(req);
    }
  }

  void _forgetRequest(String clientRequestId) {
    if (clientRequestId.isEmpty) return;
    _unboundRequestIds.remove(clientRequestId);
    _acceptedRequests.remove(clientRequestId);
    _turnByRequest.remove(clientRequestId);
    final conversationId = _activeConvByRequest.remove(clientRequestId);
    if (conversationId != null &&
        _activeRequestByConv[conversationId] == clientRequestId) {
      _activeRequestByConv.remove(conversationId);
    }
  }

  void _clearApplicationTurnTracking() {
    _activeRequestByConv.clear();
    _activeConvByRequest.clear();
    _acceptedRequests.clear();
    _turnByRequest.clear();
    _unboundRequestIds.clear();
    _pendingConvs.clear();
    _mediaByConversation.clear();
    for (final conversationId in _busyConvs.toList()) {
      _setConversationBusy(conversationId, false);
    }
  }

  bool _hasLiveConversationTurn(String id) =>
      _pendingConvs.contains(id) ||
      (_streamBuffers[id]?.streaming ?? false) ||
      _busyConvs.contains(id);

  bool _acceptCanonicalApplicationEvent(Map<String, dynamic> json) {
    if (!_directFirstEnabled) return true;
    final type = json['type']?.toString() ?? '';
    final canonicalTypes = <String>{
      'transcript',
      'response',
      'response_chunk',
      'audio',
      'media_status',
      'turn_accepted',
      'turn_status',
      'conversation_busy_changed',
    };
    if (type == 'status' && json['conversation_id'] != null) {
      canonicalTypes.add('status');
    }
    if (!canonicalTypes.contains(type)) return true;
    final conversationId = json['conversation_id']?.toString() ?? '';
    final requestId =
        json['request_id']?.toString() ??
        json['client_request_id']?.toString() ??
        '';
    final turnId = json['turn_id']?.toString() ?? '';
    final eventId = json['event_id']?.toString() ?? '';
    final eventType = json['event_type']?.toString() ?? '';
    final sequence = json['sequence'];
    final terminal = json['terminal'];
    final needsMessageId = type != 'conversation_busy_changed';
    if (conversationId.isEmpty ||
        requestId.isEmpty ||
        turnId.isEmpty ||
        eventId.isEmpty ||
        eventType != type ||
        sequence is! int ||
        sequence <= 0 ||
        terminal is! bool ||
        (needsMessageId && (json['message_id']?.toString() ?? '').isEmpty)) {
      debugPrint('[OSIA WS] rejected incomplete canonical event type=$type');
      return false;
    }
    final media = _mediaByConversation[conversationId];
    final ownsRequest =
        _activeRequestByConv[conversationId] == requestId ||
        _activeConvByRequest[requestId] == conversationId ||
        _unboundRequestIds.contains(requestId) ||
        _acceptedRequests.contains(requestId) ||
        media?.requestId == requestId;
    if (!ownsRequest) {
      debugPrint('[OSIA WS] rejected unowned canonical event type=$type');
      return false;
    }
    final ownedTurn = media?.requestId == requestId
        ? media?.turnId ?? ''
        : _turnByRequest[requestId] ?? '';
    if (ownedTurn.isNotEmpty && ownedTurn != turnId) {
      debugPrint(
        '[OSIA WS] rejected event for a stale canonical turn type=$type',
      );
      return false;
    }
    _turnByRequest.putIfAbsent(requestId, () => turnId);
    if (_seenApplicationEventIds.contains(eventId)) return false;
    final sequenceKey = '$conversationId\u0000$requestId\u0000$turnId';
    final previous = _lastApplicationSequence[sequenceKey] ?? 0;
    if (sequence <= previous) {
      debugPrint('[OSIA WS] rejected stale canonical event type=$type');
      return false;
    }
    _lastApplicationSequence[sequenceKey] = sequence;
    _seenApplicationEventIds.add(eventId);
    _applicationEventOrder.addLast(eventId);
    while (_applicationEventOrder.length > 2048) {
      _seenApplicationEventIds.remove(_applicationEventOrder.removeFirst());
    }
    return true;
  }

  bool _shouldIgnoreConversationFrame(
    String? conversationId, {
    required String clientRequestId,
    required String frameType,
    bool terminal = false,
  }) {
    final id = conversationId ?? '';
    if (id.isEmpty) {
      if (terminal) {
        if (clientRequestId.isNotEmpty &&
            _acceptedRequests.contains(clientRequestId)) {
          return false;
        }
        debugPrint(
          '[OSIA WS] ignored uncorrelated terminal frame type=$frameType '
          'without conversation metadata',
        );
        return true;
      }
      return false;
    }

    final activeReq = _activeRequestByConv[id];
    if (activeReq != null && clientRequestId.isNotEmpty) {
      if (activeReq != clientRequestId) {
        debugPrint(
          '[OSIA WS] ignored stale frame type=$frameType '
          'because a newer request is active',
        );
        return true;
      }
      return false;
    }

    if (terminal && activeReq != null && clientRequestId.isEmpty) {
      debugPrint(
        '[OSIA WS] ignored ambiguous terminal frame type=$frameType '
        'while a request is active',
      );
      return true;
    }

    if (terminal &&
        clientRequestId.isNotEmpty &&
        !_hasLiveConversationTurn(id)) {
      debugPrint(
        '[OSIA WS] ignored late terminal frame type=$frameType '
        'for an inactive conversation',
      );
      return true;
    }

    if (!terminal &&
        frameType != 'turn_accepted' &&
        clientRequestId.isNotEmpty &&
        activeReq == null &&
        !_hasLiveConversationTurn(id)) {
      debugPrint(
        '[OSIA WS] ignored late content frame type=$frameType '
        'for an inactive conversation',
      );
      return true;
    }

    return false;
  }

  void _setConversationBusy(
    String id,
    bool busy, {
    String message = '',
    String clientRequestId = '',
    String turnId = '',
  }) {
    if (id.isEmpty) return;
    if (busy) {
      _busyConvs.add(id);
    } else {
      _busyConvs.remove(id);
    }
    if (!_conversationBusyCtrl.isClosed) {
      _conversationBusyCtrl.add(
        ConversationBusyEvent(
          conversationId: id,
          busy: busy,
          message: message,
          clientRequestId: clientRequestId,
          turnId: turnId,
        ),
      );
    }
  }

  void _handleConversationBusyFrame(Map<String, dynamic> json) {
    final id = json['conversation_id']?.toString() ?? '';
    final reqId =
        json['request_id']?.toString() ??
        json['client_request_id']?.toString() ??
        '';
    final turnId = json['turn_id']?.toString() ?? '';
    if ((json['type'] ?? '').toString() == 'conversation_busy') {
      final message = json['message']?.toString() ?? '';
      _setConversationBusy(
        id,
        true,
        message: message,
        clientRequestId: reqId,
        turnId: turnId,
      );
      return;
    }
    final busy = json['busy'] == true;
    if (busy) {
      if (reqId.isNotEmpty &&
          _shouldIgnoreConversationFrame(
            id,
            clientRequestId: reqId,
            frameType: 'conversation_busy_changed',
          )) {
        return;
      }
      _setConversationBusy(id, true, clientRequestId: reqId, turnId: turnId);
      return;
    }
    if (_shouldIgnoreConversationFrame(
      id,
      clientRequestId: reqId,
      frameType: 'conversation_busy_changed',
      terminal: true,
    )) {
      return;
    }
    final hadTurnState =
        _pendingConvs.contains(id) || (_streamBuffers[id]?.streaming ?? false);
    if (hadTurnState) {
      _finishConvStream(
        id,
        error: false,
        clientRequestId: reqId,
        turnId: turnId,
      );
    } else {
      _setConversationBusy(id, false, clientRequestId: reqId, turnId: turnId);
    }
  }

  void _handleTurnAcceptedFrame(Map<String, dynamic> json) {
    final id = json['conversation_id']?.toString() ?? '';
    final reqId =
        json['request_id']?.toString() ??
        json['client_request_id']?.toString() ??
        '';
    final turnId = json['turn_id']?.toString() ?? '';
    final messageId = json['message_id']?.toString() ?? '';
    final status = json['status']?.toString() ?? 'accepted';
    final frameType = (json['type'] ?? '').toString() == 'turn_status'
        ? 'turn_status'
        : 'turn_accepted';
    final knownTurn = _turnByRequest[reqId] ?? '';
    if (knownTurn.isNotEmpty && turnId.isNotEmpty && knownTurn != turnId) {
      return;
    }
    if (id.isNotEmpty) {
      _unboundRequestIds.remove(reqId);
      if (const <String>{
        'done',
        'error',
        'cancelled',
        'canceled',
        'rejected',
      }.contains(status)) {
        if (_shouldIgnoreConversationFrame(
          id,
          clientRequestId: reqId,
          frameType: 'turn_status',
          terminal: true,
        )) {
          return;
        }
        _markDocumentCanonicalTerminal('chat', turnId);
        _finishConvStream(
          id,
          error: status != 'done',
          clientRequestId: reqId,
          turnId: turnId,
          messageId: messageId,
          keepMediaPhase: _directFirstEnabled && status == 'done',
        );
      } else {
        if (_shouldIgnoreConversationFrame(
          id,
          clientRequestId: reqId,
          frameType: frameType,
        )) {
          return;
        }
        if (reqId.isNotEmpty && turnId.isNotEmpty) {
          _turnByRequest.putIfAbsent(reqId, () => turnId);
        }
        if (reqId.isNotEmpty) _acceptedRequests.add(reqId);
        _rememberRequest(id, reqId);
        _pendingConvs.add(id);
        _setConversationBusy(id, true, clientRequestId: reqId, turnId: turnId);
      }
    } else if (reqId.isNotEmpty) {
      _acceptedRequests.add(reqId);
    }
    _emit(
      TurnAcceptedMessage(
        clientRequestId: reqId,
        turnId: turnId,
        conversationId: id,
        persisted: json['persisted'] == true,
        status: status,
      ),
    );
  }

  @visibleForTesting
  void handleConversationBusyFrameForTest(Map<String, dynamic> json) {
    _handleConversationBusyFrame(json);
  }

  @visibleForTesting
  void handleIncomingFrameForTest(Map<String, dynamic> json) {
    _onData(json);
  }

  @visibleForTesting
  void setPermissionConnectionForTest(bool connected) {
    if (connected) {
      _beginPermissionReconnect();
      _setState(ConnectionState.connected);
    } else {
      _markPermissionsOffline();
      _setState(ConnectionState.disconnected);
    }
  }

  @visibleForTesting
  String get expectedPermissionServerIdForTest => _expectedPermissionServerId;

  @visibleForTesting
  String get permissionDeviceIdForTest => _permissionDeviceId;

  @visibleForTesting
  void rememberRequestForTest(String conversationId, String clientRequestId) {
    _rememberRequest(conversationId, clientRequestId);
    if (conversationId.isNotEmpty) _pendingConvs.add(conversationId);
  }

  @visibleForTesting
  void expectAuthenticatedInitialSyncForTest() {
    _awaitingAuthenticatedInitialSync = true;
  }

  @visibleForTesting
  void handleRelayEnvelopeForTest(Map<String, dynamic> envelope) {
    _onRelayData(jsonEncode(envelope));
  }

  @visibleForTesting
  Future<Map<String, Object?>> buildRelayEncryptedEnvelopeForTest(
    Map<String, dynamic> frame, {
    required RelayConnectionConfig config,
    required RelaySessionKeys keys,
    required int seq,
  }) {
    return _buildRelayEncryptedEnvelope(
      frame,
      config: config,
      keys: keys,
      seq: seq,
      priority: relayFramePriority(frame),
      finalFrame: relayFrameIsFinal(frame),
    );
  }

  @visibleForTesting
  Future<Map<String, dynamic>?> decryptRelayEnvelopeForTest(
    Map<String, dynamic> envelope, {
    required RelaySessionKeys keys,
    SequenceReplayGuard? replayGuard,
  }) async {
    try {
      final frame = await decryptFrame(
        envelope,
        keys: keys,
        direction: RelayCryptoDirection.pcToMobile,
        replayGuard: replayGuard,
        replayKey: 'pc',
      );
      return frame.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  /// Mark conversation [id]'s turn as in flight at SEND time (WOR-75/WOR-53/
  /// WOR-62) — before the first streamed chunk lands, so switching away and
  /// straight back shows the background placeholder rather than a blank view.
  /// The first chunk ([_appendConvDelta]) / full reply ([_replaceConvText])
  /// also mark it, and the terminal frame ([_finishConvStream]) clears it, so
  /// this is idempotent and self-clearing. No-op for an empty id (a brand-new
  /// conversation has no id until the server assigns one; its first streamed
  /// chunk carries the id and marks it then).
  void markPending(String id) {
    if (id.isNotEmpty) _pendingConvs.add(id);
    if (kOsiaDebugPlaceholder) {
      debugPrint(
        '[OSIA WOR-75] markPending → pending_count=${_pendingConvs.length}',
      );
    }
  }

  /// Drop conversation [id]'s streamed-reply buffer (WOR-53). Called on
  /// delete/new and on switch-away (buffer hygiene), so the buffer map can't
  /// grow unbounded. Never closes [convStreamStream] — that happens only in
  /// [dispose].
  ///
  /// WOR-75: this drops ONLY the disposable per-turn stream buffer; it does NOT
  /// touch the [_pendingConvs] flag. The two are deliberately separate concerns:
  /// the buffer is throwaway chunk text, while the pending flag means "this
  /// conversation's turn is still in flight" and must SURVIVE a switch-away so
  /// the "OSIA is working in the background" placeholder shows when the user
  /// returns. Pending is cleared only when the turn actually ends
  /// ([_finishConvStream] on terminal done/error) or, at the delete/new and
  /// recovered-history call sites, explicitly via [clearPending].
  void clearConvBuffer(String id) {
    _streamBuffers.remove(id);
    if (kOsiaDebugPlaceholder) {
      debugPrint(
        '[OSIA WOR-75] clearConvBuffer → buffer dropped, '
        'pending_count=${_pendingConvs.length}',
      );
    }
  }

  /// Clear conversation [id]'s in-flight (pending) flag WITHOUT touching its
  /// stream buffer (WOR-75) — the counterpart to [markPending], for the call
  /// sites where a turn's pending state ends for a reason other than a terminal
  /// stream frame: the conversation was deleted or replaced by a new chat, or
  /// its finished reply was recovered via a `conversation_history` re-fetch. Also
  /// used to clear a stuck pending flag left by an UNTAGGED terminal for the
  /// active conversation. No-op for an empty id.
  void clearPending(String id) {
    if (id.isEmpty) return;
    final removed = _pendingConvs.remove(id);
    if (kOsiaDebugPlaceholder) {
      debugPrint(
        '[OSIA WOR-75] clearPending removed=$removed → '
        'pending_count=${_pendingConvs.length}',
      );
    }
  }

  /// Current connection state.
  ConnectionState _state = ConnectionState.disconnected;
  ConnectionState get state => _state;

  MemorySnapshot? _memorySnapshot;
  MemorySnapshot? get memorySnapshot => _memorySnapshot;

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
  final Future<RelayConnectionConfig> Function()? resolveRelay;
  final bool allowLegacyRendezvousFallback;
  final bool relayFallbackV1;
  final bool lanDirectV1;
  final bool webRtcDirectV1;
  final LanDirectConfig? lanDirectConfig;
  final StorageService? storage;
  final LanDiscoveryService lanDiscoveryService;

  @visibleForTesting
  final Future<bool> Function()? connectAttemptForTest;
  @visibleForTesting
  final bool Function(Map<String, dynamic>)? sendFrameForTest;

  bool _connectedViaRelay = false;
  RelayConnectionConfig? _relayConfig;
  Completer<bool>? _relayReadyCompleter;
  int _relaySeq = 0;
  int _relaySendEpoch = 0;
  Future<void> _relaySendChain = Future<void>.value();
  Future<void> _relayReceiveChain = Future<void>.value();
  int _relayE2eEpoch = 0;
  RelaySessionContext? _relayE2eContext;
  RelaySessionKeys? _relayE2eKeys;
  SequenceReplayGuard _relayE2eReplayGuard = SequenceReplayGuard();
  Map<String, dynamic>? _pendingRelayE2eReadyEnvelope;
  bool _relayInitialE2eHelloSent = false;
  bool _relayPeerContextHelloSent = false;
  bool _relayMobileReadySent = false;
  bool _relayE2eReadySent = false;
  bool _relayPeerE2eReady = false;
  bool _relayPcReady = false;
  bool _relayPairConfirmed = false;
  String _relayCommitAttemptId = '';
  bool _relayCommitSent = false;
  bool _relayCommitConfirmed = false;
  bool _relayCommitAuthorized = false;
  bool _relaySignalingStandby = false;
  bool _relayPcRequiresCommit = false;
  Completer<LanPairingIdentity?>? _lanProvisioningCompleter;
  Completer<WebRtcCapability?>? _webRtcCapabilityCompleter;
  WebRtcCapability? _webRtcCapability;
  int _webRtcAttemptGeneration = 0;
  bool _relayBlocksLegacyFallback = false;
  String? _relayHandshakeFailure;
  int _relayWorkerChunkVersion = 0;
  int _relayWorkerChunkMaxFrameBytes = 0;
  int _relayWorkerChunkMaxCiphertextChars = 0;
  int _relayWorkerChunkMaxTotalBytes = 0;
  int _relayWorkerChunkMaxCount = 0;
  int _relayPeerChunkVersion = 0;
  late final RelayE2eChunkReassembler _relayChunkReassembler;
  final Map<String, String> _relayOutboundChunkRequests = <String, String>{};
  final Map<String, Timer> _relayOutboundChunkTimers = <String, Timer>{};
  String _relayLastOutboundRequestId = '';

  WebSocketService({
    required this.ip,
    required this.token,
    this.autoReconnect = true,
    this.resolveHost,
    this.resolveRelay,
    this.allowLegacyRendezvousFallback = kAllowLegacyRendezvousFallback,
    this.relayFallbackV1 = kRelayFallbackV1,
    this.lanDirectV1 = kLanDirectV1,
    this.webRtcDirectV1 = kWebRtcDirectV1,
    this.lanDirectConfig,
    this.storage,
    LanDiscoveryService? lanDiscoveryService,
    this.connectAttemptForTest,
    this.sendFrameForTest,
  }) : lanDiscoveryService = lanDiscoveryService ?? LanDiscoveryService() {
    debugPrint(
      '[OSIA Direct] LAN enabled=$lanDirectV1 WebRTC enabled=$webRtcDirectV1',
    );
    _relayChunkReassembler = RelayE2eChunkReassembler(
      onTimeout: _handleRelayChunkTimeout,
    );
  }

  @visibleForTesting
  int get debugConnectAttemptCount => _debugConnectAttemptCount;

  @visibleForTesting
  bool get hasPendingConnectAttemptForTest => _connectFuture != null;

  @visibleForTesting
  bool get hasReconnectTimerForTest => _reconnectTimer?.isActive == true;

  @visibleForTesting
  bool get hasActiveApplicationTurnForTest => _hasActiveApplicationTurn;

  @visibleForTesting
  bool acquireApplicationTransportForTest(ApplicationTransportKind kind) {
    if (_transportLease != null) return false;
    final lease = _transportCoordinator.tryAcquire(kind, this);
    if (lease == null) return false;
    _transportLease = lease;
    return true;
  }

  @visibleForTesting
  Duration get relayNativePingIntervalForTest => _relayNativePingInterval;

  @visibleForTesting
  Map<String, bool> relayHandshakeStateForTest() => <String, bool>{
    'pc_ready': _relayPcReady,
    'peer_ready': _relayPeerE2eReady,
    'context_ready': _relayE2eContext != null,
    'keys_ready': _relayE2eKeys != null,
  };

  @visibleForTesting
  int relayInflightChunksForTest() => _relayChunkReassembler.inflightCount;

  // ── Public API ───────────────────────────────────────────────────────

  /// Open the WebSocket connection. Safe to call multiple times.
  void connect() {
    unawaited(ensureConnected(reason: 'connect'));
  }

  /// Open, or reopen, the WebSocket connection using a single shared attempt.
  ///
  /// Multiple callers (app resume, settings, chat retry, reconnect timer) all
  /// await the same in-flight connection instead of racing separate sockets.
  /// [forceReconnect] is used on app resume after backgrounding, where the OS
  /// can leave a stale socket looking connected until the next write.
  Future<void> ensureConnected({
    String reason = 'unspecified',
    bool forceReconnect = false,
  }) {
    if (_disposed) return Future<void>.value();

    final inFlight = _connectFuture;
    if (inFlight != null) return inFlight;

    final alreadyConnected =
        _state == ConnectionState.connected &&
        (_channel != null ||
            _lanTransport?.active == true ||
            _webRtcTransport?.active == true);
    if (alreadyConnected && !forceReconnect) {
      return Future<void>.value();
    }

    _intentionalClose = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final connectGeneration = ++_connectGeneration;
    _debugConnectAttemptCount++;
    debugPrint('[OSIA WS] ensureConnected($reason)');

    final completer = Completer<void>();
    final future = completer.future;
    _connectCompleter = completer;
    _connectFuture = future;
    unawaited(
      future.then<void>(
        (_) => _clearConnectAttempt(future, completer),
        onError: (Object _, StackTrace _) =>
            _clearConnectAttempt(future, completer),
      ),
    );

    _beginPermissionReconnect();
    _setState(ConnectionState.connecting);
    unawaited(
      Future<void>.microtask(() async {
        if (!_isCurrentConnect(connectGeneration)) return;
        Future<void> closeBeforeConnect = _transportCleanup;
        if (forceReconnect &&
            (_channel != null ||
                _lanTransport?.active == true ||
                _webRtcTransport?.active == true)) {
          closeBeforeConnect = _closeCurrentChannel(
            reason: 'force reconnect: $reason',
            emitDisconnected: false,
          );
        }
        await closeBeforeConnect;
        if (!_isCurrentConnect(connectGeneration)) return;
        await _doConnect(reason: reason, connectGeneration: connectGeneration);
      }).then<void>(
        (_) {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      ),
    );
    return future;
  }

  /// Close the connection and stop reconnection attempts.
  void disconnect() {
    _intentionalClose = true;
    _autonomousAuthorizationOrigin = '';
    _scheduledAuthorizationOrigin = '';
    _respondedScheduledAuthorizationRequests.clear();
    lanDiscoveryService.stop();
    _connectGeneration++;
    _socketGeneration++;
    _clearChatGptEphemeralLogin();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    final lanTransport = _lanTransport;
    final webRtcTransport = _webRtcTransport;
    final channel = _channel;
    final lease = _transportLease;
    _lanTransport = null;
    _webRtcTransport = null;
    _connectedViaLan = false;
    _connectedViaWebRtc = false;
    _channel = null;
    _transportLease = null;
    _transportCleanup = () async {
      if (lanTransport != null) await lanTransport.close();
      if (webRtcTransport != null) await webRtcTransport.close();
      if (channel != null) {
        try {
          await channel.sink.close();
        } catch (_) {
          // Best-effort intentional shutdown.
        }
      }
      lease?.release();
    }();
    _connectedViaRelay = false;
    _resetRelayE2eState();
    _relayConfig = null;
    _relayReadyCompleter = null;
    _clearApplicationTurnTracking();
    _markPermissionsOffline();
    _setState(ConnectionState.disconnected);
    final connectCompleter = _connectCompleter;
    if (connectCompleter != null && !connectCompleter.isCompleted) {
      connectCompleter.complete();
    }
  }

  /// Send a text command. Returns false when the target conversation is busy.
  bool sendText(
    String content, {
    String? conversationId,
    String? clientRequestId,
    bool ttsEnabled = true,
  }) {
    final id = conversationId ?? '';
    final requestId = clientRequestId ?? newClientRequestId();
    if (id.isNotEmpty &&
        isConversationBusy(id) &&
        _activeRequestByConv[id] != requestId) {
      _setConversationBusy(id, true);
      return false;
    }
    final sent = _send({
      'type': 'text',
      'content': content,
      'conversation_id': id,
      'request_id': requestId,
      'client_request_id': requestId,
      'tts_enabled': ttsEnabled,
      if (_clientLocale.isNotEmpty) 'locale': _clientLocale,
    });
    if (sent) {
      _rememberRequest(id, requestId);
      if (id.isNotEmpty) _setConversationBusy(id, true);
    }
    return sent;
  }

  /// Accept one already-committed attachment batch as a normal text turn.
  /// This remains a `text` application frame so turn correlation, persistence,
  /// model routing and exactly-once handling all use the existing path.
  bool sendAttachmentTurn(
    String content, {
    required String attachmentBatchId,
    required String conversationId,
    required String clientRequestId,
    bool ttsEnabled = true,
    String? expectedTransportSession,
  }) {
    if (attachmentBatchId.isEmpty || clientRequestId.isEmpty) return false;
    if (expectedTransportSession != null &&
        attachmentTransportSession != expectedTransportSession) {
      return false;
    }
    if (conversationId.isNotEmpty &&
        isConversationBusy(conversationId) &&
        _activeRequestByConv[conversationId] != clientRequestId) {
      _setConversationBusy(conversationId, true);
      return false;
    }
    final sent = _send(<String, dynamic>{
      'type': 'text',
      'content': content,
      'conversation_id': conversationId,
      'request_id': clientRequestId,
      'client_request_id': clientRequestId,
      'attachment_batch_id': attachmentBatchId,
      'tts_enabled': ttsEnabled,
      if (_clientLocale.isNotEmpty) 'locale': _clientLocale,
    });
    if (sent) {
      _rememberRequest(conversationId, clientRequestId);
      if (conversationId.isNotEmpty) {
        _setConversationBusy(conversationId, true);
      }
    }
    return sent;
  }

  /// Stable identity of the active application transport. Upload callers
  /// capture it before prepare and reject any reconnect/fallback mid-batch.
  String get attachmentTransportSession {
    final kind = _lastTransportKind;
    if (_state != ConnectionState.connected ||
        _transportLease?.active != true ||
        kind == null) {
      return '';
    }
    return '${kind.name}:$_connectGeneration:$_socketGeneration';
  }

  /// Send one bounded attachment event and wait for the selected transport's
  /// ordered writer/backpressure chain. Existing chat protocol names and send
  /// methods remain unchanged.
  Future<bool> sendAttachmentEvent(
    Map<String, dynamic> frame,
    String expectedTransportSession,
  ) async {
    const allowedTypes = <String>{
      'attachment_batch_prepare',
      'attachment_file_begin',
      'attachment_file_chunk',
      'attachment_file_complete',
      'attachment_batch_commit',
      'attachment_batch_cancel',
    };
    if (!allowedTypes.contains(frame['type']) ||
        expectedTransportSession.isEmpty ||
        attachmentTransportSession != expectedTransportSession) {
      return false;
    }
    if (!_send(frame)) return false;
    try {
      if (_connectedViaLan) {
        await _lanTransport?.drain();
        await Future<void>.delayed(const Duration(milliseconds: 4));
      } else if (_connectedViaWebRtc) {
        await _webRtcTransport?.drain();
      } else if (_connectedViaRelay) {
        await _relaySendChain;
        // The production relay guard permits 2 MiB/s with a 12 MiB burst. A
        // 20 KiB plaintext payload expands under JSON + AEAD/base64, so 24 ms
        // keeps sustained traffic below the byte-rate guard without weakening it.
        await Future<void>.delayed(const Duration(milliseconds: 24));
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 4));
      }
    } on Object {
      return false;
    }
    return attachmentTransportSession == expectedTransportSession;
  }

  /// Send a base64-encoded WAV audio command.
  bool sendAudio(
    String base64Data, {
    String? conversationId,
    String? clientRequestId,
    bool ttsEnabled = true,
  }) {
    final id = conversationId ?? '';
    final requestId = clientRequestId ?? newClientRequestId();
    if (id.isNotEmpty &&
        isConversationBusy(id) &&
        _activeRequestByConv[id] != requestId) {
      _setConversationBusy(id, true);
      return false;
    }
    final sent = _send({
      'type': 'audio',
      'format': 'wav',
      'data': base64Data,
      'conversation_id': id,
      'request_id': requestId,
      'client_request_id': requestId,
      'tts_enabled': ttsEnabled,
      if (_clientLocale.isNotEmpty) 'locale': _clientLocale,
    });
    if (sent) {
      _rememberRequest(id, requestId);
      if (id.isNotEmpty) _setConversationBusy(id, true);
    }
    return sent;
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
    // WOR-75: ...and clear its pending flag (clearConvBuffer no longer does so),
    // so no stale background placeholder lingers for a deleted conversation.
    clearPending(id);
    _forgetConversationRequest(id);
    _setConversationBusy(id, false);
  }

  /// Ask the server to rename conversation [id] to [title] (WOR-76). The server
  /// renames, acks with `{"type":"conversation_renamed", ...}` — which the
  /// client ignores: it lands in [_onData]'s `default` branch and is never
  /// emitted onto the sealed [messageStream] — then broadcasts the updated
  /// `conversations` list to all clients, refreshing the sidebar via the
  /// existing [ConversationsMessage] handler. Additive: touches nothing on the
  /// streaming / pending / reconnect paths.
  void sendRenameConversation(String id, String title) {
    _send({'type': 'rename_conversation', 'id': id, 'title': title});
  }

  /// Ask the server for the list of available models.
  void sendGetModels() {
    _send({'type': 'get_models'});
  }

  /// Tell the server to switch to [model] for subsequent generations.
  void sendSetModel(String model, {String? provider}) {
    _send({'type': 'set_model', 'model': model, 'provider': ?provider});
  }

  void sendSetModelReasoning(String provider, String model, String reasoning) {
    _send({
      'type': 'set_model_reasoning',
      'provider': provider,
      'model': model,
      'reasoning': reasoning,
    });
  }

  void sendGetChatGptAccount() {
    _send({'type': 'get_chatgpt_account'});
  }

  void sendChatGptAccountLogin() {
    _send({'type': 'chatgpt_account_login'});
  }

  void sendCancelChatGptAccountLogin() {
    _send({'type': 'chatgpt_account_cancel_login'});
  }

  void sendChatGptAccountLogout() {
    _send({'type': 'chatgpt_account_logout'});
  }

  /// Ask the server to synthesize [text] over TTS and send the audio back
  /// (the speaker button under an assistant message). Works regardless of
  /// the auto-TTS preference.
  bool sendSpeak(
    String text, {
    required String conversationId,
    required String sourceRequestId,
    required String sourceTurnId,
    required String messageId,
  }) {
    if (!_directFirstEnabled) {
      if (text.isEmpty) return false;
      return _send({'type': 'speak', 'text': text});
    }
    if (conversationId.isEmpty ||
        sourceRequestId.isEmpty ||
        sourceTurnId.isEmpty ||
        messageId.isEmpty ||
        isConversationBusy(conversationId)) {
      return false;
    }
    final preview = text.length > 50 ? '${text.substring(0, 50)}…' : text;
    debugPrint(
      '[OSIA WS] sendSpeak: state=$_state, text_chars=${preview.length}',
    );
    final requestId = newClientRequestId();
    final turnId = 'turn_${newClientRequestId()}';
    _mediaByConversation[conversationId] = _MediaCorrelation(
      requestId: requestId,
      turnId: turnId,
      messageId: messageId,
    );
    _setConversationBusy(
      conversationId,
      true,
      clientRequestId: requestId,
      turnId: turnId,
    );
    final sent = _send({
      'type': 'speak',
      'text': text,
      'conversation_id': conversationId,
      'request_id': requestId,
      'client_request_id': requestId,
      'turn_id': turnId,
      'message_id': messageId,
      'source_request_id': sourceRequestId,
      'source_turn_id': sourceTurnId,
    });
    if (!sent) {
      _mediaByConversation.remove(conversationId);
      _setConversationBusy(conversationId, false);
    }
    return sent;
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

  /// Request a fresh canonical permission snapshot for this authenticated PC.
  bool requestPermissionSnapshot() {
    if (_state != ConnectionState.connected) return false;
    return _send({
      'type': 'get_permission_snapshot',
      'schema_version': permissionSnapshotSchemaVersion,
      'device_id': _permissionDeviceId,
      'pending_request_ids': _pendingPermissionRevocations.keys.toList(),
    });
  }

  /// Submit one non-optimistic, snapshot-bound revocation to the PC authority.
  String? sendPermissionRevocation(
    PermissionRevocationOperation operation, {
    String targetId = '',
  }) {
    final snapshot = _permissionSnapshot;
    if (!permissionsLive || snapshot == null || _permissionSessionId.isEmpty) {
      return null;
    }
    final targeted = <PermissionRevocationOperation>{
      PermissionRevocationOperation.revokeTemporaryPermission,
      PermissionRevocationOperation.revokeAutonomousRun,
      PermissionRevocationOperation.revokeScheduledTask,
    }.contains(operation);
    if (targeted != targetId.isNotEmpty ||
        (targetId.isNotEmpty && !_isPermissionOpaqueId(targetId))) {
      return null;
    }
    final requestId = 'permission-${newClientRequestId()}';
    final pending = _PendingPermissionRevocation(
      sessionId: _permissionSessionId,
      policyEpoch: snapshot.policyEpoch,
      snapshotSequence: snapshot.sequence,
      targetId: targetId,
    );
    final sent = _send({
      'type': 'permission_revocation_request',
      'schema_version': permissionSnapshotSchemaVersion,
      'request_id': requestId,
      'device_id': _permissionDeviceId,
      'session_id': _permissionSessionId,
      'expected_policy_epoch': snapshot.policyEpoch,
      'expected_snapshot_sequence': snapshot.sequence,
      'operation': operation.wireValue,
      'target_id': targetId,
      'expires_at': DateTime.now().millisecondsSinceEpoch / 1000.0 + 30.0,
    });
    if (!sent) return null;
    _pendingPermissionRevocations[requestId] = pending;
    return requestId;
  }

  /// Ask the PC for the raw API keys, to pre-fill the provider editors. The
  /// reply arrives on [apiKeysStream] as an [ApiKeysMessage].
  void sendGetApiKeys() {
    _send({'type': 'get_api_keys'});
  }

  /// Ask the PC for the authoritative local-memory snapshot. The reply arrives
  /// on [memoryStream] as a [MemorySnapshot].
  void requestMemory() {
    _send({'type': 'get_memory'});
  }

  /// Create or update one memory entry through the PC's MemoryStore.
  void upsertMemory(Map<String, dynamic> entry) {
    _send({'type': 'upsert_memory', 'entry': entry});
  }

  /// Delete one memory entry by id.
  void deleteMemory(String id) {
    _send({'type': 'delete_memory', 'id': id});
  }

  /// Clear every local memory entry on the PC after UI confirmation.
  void clearMemory() {
    _send({'type': 'clear_memory'});
  }

  /// Ask the PC for a compact id+title list of stored conversations, to fill
  /// the cron editor's "linked conversation" picker (WOR-24). The reply arrives
  /// on [conversationsListStream] as a [ConversationsListMessage].
  void sendGetConversations() {
    _send({'type': 'get_conversations'});
  }

  /// Ask the PC authority to prepare an exact, revision-bound authorization.
  void sendScheduledTaskAuthorizationRequest(
    Map<String, dynamic> job, {
    int? maxExecutions,
  }) {
    final taskId = (job['id'] ?? job['task_id'] ?? '').toString();
    if (_scheduledAuthorizationOrigin.isEmpty || taskId.isEmpty) return;
    _send({
      'type': 'scheduled_task_authorization_request',
      'task_id': taskId,
      'max_executions': ?maxExecutions,
    });
  }

  bool canRespondToScheduledTaskAuthorization(
    ScheduledTaskAuthorizationEvent event,
  ) {
    final request = event.request;
    if (request == null || _scheduledAuthorizationOrigin.isEmpty) return false;
    final requestId = (request['request_id'] ?? '').toString();
    return requestId.isNotEmpty &&
        !_respondedScheduledAuthorizationRequests.contains(requestId) &&
        request['origin_ref'] == _scheduledAuthorizationOrigin;
  }

  /// Approve or deny the exact sanitized envelope returned by the PC.
  void sendScheduledTaskAuthorizationResponse(
    ScheduledTaskAuthorizationEvent event,
    String action,
  ) {
    if (!canRespondToScheduledTaskAuthorization(event)) return;
    final request = event.request!;
    final requestId = (request['request_id'] ?? '').toString();
    _respondedScheduledAuthorizationRequests.add(requestId);
    _send({
      'type': 'scheduled_task_authorization_response',
      'protocol_version': request['protocol_version'],
      'request_id': requestId,
      'task_id': request['task_id'],
      'task_revision': request['task_revision'],
      'definition_hash': request['definition_hash'],
      'authorization_revision': request['authorization_revision'],
      'policy_epoch': request['policy_epoch'],
      'expiration': request['expiration'],
      'origin_ref': _scheduledAuthorizationOrigin,
      'action': action,
    });
  }

  Map<String, dynamic>? _scheduledTaskControlEnvelope(
    Map<String, dynamic> job,
  ) {
    final taskId = (job['id'] ?? job['task_id'] ?? '').toString();
    final definitionHash = (job['definition_hash'] ?? '').toString();
    if (_scheduledAuthorizationOrigin.isEmpty ||
        taskId.isEmpty ||
        definitionHash.isEmpty) {
      return null;
    }
    return <String, dynamic>{
      'protocol_version': 1,
      'task_id': taskId,
      'task_revision': job['task_revision'],
      'definition_hash': definitionHash,
      'authorization_revision': job['authorization_revision'],
      'policy_epoch': job['policy_epoch'],
      'expiration': job['authorization_expires_at'],
      'origin_ref': _scheduledAuthorizationOrigin,
    };
  }

  void sendScheduledTaskAuthorizationRevoke(Map<String, dynamic> job) {
    final envelope = _scheduledTaskControlEnvelope(job);
    if (envelope == null) return;
    _send({'type': 'scheduled_task_authorization_revoke', ...envelope});
  }

  void sendScheduledTaskDisable(Map<String, dynamic> job) {
    final envelope = _scheduledTaskControlEnvelope(job);
    if (envelope == null) return;
    _send({'type': 'scheduled_task_disable', ...envelope});
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
    sendAutonomousStartWithSources(objective, model, const []);
  }

  bool sendAutonomousStartWithSources(
    String objective,
    String model,
    List<String> documentSources,
  ) {
    final sourcePattern = RegExp(r'^src_[0-9a-f]{32}$');
    if (documentSources.length > 10 ||
        documentSources.toSet().length != documentSources.length ||
        documentSources.any((source) => !sourcePattern.hasMatch(source))) {
      return false;
    }
    _expectNewAutonomousRun = true;
    return _send({
      'type': 'autonomous_start',
      'objective': objective,
      'model': model,
      'document_sources': List<String>.unmodifiable(documentSources),
      if (_clientLocale.isNotEmpty) 'locale': _clientLocale,
    });
  }

  bool sendAutonomousReleaseSources(List<String> documentSources) {
    final sourcePattern = RegExp(r'^src_[0-9a-f]{32}$');
    if (documentSources.isEmpty ||
        documentSources.length > 10 ||
        documentSources.toSet().length != documentSources.length ||
        documentSources.any((source) => !sourcePattern.hasMatch(source))) {
      return false;
    }
    return _send({
      'type': 'autonomous_release_sources',
      'document_sources': List<String>.unmodifiable(documentSources),
    });
  }

  bool canRespondToAutonomousRequest(Map<String, dynamic>? request) {
    if (request == null || _autonomousAuthorizationOrigin.isEmpty) return false;
    if (request['responded'] == true) return false;
    return request['origin_ref'] == _autonomousAuthorizationOrigin;
  }

  Map<String, dynamic> _autonomousResponseEnvelope(
    Map<String, dynamic> request,
    String action,
  ) {
    return {
      'protocol_version': request['protocol_version'],
      'request_id': request['request_id'],
      'run_id': request['run_id'],
      'plan_revision': request['plan_revision'],
      'authorization_revision': request['authorization_revision'],
      'expected_policy_epoch': request['expected_policy_epoch'],
      'origin_ref': _autonomousAuthorizationOrigin,
      'action': action,
    };
  }

  void sendAutonomousAuthorizationResponse(
    AutonomousProgressMessage run,
    String action, {
    List<String>? selectedCapabilityIds,
  }) {
    final request = run.authorizationRequest;
    if (!canRespondToAutonomousRequest(request)) return;
    _send({
      'type': 'autonomous_authorization_response',
      ..._autonomousResponseEnvelope(request!, action),
      'selected_capability_ids': ?selectedCapabilityIds,
    });
  }

  void sendAutonomousScopeExtensionResponse(
    AutonomousProgressMessage run,
    String action,
  ) {
    final request = run.pendingScopeExtension;
    if (!canRespondToAutonomousRequest(request)) return;
    _send({
      'type': 'autonomous_scope_extension_response',
      ..._autonomousResponseEnvelope(request!, action),
    });
  }

  void sendAutonomousAuthorizationRevoke(AutonomousProgressMessage run) {
    if (_autonomousAuthorizationOrigin.isEmpty || run.runId == null) return;
    _send({
      'type': 'autonomous_authorization_revoke',
      'protocol_version': run.protocolVersion,
      'run_id': run.runId,
      'plan_revision': run.planRevision,
      'authorization_revision': run.authorizationRevision,
      'expected_policy_epoch': run.policyEpoch,
      'origin_ref': _autonomousAuthorizationOrigin,
    });
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
    _awaitingAutonomousSnapshot = true;
    _send({'type': 'get_autonomous_status'});
  }

  /// Ask for a fresh value-free browser snapshot after authentication or
  /// reconnect. Cached state stays explicitly non-live until it arrives.
  void sendGetBrowserStatus() {
    _send({'type': 'get_browser_status', 'schema_version': 1});
  }

  void sendGetDocumentStatus() {
    _awaitingDocumentSnapshot = true;
    final scopes = <String>{
      ..._knownDocumentScopes,
      for (final turnId in _turnByRequest.values)
        if (turnId.isNotEmpty) _documentScopeKey('chat', turnId),
      if (_autonomousProgressRunId.isNotEmpty &&
          _autonomousProgressRunId != 'idle')
        _documentScopeKey('autonomous', _autonomousProgressRunId),
    };
    _send({
      'type': 'get_document_status',
      'schema_version': 1,
      'device_id': _permissionDeviceId,
      'scopes': <Map<String, String>>[
        for (final key in scopes.take(8))
          <String, String>{
            'scope_type': key.substring(0, key.indexOf('\u0000')),
            'scope_id': key.substring(key.indexOf('\u0000') + 1),
          },
      ],
    });
  }

  // ── MCP / Connectors (WOR-44 Phase 4) ──
  //
  // The PC accepts these actions and broadcasts `mcp_status` frames (surfaced
  // on [mcpStatusStream]) on every status transition. Purely additive: they
  // reuse the same [_send] path as every other command and touch nothing on
  // the chat / streaming / sealed-message path. The server keeps tokens in its
  // gitignored store (set via [sendSetApiKey] under `mcp:<id>`) and the server
  // list in `settings.json` `mcp_servers` (set via [sendSetSetting], always
  // with `env: {}` — never a token) — these actions only drive connection.

  /// Connect the saved MCP server [id]. The PC immediately broadcasts an
  /// optimistic `connecting` status, then the resolved status when the
  /// handshake settles — both arrive on [mcpStatusStream].
  void sendMcpConnect(String id, {String? requestId}) {
    _send({
      'type': 'mcp_connect',
      'id': id,
      if (requestId != null && requestId.isNotEmpty) 'request_id': requestId,
    });
  }

  /// Disconnect the MCP server [id]. The resolved status arrives on
  /// [mcpStatusStream].
  void sendMcpDisconnect(String id) {
    _send({'type': 'mcp_disconnect', 'id': id});
  }

  /// Cancel an in-flight OAuth connect for the MCP connector [id] (WOR-97):
  /// `{"type":"mcp_oauth_cancel","id":id}`. The server acks `status: done`,
  /// then broadcasts a `disconnected` `mcp_status` on [mcpStatusStream]. It is
  /// a no-op unless the connector is currently `connecting`, carries no secret,
  /// and does NOT change the saved `enabled` flag. (Distinct from
  /// [sendMcpDisconnect] / [sendMcpSignOut], which tear down a live connection
  /// and/or revoke the stored token.)
  void sendMcpOauthCancel(String id, {String? requestId, String? attemptId}) {
    _send({
      'type': 'mcp_oauth_cancel',
      'id': id,
      if (requestId != null && requestId.isNotEmpty) 'request_id': requestId,
      if (attemptId != null && attemptId.isNotEmpty) 'attempt_id': attemptId,
    });
  }

  /// Sign out of an OAuth MCP connector [id] (WOR-96 PART 2b): disconnect AND
  /// revoke the stored token (`{"type":"mcp_disconnect","id":id,"revoke":true}`).
  /// With [forgetClient] true the server also forgets the OAuth client
  /// registration (`"forget_client":true`) so a re-connect can pick a different
  /// account ("switch account"). The resolved status arrives on
  /// [mcpStatusStream]. (Plain disconnect — keep the token — uses
  /// [sendMcpDisconnect] instead.)
  void sendMcpSignOut(String id, {bool forgetClient = false}) {
    _send({
      'type': 'mcp_disconnect',
      'id': id,
      'revoke': true,
      if (forgetClient) 'forget_client': true,
    });
  }

  /// Ask the PC for current MCP connector status. With [id] null the reply
  /// reports every known server; otherwise just that one. The reply arrives on
  /// [mcpStatusStream] as an [McpStatusMessage].
  void sendMcpStatus([String? id]) {
    _send({'type': 'mcp_status', if (id != null && id.isNotEmpty) 'id': id});
  }

  /// Answer a write-tool confirmation request (`mcp_confirm_request`, WOR-44
  /// Phase 5): reply `{"type":"mcp_confirm_response","id":id,"approved":...}`
  /// with the SAME [id] the request carried. The server unblocks the agent and
  /// either runs the tool ([approved] true) or denies it ([approved] false).
  void sendMcpConfirmResponse(String id, bool approved) {
    _send({'type': 'mcp_confirm_response', 'id': id, 'approved': approved});
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
  bool sendFile(
    String filename,
    String base64Data, {
    bool isImage = false,
    String conversationId = '',
    String clientRequestId = '',
    String prompt = '',
  }) {
    final msg = <String, dynamic>{
      'type': 'file',
      'filename': filename,
      'data': base64Data,
      'is_image': isImage,
      'conversation_id': conversationId,
    };
    if (isImage) {
      if (clientRequestId.isEmpty) return false;
      msg['image_base64'] = base64Data;
      msg['request_id'] = clientRequestId;
      msg['client_request_id'] = clientRequestId;
      msg['prompt'] = prompt;
    }
    final sent = _send(msg);
    if (sent && isImage) {
      _rememberRequest(conversationId, clientRequestId);
      if (conversationId.isNotEmpty) {
        _setConversationBusy(conversationId, true);
      }
    }
    return sent;
  }

  /// Free all resources.
  void dispose() {
    if (_disposed) return;
    disconnect();
    _disposed = true;
    _drainTimer?.cancel();
    _drainTimer = null;
    _outQueue.clear();
    _connectionCtrl.close();
    _messageCtrl.close();
    _errorCtrl.close();
    _relayTransferCtrl.close();
    _configCtrl.close();
    _permissionSnapshotCtrl.close();
    _permissionAckCtrl.close();
    _chatGptAccountCtrl.close();
    _apiKeysCtrl.close();
    _memoryCtrl.close();
    _memoryErrorCtrl.close();
    _heartbeatCtrl.close();
    _newChatCtrl.close();
    _conversationsListCtrl.close();
    _cronNotificationCtrl.close();
    _scheduledAuthorizationCtrl.close();
    _autonomousCtrl.close();
    _browserProgressCtrl.close();
    _documentProgressCtrl.close();
    _mcpStatusCtrl.close();
    _mcpConfirmCtrl.close();
    _mcpOauthUrlCtrl.close();
    _conversationBusyCtrl.close();
    _attachmentProtocolCtrl.close();
    _convStreamCtrl.close();
    _streamBuffers.clear();
    _pendingConvs.clear();
    _busyConvs.clear();
    _activeRequestByConv.clear();
    _activeConvByRequest.clear();
    _acceptedRequests.clear();
    _turnByRequest.clear();
    _unboundRequestIds.clear();
    _seenCronNotifications.clear();
    _mediaByConversation.clear();
    _seenApplicationEventIds.clear();
    _applicationEventOrder.clear();
    _lastApplicationSequence.clear();
    _pendingPermissionRevocations.clear();
    _documentProgress.clear();
    _knownDocumentScopes.clear();
    _canonicalTerminalDocumentScopes.clear();
  }

  /// Strip any scheme, path, or port the user may have pasted into the
  /// settings field so we can build a clean `ws://host:8765/ws` URL.
  static String _sanitizeHost(String raw) {
    var s = raw.trim();
    s = s.replaceFirst(RegExp(r'^(wss?|https?)://', caseSensitive: false), '');
    final slash = s.indexOf('/');
    if (slash != -1) s = s.substring(0, slash);
    final colon = s.indexOf(':');
    if (colon != -1) s = s.substring(0, colon);
    return s;
  }

  // ── Internals ────────────────────────────────────────────────────────

  void _releaseTransportLease() {
    final lease = _transportLease;
    _transportLease = null;
    lease?.release();
  }

  bool get _hasActiveApplicationTurn =>
      _activeRequestByConv.isNotEmpty ||
      _acceptedRequests.isNotEmpty ||
      _unboundRequestIds.isNotEmpty ||
      _mediaByConversation.isNotEmpty;

  bool get _directFirstEnabled => lanDirectV1 || webRtcDirectV1;

  bool _isCurrentConnect(int generation) =>
      !_disposed && !_intentionalClose && generation == _connectGeneration;

  void _clearConnectAttempt(Future<void> future, Completer<void> completer) {
    if (identical(_connectFuture, future)) _connectFuture = null;
    if (identical(_connectCompleter, completer)) _connectCompleter = null;
  }

  bool _isCurrentSocket(int generation) =>
      !_disposed && !_intentionalClose && generation == _socketGeneration;

  bool _isValidChatGptAccountSnapshot(Object? raw) {
    if (raw is! Map || raw['connected'] is! bool) return false;
    final providerId = (raw['providerId'] ?? 'chatgpt_account')
        .toString()
        .trim()
        .toLowerCase();
    return providerId == 'chatgpt_account';
  }

  ChatGptAccountState _acceptChatGptAccountSnapshot(
    Object? raw, {
    required bool standalone,
  }) {
    if (!_isValidChatGptAccountSnapshot(raw)) return _chatGptAccountState;
    // A dedicated state reply is newer/more specific than the account copy
    // embedded in a catalogue. Once any valid snapshot is cached, preserve it
    // until the requested dedicated reply arrives; a slower models_list must
    // not roll the UI back during reconnect or refresh.
    if (!standalone && _hasChatGptAccountState) {
      return _chatGptAccountState;
    }
    final state = ChatGptAccountState.fromJson(raw);
    _chatGptAccountState = state;
    _hasChatGptAccountState = true;
    if (!_chatGptAccountCtrl.isClosed) _chatGptAccountCtrl.add(state);
    return state;
  }

  void _clearChatGptEphemeralLogin() {
    _awaitingAuthenticatedInitialSync = false;
    if (!_hasChatGptAccountState) return;
    final current = _chatGptAccountState;
    if (!current.connecting &&
        !current.loginCancellable &&
        current.verificationUrl.isEmpty &&
        current.userCode.isEmpty) {
      return;
    }
    final safe = current.withoutEphemeralLogin();
    _chatGptAccountState = safe;
    if (!_chatGptAccountCtrl.isClosed) _chatGptAccountCtrl.add(safe);
  }

  void _requestAuthenticatedInitialState() {
    if (!_awaitingAuthenticatedInitialSync) return;
    _awaitingAuthenticatedInitialSync = false;
    sendGetChatGptAccount();
    sendGetModels();
    requestPermissionSnapshot();
    sendGetAutonomousStatus();
    sendGetBrowserStatus();
    sendGetDocumentStatus();
  }

  String get _expectedPermissionServerId => sha256
      .convert(utf8.encode('osia-permission-server-v1\u0000$token'))
      .toString();

  bool _rememberProgressEvent(String eventId) {
    if (_seenProgressEventIds.contains(eventId)) return false;
    _seenProgressEventIds.add(eventId);
    _progressEventOrder.addLast(eventId);
    while (_progressEventOrder.length > 256) {
      _seenProgressEventIds.remove(_progressEventOrder.removeFirst());
    }
    return true;
  }

  void _beginProgressReconnect() {
    _autonomousProgressLive = false;
    _awaitingAutonomousSnapshot = true;
    _browserProgressLive = false;
    _documentProgressLive = false;
    _awaitingDocumentSnapshot = true;
  }

  void _markProgressOffline() {
    _beginProgressReconnect();
  }

  bool _validAutonomousProgressFrame(Map<String, dynamic> json) {
    if (json['schema_version'] != 1 ||
        json['event_id'] is! String ||
        json['sequence'] is! int ||
        json['server_id'] != _expectedPermissionServerId ||
        json['session_id'] is! String ||
        json['run_id'] is! String ||
        json['plan_revision'] is! int ||
        json['authorization_revision'] is! int ||
        json['safe_operation_phase'] is! String ||
        json['safe_site_display'] is! String ||
        json['safe_progress_text'] is! String ||
        json['terminal'] is! bool) {
      return false;
    }
    final eventId = json['event_id'] as String;
    final sequence = json['sequence'] as int;
    final sessionId = json['session_id'] as String;
    final runId = json['run_id'] as String;
    final planRevision = json['plan_revision'] as int;
    final authorizationRevision = json['authorization_revision'] as int;
    final site = json['safe_site_display'] as String;
    final progress = json['safe_progress_text'] as String;
    final event = (json['event'] ?? '').toString().toLowerCase();
    final finalAnswer = json['final_answer'];
    if (eventId.isEmpty ||
        eventId.length > 128 ||
        sequence < 1 ||
        sessionId.isEmpty ||
        sessionId.length > 128 ||
        runId.isEmpty ||
        runId.length > 256 ||
        planRevision < 0 ||
        authorizationRevision < 0 ||
        site.length > 512 ||
        !_isSafeProgressSiteDisplay(site) ||
        progress.isEmpty ||
        progress.length > 300 ||
        json['safe_operation_phase'] != event ||
        !const <String>{
          'aborted',
          'authorization_denied',
          'authorization_pending',
          'blocked_outcome_unknown',
          'busy',
          'cancelled',
          'done',
          'failed',
          'idle',
          'interrupted',
          'plan_failed',
          'running',
          'salvaged',
          'scope_extension_denied',
          'state_updated',
          'suspended_authorization_revoked',
          'suspended_browser_intervention',
          'suspended_browser_state',
          'suspended_scope_extension',
          'task_done',
          'task_failed',
        }.contains(event) ||
        !const <String>{
          'Autonomous work is running',
          'One planned step completed',
          'One planned step needs attention',
          'Autonomous work completed',
          'Autonomous work stopped with an error',
          'Autonomous work is paused',
          'Autonomous work was cancelled',
          'No Autonomous work is active',
          'Autonomous state updated',
        }.contains(progress) ||
        (finalAnswer != null &&
            (event != 'done' ||
                json['terminal'] != true ||
                finalAnswer is! String ||
                finalAnswer.trim().isEmpty ||
                finalAnswer.length > 8000)) ||
        _seenProgressEventIds.contains(eventId)) {
      return false;
    }
    final rawArtifact = json['artifact_safe_summary'];
    if (rawArtifact != null) {
      if (rawArtifact is! Map ||
          rawArtifact.keys.any(
            (key) =>
                key is! String ||
                !const <String>{
                  'artifact_id',
                  'size',
                  'mime_type',
                  'classification',
                  'private',
                }.contains(key),
          ) ||
          rawArtifact['private'] != true ||
          (rawArtifact['size'] != null &&
              (rawArtifact['size'] is! int || rawArtifact['size'] < 0)) ||
          !_isSafeArtifactMetadata(rawArtifact)) {
        return false;
      }
    }
    if (_autonomousProgressSessionId.isEmpty) {
      if (_retiredAutonomousProgressSessions.contains(sessionId)) return false;
      _autonomousProgressSessionId = sessionId;
    } else if (sessionId != _autonomousProgressSessionId) {
      if (!_awaitingAutonomousSnapshot ||
          _retiredAutonomousProgressSessions.contains(sessionId)) {
        return false;
      }
      _retiredAutonomousProgressSessions.add(_autonomousProgressSessionId);
      _autonomousProgressSessionId = sessionId;
      _autonomousProgressRunId = '';
      _lastAutonomousProgressSequence = 0;
      _lastAutonomousPlanRevision = -1;
      _lastAutonomousAuthorizationRevision = -1;
      _autonomousTerminalSeen = false;
    }
    if (_autonomousProgressRunId.isEmpty) {
      _autonomousProgressRunId = runId;
    } else if (runId != _autonomousProgressRunId) {
      final newRunAllowed =
          _awaitingAutonomousSnapshot ||
          _expectNewAutonomousRun ||
          _autonomousTerminalSeen ||
          _autonomousProgressRunId == 'idle';
      if (!newRunAllowed ||
          const <String>{
            'task_done',
            'task_failed',
            'salvaged',
          }.contains(event)) {
        return false;
      }
      _autonomousProgressRunId = runId;
      _lastAutonomousProgressSequence = 0;
      _lastAutonomousPlanRevision = -1;
      _lastAutonomousAuthorizationRevision = -1;
      _autonomousTerminalSeen = false;
    }
    if (sequence <= _lastAutonomousProgressSequence ||
        planRevision < _lastAutonomousPlanRevision ||
        authorizationRevision < _lastAutonomousAuthorizationRevision ||
        (_autonomousTerminalSeen &&
            !(_awaitingAutonomousSnapshot && json['terminal'] == true))) {
      return false;
    }
    _lastAutonomousProgressSequence = sequence;
    _lastAutonomousPlanRevision = planRevision;
    _lastAutonomousAuthorizationRevision = authorizationRevision;
    _autonomousTerminalSeen = json['terminal'] as bool;
    _autonomousProgressLive = true;
    _awaitingAutonomousSnapshot = false;
    _expectNewAutonomousRun = false;
    return _rememberProgressEvent(eventId);
  }

  static String _documentScopeKey(String scopeType, String scopeId) =>
      '$scopeType\u0000$scopeId';

  static String _documentItemKey(DocumentProgressMessage progress) =>
      '${_documentScopeKey(progress.scopeType, progress.scopeId)}'
      '\u0000${progress.itemId}';

  void _markDocumentCanonicalTerminal(String scopeType, String scopeId) {
    if (scopeId.isEmpty) return;
    _canonicalTerminalDocumentScopes.add(_documentScopeKey(scopeType, scopeId));
  }

  bool _ownsDocumentScope(DocumentProgressMessage progress) {
    final scopeKey = _documentScopeKey(progress.scopeType, progress.scopeId);
    if (_knownDocumentScopes.contains(scopeKey)) return true;
    if (progress.scopeType == 'chat') {
      return _turnByRequest.values.contains(progress.scopeId);
    }
    return _autonomousProgressRunId.isNotEmpty &&
        _autonomousProgressRunId != 'idle' &&
        progress.scopeId == _autonomousProgressRunId;
  }

  void _handleDocumentProgress(Map<String, dynamic> json) {
    final progress = DocumentProgressMessage.tryParse(json);
    if (progress == null ||
        progress.serverId != _expectedPermissionServerId ||
        _seenProgressEventIds.contains(progress.eventId) ||
        !_ownsDocumentScope(progress)) {
      return;
    }
    final scopeKey = _documentScopeKey(progress.scopeType, progress.scopeId);
    if (_canonicalTerminalDocumentScopes.contains(scopeKey)) return;
    if (_documentProgressSessionId.isEmpty) {
      if (_retiredDocumentProgressSessions.contains(progress.sessionId)) {
        return;
      }
      _documentProgressSessionId = progress.sessionId;
    } else if (progress.sessionId != _documentProgressSessionId) {
      if (_documentProgressLive ||
          !_awaitingDocumentSnapshot ||
          _retiredDocumentProgressSessions.contains(progress.sessionId)) {
        return;
      }
      _retiredDocumentProgressSessions.add(_documentProgressSessionId);
      while (_retiredDocumentProgressSessions.length > 8) {
        _retiredDocumentProgressSessions.remove(
          _retiredDocumentProgressSessions.first,
        );
      }
      _documentProgressSessionId = progress.sessionId;
      _lastDocumentSequence.clear();
      _lastDocumentRevision.clear();
      _lastDocumentPhaseRank.clear();
      _terminalDocumentItems.clear();
    }
    if (progress.scopeType == 'chat' && progress.planRevision != 0) return;
    if (progress.scopeType == 'autonomous' &&
        _lastAutonomousPlanRevision >= 0 &&
        progress.planRevision < _lastAutonomousPlanRevision) {
      return;
    }
    final previousSequence = _lastDocumentSequence[scopeKey] ?? 0;
    final previousRevision = _lastDocumentRevision[scopeKey] ?? -1;
    if (progress.sequence <= previousSequence ||
        progress.planRevision < previousRevision) {
      return;
    }
    const phaseRank = <String, int>{
      'identifying': 0,
      'inspecting': 1,
      'extracting': 2,
      'indexing': 3,
      'ready': 4,
    };
    final itemKey = _documentItemKey(progress);
    final priorRank = _lastDocumentPhaseRank[itemKey] ?? -1;
    final cached = _documentProgress[itemKey];
    if (_terminalDocumentItems.contains(itemKey)) {
      final authoritativeRepeat =
          progress.snapshot &&
          _awaitingDocumentSnapshot &&
          cached != null &&
          cached.phase == progress.phase &&
          progress.terminal;
      if (!authoritativeRepeat) return;
    } else if (progress.phase != 'failed' &&
        (phaseRank[progress.phase] ?? -1) <= priorRank) {
      return;
    }
    _lastDocumentSequence[scopeKey] = progress.sequence;
    _lastDocumentRevision[scopeKey] = progress.planRevision;
    if (progress.phase != 'failed') {
      _lastDocumentPhaseRank[itemKey] = phaseRank[progress.phase]!;
    }
    if (progress.terminal) _terminalDocumentItems.add(itemKey);
    _knownDocumentScopes.add(scopeKey);
    _documentProgress[itemKey] = progress;
    while (_documentProgress.length > 80) {
      _documentProgress.remove(_documentProgress.keys.first);
    }
    _documentProgressLive = true;
    _awaitingDocumentSnapshot = false;
    if (_rememberProgressEvent(progress.eventId) &&
        !_documentProgressCtrl.isClosed) {
      _documentProgressCtrl.add(progress);
    }
  }

  void _handleBrowserProgress(Map<String, dynamic> json) {
    final progress = BrowserProgressMessage.tryParse(json);
    if (progress == null ||
        progress.serverId != _expectedPermissionServerId ||
        _seenProgressEventIds.contains(progress.eventId)) {
      return;
    }
    if (_browserProgressSessionId.isEmpty) {
      if (_retiredBrowserProgressSessions.contains(progress.sessionId)) return;
      _browserProgressSessionId = progress.sessionId;
    } else if (progress.sessionId != _browserProgressSessionId) {
      if (_browserProgressLive ||
          _retiredBrowserProgressSessions.contains(progress.sessionId)) {
        return;
      }
      _retiredBrowserProgressSessions.add(_browserProgressSessionId);
      _browserProgressSessionId = progress.sessionId;
      _browserProgressRunId = '';
      _lastBrowserProgressSequence = 0;
      _lastBrowserPlanRevision = -1;
      _lastBrowserAuthorizationRevision = -1;
      _browserTerminalSeen = false;
    }
    if (_browserProgressRunId.isEmpty) {
      _browserProgressRunId = progress.runId;
    } else if (progress.runId != _browserProgressRunId) {
      if (progress.phase != 'snapshot' && progress.phase != 'waiting') {
        return;
      }
      _browserProgressRunId = progress.runId;
      _lastBrowserProgressSequence = 0;
      _lastBrowserPlanRevision = -1;
      _lastBrowserAuthorizationRevision = -1;
      _browserTerminalSeen = false;
    }
    if (progress.sequence <= _lastBrowserProgressSequence ||
        progress.planRevision < _lastBrowserPlanRevision ||
        progress.authorizationRevision < _lastBrowserAuthorizationRevision ||
        (_browserTerminalSeen &&
            !(!_browserProgressLive &&
                progress.phase == 'snapshot' &&
                progress.terminal))) {
      return;
    }
    _lastBrowserProgressSequence = progress.sequence;
    _lastBrowserPlanRevision = progress.planRevision;
    _lastBrowserAuthorizationRevision = progress.authorizationRevision;
    _browserTerminalSeen = progress.terminal;
    _browserProgress = progress;
    _browserProgressLive = true;
    if (_rememberProgressEvent(progress.eventId) &&
        !_browserProgressCtrl.isClosed) {
      _browserProgressCtrl.add(progress);
    }
  }

  void _beginPermissionReconnect() {
    _beginProgressReconnect();
    if (_permissionSessionId.isNotEmpty) {
      _retiredPermissionSessionIds.add(_permissionSessionId);
    }
    _permissionSessionId = '';
    _lastPermissionSequence = 0;
    _permissionsLive = false;
  }

  void _markPermissionsOffline() {
    _markProgressOffline();
    if (_permissionSessionId.isNotEmpty) {
      _retiredPermissionSessionIds.add(_permissionSessionId);
    }
    _permissionSessionId = '';
    _lastPermissionSequence = 0;
    _permissionsLive = false;
  }

  void _handlePermissionSnapshot(Map<String, dynamic> json) {
    final snapshot = PermissionSnapshot.tryParse(json);
    if (snapshot == null ||
        snapshot.serverId != _expectedPermissionServerId ||
        snapshot.policyEpoch < _lastPermissionEpoch) {
      return;
    }
    if (_permissionSessionId.isEmpty) {
      if (_retiredPermissionSessionIds.contains(snapshot.sessionId)) {
        return;
      }
      _permissionSessionId = snapshot.sessionId;
      _lastPermissionSequence = 0;
    } else if (snapshot.sessionId != _permissionSessionId) {
      return;
    }
    if (snapshot.sequence <= _lastPermissionSequence) return;

    _lastPermissionSequence = snapshot.sequence;
    _lastPermissionEpoch = snapshot.policyEpoch;
    _permissionSnapshot = snapshot;
    _permissionsLive = _state == ConnectionState.connected;
    for (final pending in snapshot.pendingRequests) {
      if (pending.status != 'pending') {
        _pendingPermissionRevocations.remove(pending.requestId);
      }
    }
    if (!_permissionSnapshotCtrl.isClosed) {
      _permissionSnapshotCtrl.add(snapshot);
    }
  }

  void _handlePermissionRevocationAck(Map<String, dynamic> json) {
    final ack = PermissionRevocationAck.tryParse(json);
    if (ack == null ||
        ack.serverId != _expectedPermissionServerId ||
        _permissionSessionId.isEmpty ||
        ack.sessionId != _permissionSessionId) {
      return;
    }
    final pending = _pendingPermissionRevocations[ack.requestId];
    if (pending == null ||
        pending.sessionId != _permissionSessionId ||
        ack.basePolicyEpoch != pending.policyEpoch ||
        ack.baseSnapshotSequence != pending.snapshotSequence ||
        ack.policyEpoch < pending.policyEpoch) {
      return;
    }
    _pendingPermissionRevocations.remove(ack.requestId);
    if (ack.succeeded ||
        ack.reason == 'stale_epoch' ||
        ack.reason == 'stale_snapshot') {
      _permissionsLive = false;
      requestPermissionSnapshot();
    }
    if (!_permissionAckCtrl.isClosed) _permissionAckCtrl.add(ack);
  }

  void _resetRelayE2eState() {
    _relayE2eEpoch++;
    _relaySendEpoch++;
    _relaySendChain = Future<void>.value();
    _relayReceiveChain = Future<void>.value();
    _relayE2eContext = null;
    _relayE2eKeys = null;
    _relayE2eReplayGuard = SequenceReplayGuard();
    _pendingRelayE2eReadyEnvelope = null;
    _relayInitialE2eHelloSent = false;
    _relayPeerContextHelloSent = false;
    _relayMobileReadySent = false;
    _relayE2eReadySent = false;
    _relayPeerE2eReady = false;
    _relayPcReady = false;
    _relayPairConfirmed = false;
    _relayCommitAttemptId = '';
    _relayCommitSent = false;
    _relayCommitConfirmed = false;
    _relayCommitAuthorized = false;
    _relaySignalingStandby = false;
    _relayPcRequiresCommit = false;
    final capabilityCompleter = _webRtcCapabilityCompleter;
    if (capabilityCompleter != null && !capabilityCompleter.isCompleted) {
      capabilityCompleter.complete(null);
    }
    _webRtcCapabilityCompleter = null;
    _webRtcCapability = null;
    _lanProvisioningCompleter = null;
    _relayWorkerChunkVersion = 0;
    _relayWorkerChunkMaxFrameBytes = 0;
    _relayWorkerChunkMaxCiphertextChars = 0;
    _relayWorkerChunkMaxTotalBytes = 0;
    _relayWorkerChunkMaxCount = 0;
    _relayPeerChunkVersion = 0;
    _relayChunkReassembler.clear();
    for (final timer in _relayOutboundChunkTimers.values) {
      timer.cancel();
    }
    _relayOutboundChunkTimers.clear();
    _relayOutboundChunkRequests.clear();
    _relayLastOutboundRequestId = '';
  }

  bool get _relayChunkingSupported =>
      _relayWorkerChunkVersion == relayE2eChunkVersion &&
      _relayPeerChunkVersion == relayE2eChunkVersion &&
      _relayWorkerChunkMaxFrameBytes >= relayE2eSafeFrameBytes &&
      _relayWorkerChunkMaxCiphertextChars >= relayE2eChunkCiphertextChars &&
      _relayWorkerChunkMaxTotalBytes >= relayE2eChunkMaxTotalBytes &&
      _relayWorkerChunkMaxCount >= relayE2eChunkMaxCount;

  void _captureRelayWorkerChunkCapabilities(Object? payload) {
    if (payload is! Map) return;
    int readLimit(String name, int localLimit) {
      final value = payload[name];
      return value is int && value > 0 ? min(value, localLimit) : 0;
    }

    final version = payload['e2e_chunk_version'];
    _relayWorkerChunkVersion = version is int ? version : 0;
    _relayWorkerChunkMaxFrameBytes = readLimit(
      'e2e_chunk_max_frame_bytes',
      relayE2eSafeFrameBytes,
    );
    _relayWorkerChunkMaxCiphertextChars = readLimit(
      'e2e_chunk_max_ciphertext_chars',
      relayE2eChunkCiphertextChars,
    );
    _relayWorkerChunkMaxTotalBytes = readLimit(
      'e2e_chunk_max_total_bytes',
      relayE2eChunkMaxTotalBytes,
    );
    _relayWorkerChunkMaxCount = readLimit(
      'e2e_chunk_max_count',
      relayE2eChunkMaxCount,
    );
  }

  bool _relayWorkerCapabilitiesReady(Object? payload) =>
      payload is Map &&
      payload['max_frame_bytes'] is int &&
      payload['max_frame_bytes'] >= 65536 &&
      payload['max_batch_items'] is int &&
      payload['max_batch_items'] > 0 &&
      _relayWorkerChunkVersion == relayE2eChunkVersion &&
      _relayWorkerChunkMaxFrameBytes == relayE2eSafeFrameBytes &&
      _relayWorkerChunkMaxCiphertextChars == relayE2eChunkCiphertextChars &&
      _relayWorkerChunkMaxTotalBytes == relayE2eChunkMaxTotalBytes &&
      _relayWorkerChunkMaxCount == relayE2eChunkMaxCount;

  void _emitRelayTransfer(RelayTransferEvent event) {
    if (!_disposed && !_relayTransferCtrl.isClosed) {
      _relayTransferCtrl.add(event);
    }
  }

  void _rememberOutboundRelayChunk(String chunkId, String clientRequestId) {
    _relayOutboundChunkTimers.remove(chunkId)?.cancel();
    _relayOutboundChunkRequests.remove(chunkId);
    while (_relayOutboundChunkRequests.length >= 64) {
      final oldestChunkId = _relayOutboundChunkRequests.keys.first;
      _relayOutboundChunkRequests.remove(oldestChunkId);
      _relayOutboundChunkTimers.remove(oldestChunkId)?.cancel();
    }
    _relayOutboundChunkRequests[chunkId] = clientRequestId;
    _relayOutboundChunkTimers[chunkId] = Timer(const Duration(minutes: 1), () {
      _relayOutboundChunkTimers.remove(chunkId);
      _relayOutboundChunkRequests.remove(chunkId);
    });
  }

  String _forgetOutboundRelayChunk(String chunkId) {
    _relayOutboundChunkTimers.remove(chunkId)?.cancel();
    return _relayOutboundChunkRequests.remove(chunkId) ?? '';
  }

  void _rollbackRelayRequest(String clientRequestId) {
    if (clientRequestId.isEmpty) return;
    _acceptedRequests.remove(clientRequestId);
    _turnByRequest.remove(clientRequestId);
    final conversationId = _activeConvByRequest.remove(clientRequestId);
    if (conversationId == null || conversationId.isEmpty) return;
    if (_activeRequestByConv[conversationId] == clientRequestId) {
      _activeRequestByConv.remove(conversationId);
      _pendingConvs.remove(conversationId);
      _setConversationBusy(conversationId, false);
    }
  }

  void _maybeCompleteRelayReady() {
    final context = _relayE2eContext;
    if (context != null &&
        _relayPairConfirmed &&
        _relayPcReady &&
        _relayPeerE2eReady &&
        _relayE2eKeys != null) {
      if (!_directFirstEnabled) {
        _markConnected();
        _completeRelayReady(true);
        return;
      }
      if (!_relayPcRequiresCommit) {
        var activated = false;
        if (_transportLease?.active != true) {
          final lease = _transportCoordinator.tryAcquire(
            ApplicationTransportKind.relay,
            this,
          );
          if (lease == null) {
            _failRelayHandshake(kRelayE2eStaleSessionError);
            return;
          }
          _transportLease = lease;
          activated = true;
        }
        _relaySignalingStandby = false;
        _lastTransportKind = ApplicationTransportKind.relay;
        if (_state != ConnectionState.connected) _markConnected();
        _completeRelayReady(true);
        if (activated) {
          debugPrint('[OSIA Relay] authenticated relay-only PC selected');
        }
        return;
      }
      if (!_relayCommitAuthorized) {
        _relaySignalingStandby = true;
        _completeRelayReady(true);
        return;
      }
      if (_relayCommitConfirmed) {
        _relaySignalingStandby = false;
        _markConnected();
        _completeRelayReady(true);
        return;
      }
      if (_relayCommitSent) return;
      final random = Random.secure();
      _relayCommitAttemptId = List<int>.generate(
        16,
        (_) => random.nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      _relayCommitSent = true;
      final queued = _sendRelayEncryptedFrame(<String, dynamic>{
        'type': 'transport_commit',
        'transport': 'relay',
        'attempt_id': _relayCommitAttemptId,
      });
      if (!queued) {
        _relayCommitSent = false;
        _failRelayHandshake(kRelayE2eStaleSessionError);
      }
    }
  }

  void _attachChannel(
    WebSocketChannel channel, {
    required bool relay,
    required void Function(dynamic raw) onData,
  }) {
    final generation = ++_socketGeneration;
    _awaitingAuthenticatedInitialSync = true;
    _channel = channel;
    _connectedViaRelay = relay;
    channel.stream.listen(
      (raw) {
        if (_isCurrentSocket(generation)) onData(raw);
      },
      onError: (error) {
        if (_isCurrentSocket(generation)) _onError(error);
      },
      onDone: () {
        if (_isCurrentSocket(generation)) {
          _onDone();
        } else {
          debugPrint('[OSIA WS] Ignored stale socket close.');
        }
      },
      cancelOnError: false,
    );
  }

  Future<void> _closeCurrentChannel({
    required String reason,
    required bool emitDisconnected,
  }) async {
    final channel = _channel;
    final lanTransport = _lanTransport;
    final webRtcTransport = _webRtcTransport;
    _socketGeneration++;
    _clearChatGptEphemeralLogin();
    // This close path invalidates the socket callback itself, so any one-shot
    // reconnect suppression assigned to that socket must not leak forward to
    // a later, healthy connection.
    _suppressReconnectOnce = false;
    _channel = null;
    _lanTransport = null;
    _webRtcTransport = null;
    _connectedViaLan = false;
    _connectedViaWebRtc = false;
    _connectedViaRelay = false;
    _relayConfig = null;
    _completeRelayReady(false);
    _resetRelayE2eState();
    _relayReadyCompleter = null;
    _markPermissionsOffline();
    if (channel != null) {
      debugPrint('[OSIA WS] Closing current socket ($reason).');
      try {
        await channel.sink.close();
      } catch (e) {
        debugPrint('[OSIA WS] Socket close failed during reconnect: $e');
      }
    }
    if (lanTransport != null) await lanTransport.close();
    if (webRtcTransport != null) await webRtcTransport.close();
    _releaseTransportLease();
    if (emitDisconnected) _setState(ConnectionState.disconnected);
  }

  void _setState(ConnectionState newState) {
    if (_disposed || _connectionCtrl.isClosed) return;
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
  void _appendConvDelta(
    String? convId,
    String delta, {
    String clientRequestId = '',
    String turnId = '',
    String messageId = '',
  }) {
    if (convId == null || convId.isEmpty || _convStreamCtrl.isClosed) return;
    if (_shouldIgnoreConversationFrame(
      convId,
      clientRequestId: clientRequestId,
      frameType: 'response_chunk',
    )) {
      return;
    }
    final st = _streamBuffers.putIfAbsent(convId, () => _ConvStreamState());
    final wasStreaming = st.streaming;
    // First chunk of a fresh turn: drop the previous turn's text.
    if (!st.streaming) st.text.clear();
    final existing = st.text.toString();
    final needsSpace =
        existing.isNotEmpty &&
        !existing.endsWith(' ') &&
        !existing.endsWith('\n') &&
        !delta.startsWith(' ');
    if (needsSpace) st.text.write(' ');
    st.text.write(delta);
    st.streaming = true;
    if (messageId.isNotEmpty) st.messageId = messageId;
    _pendingConvs.add(convId); // WOR-75/WOR-53/WOR-62: turn in flight.
    if (kOsiaDebugPlaceholder && !wasStreaming) {
      debugPrint(
        '[OSIA WOR-75] _appendConvDelta FIRST chunk '
        '→ streaming=true, pending_count=${_pendingConvs.length}',
      );
    }
    _capConvBuffers();
    _convStreamCtrl.add(
      ConvStreamEvent(
        convId,
        clientRequestId: clientRequestId,
        turnId: turnId,
        messageId: messageId,
        delta: delta,
      ),
    );
  }

  /// Replace conversation [convId]'s buffer with the canonical full reply
  /// [text] (the `response` frame) and broadcast it. Keeps the buffer's
  /// hydration text in sync with the assembled reply rather than the
  /// chunk-concatenation.
  void _replaceConvText(
    String? convId,
    String text, {
    String clientRequestId = '',
    String turnId = '',
    String messageId = '',
  }) {
    if (convId == null || convId.isEmpty || _convStreamCtrl.isClosed) return;
    if (_shouldIgnoreConversationFrame(
      convId,
      clientRequestId: clientRequestId,
      frameType: 'response',
    )) {
      return;
    }
    final st = _streamBuffers.putIfAbsent(convId, () => _ConvStreamState());
    st.text
      ..clear()
      ..write(text);
    st.streaming = true;
    if (messageId.isNotEmpty) st.messageId = messageId;
    _pendingConvs.add(convId); // WOR-75/WOR-53/WOR-62: turn in flight.
    if (kOsiaDebugPlaceholder) {
      debugPrint(
        '[OSIA WOR-75] _replaceConvText full reply '
        '→ streaming=true, pending_count=${_pendingConvs.length}',
      );
    }
    _capConvBuffers();
    _convStreamCtrl.add(
      ConvStreamEvent(
        convId,
        clientRequestId: clientRequestId,
        turnId: turnId,
        messageId: messageId,
        delta: text,
      ),
    );
  }

  /// Mark conversation [convId]'s turn finished (terminal `status`) and
  /// broadcast a terminal [ConvStreamEvent]. The buffered text is kept (for
  /// hydration on return) until the next turn resets it or [clearConvBuffer]
  /// drops it.
  void _finishConvStream(
    String? convId, {
    required bool error,
    String clientRequestId = '',
    String turnId = '',
    String messageId = '',
    String frameType = 'terminal',
    bool keepMediaPhase = false,
  }) {
    if (_convStreamCtrl.isClosed) return;
    if (_shouldIgnoreConversationFrame(
      convId,
      clientRequestId: clientRequestId,
      frameType: frameType,
      terminal: true,
    )) {
      return;
    }
    if (convId == null || convId.isEmpty) {
      // WOR-75: an UNTAGGED terminal — the server didn't tell us which
      // conversation finished, so we can't clear a specific buffer/pending flag
      // in the service. Broadcast it untagged so the chat screen applies it to
      // the conversation currently on screen (the only turn it could be
      // watching) and clears THAT conversation's pending — otherwise an untagged
      // done would leave pending stuck true and the background placeholder up.
      if (kOsiaDebugPlaceholder) {
        debugPrint(
          '[OSIA WOR-75] _finishConvStream(error=$error) UNTAGGED — '
          'broadcasting to active conv (no id to clear in service)',
        );
      }
      _forgetRequest(clientRequestId);
      _convStreamCtrl.add(
        ConvStreamEvent(
          '',
          clientRequestId: clientRequestId,
          turnId: turnId,
          done: !error,
          error: error,
          untagged: true,
        ),
      );
      return;
    }
    final st = _streamBuffers[convId];
    if (st != null) st.streaming = false;
    _pendingConvs.remove(convId); // WOR-75/WOR-53/WOR-62: turn finished.
    if (keepMediaPhase &&
        clientRequestId.isNotEmpty &&
        turnId.isNotEmpty &&
        messageId.isNotEmpty) {
      _mediaByConversation[convId] = _MediaCorrelation(
        requestId: clientRequestId,
        turnId: turnId,
        messageId: messageId,
      );
      _setConversationBusy(
        convId,
        true,
        clientRequestId: clientRequestId,
        turnId: turnId,
      );
    } else {
      _forgetConversationRequest(convId);
      _acceptedRequests.remove(clientRequestId);
      _setConversationBusy(
        convId,
        false,
        clientRequestId: clientRequestId,
        turnId: turnId,
      );
    }
    if (kOsiaDebugPlaceholder) {
      debugPrint(
        '[OSIA WOR-75] _finishConvStream(error=$error) '
        '→ pending_count=${_pendingConvs.length}',
      );
    }
    _convStreamCtrl.add(
      ConvStreamEvent(
        convId,
        clientRequestId: clientRequestId,
        turnId: turnId,
        messageId: messageId,
        done: !error,
        error: error,
      ),
    );
  }

  bool _finishMediaPhase(
    String conversationId, {
    required String clientRequestId,
    required String turnId,
    required String messageId,
  }) {
    if (!_directFirstEnabled) return true;
    final expected = _mediaByConversation[conversationId];
    if (expected == null ||
        expected.requestId != clientRequestId ||
        expected.turnId != turnId ||
        expected.messageId != messageId) {
      debugPrint('[OSIA WS] ignored stale or unowned media event');
      return false;
    }
    _mediaByConversation.remove(conversationId);
    _forgetConversationRequest(conversationId);
    _acceptedRequests.remove(clientRequestId);
    _setConversationBusy(
      conversationId,
      false,
      clientRequestId: clientRequestId,
      turnId: turnId,
    );
    return true;
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

  bool _send(Map<String, dynamic> json) {
    final testSender = sendFrameForTest;
    if (testSender != null) {
      return testSender(Map<String, dynamic>.from(json));
    }
    final lanTransport = _lanTransport;
    if (_connectedViaLan && lanTransport != null) {
      if (_transportLease?.active != true) {
        debugPrint(
          '[OSIA LAN] Send DROPPED (application lease inactive): '
          'type=${json['type']}',
        );
        return false;
      }
      return lanTransport.send(json);
    }
    final webRtcTransport = _webRtcTransport;
    if (_connectedViaWebRtc && webRtcTransport != null) {
      if (_transportLease?.active != true) {
        debugPrint(
          '[OSIA WebRTC] Send DROPPED (application lease inactive): '
          'type=${json['type']}',
        );
        return false;
      }
      return webRtcTransport.send(json);
    }
    // Surface dropped sends loudly — a null channel means the socket is
    // down and the message silently goes nowhere otherwise.
    if (_channel == null) {
      debugPrint(
        '[OSIA WS] Send DROPPED (socket not connected): type=${json['type']}',
      );
      return false;
    }
    if (_connectedViaRelay) {
      if (_transportLease?.active != true) return false;
      return _sendRelayEncryptedFrame(json);
    }
    if (_transportLease?.active != true) return false;
    final encoded = jsonEncode(json);
    try {
      _channel?.sink.add(encoded);
      return true;
    } catch (e) {
      debugPrint('[OSIA WS] Send error: $e');
      return false;
    }
  }

  /// Clear conversation [id]'s busy flag (WOR-103), used by recovery paths that
  /// learn a turn finished via refreshed history instead of a terminal frame.
  void clearConversationBusy(String id) {
    _forgetConversationRequest(id);
    _setConversationBusy(id, false);
  }

  Future<bool> _tryLanConnect(
    LanDirectConfig config,
    int connectGeneration,
  ) async {
    final lease = _transportCoordinator.tryAcquire(
      ApplicationTransportKind.lan,
      this,
    );
    if (lease == null) return false;
    _transportLease = lease;
    var retainLease = false;
    LanCloseInfo? closeInfo;
    late final LanDirectTransport transport;
    transport = LanDirectTransport(
      config: config,
      token: token,
      onFrame: (frame) {
        if (identical(_lanTransport, transport)) {
          _onData(frame);
        }
      },
      onClosed: () => _onLanTransportClosed(transport, closeInfo),
      onCloseInfo: (info) => closeInfo = info,
      onError: (error) {
        debugPrint('[OSIA LAN] active transport error: ${error.runtimeType}');
      },
    );
    _lanTransport = transport;
    try {
      debugPrint('[OSIA LAN] Connecting to authenticated private endpoint');
      _awaitingAuthenticatedInitialSync = true;
      final ready = await transport.connect();
      if (!_isCurrentConnect(connectGeneration) || !ready) {
        await transport.close();
        return false;
      }
      _lanTransport = transport;
      _connectedViaLan = true;
      _lastTransportKind = ApplicationTransportKind.lan;
      retainLease = true;
      _markConnected();
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnectAttempt = 0;
      debugPrint('[OSIA LAN] secure E2E bridge ready');
      return true;
    } catch (error) {
      debugPrint('[OSIA LAN] handshake failed: ${error.runtimeType}');
      await transport.close();
      return false;
    } finally {
      if (!retainLease) {
        if (identical(_lanTransport, transport)) _lanTransport = null;
        if (identical(_transportLease, lease)) _transportLease = null;
        lease.release();
      }
    }
  }

  void _onLanTransportClosed(
    LanDirectTransport transport,
    LanCloseInfo? closeInfo,
  ) {
    if (!identical(_lanTransport, transport)) return;
    final hadActiveTurn = _hasActiveApplicationTurn;
    _lanTransport = null;
    _connectedViaLan = false;
    _clearChatGptEphemeralLogin();
    _releaseTransportLease();
    _setState(ConnectionState.disconnected);
    debugPrint(
      '[OSIA LAN] closed '
      '(code=${closeInfo?.code}, category=${closeInfo?.category ?? 'network'})',
    );
    if (_intentionalClose) return;
    if (hadActiveTurn) {
      _failActiveApplicationTurns();
      if (!_errorCtrl.isClosed) {
        _errorCtrl.add(
          'Secure LAN connection closed during an active request. '
          'Automatic transport switching is disabled.',
        );
      }
      return;
    }
    _scheduleReconnect();
  }

  Future<bool> _tryWebRtcConnect(
    WebRtcCapability capability,
    int connectGeneration,
  ) async {
    if (!webRtcDirectV1 || !capability.enabled || _hasActiveApplicationTurn) {
      return false;
    }
    ApplicationTransportLease? authorizedLease;
    var retainLease = false;
    late final WebRtcDirectTransport transport;
    transport = WebRtcDirectTransport(
      capability: capability,
      token: token,
      pairId: RelayService.derivePairCredentials(token).pairId,
      sendSignal: (frame) => _sendRelayEncryptedFrame(
        frame.cast<String, dynamic>(),
        priorityOverride: relayPriorityCritical,
        finalOverride: frame['terminal'] == true,
      ),
      authorizeCommit: () {
        if (_transportLease?.active == true) return false;
        final lease = _transportCoordinator.tryAcquire(
          ApplicationTransportKind.webrtc,
          this,
        );
        if (lease == null) return false;
        authorizedLease = lease;
        _transportLease = lease;
        return true;
      },
      onFrame: (frame) {
        if (identical(_webRtcTransport, transport)) _onData(frame);
      },
      onClosed: (info) => _onWebRtcTransportClosed(transport, info),
    );
    _webRtcTransport = transport;
    try {
      debugPrint('[OSIA WebRTC] preparing data-only direct transport');
      final ready = await transport.connect(
        attemptGeneration: ++_webRtcAttemptGeneration,
      );
      if (!_isCurrentConnect(connectGeneration) || !ready) {
        await transport.close();
        return false;
      }
      if (authorizedLease?.active != true) {
        await transport.close();
        return false;
      }
      _connectedViaWebRtc = true;
      _lastTransportKind = ApplicationTransportKind.webrtc;
      retainLease = true;
      _markConnected();
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnectAttempt = 0;
      debugPrint('[OSIA WebRTC] authenticated direct bridge selected');
      return true;
    } catch (error) {
      debugPrint('[OSIA WebRTC] activation failed: ${error.runtimeType}');
      await transport.close();
      return false;
    } finally {
      if (!retainLease) {
        if (identical(_webRtcTransport, transport)) _webRtcTransport = null;
        if (identical(_transportLease, authorizedLease)) {
          _transportLease = null;
        }
        authorizedLease?.release();
      }
    }
  }

  void _onWebRtcTransportClosed(
    WebRtcDirectTransport transport,
    WebRtcCloseInfo info,
  ) {
    if (!identical(_webRtcTransport, transport)) return;
    final hadActiveTurn = info.hadActiveTurn || _hasActiveApplicationTurn;
    _webRtcTransport = null;
    _connectedViaWebRtc = false;
    _clearChatGptEphemeralLogin();
    _releaseTransportLease();
    _setState(ConnectionState.disconnected);
    debugPrint('[OSIA WebRTC] closed category=${info.category}');
    if (_intentionalClose) return;
    if (hadActiveTurn) {
      _failActiveApplicationTurns();
      if (!_errorCtrl.isClosed) {
        _errorCtrl.add(
          'Secure WebRTC connection closed during an active request. '
          'Automatic transport switching is disabled.',
        );
      }
      return;
    }
    _scheduleReconnect();
  }

  Future<LanDirectConfig?> _discoverLanConfig(
    LanPairingIdentity identity,
  ) async {
    final service = await lanDiscoveryService.discover(identity.instanceAlias);
    if (service == null) return null;
    return LanDirectConfig(
      host: service.host,
      port: service.port,
      certificateSha256: identity.certificateSha256,
    );
  }

  void _failActiveApplicationTurns() {
    final conversations = <String>{
      ..._activeRequestByConv.keys,
      ..._mediaByConversation.keys,
    };
    for (final conversationId in conversations) {
      final media = _mediaByConversation[conversationId];
      final requestId =
          _activeRequestByConv[conversationId] ?? media?.requestId ?? '';
      _finishConvStream(
        conversationId,
        error: true,
        clientRequestId: requestId,
        turnId: media?.turnId ?? '',
        messageId: media?.messageId ?? '',
        frameType: 'local_transport_failure',
      );
    }
    _mediaByConversation.clear();
    _unboundRequestIds.clear();
  }

  Future<bool> _tryRelayConnect(
    RelayConnectionConfig config,
    int connectGeneration, {
    bool standbyOnly = false,
  }) async {
    final lease = standbyOnly
        ? null
        : _transportCoordinator.tryAcquire(
            ApplicationTransportKind.relay,
            this,
          );
    if (!standbyOnly && lease == null) return false;
    if (lease != null) _transportLease = lease;
    var retainLease = false;
    _relayHandshakeFailure = null;
    _relayBlocksLegacyFallback = false;
    final uri = _relayUri(config);
    final relayTarget =
        '${uri.scheme}://${uri.host}'
        '${uri.hasPort ? ':${uri.port}' : ''}${uri.path}';
    debugPrint(
      '[OSIA Relay] Connecting to $relayTarget '
      '(timeout ${_connectTimeout.inSeconds}s)',
    );

    try {
      final socket = await WebSocket.connect(
        uri.toString(),
      ).timeout(_connectTimeout);
      if (!_isCurrentConnect(connectGeneration)) {
        unawaited(socket.close());
        return false;
      }
      socket.pingInterval = _relayNativePingInterval;
      _relayConfig = config;
      _relaySeq = 0;
      _resetRelayE2eState();
      if (standbyOnly) {
        _relaySignalingStandby = true;
        if (lanDirectV1) {
          _lanProvisioningCompleter = Completer<LanPairingIdentity?>();
        }
        if (webRtcDirectV1) {
          _webRtcCapabilityCompleter = Completer<WebRtcCapability?>();
        }
      }
      _relayReadyCompleter = Completer<bool>();
      _attachChannel(
        IOWebSocketChannel(socket),
        relay: true,
        onData: _onRelayData,
      );

      _sendRelayEnvelope('PAIR_START', {'secret': config.secret});

      final ready = await _relayReadyCompleter!.future.timeout(
        _relayReadyTimeout,
        onTimeout: () => false,
      );
      if (!_isCurrentConnect(connectGeneration)) return false;
      if (ready) {
        if (!standbyOnly && lease != null) {
          _transportLease = lease;
          _lastTransportKind = ApplicationTransportKind.relay;
          retainLease = true;
        }
        return true;
      }

      _relayHandshakeFailure ??= kRelayE2eHandshakeTimeoutError;

      await _closeCurrentChannel(
        reason: 'relay E2E handshake did not complete',
        emitDisconnected: false,
      );
      return false;
    } catch (e) {
      if (_isCurrentConnect(connectGeneration)) {
        _channel = null;
        _connectedViaRelay = false;
        _relayConfig = null;
        _relayReadyCompleter = null;
      }
      _relayHandshakeFailure ??= kRelayUnreachableError;
      debugPrint('[OSIA Relay] connect failed: ${e.runtimeType}');
      return false;
    } finally {
      if (lease != null && !retainLease) {
        if (identical(_transportLease, lease)) _transportLease = null;
        lease.release();
      }
    }
  }

  Future<bool> _commitRelayStandby(int connectGeneration) async {
    if (_channel == null ||
        _relayConfig == null ||
        !_relaySignalingStandby ||
        !_relayPcReady ||
        !_relayPeerE2eReady ||
        _relayE2eKeys == null) {
      return false;
    }
    final lease = _transportCoordinator.tryAcquire(
      ApplicationTransportKind.relay,
      this,
    );
    if (lease == null) return false;
    _transportLease = lease;
    var retainLease = false;
    try {
      _relayCommitAuthorized = true;
      _relayReadyCompleter = Completer<bool>();
      _maybeCompleteRelayReady();
      final ready = await _relayReadyCompleter!.future.timeout(
        _relayReadyTimeout,
        onTimeout: () => false,
      );
      if (!_isCurrentConnect(connectGeneration) || !ready) return false;
      _relaySignalingStandby = false;
      _lastTransportKind = ApplicationTransportKind.relay;
      retainLease = true;
      return true;
    } finally {
      if (!retainLease) {
        if (identical(_transportLease, lease)) _transportLease = null;
        lease.release();
      }
    }
  }

  Uri _relayUri(RelayConnectionConfig config) {
    final uri = config.endpoint;
    if ((uri.scheme != 'ws' && uri.scheme != 'wss') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.path != '/ws' ||
        uri.queryParametersAll.length != 1 ||
        uri.queryParametersAll['pair_id']?.length != 1 ||
        uri.queryParametersAll['pair_id']?.single != config.pairId ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(config.pairId)) {
      throw const FormatException('invalid canonical relay v2 URL');
    }
    return uri;
  }

  bool _queueRelaySend(
    Future<void> Function(
      WebSocketChannel channel,
      RelayConnectionConfig config,
      int epoch,
    )
    operation, {
    void Function()? onInvalidated,
  }) {
    final channel = _channel;
    final config = _relayConfig;
    if (channel == null || config == null) return false;
    final epoch = _relaySendEpoch;
    final previous = _relaySendChain;
    _relaySendChain = _runRelaySend(
      previous,
      channel,
      config,
      epoch,
      operation,
      onInvalidated,
    );
    return true;
  }

  Future<void> _runRelaySend(
    Future<void> previous,
    WebSocketChannel channel,
    RelayConnectionConfig config,
    int epoch,
    Future<void> Function(
      WebSocketChannel channel,
      RelayConnectionConfig config,
      int epoch,
    )
    operation,
    void Function()? onInvalidated,
  ) async {
    try {
      await previous;
      if (epoch != _relaySendEpoch ||
          !identical(_channel, channel) ||
          !identical(_relayConfig, config)) {
        onInvalidated?.call();
        return;
      }
      await operation(channel, config, epoch);
    } catch (e) {
      debugPrint('[OSIA Relay] queued send failed: ${e.runtimeType}');
    }
  }

  bool _sendRelayEnvelope(String type, Map<String, dynamic> payload) {
    final stablePayload = Map<String, dynamic>.from(payload);
    return _queueRelaySend((channel, config, epoch) async {
      final seq = ++_relaySeq;
      channel.sink.add(
        jsonEncode({
          'v': 2,
          'type': type,
          'role': 'mobile',
          'pair_id': config.pairId,
          'seq': seq,
          'ack': 0,
          'payload': stablePayload,
        }),
      );
    });
  }

  bool _sendRelayE2eHello({bool forPeerContext = false}) {
    final config = _relayConfig;
    if (config == null) return false;
    if (forPeerContext) {
      if (_relayPeerContextHelloSent) return false;
    } else if (_relayInitialE2eHelloSent) {
      return false;
    }
    final queued = _sendRelayEnvelope('E2E_HELLO', {
      'e2e_version': relayE2eVersion,
      'alg': relayCryptoAlgChacha20Poly1305,
      'e2e_chunk_version': relayE2eChunkVersion,
      'public_key': b64UrlEncodeNoPadding(config.e2ePublicKey),
      'nonce_base': b64UrlEncodeNoPadding(config.e2eNonceBase),
    });
    if (queued) {
      if (forPeerContext) {
        _relayPeerContextHelloSent = true;
      } else {
        _relayInitialE2eHelloSent = true;
      }
    }
    return queued;
  }

  bool _sendRelayMobileReady() {
    if (_relayMobileReadySent) return false;
    final queued = _sendRelayEnvelope('MOBILE_READY', <String, dynamic>{});
    if (queued) _relayMobileReadySent = true;
    return queued;
  }

  bool _sendRelayE2eReady() {
    final context = _relayE2eContext;
    final keys = _relayE2eKeys;
    final config = _relayConfig;
    if (_relayE2eReadySent ||
        context == null ||
        keys == null ||
        config == null) {
      return false;
    }
    final queued = _sendRelayEnvelope('E2E_READY', {
      'e2e_version': relayE2eVersion,
      'alg': relayCryptoAlgChacha20Poly1305,
      'kid': keys.kid,
      'tag': handshakeConfirmationTag(
        token: token,
        context: context,
        senderRole: 'mobile',
      ),
    });
    if (queued) _relayE2eReadySent = true;
    return queued;
  }

  bool _sendRelayEncryptedFrame(
    Map<String, dynamic> frame, {
    String? priorityOverride,
    bool? finalOverride,
  }) {
    final channel = _channel;
    final config = _relayConfig;
    final context = _relayE2eContext;
    final keys = _relayE2eKeys;
    if (channel == null ||
        config == null ||
        context == null ||
        keys == null ||
        !_relayPairConfirmed ||
        !_relayPcReady ||
        !_relayPeerE2eReady) {
      debugPrint('[OSIA Relay] app frame dropped before E2E ready');
      return false;
    }
    final stableFrame = Map<String, dynamic>.from(frame);
    final clientRequestId = frame['client_request_id']?.toString() ?? '';
    if (clientRequestId.isNotEmpty) {
      _relayLastOutboundRequestId = clientRequestId;
    }
    final priority = priorityOverride ?? relayFramePriority(frame);
    final finalFrame = finalOverride ?? relayFrameIsFinal(frame);
    var invalidationReported = false;
    void reportInvalidation() {
      if (invalidationReported) return;
      invalidationReported = true;
      final wasActive = _activeConvByRequest.containsKey(clientRequestId);
      _rollbackRelayRequest(clientRequestId);
      if (!wasActive) return;
      _emitRelayTransfer(
        RelayTransferEvent(
          direction: RelayTransferDirection.outbound,
          state: RelayTransferState.failed,
          chunkId: '',
          clientRequestId: clientRequestId,
          errorKind: RelayTransferErrorKind.relayUnreachable,
        ),
      );
    }

    return _queueRelaySend((queuedChannel, queuedConfig, epoch) async {
      if (!identical(channel, queuedChannel) ||
          !identical(config, queuedConfig) ||
          !identical(_relayE2eKeys, keys)) {
        reportInvalidation();
        return;
      }
      final seq = ++_relaySeq;
      final envelope = await _buildRelayEncryptedEnvelope(
        stableFrame,
        config: config,
        keys: keys,
        seq: seq,
        priority: priority,
        finalFrame: finalFrame,
      );
      if (epoch != _relaySendEpoch ||
          !identical(_channel, queuedChannel) ||
          !identical(_relayConfig, queuedConfig) ||
          !identical(_relayE2eKeys, keys)) {
        reportInvalidation();
        return;
      }

      if (relaySerializedJsonBytes(envelope) <= relayE2eSafeFrameBytes) {
        queuedChannel.sink.add(jsonEncode(envelope));
        return;
      }

      if (!_relayChunkingSupported) {
        _rollbackRelayRequest(clientRequestId);
        _emitRelayTransfer(
          RelayTransferEvent(
            direction: RelayTransferDirection.outbound,
            state: RelayTransferState.failed,
            chunkId: '',
            clientRequestId: clientRequestId,
            errorKind: RelayTransferErrorKind.unsupportedChunk,
          ),
        );
        return;
      }

      final chunkId = generateRelayChunkId();
      late final List<Map<String, Object?>> chunks;
      try {
        chunks = buildRelayE2eChunks(
          envelope,
          chunkId: chunkId,
          relaySeqForIndex: (index) => index == 0 ? seq : ++_relaySeq,
        );
      } on RelayChunkLimitException {
        _rollbackRelayRequest(clientRequestId);
        _emitRelayTransfer(
          RelayTransferEvent(
            direction: RelayTransferDirection.outbound,
            state: RelayTransferState.failed,
            chunkId: chunkId,
            clientRequestId: clientRequestId,
            errorKind: RelayTransferErrorKind.frameTooLarge,
          ),
        );
        return;
      }

      _rememberOutboundRelayChunk(chunkId, clientRequestId);
      _emitRelayTransfer(
        RelayTransferEvent(
          direction: RelayTransferDirection.outbound,
          state: RelayTransferState.started,
          chunkId: chunkId,
          clientRequestId: clientRequestId,
        ),
      );
      try {
        for (final chunk in chunks) {
          queuedChannel.sink.add(jsonEncode(chunk));
        }
      } catch (_) {
        _forgetOutboundRelayChunk(chunkId);
        _rollbackRelayRequest(clientRequestId);
        _emitRelayTransfer(
          RelayTransferEvent(
            direction: RelayTransferDirection.outbound,
            state: RelayTransferState.failed,
            chunkId: chunkId,
            clientRequestId: clientRequestId,
            errorKind: RelayTransferErrorKind.relayUnreachable,
          ),
        );
        rethrow;
      }
      _emitRelayTransfer(
        RelayTransferEvent(
          direction: RelayTransferDirection.outbound,
          state: RelayTransferState.completed,
          chunkId: chunkId,
          clientRequestId: clientRequestId,
        ),
      );
    }, onInvalidated: reportInvalidation);
  }

  Future<Map<String, Object?>> _buildRelayEncryptedEnvelope(
    Map<String, dynamic> frame, {
    required RelayConnectionConfig config,
    required RelaySessionKeys keys,
    required int seq,
    required String priority,
    required bool finalFrame,
  }) async {
    final encrypted = await encryptFrame(
      frame,
      keys: keys,
      direction: RelayCryptoDirection.mobileToPc,
      pairId: config.pairId,
      role: 'mobile',
      priority: priority,
      finalFrame: finalFrame,
      seq: seq,
    );
    return <String, Object?>{
      'v': 2,
      'type': 'E2E_FRAME',
      'role': 'mobile',
      'pair_id': config.pairId,
      'seq': seq,
      'ack': 0,
      ...encrypted,
    };
  }

  void _markConnected() {
    if (_state != ConnectionState.connected) {
      _setState(ConnectionState.connected);
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
  }

  void _completeRelayReady(bool ready) {
    final completer = _relayReadyCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(ready);
    }
  }

  void _failRelayHandshake(String message, {bool closeSocket = true}) {
    _relayHandshakeFailure ??= message;
    _completeRelayReady(false);
    if (closeSocket) _channel?.sink.close();
  }

  static bool _hasLegacyRelayIdentity(Map<String, dynamic> envelope) =>
      const <String>{
        'device_id',
        'session_id',
        'from',
        'to',
        'to_session_id',
      }.any(envelope.containsKey);

  static bool _hasExactKeys(Map<Object?, Object?> value, Set<String> keys) =>
      value.length == keys.length && value.keys.every(keys.contains);

  void _replaceRelayPeerCryptoContext() {
    final activeRequestIds = _activeConvByRequest.keys.toList(growable: false);
    for (final clientRequestId in activeRequestIds) {
      _rollbackRelayRequest(clientRequestId);
      _emitRelayTransfer(
        RelayTransferEvent(
          direction: RelayTransferDirection.outbound,
          state: RelayTransferState.failed,
          chunkId: '',
          clientRequestId: clientRequestId,
          errorKind: RelayTransferErrorKind.relayUnreachable,
        ),
      );
    }
    _relayE2eEpoch++;
    _relaySendEpoch++;
    _relaySendChain = Future<void>.value();
    _relayE2eContext = null;
    _relayE2eKeys = null;
    _relayE2eReplayGuard = SequenceReplayGuard();
    _pendingRelayE2eReadyEnvelope = null;
    _relayPeerContextHelloSent = false;
    _relayE2eReadySent = false;
    _relayPeerE2eReady = false;
    _relayPcReady = false;
    _relayPeerChunkVersion = 0;
    _relayChunkReassembler.clear();
    for (final timer in _relayOutboundChunkTimers.values) {
      timer.cancel();
    }
    _relayOutboundChunkTimers.clear();
    _relayOutboundChunkRequests.clear();
  }

  Future<void> _handleRelayE2eHello(
    Map<String, dynamic> envelope,
    Map<Object?, Object?> payload,
  ) async {
    final config = _relayConfig;
    if (config == null || !_relayPairConfirmed) return;
    if ((envelope['role']?.toString() ?? '') != 'pc' ||
        (envelope['pair_id']?.toString() ?? '') != config.pairId ||
        envelope['v'] != 2 ||
        _hasLegacyRelayIdentity(envelope) ||
        envelope['type'] != 'E2E_HELLO' ||
        !_hasExactKeys(envelope, _relayControlFields) ||
        !_hasExactKeys(payload, _relayHelloPayloadFields) ||
        envelope['payload'] != payload ||
        payload['e2e_version'] != relayE2eVersion ||
        payload['alg'] != relayCryptoAlgChacha20Poly1305) {
      _failRelayHandshake(kRelayE2eStaleSessionError);
      return;
    }
    final peerChunkVersion = payload['e2e_chunk_version'];
    var epoch = _relayE2eEpoch;
    try {
      final pcPublicKey = b64UrlDecodeNoPadding(
        payload['public_key']?.toString() ?? '',
      );
      final pcNonceBase = b64UrlDecodeNoPadding(
        payload['nonce_base']?.toString() ?? '',
      );
      if (pcPublicKey.length != 32 || pcNonceBase.length != 4) {
        throw const FormatException('invalid PC E2E key material');
      }
      bool matchesContext(RelaySessionContext current) =>
          listEquals(current.pcPublicKey, pcPublicKey) &&
          listEquals(current.pcNonceBase, pcNonceBase);

      final active = _relayE2eContext;
      if (active != null) {
        if (!matchesContext(active)) {
          _replaceRelayPeerCryptoContext();
          epoch = _relayE2eEpoch;
          debugPrint('[OSIA Relay] authoritative PC E2E peer replaced');
        } else {
          return;
        }
      }
      _relayPeerChunkVersion = peerChunkVersion == relayE2eChunkVersion
          ? relayE2eChunkVersion
          : 0;
      // The initial HELLO may have been sent before this PC joined. Send one
      // peer-bound copy for this validated key+nonce context, never for a
      // byte-identical duplicate or a readiness hint.
      _sendRelayE2eHello(forPeerContext: true);
      final context = RelaySessionContext(
        pairId: config.pairId,
        pcPublicKey: pcPublicKey,
        mobilePublicKey: config.e2ePublicKey,
        pcNonceBase: pcNonceBase,
        mobileNonceBase: config.e2eNonceBase,
      );
      final keys = await deriveSessionKeys(
        token: token,
        localPrivateKey: config.e2ePrivateKey,
        peerPublicKey: pcPublicKey,
        context: context,
      );
      if (epoch != _relayE2eEpoch ||
          !identical(_relayConfig, config) ||
          _channel == null) {
        return;
      }
      final activeAfterDerive = _relayE2eContext;
      if (activeAfterDerive != null) {
        if (!matchesContext(activeAfterDerive)) {
          _replaceRelayPeerCryptoContext();
        }
        return;
      }
      _relayE2eContext = context;
      _relayE2eKeys = keys;
      _sendRelayE2eReady();
      final pendingReady = _pendingRelayE2eReadyEnvelope;
      if (pendingReady != null) {
        _pendingRelayE2eReadyEnvelope = null;
        _handleRelayE2eReady(pendingReady);
      }
      _maybeCompleteRelayReady();
    } catch (e) {
      debugPrint('[OSIA Relay] E2E hello rejected: ${e.runtimeType}');
      _failRelayHandshake(kRelayE2eAuthMismatchError);
    }
  }

  void _handleRelayE2eReady(Map<String, dynamic> envelope) {
    final payload = envelope['payload'];
    if (payload is! Map) {
      _failRelayHandshake(kRelayE2eAuthMismatchError);
      return;
    }
    final context = _relayE2eContext;
    final keys = _relayE2eKeys;
    if (context == null || keys == null) {
      _pendingRelayE2eReadyEnvelope = Map<String, dynamic>.from(envelope);
      return;
    }
    if (envelope['v'] != 2 ||
        (envelope['role']?.toString() ?? '') != 'pc' ||
        (envelope['pair_id']?.toString() ?? '') != context.pairId ||
        _hasLegacyRelayIdentity(envelope) ||
        envelope['type'] != 'E2E_READY' ||
        !_hasExactKeys(envelope, _relayControlFields) ||
        !_hasExactKeys(payload, _relayReadyPayloadFields) ||
        envelope['payload'] != payload ||
        payload['e2e_version'] != relayE2eVersion ||
        payload['alg'] != relayCryptoAlgChacha20Poly1305) {
      _failRelayHandshake(kRelayE2eStaleSessionError);
      return;
    }
    final kid = payload['kid']?.toString() ?? '';
    if (kid != keys.kid) {
      debugPrint('[OSIA Relay] E2E ready rejected: key id mismatch');
      _failRelayHandshake(kRelayE2eAuthMismatchError);
      return;
    }
    final tag = payload['tag']?.toString() ?? '';
    bool verified;
    try {
      verified = verifyHandshakeConfirmation(
        token: token,
        context: context,
        senderRole: 'pc',
        tag: tag,
      );
    } catch (_) {
      verified = false;
    }
    if (!verified) {
      debugPrint('[OSIA Relay] E2E ready rejected: confirmation failed');
      _failRelayHandshake(kRelayE2eAuthMismatchError);
      return;
    }
    _relayPeerE2eReady = true;
    _maybeCompleteRelayReady();
  }

  void _queueRelayE2eFrame(Map<String, dynamic> envelope) {
    final epoch = _relayE2eEpoch;
    final previous = _relayReceiveChain;
    final stableEnvelope = Map<String, dynamic>.from(envelope);
    _relayReceiveChain = _runRelayE2eFrame(previous, stableEnvelope, epoch);
  }

  void _queueRelayE2eHello(
    Map<String, dynamic> envelope,
    Map<Object?, Object?> payload,
  ) {
    final previous = _relayReceiveChain;
    final stableEnvelope = Map<String, dynamic>.from(envelope);
    final stablePayload = Map<Object?, Object?>.from(payload);
    stableEnvelope['payload'] = stablePayload;
    _relayReceiveChain = _runRelayE2eHello(
      previous,
      stableEnvelope,
      stablePayload,
    );
  }

  Future<void> _runRelayE2eHello(
    Future<void> previous,
    Map<String, dynamic> envelope,
    Map<Object?, Object?> payload,
  ) async {
    try {
      await previous;
      await _handleRelayE2eHello(envelope, payload);
    } catch (e) {
      debugPrint('[OSIA Relay] E2E hello processing failed: ${e.runtimeType}');
    }
  }

  void _queueRelayE2eChunk(Map<String, dynamic> envelope) {
    final epoch = _relayE2eEpoch;
    final previous = _relayReceiveChain;
    final stableEnvelope = Map<String, dynamic>.from(envelope);
    _relayReceiveChain = _runRelayE2eChunk(previous, stableEnvelope, epoch);
  }

  Future<void> _runRelayE2eFrame(
    Future<void> previous,
    Map<String, dynamic> envelope,
    int epoch,
  ) async {
    try {
      await previous;
      if (epoch != _relayE2eEpoch) return;
      await _handleRelayE2eFrame(envelope, epoch);
    } catch (e) {
      debugPrint(
        '[OSIA Relay] encrypted frame processing failed: ${e.runtimeType}',
      );
    }
  }

  Future<void> _runRelayE2eChunk(
    Future<void> previous,
    Map<String, dynamic> envelope,
    int epoch,
  ) async {
    try {
      await previous;
      if (epoch != _relayE2eEpoch) return;
      await _handleRelayE2eChunk(envelope, epoch);
    } catch (e) {
      debugPrint(
        '[OSIA Relay] encrypted chunk processing failed: ${e.runtimeType}',
      );
    }
  }

  Future<bool> _handleRelayE2eFrame(
    Map<String, dynamic> envelope,
    int epoch,
  ) async {
    final keys = _relayE2eKeys;
    final context = _relayE2eContext;
    if (keys == null || context == null || !_relayPeerE2eReady) {
      debugPrint('[OSIA Relay] encrypted frame arrived before E2E was ready');
      _relayHandshakeFailure ??= kRelayE2eStaleSessionError;
      return false;
    }
    if (envelope['v'] != 2 ||
        (envelope['role']?.toString() ?? '') != 'pc' ||
        (envelope['pair_id']?.toString() ?? '') != context.pairId ||
        _hasLegacyRelayIdentity(envelope) ||
        !_hasExactKeys(envelope, _relayE2eFrameFields)) {
      debugPrint('[OSIA Relay] ignored encrypted frame for a stale session');
      return false;
    }
    try {
      final frame = await decryptFrame(
        envelope,
        keys: keys,
        direction: RelayCryptoDirection.pcToMobile,
        replayGuard: _relayE2eReplayGuard,
        replayKey: 'pc',
      );
      if (epoch != _relayE2eEpoch) return false;
      if (frame['type'] == 'webrtc_capabilities') {
        final capability = WebRtcCapability.fromFrame(frame);
        _webRtcCapability = capability;
        final completer = _webRtcCapabilityCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(capability);
        }
        debugPrint(
          '[OSIA WebRTC] PC capability enabled=${capability.enabled} '
          'ice_servers=${capability.iceServers.length}',
        );
        return true;
      }
      if (webRtcSignalEventTypes.contains(frame['event_type'])) {
        final transport = _webRtcTransport;
        if (transport != null) {
          await transport.handleSignal(frame);
        }
        return true;
      }
      if (frame['type'] == 'lan_provisioning') {
        if (frame.keys.toSet().difference(const <String>{
              'type',
              'protocol_version',
              'product_version',
              'instance_alias',
              'certificate_sha256',
              'port',
              'path',
            }).isNotEmpty ||
            frame.length != 7 ||
            frame['protocol_version'] != lanDirectProtocolVersion ||
            frame['port'] != lanDirectPort ||
            frame['path'] != '/lan' ||
            (frame['product_version']?.toString() ?? '').isEmpty) {
          _failRelayHandshake(kRelayE2eStaleSessionError);
          return false;
        }
        final alias = frame['instance_alias']?.toString() ?? '';
        final pin = frame['certificate_sha256']?.toString() ?? '';
        if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(alias) ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(pin)) {
          _failRelayHandshake(kRelayE2eStaleSessionError);
          return false;
        }
        final identity = LanPairingIdentity(
          instanceAlias: alias,
          certificateSha256: pin,
        );
        final config = _relayConfig;
        if (storage != null && config != null) {
          await storage!.setLanPairing(config.pairId, identity);
        }
        final completer = _lanProvisioningCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(identity);
        }
        return true;
      }
      if (frame['type'] == 'relay_chunk_error') {
        _handleRelayChunkErrorFrame(frame);
        return true;
      }
      if (frame['type'] == 'transport_committed') {
        if (!_directFirstEnabled ||
            frame.length != 3 ||
            frame['transport'] != 'relay' ||
            frame['attempt_id'] != _relayCommitAttemptId ||
            !_relayCommitSent) {
          _failRelayHandshake(kRelayE2eStaleSessionError);
          return false;
        }
        _relayCommitConfirmed = true;
        _maybeCompleteRelayReady();
        return true;
      }
      if (_directFirstEnabled &&
          _relaySignalingStandby &&
          !_relayCommitConfirmed) {
        _failRelayHandshake(kRelayE2eStaleSessionError);
        return false;
      }
      _onData(frame.cast<String, dynamic>());
      return true;
    } catch (e) {
      debugPrint('[OSIA Relay] invalid encrypted frame: ${e.runtimeType}');
      _emitRelayTransfer(
        RelayTransferEvent(
          direction: RelayTransferDirection.inbound,
          state: RelayTransferState.failed,
          chunkId: '',
          clientRequestId: _relayLastOutboundRequestId,
          errorKind: RelayTransferErrorKind.e2eDecryptFailed,
        ),
      );
      if (!_errorCtrl.isClosed) {
        _errorCtrl.add(kRelayE2eDecryptFailedError);
      }
      _channel?.sink.close();
      return false;
    }
  }

  Future<void> _handleRelayE2eChunk(
    Map<String, dynamic> envelope,
    int epoch,
  ) async {
    final context = _relayE2eContext;
    final keys = _relayE2eKeys;
    if (!_relayChunkingSupported ||
        keys == null ||
        context == null ||
        !_relayPeerE2eReady) {
      _emitRelayTransfer(
        const RelayTransferEvent(
          direction: RelayTransferDirection.inbound,
          state: RelayTransferState.failed,
          chunkId: '',
          errorKind: RelayTransferErrorKind.unsupportedChunk,
        ),
      );
      return;
    }
    final frameSeq = envelope['frame_seq'];
    if (envelope['kid'] != keys.kid || frameSeq is! int) {
      debugPrint('[OSIA Relay] ignored encrypted chunk for an old key context');
      return;
    }
    try {
      final nonce = b64UrlDecodeNoPadding(envelope['nonce']?.toString() ?? '');
      final expected = nonceForSeq(
        keys.directionNonceBase(RelayCryptoDirection.pcToMobile),
        frameSeq,
      );
      if (!listEquals(nonce, expected)) {
        debugPrint('[OSIA Relay] ignored encrypted chunk with a stale nonce');
        return;
      }
    } catch (_) {
      debugPrint('[OSIA Relay] ignored encrypted chunk with invalid metadata');
      return;
    }
    if (envelope['v'] != 2 ||
        (envelope['role']?.toString() ?? '') != 'pc' ||
        (envelope['pair_id']?.toString() ?? '') != context.pairId ||
        _hasLegacyRelayIdentity(envelope)) {
      debugPrint('[OSIA Relay] ignored encrypted chunk for a stale session');
      return;
    }

    try {
      final result = _relayChunkReassembler.accept(
        envelope.cast<String, Object?>(),
      );
      if (result.started) {
        _emitRelayTransfer(
          RelayTransferEvent(
            direction: RelayTransferDirection.inbound,
            state: RelayTransferState.started,
            chunkId: result.chunkId,
            clientRequestId: _relayLastOutboundRequestId,
          ),
        );
      }
      final complete = result.completeEnvelope;
      if (complete == null || epoch != _relayE2eEpoch) return;
      final delivered = await _handleRelayE2eFrame(
        complete.cast<String, dynamic>(),
        epoch,
      );
      if (delivered && epoch == _relayE2eEpoch) {
        _emitRelayTransfer(
          RelayTransferEvent(
            direction: RelayTransferDirection.inbound,
            state: RelayTransferState.completed,
            chunkId: result.chunkId,
            clientRequestId: _relayLastOutboundRequestId,
          ),
        );
      }
    } on RelayChunkException catch (e) {
      _emitRelayTransfer(
        RelayTransferEvent(
          direction: RelayTransferDirection.inbound,
          state: RelayTransferState.failed,
          chunkId: e.chunkId,
          clientRequestId: _relayLastOutboundRequestId,
          errorKind: RelayTransferErrorKind.chunkFailed,
        ),
      );
      _sendRelayInternalChunkError(e.chunkId, e.code);
      final sendTail = _relaySendChain;
      final channel = _channel;
      unawaited(
        sendTail.whenComplete(() {
          if (epoch == _relayE2eEpoch && identical(channel, _channel)) {
            channel?.sink.close();
          }
        }),
      );
    }
  }

  void _handleRelayChunkTimeout(RelayChunkTimeoutEvent event) {
    if (_relayE2eKeys == null || !_relayPeerE2eReady) return;
    _emitRelayTransfer(
      RelayTransferEvent(
        direction: RelayTransferDirection.inbound,
        state: RelayTransferState.failed,
        chunkId: event.chunkId,
        clientRequestId: _relayLastOutboundRequestId,
        errorKind: RelayTransferErrorKind.chunkFailed,
      ),
    );
    _sendRelayInternalChunkError(event.chunkId, 'chunk_timeout');
  }

  void _sendRelayInternalChunkError(String chunkId, String code) {
    if (chunkId.isEmpty) return;
    _sendRelayEncryptedFrame(<String, dynamic>{
      'type': 'relay_chunk_error',
      'chunk_id': chunkId,
      'code': code,
    });
  }

  void _handleRelayChunkErrorFrame(Map<String, Object?> frame) {
    final chunkId = frame['chunk_id']?.toString() ?? '';
    final code = frame['code']?.toString() ?? '';
    if (chunkId.isEmpty) return;
    if (code == 'unsupported_chunk' || code == 'frame_too_large') {
      _emitRelayTransfer(
        RelayTransferEvent(
          direction: RelayTransferDirection.inbound,
          state: RelayTransferState.failed,
          chunkId: chunkId,
          clientRequestId: _relayLastOutboundRequestId,
          errorKind: code == 'unsupported_chunk'
              ? RelayTransferErrorKind.unsupportedChunk
              : RelayTransferErrorKind.frameTooLarge,
        ),
      );
      return;
    }
    if (!code.startsWith('chunk_')) return;
    final clientRequestId = _forgetOutboundRelayChunk(chunkId);
    if (clientRequestId.isEmpty) return;
    _rollbackRelayRequest(clientRequestId);
    _emitRelayTransfer(
      RelayTransferEvent(
        direction: RelayTransferDirection.outbound,
        state: RelayTransferState.failed,
        chunkId: chunkId,
        clientRequestId: clientRequestId,
        errorKind: RelayTransferErrorKind.chunkFailed,
      ),
    );
  }

  void _onRelayData(dynamic raw) {
    try {
      final Map<String, dynamic> envelope = (raw is String)
          ? jsonDecode(raw) as Map<String, dynamic>
          : raw;
      final type = envelope['type']?.toString() ?? '';
      final payload = envelope['payload'];

      switch (type) {
        case 'PAIR_CONFIRM':
          final config = _relayConfig;
          _captureRelayWorkerChunkCapabilities(payload);
          if (config == null ||
              envelope['v'] != 2 ||
              envelope['role'] != 'mobile' ||
              envelope['pair_id'] != config.pairId ||
              payload is! Map ||
              payload['relay_protocol_version'] != 2 ||
              payload['identity_mode'] != 'role_authority' ||
              !_relayWorkerCapabilitiesReady(payload) ||
              _hasLegacyRelayIdentity(envelope)) {
            _relayBlocksLegacyFallback = true;
            _failRelayHandshake(kRelayUpdateRequiredError);
            break;
          }
          debugPrint('[OSIA Relay] pair confirmed');
          _relayPairConfirmed = true;
          _sendRelayE2eHello();
          _sendRelayMobileReady();
        case 'E2E_HELLO':
          if (payload is Map) {
            _queueRelayE2eHello(envelope, payload);
          }
        case 'E2E_READY':
          _handleRelayE2eReady(envelope);
        case 'PC_READY':
          final config = _relayConfig;
          if (config == null ||
              envelope['v'] != 2 ||
              (envelope['role']?.toString() ?? '') != 'pc' ||
              (envelope['pair_id']?.toString() ?? '') != config.pairId ||
              _hasLegacyRelayIdentity(envelope)) {
            _failRelayHandshake(kRelayE2eStaleSessionError);
            break;
          }
          final relayOnlyReady =
              payload is Map && payload.length == 1 && payload['e2e'] == true;
          final standbyReady =
              payload is Map &&
              payload.length == 2 &&
              payload['e2e'] == true &&
              payload['standby'] == true;
          if (_directFirstEnabled && !relayOnlyReady && !standbyReady) {
            _failRelayHandshake(kRelayE2eStaleSessionError);
            break;
          }
          _relayPcRequiresCommit = _directFirstEnabled && standbyReady;
          if (_directFirstEnabled && relayOnlyReady) {
            _relaySignalingStandby = false;
          }
          _relayPcReady = true;
          _maybeCompleteRelayReady();
        case 'E2E_FRAME':
          _queueRelayE2eFrame(envelope);
        case 'E2E_CHUNK':
          _queueRelayE2eChunk(envelope);
        case 'FRAME':
          if (_connectedViaRelay) {
            debugPrint('[OSIA Relay] dropped plaintext FRAME; E2E is required');
            _failRelayHandshake(kRelayE2eRequiredError);
            break;
          }
          _markConnected();
          _completeRelayReady(true);
          if (payload is Map) {
            final frame = payload['frame'];
            if (frame is Map) {
              _onData(frame.cast<String, dynamic>());
            }
          }
        case 'BATCH':
          if (_connectedViaRelay) {
            debugPrint('[OSIA Relay] dropped plaintext BATCH; E2E is required');
            _failRelayHandshake(kRelayE2eRequiredError);
            break;
          }
          _markConnected();
          _completeRelayReady(true);
          if (payload is Map && payload['frames'] is List) {
            for (final frame in payload['frames'] as List) {
              if (frame is Map) _onData(frame.cast<String, dynamic>());
            }
          }
        case 'PING':
          _sendRelayEnvelope('PONG', {
            't': DateTime.now().millisecondsSinceEpoch,
          });
        case 'DISCONNECT':
          _relayHandshakeFailure ??= kRelayE2eStaleSessionError;
          _channel?.sink.close();
        case 'ERROR':
          final code = payload is Map ? payload['code']?.toString() ?? '' : '';
          if (code == 'peer_unavailable') {
            debugPrint('[OSIA Relay] peer unavailable during handshake grace');
            break;
          }
          final msg = _relayErrorMessage(code);
          debugPrint('[OSIA Relay] control error: $code');
          if (code == 'update_required' ||
              code == 'pair_proof_mismatch' ||
              code == 'invalid_pair_route' ||
              code == 'session_superseded') {
            _relayBlocksLegacyFallback = true;
            _reconnectTimer?.cancel();
            _reconnectTimer = null;
            _suppressReconnectOnce = true;
            _relayHandshakeFailure ??= msg;
            _completeRelayReady(false);
            if (_state == ConnectionState.connected && !_errorCtrl.isClosed) {
              _errorCtrl.add(msg);
            }
            _channel?.sink.close();
            break;
          }
          if (code == 'resume_not_supported') {
            _relayHandshakeFailure ??= msg;
            _completeRelayReady(false);
            _channel?.sink.close();
            break;
          }
          if (_state == ConnectionState.connected) {
            final RelayTransferErrorKind? errorKind = switch (code) {
              'frame_too_large' => RelayTransferErrorKind.frameTooLarge,
              'unsupported_chunk' ||
              'update_required' => RelayTransferErrorKind.unsupportedChunk,
              'e2e_auth_failed' ||
              'e2e_decrypt_failed' => RelayTransferErrorKind.e2eDecryptFailed,
              _ when code.startsWith('chunk_') =>
                RelayTransferErrorKind.chunkFailed,
              _ => null,
            };
            if (errorKind != null) {
              final requestId = _relayLastOutboundRequestId;
              _rollbackRelayRequest(requestId);
              _emitRelayTransfer(
                RelayTransferEvent(
                  direction: RelayTransferDirection.outbound,
                  state: RelayTransferState.failed,
                  chunkId: '',
                  clientRequestId: requestId,
                  errorKind: errorKind,
                ),
              );
            }
            break;
          }
          _relayHandshakeFailure ??= msg;
          _completeRelayReady(false);
        default:
          debugPrint('[OSIA Relay] unhandled envelope type="$type"');
      }
    } catch (e) {
      debugPrint('[OSIA Relay] parse error: ${e.runtimeType}');
    }
  }

  Future<void> _doConnect({
    required String reason,
    required int connectGeneration,
  }) async {
    final testAttempt = connectAttemptForTest;
    if (testAttempt != null) {
      try {
        final succeeded = await testAttempt();
        if (!_isCurrentConnect(connectGeneration)) return;
        _setState(
          succeeded ? ConnectionState.connected : ConnectionState.disconnected,
        );
      } catch (_) {
        if (_isCurrentConnect(connectGeneration)) {
          _setState(ConnectionState.disconnected);
        }
      }
      return;
    }

    if (_directFirstEnabled &&
        const <ApplicationTransportKind>{
          ApplicationTransportKind.lan,
          ApplicationTransportKind.webrtc,
        }.contains(_lastTransportKind) &&
        _hasActiveApplicationTurn) {
      debugPrint(
        '[OSIA Direct] reconnect blocked while an application request is active',
      );
      _setState(ConnectionState.disconnected);
      return;
    }

    if (lanDirectV1 && !_hasActiveApplicationTurn) {
      try {
        final manualConfig =
            lanDirectConfig ?? LanDirectConfig.fromEnvironment();
        if (manualConfig != null) {
          final lanReady = await _tryLanConnect(
            manualConfig,
            connectGeneration,
          );
          if (!_isCurrentConnect(connectGeneration)) return;
          if (lanReady) return;
        } else if (storage != null) {
          final pairId = RelayService.derivePairCredentials(token).pairId;
          final savedIdentity = await storage!.getLanPairing(pairId);
          if (!_isCurrentConnect(connectGeneration)) return;
          if (savedIdentity != null) {
            final discovered = await _discoverLanConfig(savedIdentity);
            if (!_isCurrentConnect(connectGeneration)) return;
            if (discovered != null &&
                await _tryLanConnect(discovered, connectGeneration)) {
              return;
            }
          }
        }
      } catch (error) {
        debugPrint('[OSIA LAN] preactivation attempt failed');
      }
    }

    if (_directFirstEnabled &&
        _relaySignalingStandby &&
        _channel != null &&
        !_hasActiveApplicationTurn) {
      final capability = _webRtcCapability;
      if (webRtcDirectV1 &&
          capability != null &&
          capability.enabled &&
          await _tryWebRtcConnect(capability, connectGeneration)) {
        return;
      }
      if (await _commitRelayStandby(connectGeneration)) return;
      await _closeCurrentChannel(
        reason: 'existing relay standby could not be committed',
        emitDisconnected: false,
      );
    }

    if (relayFallbackV1 && resolveRelay != null) {
      try {
        final relayConfig = await resolveRelay!();
        if (!_isCurrentConnect(connectGeneration)) return;
        final relayReady = await _tryRelayConnect(
          relayConfig,
          connectGeneration,
          standbyOnly: _directFirstEnabled,
        );
        if (!_isCurrentConnect(connectGeneration)) return;
        if (relayReady && _directFirstEnabled) {
          if (!_relaySignalingStandby) return;
          LanPairingIdentity? provisioned;
          final provisioning = _lanProvisioningCompleter;
          if (provisioning != null) {
            provisioned = await provisioning.future.timeout(
              const Duration(seconds: 2),
              onTimeout: () => null,
            );
          }
          if (!_isCurrentConnect(connectGeneration)) return;
          if (provisioned != null) {
            final discovered = await _discoverLanConfig(provisioned);
            if (!_isCurrentConnect(connectGeneration)) return;
            if (discovered != null &&
                await _tryLanConnect(discovered, connectGeneration)) {
              return;
            }
          }
          WebRtcCapability? capability = _webRtcCapability;
          final capabilityCompleter = _webRtcCapabilityCompleter;
          if (webRtcDirectV1 &&
              capability == null &&
              capabilityCompleter != null) {
            capability = await capabilityCompleter.future.timeout(
              const Duration(seconds: 2),
              onTimeout: () => null,
            );
          }
          if (!_isCurrentConnect(connectGeneration)) return;
          if (webRtcDirectV1 &&
              capability != null &&
              capability.enabled &&
              await _tryWebRtcConnect(capability, connectGeneration)) {
            return;
          }
          if (await _commitRelayStandby(connectGeneration)) return;
          await _closeCurrentChannel(
            reason: 'LAN preactivation failed and relay commit was unavailable',
            emitDisconnected: false,
          );
        } else if (relayReady) {
          return;
        }
        if (_relayBlocksLegacyFallback) {
          final error = _relayHandshakeFailure ?? kRelayUpdateRequiredError;
          if (!_errorCtrl.isClosed) _errorCtrl.add(error);
          _setState(ConnectionState.disconnected);
          return;
        }
        if (!allowLegacyRendezvousFallback) {
          final error = _relayHandshakeFailure ?? kRelayE2eUnavailableError;
          debugPrint(
            '[OSIA Relay] E2E connection failed; legacy fallback disabled',
          );
          _errorCtrl.add(error);
          _setState(ConnectionState.disconnected);
          _scheduleReconnect();
          return;
        }
        debugPrint(
          '[OSIA Relay] Relay unavailable; using legacy rendezvous fallback',
        );
      } catch (e) {
        if (!_isCurrentConnect(connectGeneration)) return;
        if (e is FormatException) {
          debugPrint('[OSIA Relay] invalid relay configuration');
          if (!_errorCtrl.isClosed) {
            _errorCtrl.add(kRelayPairingConfigurationError);
          }
          _setState(ConnectionState.disconnected);
          return;
        }
        if (!allowLegacyRendezvousFallback) {
          debugPrint(
            '[OSIA Relay] Relay setup failed; legacy rendezvous fallback disabled',
          );
          _errorCtrl.add(kRelayUnreachableError);
          _setState(ConnectionState.disconnected);
          _scheduleReconnect();
          return;
        }
        debugPrint('[OSIA Relay] Relay setup failed; using legacy fallback');
      }
    }

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
        if (!_isCurrentConnect(connectGeneration)) return;
      } catch (e) {
        if (!_isCurrentConnect(connectGeneration)) return;
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
    debugPrint(
      '[OSIA WS] Connecting to $url (timeout ${_connectTimeout.inSeconds}s)',
    );

    final legacyLease = _transportCoordinator.tryAcquire(
      ApplicationTransportKind.legacy,
      this,
    );
    if (legacyLease == null) {
      _setState(ConnectionState.disconnected);
      return;
    }
    _transportLease = legacyLease;
    var retainLegacyLease = false;
    try {
      final socket = await WebSocket.connect(url).timeout(_connectTimeout);
      if (!_isCurrentConnect(connectGeneration)) {
        unawaited(socket.close());
        return;
      }

      // Socket is open — we're connected. Don't wait for any server message
      // to flip state, or the badge stays on "Connexion…" forever.
      _attachChannel(IOWebSocketChannel(socket), relay: false, onData: _onData);
      _lastTransportKind = ApplicationTransportKind.legacy;
      retainLegacyLease = true;
      _markConnected();
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
      debugPrint('[OSIA WS] Socket open, sending auth');

      // Auth is the first message after the socket opens.
      _send({'type': 'auth', 'token': token, 'device_id': _permissionDeviceId});
    } on TimeoutException {
      if (!_isCurrentConnect(connectGeneration)) return;
      final msg =
          'Connexion expirée après ${_connectTimeout.inSeconds}s ($url)';
      debugPrint('[OSIA WS] $msg');
      _errorCtrl.add(msg);
      _setState(ConnectionState.disconnected);
      _scheduleReconnect();
    } on SocketException catch (e) {
      if (!_isCurrentConnect(connectGeneration)) return;
      final msg = 'Réseau injoignable: ${e.message} ($url)';
      debugPrint('[OSIA WS] $msg');
      _errorCtrl.add(msg);
      _setState(ConnectionState.disconnected);
      _scheduleReconnect();
    } on WebSocketException catch (e) {
      if (!_isCurrentConnect(connectGeneration)) return;
      final msg = 'WebSocket refusé: ${e.message} ($url)';
      debugPrint('[OSIA WS] $msg');
      _errorCtrl.add(msg);
      _setState(ConnectionState.disconnected);
      _scheduleReconnect();
    } catch (e) {
      if (!_isCurrentConnect(connectGeneration)) return;
      final msg = 'Échec de connexion: $e ($url)';
      debugPrint('[OSIA WS] $msg');
      _errorCtrl.add(msg);
      _setState(ConnectionState.disconnected);
      _scheduleReconnect();
    } finally {
      if (!retainLegacyLease) {
        if (identical(_transportLease, legacyLease)) _transportLease = null;
        legacyLease.release();
      }
    }
  }

  void _onData(dynamic raw) {
    try {
      final Map<String, dynamic> json = (raw is String)
          ? jsonDecode(raw) as Map<String, dynamic>
          : raw;

      if (!_acceptCanonicalApplicationEvent(json)) return;

      final type = json['type'] as String?;
      final content = json['content'] as String?;
      final data = json['data'] as String?;
      // WOR-53: optional per-turn conversation-id routing hint. The server tags
      // the streaming frames (response_chunk / response / status) with
      // `conversation_id`; conversation_history mirrors it onto `id`, so read
      // conversation_id with an id fallback. Only the streaming cases below use
      // it — it routes a backgrounded stream to its conversation buffer.
      final convId = (json['conversation_id'] ?? json['id'])?.toString();
      final clientRequestId =
          json['request_id']?.toString() ??
          json['client_request_id']?.toString() ??
          '';
      final turnId = json['turn_id']?.toString() ?? '';
      final messageId = json['message_id']?.toString() ?? '';

      if (const <String>{
        'attachment_batch_accept',
        'attachment_batch_reject',
        'attachment_batch_commit_ack',
        'attachment_batch_failed',
      }.contains(type)) {
        if (!_attachmentProtocolCtrl.isClosed) {
          _attachmentProtocolCtrl.add(
            AttachmentProtocolMessage(Map<String, dynamic>.from(json)),
          );
        }
        return;
      }

      switch (type) {
        case 'transcript':
          if (content != null) {
            _emit(
              TranscriptMessage(
                content,
                conversationId: convId ?? '',
                clientRequestId: clientRequestId,
                turnId: turnId,
                messageId: messageId,
              ),
            );
          }
        case 'response':
          if (content != null) {
            _markDocumentCanonicalTerminal('chat', turnId);
            if (!_directFirstEnabled) _emit(ResponseMessage(content));
            // WOR-53: also replace this conversation's buffer with the
            // canonical full reply (parallel sink — no change to pacing).
            _replaceConvText(
              convId,
              content,
              clientRequestId: clientRequestId,
              turnId: turnId,
              messageId: messageId,
            );
          }
        case 'response_chunk':
          if (content != null && content.isNotEmpty) {
            if (!_directFirstEnabled) _emit(ResponseChunkMessage(content));
            // WOR-53: also accrue the delta into this conversation's buffer so
            // its reply survives a screen switch and hydrates on return.
            _appendConvDelta(
              convId,
              content,
              clientRequestId: clientRequestId,
              turnId: turnId,
              messageId: messageId,
            );
          }
        case 'audio':
          if (data != null) {
            final source = json['source'] as String?;
            final mediaTerminal = json['media_terminal'] == true;
            debugPrint(
              '[OSIA WS] audio frame received: ${data.length} b64 chars, '
              'source=$source',
            );
            final owned =
                !mediaTerminal ||
                _finishMediaPhase(
                  convId ?? '',
                  clientRequestId: clientRequestId,
                  turnId: turnId,
                  messageId: messageId,
                );
            if (!owned) break;
            _emit(
              AudioMessage(
                data,
                source: source,
                conversationId: convId ?? '',
                clientRequestId: clientRequestId,
                turnId: turnId,
                messageId: messageId,
              ),
            );
          }
        case 'media_status':
          if (json['media_terminal'] == true) {
            _finishMediaPhase(
              convId ?? '',
              clientRequestId: clientRequestId,
              turnId: turnId,
              messageId: messageId,
            );
          }
        case 'status':
          if (content != null) {
            if (content == 'done' && (convId == null || convId.isEmpty)) {
              _requestAuthenticatedInitialState();
            }
            _emit(
              StatusMessage(
                content,
                conversationId: convId ?? '',
                clientRequestId: clientRequestId,
                turnId: turnId,
              ),
            );
            // WOR-53: a terminal turn status finalizes the conversation's
            // background stream (marks it not-streaming + terminal event).
            // Early error frames without a conversation_id are ignored by
            // [_finishConvStream]'s null guard.
            if (content == 'done' || content == 'error') {
              _markDocumentCanonicalTerminal('chat', turnId);
              if (kOsiaDebugPlaceholder) {
                debugPrint(
                  '[OSIA WOR-75] terminal status received '
                  'tagged=${convId != null}',
                );
              }
              _finishConvStream(
                convId,
                error: content == 'error',
                clientRequestId: clientRequestId,
                turnId: turnId,
                frameType: 'status',
              );
            }
          }
        case 'turn_accepted':
        case 'turn_status':
          _handleTurnAcceptedFrame(json);
        case 'response_done':
        case 'turn_complete':
        case 'done':
          _markDocumentCanonicalTerminal('chat', turnId);
          _finishConvStream(
            convId,
            error: false,
            clientRequestId: clientRequestId,
            turnId: turnId,
            frameType: type ?? 'done',
          );
        case 'error':
          if (convId != null && convId.isNotEmpty) {
            _markDocumentCanonicalTerminal('chat', turnId);
            _finishConvStream(
              convId,
              error: true,
              clientRequestId: clientRequestId,
              turnId: turnId,
              frameType: 'error',
            );
          }
        case 'conversations':
          final raw = json['items'] ?? json['conversations'];
          if (raw is List) {
            final list = raw
                .whereType<Map>()
                .map((e) => Conversation.fromJson(e.cast<String, dynamic>()))
                .toList();
            debugPrint(
              '[OSIA WS] conversations received: ${list.length} item(s)',
            );
            if (list.isNotEmpty) {
              debugPrint('[OSIA WS]   first conversation metadata received');
            }
            _emit(ConversationsMessage(list));
          } else {
            debugPrint(
              '[OSIA WS] conversations message had no list payload: keys=${json.keys.toList()}',
            );
          }
        case 'active_conversation':
          final id = json['id']?.toString();
          final title = json['title']?.toString();
          debugPrint('[OSIA WS] active_conversation received');
          _emit(ActiveConversationMessage(id: id, title: title));
        case 'models_list':
          final catalogue = json['catalogue'];
          final rawProviders = catalogue is Map ? catalogue['providers'] : null;
          final hasAuthoritativeCatalogue = rawProviders is List;
          final providerIds = <String>{};
          final providers = rawProviders is List
              ? rawProviders
                    .whereType<Map>()
                    .map(
                      (value) => ModelProviderCatalogueEntry.fromJson(
                        value.cast<String, dynamic>(),
                      ),
                    )
                    .where(
                      (entry) =>
                          entry.id.isNotEmpty &&
                          entry.models.isNotEmpty &&
                          providerIds.add(entry.id),
                    )
                    .toList()
              : <ModelProviderCatalogueEntry>[];
          final seenModels = <String>{};
          final rawModels = json['models'] ?? json['items'];
          final list = hasAuthoritativeCatalogue
              ? [for (final provider in providers) ...provider.models]
              : rawModels is List
              ? rawModels
                    .map(OsiaModel.fromJson)
                    .where(
                      (model) =>
                          model.id.trim().isNotEmpty &&
                          model.selectable &&
                          seenModels.add(
                            '${model.provider ?? ''}\u0000${model.id}',
                          ),
                    )
                    .toList()
              : <OsiaModel>[];
          final current = (json['current'] ?? json['selected'])?.toString();
          final currentProvider = json['current_provider']?.toString();
          final account = _acceptChatGptAccountSnapshot(
            json['account'],
            standalone: false,
          );
          debugPrint(
            '[OSIA WS] models_list: ${list.length} model(s), current=$current',
          );
          _emit(
            ModelsListMessage(
              models: list,
              providers: providers,
              current: current,
              currentProvider: currentProvider,
              account: account,
            ),
          );
        case 'chatgpt_account_state':
          _acceptChatGptAccountSnapshot(json['account'], standalone: true);
        case 'permission_snapshot':
          _handlePermissionSnapshot(json);
        case 'permission_revocation_ack':
          _handlePermissionRevocationAck(json);
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
              'heavy=${data.heavyChain.length} medium=${data.mediumChain.length}',
            );
            if (!_configCtrl.isClosed) _configCtrl.add(data);
          } else {
            debugPrint('[OSIA WS] config message had no config payload');
          }
        case 'conversation_history':
          final raw = json['messages'];
          final list = raw is List
              ? raw
                    .whereType<Map>()
                    .map(
                      (m) => HistoryMessage.fromJson(m.cast<String, dynamic>()),
                    )
                    .toList()
              : <HistoryMessage>[];
          debugPrint(
            '[OSIA WS] conversation_history: ${list.length} message(s)',
          );
          _emit(
            ConversationHistoryMessage(
              id: json['id']?.toString(),
              messages: list,
            ),
          );
        case 'api_keys':
          // Raw provider keys for pre-filling editors. Delivered on its own
          // [apiKeysStream] (NOT the paced message queue) so it can't disturb
          // response-chunk streaming.
          final keysMsg = ApiKeysMessage.fromJson(json);
          debugPrint(
            '[OSIA WS] api_keys received: ${keysMsg.keys.length} key(s)',
          );
          if (!_apiKeysCtrl.isClosed) _apiKeysCtrl.add(keysMsg);
        case 'memory':
        case 'memory_updated':
          // Local memory snapshots. Own stream, same rationale as config.
          final rawMemory = json['memory'];
          if (rawMemory is Map) {
            final snapshot = MemorySnapshot.fromJson(
              rawMemory.cast<String, dynamic>(),
            );
            _memorySnapshot = snapshot;
            debugPrint(
              '[OSIA WS] $type received: ${snapshot.entries.length} entries',
            );
            if (!_memoryCtrl.isClosed) _memoryCtrl.add(snapshot);
          } else {
            debugPrint('[OSIA WS] $type message had no memory payload');
          }
        case 'memory_error':
          final err = MemoryErrorMessage.fromJson(json);
          debugPrint('[OSIA WS] memory_error ${err.code}');
          if (!_memoryErrorCtrl.isClosed) _memoryErrorCtrl.add(err);
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
                    .map(
                      (e) =>
                          ConversationItem.fromJson(e.cast<String, dynamic>()),
                    )
                    .toList()
              : <ConversationItem>[];
          debugPrint('[OSIA WS] conversations_list: ${convs.length} item(s)');
          if (!_conversationsListCtrl.isClosed) {
            _conversationsListCtrl.add(ConversationsListMessage(convs));
          }
        case 'cron_notification':
          final note = CronNotificationMessage.fromJson(json);
          if (_directFirstEnabled &&
              (note.id.isEmpty ||
                  note.requestId.isEmpty ||
                  note.turnId.isEmpty ||
                  note.messageId.isEmpty ||
                  note.eventId != note.id ||
                  note.eventType != 'cron_notification' ||
                  note.sequence <= 0 ||
                  !note.terminal)) {
            debugPrint('[OSIA WS] rejected incomplete cron notification');
            break;
          }
          final id = note.id;
          if (id.isNotEmpty) {
            if (_seenCronNotifications.contains(id)) break;
            _seenCronNotifications.add(id);
            if (_seenCronNotifications.length > 200) {
              _seenCronNotifications.clear();
              _seenCronNotifications.add(id);
            }
          }
          debugPrint('[OSIA WS] cron_notification: status=${note.status}');
          if (!_cronNotificationCtrl.isClosed) {
            _cronNotificationCtrl.add(note);
          }
        case 'scheduled_task_authorization_context':
          final origin = json['origin_ref'];
          _scheduledAuthorizationOrigin = origin is String ? origin : '';
        case 'scheduled_task_authorization_request':
        case 'scheduled_task_authorization_state':
          final event = ScheduledTaskAuthorizationEvent.fromJson(json);
          if (!_scheduledAuthorizationCtrl.isClosed) {
            _scheduledAuthorizationCtrl.add(event);
          }
        case 'autonomous_authorization_context':
          final origin = json['origin_ref'];
          _autonomousAuthorizationOrigin = origin is String ? origin : '';
        case 'autonomous_progress':
          // Canonical progress is accepted only after the authenticated
          // server/session/run/revision/sequence guard. A stale frame can
          // never replace the terminal result.
          if (!_validAutonomousProgressFrame(json)) break;
          final canonicalProgress = AutonomousProgressMessage.fromJson(json);
          _autonomousProgress = canonicalProgress;
          final documentSnapshot = json['document_progress'];
          if (documentSnapshot is List) {
            for (final item in documentSnapshot.whereType<Map>()) {
              _handleDocumentProgress(Map<String, dynamic>.from(item));
            }
          }
          if (canonicalProgress.terminal == true &&
              (canonicalProgress.runId ?? '').isNotEmpty) {
            _markDocumentCanonicalTerminal(
              'autonomous',
              canonicalProgress.runId!,
            );
          }
          debugPrint(
            '[OSIA WS] autonomous_progress: event=${canonicalProgress.event} '
            '${canonicalProgress.tasksDone}/${canonicalProgress.tasksTotal}',
          );
          if (!_autonomousCtrl.isClosed) {
            _autonomousCtrl.add(canonicalProgress);
          }
        case 'autonomous_plan_ready':
        case 'autonomous_authorization_request':
        case 'autonomous_scope_extension_request':
        case 'autonomous_authorization_state':
        case 'autonomous_authorization_revoked':
          // Live progress for an autonomous run (WOR-45 Phase 5). Delivered on
          // its own [autonomousStream] (NOT the paced message queue) so it can't
          // disturb response-chunk streaming.
          final prog = AutonomousProgressMessage.fromJson(json);
          _autonomousProgress = prog;
          debugPrint(
            '[OSIA WS] autonomous_progress: event=${prog.event} '
            '${prog.tasksDone}/${prog.tasksTotal}',
          );
          if (!_autonomousCtrl.isClosed) {
            _autonomousCtrl.add(prog);
          }
        case 'browser_progress':
          _handleBrowserProgress(json);
        case 'document_progress':
          _handleDocumentProgress(json);
        case 'mcp_status':
          // Live MCP connector status (WOR-44 Phase 4). Delivered on its own
          // [mcpStatusStream] (NOT the paced message queue) so it can't disturb
          // response-chunk streaming, exactly like config/heartbeat.
          final st = McpStatusMessage.fromJson(json);
          if (!_mcpStatusCtrl.isClosed) _mcpStatusCtrl.add(st);
        case 'mcp_confirm_request':
          // A write-tool confirmation gate (WOR-44 Phase 5). Delivered on its
          // own [mcpConfirmStream] (NOT the paced message queue) so it can't
          // disturb response-chunk streaming, exactly like mcp_status. The UI
          // MUST answer via [sendMcpConfirmResponse] with the same id — the
          // server blocks the agent until then and denies on timeout/disconnect.
          final req = McpConfirmRequest.fromJson(json);
          if (req.id.isNotEmpty && !_mcpConfirmCtrl.isClosed) {
            _mcpConfirmCtrl.add(req);
          }
        case 'mcp_oauth_url':
          // OAuth authorization URL for an MCP connector (WOR-96 PART 2b).
          // Sent to the requesting connection ONLY (not broadcast). Delivered
          // on its own [mcpOauthUrlStream] — exactly like mcp_status/config,
          // never via _emit, so it never touches the sealed OsiaMessage switch.
          // The URL is public (no secret); safe to open in a browser.
          final oid = json['id']?.toString();
          final ourl = json['url']?.toString();
          if (oid != null &&
              oid.isNotEmpty &&
              ourl != null &&
              ourl.isNotEmpty &&
              !_mcpOauthUrlCtrl.isClosed) {
            final requestId = (json['request_id'] ?? '').toString().trim();
            final attemptId = (json['attempt_id'] ?? '').toString().trim();
            _mcpOauthUrlCtrl.add(
              McpOauthUrl(
                id: oid,
                url: ourl,
                requestId: requestId.isEmpty ? null : requestId,
                attemptId: attemptId.isEmpty ? null : attemptId,
                expiresAt: json['expires_at'] is num
                    ? (json['expires_at'] as num).toDouble()
                    : null,
              ),
            );
          }
        case 'conversation_busy_changed':
          _handleConversationBusyFrame(json);
        case 'conversation_busy':
          _handleConversationBusyFrame(json);
        default:
          debugPrint(
            '[OSIA WS] unhandled message type="$type" keys=${json.keys.toList()}',
          );
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
    _clearChatGptEphemeralLogin();
    debugPrint(
      '[OSIA WS] Connection closed (code=$code, reason="$reason", '
      'intentional=$_intentionalClose, autoReconnect=$autoReconnect).',
    );
    final signalingOnly = _relaySignalingStandby && !_relayCommitAuthorized;
    if (signalingOnly) {
      _channel = null;
      _connectedViaRelay = false;
      _relayConfig = null;
      _completeRelayReady(false);
      _resetRelayE2eState();
      _relayReadyCompleter = null;
      if (!_connectedViaLan &&
          !_connectedViaWebRtc &&
          _state != ConnectionState.connecting &&
          !_intentionalClose) {
        _setState(ConnectionState.disconnected);
        _scheduleReconnect();
      }
      return;
    }
    final relayDroppedWhileConnected =
        _connectedViaRelay && _state == ConnectionState.connected;
    final relayDroppedRequestId = _relayLastOutboundRequestId;
    _channel = null;
    _releaseTransportLease();
    _connectedViaRelay = false;
    _relayConfig = null;
    _resetRelayE2eState();
    _completeRelayReady(false);
    _relayReadyCompleter = null;
    _markPermissionsOffline();
    _setState(ConnectionState.disconnected);
    if (relayDroppedWhileConnected && !_intentionalClose) {
      if (!_errorCtrl.isClosed) _errorCtrl.add(kRelayUnreachableError);
      _emitRelayTransfer(
        RelayTransferEvent(
          direction: RelayTransferDirection.outbound,
          state: RelayTransferState.failed,
          chunkId: '',
          clientRequestId: relayDroppedRequestId,
          errorKind: RelayTransferErrorKind.relayUnreachable,
        ),
      );
    }
    if (_suppressReconnectOnce) {
      _suppressReconnectOnce = false;
    } else if (!_intentionalClose) {
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
      '[OSIA WS] Reconnecting in ${delayMs}ms (attempt $_reconnectAttempt)...',
    );

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      // Only reconnect if we're still actually down. A connection may have come
      // back up via connect() (e.g. the user's "Retry") between this timer being
      // scheduled and firing; reconnecting then would open a duplicate socket
      // and restart the open→close loop.
      if (!_intentionalClose && _state == ConnectionState.disconnected) {
        unawaited(ensureConnected(reason: 'reconnect_timer'));
      }
    });
  }
}
