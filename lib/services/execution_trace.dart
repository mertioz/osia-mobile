import 'dart:convert';

import 'package:flutter/foundation.dart';

const int executionTraceSchemaVersion = 1;
const String executionTraceRedactionClass = 'public_ui';
const int executionTraceMaxEvents = 24;
const int executionTraceMaxSerializedBytes = 12 * 1024;

enum ExecutionTraceKind {
  reasoningSummary,
  goal,
  action,
  waitingPermission,
  result,
  continuation,
  reconciliation,
  terminal,
}

const Map<String, ExecutionTraceKind> _kindByWire =
    <String, ExecutionTraceKind>{
      'reasoning_summary': ExecutionTraceKind.reasoningSummary,
      'public_reasoning_summary': ExecutionTraceKind.reasoningSummary,
      'goal': ExecutionTraceKind.goal,
      'action': ExecutionTraceKind.action,
      'waiting_permission': ExecutionTraceKind.waitingPermission,
      'result': ExecutionTraceKind.result,
      'continuation': ExecutionTraceKind.continuation,
      'reconciliation': ExecutionTraceKind.reconciliation,
      'terminal': ExecutionTraceKind.terminal,
    };

const Map<String, ExecutionTraceKind> executionTraceDisplayKeys =
    <String, ExecutionTraceKind>{
      'execution.reasoning.summary': ExecutionTraceKind.reasoningSummary,
      'execution.goal.answer': ExecutionTraceKind.goal,
      'execution.goal.complete_task': ExecutionTraceKind.goal,
      'execution.action.preparing': ExecutionTraceKind.action,
      'execution.action.browser': ExecutionTraceKind.action,
      'execution.action.document': ExecutionTraceKind.action,
      'execution.action.filesystem': ExecutionTraceKind.action,
      'execution.action.shell': ExecutionTraceKind.action,
      'execution.action.connector': ExecutionTraceKind.action,
      'execution.action.memory': ExecutionTraceKind.action,
      'execution.action.scheduled_task': ExecutionTraceKind.action,
      'execution.action.capability': ExecutionTraceKind.action,
      'execution.permission.waiting': ExecutionTraceKind.waitingPermission,
      'execution.result.completed': ExecutionTraceKind.result,
      'execution.result.needs_attention': ExecutionTraceKind.result,
      'execution.result.cancelled': ExecutionTraceKind.result,
      'execution.continuation.new_strategy': ExecutionTraceKind.continuation,
      'execution.reconciliation.verifying': ExecutionTraceKind.reconciliation,
      'execution.terminal.success': ExecutionTraceKind.terminal,
      'execution.terminal.blocked': ExecutionTraceKind.terminal,
      'execution.terminal.cancelled': ExecutionTraceKind.terminal,
      'execution.terminal.safety_block': ExecutionTraceKind.terminal,
    };

final RegExp _safeIdPattern = RegExp(r'^[A-Za-z0-9._:-]{1,256}$');

bool _safeOptionalId(String value) =>
    value.isEmpty || _safeIdPattern.hasMatch(value);

bool _safeMetadata(String value, {int maxLength = 256}) {
  if (value.length > maxLength) return false;
  for (final unit in value.codeUnits) {
    if (unit < 0x20 || unit == 0x7f) return false;
  }
  return true;
}

bool _safePublicSummary(String value) {
  if (value.trim().isEmpty ||
      value.length > 2000 ||
      utf8.encode(value).length > 4096) {
    return false;
  }
  if (RegExp(
    r'<\s*/?\s*(?:think(?:ing)?|reasoning|analysis|tool(?:[_-]?(?:call|result|code))?|function_calls)\b',
    caseSensitive: false,
  ).hasMatch(value)) {
    return false;
  }
  for (final unit in value.codeUnits) {
    if ((unit < 0x20 && unit != 0x09 && unit != 0x0a) ||
        unit == 0x7f ||
        const <int>{
          0x061c,
          0x200e,
          0x200f,
          0x202a,
          0x202b,
          0x202c,
          0x202d,
          0x202e,
          0x2066,
          0x2067,
          0x2068,
          0x2069,
        }.contains(unit)) {
      return false;
    }
  }
  return true;
}

@immutable
class ExecutionTraceKey {
  final String conversationId;
  final String requestId;
  final String turnId;
  final String runId;
  final String providerId;
  final String modelId;
  final String effectiveReasoning;

  const ExecutionTraceKey({
    required this.conversationId,
    required this.requestId,
    required this.turnId,
    this.runId = '',
    this.providerId = '',
    this.modelId = '',
    this.effectiveReasoning = '',
  });

  /// Current unified-run traces carry the whole metadata group together.
  /// A completely absent group remains valid only for historical snapshots.
  bool get hasCanonicalMetadata =>
      runId.isNotEmpty ||
      providerId.isNotEmpty ||
      modelId.isNotEmpty ||
      effectiveReasoning.isNotEmpty;

  bool get valid =>
      _safeIdPattern.hasMatch(conversationId) &&
      _safeIdPattern.hasMatch(requestId) &&
      _safeIdPattern.hasMatch(turnId) &&
      _safeOptionalId(runId) &&
      _safeMetadata(providerId) &&
      _safeMetadata(modelId) &&
      _safeMetadata(effectiveReasoning, maxLength: 64) &&
      (!hasCanonicalMetadata ||
          (runId.isNotEmpty &&
              providerId.isNotEmpty &&
              modelId.isNotEmpty &&
              effectiveReasoning.isNotEmpty));

  @override
  bool operator ==(Object other) =>
      other is ExecutionTraceKey &&
      other.conversationId == conversationId &&
      other.requestId == requestId &&
      other.turnId == turnId &&
      other.runId == runId &&
      other.providerId == providerId &&
      other.modelId == modelId &&
      other.effectiveReasoning == effectiveReasoning;

  @override
  int get hashCode => Object.hash(
    conversationId,
    requestId,
    turnId,
    runId,
    providerId,
    modelId,
    effectiveReasoning,
  );
}

@immutable
class ExecutionTraceDisplay {
  final String key;
  final Map<String, Object?> args;

  const ExecutionTraceDisplay(
    this.key, [
    this.args = const <String, Object?>{},
  ]);

  static ExecutionTraceDisplay? parse(Object? raw, ExecutionTraceKind kind) {
    if (raw is! Map ||
        raw.keys.toSet().difference(const {'key', 'args'}).isNotEmpty) {
      return null;
    }
    final key = raw['key'];
    final args = raw['args'];
    if (key is! String ||
        executionTraceDisplayKeys[key] != kind ||
        args is! Map ||
        args.isNotEmpty) {
      return null;
    }
    return ExecutionTraceDisplay(key);
  }

  Map<String, Object?> toJson() => <String, Object?>{'key': key, 'args': args};
}

@immutable
class ExecutionTraceEvent {
  final String eventId;
  final ExecutionTraceKey traceKey;
  final int sequence;
  final int revision;
  final ExecutionTraceKind kind;
  final ExecutionTraceDisplay display;
  final DateTime timestamp;
  final bool terminal;
  final String invocationId;
  final String toolAttemptId;
  final String permissionRequestId;
  final String publicSummary;

  const ExecutionTraceEvent({
    required this.eventId,
    required this.traceKey,
    required this.sequence,
    required this.revision,
    required this.kind,
    required this.display,
    required this.timestamp,
    required this.terminal,
    this.invocationId = '',
    this.toolAttemptId = '',
    this.permissionRequestId = '',
    this.publicSummary = '',
  });

  static const Set<String> _requiredKeys = <String>{
    'schema_version',
    'event_id',
    'conversation_id',
    'request_id',
    'turn_id',
    'sequence',
    'revision',
    'kind',
    'display',
    'timestamp',
    'terminal',
    'redaction_class',
  };
  static const Set<String> _optionalKeys = <String>{
    'invocation_id',
    'tool_attempt_id',
    'permission_request_id',
    'run_id',
    'provider_id',
    'model_id',
    'effective_reasoning',
    'summary',
    'public_summary',
  };

  static ExecutionTraceEvent? parse(
    Map<String, dynamic> raw, {
    bool envelope = false,
  }) {
    final allowed = <String>{
      ..._requiredKeys,
      ..._optionalKeys,
      if (envelope) 'type',
      if (envelope) 'snapshot',
    };
    if (!raw.keys.toSet().containsAll(_requiredKeys) ||
        raw.keys.toSet().difference(allowed).isNotEmpty ||
        raw['schema_version'] != executionTraceSchemaVersion ||
        raw['redaction_class'] != executionTraceRedactionClass ||
        (envelope && raw['type'] != 'execution_trace')) {
      return null;
    }
    final eventId = raw['event_id'];
    final conversationId = raw['conversation_id'];
    final requestId = raw['request_id'];
    final turnId = raw['turn_id'];
    final runId = raw['run_id'] ?? '';
    final providerId = raw['provider_id'] ?? '';
    final modelId = raw['model_id'] ?? '';
    final effectiveReasoning = raw['effective_reasoning'] ?? '';
    final sequence = raw['sequence'];
    final revision = raw['revision'];
    final kindWire = raw['kind'];
    final kind = _kindByWire[kindWire];
    final timestampRaw = raw['timestamp'];
    final terminal = raw['terminal'];
    if (eventId is! String ||
        conversationId is! String ||
        requestId is! String ||
        turnId is! String ||
        runId is! String ||
        providerId is! String ||
        modelId is! String ||
        effectiveReasoning is! String ||
        sequence is! int ||
        sequence < 1 ||
        revision is! int ||
        revision < 1 ||
        kind == null ||
        timestampRaw is! String ||
        timestampRaw.length > 64 ||
        terminal is! bool ||
        terminal != (kind == ExecutionTraceKind.terminal)) {
      return null;
    }
    final traceKey = ExecutionTraceKey(
      conversationId: conversationId,
      requestId: requestId,
      turnId: turnId,
      runId: runId,
      providerId: providerId,
      modelId: modelId,
      effectiveReasoning: effectiveReasoning,
    );
    final metadataKeys = const <String>{
      'run_id',
      'provider_id',
      'model_id',
      'effective_reasoning',
    };
    final suppliedMetadataKeys = raw.keys.toSet().intersection(metadataKeys);
    final exactCurrentMetadata =
        suppliedMetadataKeys.isEmpty ||
        (suppliedMetadataKeys.length == metadataKeys.length &&
            runId.isNotEmpty &&
            providerId.isNotEmpty &&
            modelId.isNotEmpty);
    final timestamp = DateTime.tryParse(timestampRaw);
    final display = ExecutionTraceDisplay.parse(raw['display'], kind);
    if (!_safeIdPattern.hasMatch(eventId) ||
        !traceKey.valid ||
        !exactCurrentMetadata ||
        (kind == ExecutionTraceKind.reasoningSummary &&
            suppliedMetadataKeys.length != metadataKeys.length) ||
        timestamp == null ||
        display == null) {
      return null;
    }
    String optionalId(String name) {
      final value = raw[name];
      if (value == null) return '';
      if (value is! String || !_safeIdPattern.hasMatch(value)) {
        return '!invalid!';
      }
      return value;
    }

    final invocationId = optionalId('invocation_id');
    final toolAttemptId = optionalId('tool_attempt_id');
    final permissionRequestId = optionalId('permission_request_id');
    final canonicalSummary = raw['summary'];
    final legacySummary = raw['public_summary'];
    final publicSummary = canonicalSummary ?? legacySummary ?? '';
    if (<String>{
          invocationId,
          toolAttemptId,
          permissionRequestId,
        }.contains('!invalid!') ||
        publicSummary is! String ||
        (canonicalSummary != null && canonicalSummary is! String) ||
        (legacySummary != null && legacySummary is! String) ||
        (canonicalSummary is String &&
            legacySummary is String &&
            canonicalSummary != legacySummary)) {
      return null;
    }
    if (kind == ExecutionTraceKind.reasoningSummary) {
      if (!_safePublicSummary(publicSummary)) {
        return null;
      }
    } else if (publicSummary.isNotEmpty) {
      return null;
    }
    return ExecutionTraceEvent(
      eventId: eventId,
      traceKey: traceKey,
      sequence: sequence,
      revision: revision,
      kind: kind,
      display: display,
      timestamp: timestamp.toUtc(),
      terminal: terminal,
      invocationId: invocationId,
      toolAttemptId: toolAttemptId,
      permissionRequestId: permissionRequestId,
      publicSummary: publicSummary,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': executionTraceSchemaVersion,
    'event_id': eventId,
    'conversation_id': traceKey.conversationId,
    'request_id': traceKey.requestId,
    'turn_id': traceKey.turnId,
    if (traceKey.hasCanonicalMetadata) 'run_id': traceKey.runId,
    if (traceKey.hasCanonicalMetadata) 'provider_id': traceKey.providerId,
    if (traceKey.hasCanonicalMetadata) 'model_id': traceKey.modelId,
    if (traceKey.hasCanonicalMetadata)
      'effective_reasoning': traceKey.effectiveReasoning,
    'sequence': sequence,
    'revision': revision,
    'kind': kind == ExecutionTraceKind.reasoningSummary
        ? 'public_reasoning_summary'
        : _kindByWire.entries.firstWhere((entry) => entry.value == kind).key,
    'display': display.toJson(),
    'timestamp': timestamp.toIso8601String(),
    'terminal': terminal,
    'redaction_class': executionTraceRedactionClass,
    if (invocationId.isNotEmpty) 'invocation_id': invocationId,
    if (toolAttemptId.isNotEmpty) 'tool_attempt_id': toolAttemptId,
    if (permissionRequestId.isNotEmpty)
      'permission_request_id': permissionRequestId,
    if (publicSummary.isNotEmpty) 'summary': publicSummary,
  };
}

@immutable
class ExecutionTraceEnvelope {
  final ExecutionTraceEvent event;
  final List<ExecutionTraceEvent> snapshot;

  const ExecutionTraceEnvelope({required this.event, required this.snapshot});

  static ExecutionTraceEnvelope? parse(Map<String, dynamic> raw) {
    final event = ExecutionTraceEvent.parse(raw, envelope: true);
    final snapshotRaw = raw['snapshot'];
    if (event == null ||
        snapshotRaw is! List ||
        snapshotRaw.length > executionTraceMaxEvents) {
      return null;
    }
    final snapshot = <ExecutionTraceEvent>[];
    for (final item in snapshotRaw) {
      if (item is! Map) return null;
      final parsed = ExecutionTraceEvent.parse(Map<String, dynamic>.from(item));
      if (parsed == null || parsed.traceKey != event.traceKey) return null;
      snapshot.add(parsed);
    }
    if (snapshot.isNotEmpty &&
        !snapshot.any(
          (item) =>
              item.eventId == event.eventId &&
              item.sequence == event.sequence &&
              item.revision == event.revision,
        )) {
      return null;
    }
    final encodedBytes = utf8.encode(jsonEncode(raw)).length;
    if (encodedBytes > executionTraceMaxSerializedBytes) return null;
    return ExecutionTraceEnvelope(event: event, snapshot: snapshot);
  }
}

@immutable
class ExecutionTraceSnapshot {
  final ExecutionTraceKey key;
  final List<ExecutionTraceEvent> events;

  ExecutionTraceSnapshot({
    required this.key,
    required List<ExecutionTraceEvent> events,
  }) : events = List<ExecutionTraceEvent>.unmodifiable(events);

  bool get terminal => events.isNotEmpty && events.last.terminal;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': executionTraceSchemaVersion,
    'conversation_id': key.conversationId,
    'request_id': key.requestId,
    'turn_id': key.turnId,
    if (key.hasCanonicalMetadata) 'run_id': key.runId,
    if (key.hasCanonicalMetadata) 'provider_id': key.providerId,
    if (key.hasCanonicalMetadata) 'model_id': key.modelId,
    if (key.hasCanonicalMetadata) 'effective_reasoning': key.effectiveReasoning,
    'redaction_class': executionTraceRedactionClass,
    'events': events.map((event) => event.toJson()).toList(),
  };

  static ExecutionTraceSnapshot? parseHistory(Object? raw) {
    const required = <String>{
      'schema_version',
      'conversation_id',
      'request_id',
      'turn_id',
      'redaction_class',
      'events',
    };
    const optional = <String>{
      'run_id',
      'provider_id',
      'model_id',
      'effective_reasoning',
    };
    if (raw is! Map ||
        !raw.keys.toSet().containsAll(required) ||
        raw.keys.toSet().difference(const <String>{
          'schema_version',
          'conversation_id',
          'request_id',
          'turn_id',
          ...optional,
          'redaction_class',
          'events',
        }).isNotEmpty ||
        raw['schema_version'] != executionTraceSchemaVersion ||
        raw['redaction_class'] != executionTraceRedactionClass) {
      return null;
    }
    final suppliedOptional = raw.keys.toSet().intersection(optional);
    if (suppliedOptional.isNotEmpty &&
        suppliedOptional.length != optional.length) {
      return null;
    }
    final conversationId = raw['conversation_id'];
    final requestId = raw['request_id'];
    final turnId = raw['turn_id'];
    final runId = raw['run_id'] ?? '';
    final providerId = raw['provider_id'] ?? '';
    final modelId = raw['model_id'] ?? '';
    final effectiveReasoning = raw['effective_reasoning'] ?? '';
    if (conversationId is! String ||
        requestId is! String ||
        turnId is! String ||
        runId is! String ||
        providerId is! String ||
        modelId is! String ||
        effectiveReasoning is! String) {
      return null;
    }
    final key = ExecutionTraceKey(
      conversationId: conversationId,
      requestId: requestId,
      turnId: turnId,
      runId: runId,
      providerId: providerId,
      modelId: modelId,
      effectiveReasoning: effectiveReasoning,
    );
    final items = raw['events'];
    if (!key.valid ||
        items is! List ||
        items.length > executionTraceMaxEvents) {
      return null;
    }
    final events = <ExecutionTraceEvent>[];
    final eventIds = <String>{};
    var lastSequence = 0;
    var terminalSeen = false;
    for (final item in items) {
      if (item is! Map) return null;
      final event = ExecutionTraceEvent.parse(Map<String, dynamic>.from(item));
      if (event == null ||
          event.traceKey != key ||
          !eventIds.add(event.eventId) ||
          event.sequence <= lastSequence ||
          terminalSeen) {
        return null;
      }
      lastSequence = event.sequence;
      terminalSeen = event.terminal;
      events.add(event);
    }
    final snapshot = ExecutionTraceSnapshot(key: key, events: events);
    if (utf8.encode(jsonEncode(snapshot.toJson())).length >
        executionTraceMaxSerializedBytes) {
      return null;
    }
    return snapshot;
  }
}

/// Returns [snapshot] only when it belongs to the exact visible Chat identity.
///
/// Current unified turns carry run/provider/model/reasoning together. Legacy
/// history remains readable when both the message and its trace omit that whole
/// metadata group, but an incomplete or stale identity never crosses messages.
ExecutionTraceSnapshot? executionTraceForExactIdentity(
  ExecutionTraceSnapshot? snapshot, {
  required String conversationId,
  required String requestId,
  required String turnId,
  required String runId,
  required String providerId,
  required String modelId,
  required String effectiveReasoning,
}) {
  if (snapshot == null || !snapshot.key.valid) return null;
  final key = snapshot.key;
  return key.conversationId == conversationId &&
          key.requestId == requestId &&
          key.turnId == turnId &&
          key.runId == runId &&
          key.providerId == providerId &&
          key.modelId == modelId &&
          key.effectiveReasoning == effectiveReasoning
      ? snapshot
      : null;
}

class ExecutionTraceAccumulator {
  final ExecutionTraceKey key;
  final Map<String, ExecutionTraceEvent> _events =
      <String, ExecutionTraceEvent>{};
  final Map<int, String> _eventBySequence = <int, String>{};
  bool _terminal = false;

  ExecutionTraceAccumulator(this.key);

  bool get terminal => _terminal;

  ExecutionTraceSnapshot? get snapshot {
    if (_events.isEmpty) return null;
    final values = _events.values.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return ExecutionTraceSnapshot(key: key, events: values);
  }

  ExecutionTraceSnapshot? merge(ExecutionTraceEnvelope envelope) {
    if (envelope.event.traceKey != key) {
      return null;
    }
    final incoming = envelope.snapshot.isEmpty
        ? <ExecutionTraceEvent>[envelope.event]
        : envelope.snapshot;
    final ordered = List<ExecutionTraceEvent>.of(incoming)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (_terminal) {
      if (!envelope.event.terminal) return null;
      for (final event in ordered) {
        final previous = _events[event.eventId];
        if (previous == null ||
            event.sequence != previous.sequence ||
            event.revision > previous.revision ||
            (event.revision == previous.revision &&
                jsonEncode(event.toJson()) != jsonEncode(previous.toJson()))) {
          return null;
        }
      }
      final values = _events.values.toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
      return ExecutionTraceSnapshot(key: key, events: values);
    }
    final candidateEvents = Map<String, ExecutionTraceEvent>.of(_events);
    final candidateSequences = Map<int, String>.of(_eventBySequence);
    var terminalSeen = envelope.snapshot.isEmpty ? _terminal : false;
    for (final event in ordered) {
      if (event.traceKey != key || (terminalSeen && !event.terminal)) {
        return null;
      }
      final sequenceOwner = candidateSequences[event.sequence];
      final previous = candidateEvents[event.eventId];
      if (sequenceOwner != null && sequenceOwner != event.eventId) return null;
      if (previous != null) {
        if (event.sequence != previous.sequence) return null;
        if (event.revision == previous.revision &&
            jsonEncode(event.toJson()) != jsonEncode(previous.toJson())) {
          return null;
        }
        if (event.revision <= previous.revision) {
          continue;
        }
      } else if (candidateSequences.isNotEmpty &&
          event.sequence <
              candidateSequences.keys.reduce((a, b) => a > b ? a : b) &&
          envelope.snapshot.isEmpty) {
        return null;
      }
      candidateEvents[event.eventId] = event;
      candidateSequences[event.sequence] = event.eventId;
      terminalSeen = terminalSeen || event.terminal;
    }
    final values = candidateEvents.values.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (values.length > executionTraceMaxEvents) return null;
    terminalSeen = false;
    for (final event in values) {
      if (terminalSeen) return null;
      terminalSeen = event.terminal;
    }
    final snapshot = ExecutionTraceSnapshot(key: key, events: values);
    if (utf8.encode(jsonEncode(snapshot.toJson())).length >
        executionTraceMaxSerializedBytes) {
      return null;
    }
    _events
      ..clear()
      ..addAll(candidateEvents);
    _eventBySequence
      ..clear()
      ..addAll(candidateSequences);
    _terminal = terminalSeen;
    return snapshot;
  }
}
