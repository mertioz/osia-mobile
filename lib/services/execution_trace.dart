import 'dart:convert';

import 'package:flutter/foundation.dart';

const int executionTraceSchemaVersion = 1;
const String executionTraceRedactionClass = 'public_ui';
const int executionTraceMaxEvents = 24;
const int executionTraceMaxSerializedBytes = 12 * 1024;

enum ExecutionTraceKind {
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

@immutable
class ExecutionTraceKey {
  final String conversationId;
  final String requestId;
  final String turnId;

  const ExecutionTraceKey({
    required this.conversationId,
    required this.requestId,
    required this.turnId,
  });

  bool get valid =>
      _safeIdPattern.hasMatch(conversationId) &&
      _safeIdPattern.hasMatch(requestId) &&
      _safeIdPattern.hasMatch(turnId);

  @override
  bool operator ==(Object other) =>
      other is ExecutionTraceKey &&
      other.conversationId == conversationId &&
      other.requestId == requestId &&
      other.turnId == turnId;

  @override
  int get hashCode => Object.hash(conversationId, requestId, turnId);
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
    final sequence = raw['sequence'];
    final revision = raw['revision'];
    final kind = _kindByWire[raw['kind']];
    final timestampRaw = raw['timestamp'];
    final terminal = raw['terminal'];
    if (eventId is! String ||
        conversationId is! String ||
        requestId is! String ||
        turnId is! String ||
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
    );
    final timestamp = DateTime.tryParse(timestampRaw);
    final display = ExecutionTraceDisplay.parse(raw['display'], kind);
    if (!_safeIdPattern.hasMatch(eventId) ||
        !traceKey.valid ||
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
    if (<String>{
      invocationId,
      toolAttemptId,
      permissionRequestId,
    }.contains('!invalid!')) {
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
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': executionTraceSchemaVersion,
    'event_id': eventId,
    'conversation_id': traceKey.conversationId,
    'request_id': traceKey.requestId,
    'turn_id': traceKey.turnId,
    'sequence': sequence,
    'revision': revision,
    'kind': _kindByWire.entries.firstWhere((entry) => entry.value == kind).key,
    'display': display.toJson(),
    'timestamp': timestamp.toIso8601String(),
    'terminal': terminal,
    'redaction_class': executionTraceRedactionClass,
    if (invocationId.isNotEmpty) 'invocation_id': invocationId,
    if (toolAttemptId.isNotEmpty) 'tool_attempt_id': toolAttemptId,
    if (permissionRequestId.isNotEmpty)
      'permission_request_id': permissionRequestId,
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
    'redaction_class': executionTraceRedactionClass,
    'events': events.map((event) => event.toJson()).toList(),
  };

  static ExecutionTraceSnapshot? parseHistory(Object? raw) {
    if (raw is! Map ||
        raw.keys.toSet().difference(const <String>{
          'schema_version',
          'conversation_id',
          'request_id',
          'turn_id',
          'redaction_class',
          'events',
        }).isNotEmpty ||
        raw.length != 6 ||
        raw['schema_version'] != executionTraceSchemaVersion ||
        raw['redaction_class'] != executionTraceRedactionClass) {
      return null;
    }
    final key = ExecutionTraceKey(
      conversationId: raw['conversation_id']?.toString() ?? '',
      requestId: raw['request_id']?.toString() ?? '',
      turnId: raw['turn_id']?.toString() ?? '',
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

class ExecutionTraceAccumulator {
  final ExecutionTraceKey key;
  final Map<String, ExecutionTraceEvent> _events =
      <String, ExecutionTraceEvent>{};
  final Map<int, String> _eventBySequence = <int, String>{};
  bool _terminal = false;

  ExecutionTraceAccumulator(this.key);

  bool get terminal => _terminal;

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
