import 'package:flutter/material.dart';

import '../l10n.dart';
import '../motion.dart';
import '../services/execution_trace.dart';
import '../theme.dart';

const int executionTraceSummaryMaxClauses = 12;

enum _TraceOutcome { pending, completed, needsAttention, cancelled }

enum _NarrativeKind { completedAction, recovery, blocker, neutral }

class _TraceActionFact {
  _TraceActionFact({
    required this.sequence,
    required this.displayKey,
    required this.toolAttemptId,
  });

  final int sequence;
  final String displayKey;
  final String toolAttemptId;
  _TraceOutcome outcome = _TraceOutcome.pending;
  int outcomeSequence = 0;
  bool waitedForPermission = false;
}

class _TracePermissionFact {
  const _TracePermissionFact({
    required this.sequence,
    required this.toolAttemptId,
  });

  final int sequence;
  final String toolAttemptId;
}

class _RecoveryFact {
  const _RecoveryFact({required this.failed, required this.succeeded});

  final _TraceActionFact failed;
  final _TraceActionFact succeeded;
}

class _NarrativeItem {
  const _NarrativeItem({
    required this.sequence,
    required this.kind,
    this.actionKey = '',
    this.textKey = '',
  });

  final int sequence;
  final _NarrativeKind kind;
  final String actionKey;
  final String textKey;
}

class _NarrativeSentence {
  const _NarrativeSentence({required this.text, required this.kind});

  final String text;
  final _NarrativeKind kind;
}

/// Converts only the validated public execution ledger into bounded prose.
///
/// The formatter is deliberately local and deterministic. It groups correlated
/// lifecycle events into user-visible facts, keeps real action order, and never
/// consumes free-form event data or correlation identifiers as display text.
String formatExecutionTraceSummary(
  OsiaStrings strings,
  ExecutionTraceSnapshot snapshot,
) {
  if (!snapshot.key.valid) return '';

  final latestByEventId = <String, ExecutionTraceEvent>{};
  for (final event in snapshot.events) {
    if (event.traceKey != snapshot.key ||
        event.sequence < 1 ||
        event.revision < 1 ||
        event.display.args.isNotEmpty ||
        executionTraceDisplayKeys[event.display.key] != event.kind ||
        event.terminal != (event.kind == ExecutionTraceKind.terminal)) {
      continue;
    }
    final previous = latestByEventId[event.eventId];
    if (previous == null || event.revision > previous.revision) {
      latestByEventId[event.eventId] = event;
    }
  }

  final ordered = latestByEventId.values.toList()
    ..sort((a, b) {
      final sequenceOrder = a.sequence.compareTo(b.sequence);
      return sequenceOrder != 0
          ? sequenceOrder
          : a.eventId.compareTo(b.eventId);
    });
  final actions = <_TraceActionFact>[];
  final permissions = <_TracePermissionFact>[];
  final continuationSequences = <int>[];
  final genericResults = <({int sequence, String displayKey})>[];
  String terminalKey = '';

  for (final event in ordered) {
    switch (event.kind) {
      case ExecutionTraceKind.action:
        if (event.display.key != 'execution.action.preparing') {
          actions.add(
            _TraceActionFact(
              sequence: event.sequence,
              displayKey: event.display.key,
              toolAttemptId: event.toolAttemptId,
            ),
          );
        }
      case ExecutionTraceKind.waitingPermission:
        permissions.add(
          _TracePermissionFact(
            sequence: event.sequence,
            toolAttemptId: event.toolAttemptId,
          ),
        );
      case ExecutionTraceKind.result:
        final action = _matchingAction(actions, event);
        if (action == null) {
          genericResults.add((
            sequence: event.sequence,
            displayKey: event.display.key,
          ));
        } else {
          action
            ..outcome = switch (event.display.key) {
              'execution.result.completed' => _TraceOutcome.completed,
              'execution.result.cancelled' => _TraceOutcome.cancelled,
              _ => _TraceOutcome.needsAttention,
            }
            ..outcomeSequence = event.sequence;
        }
      case ExecutionTraceKind.continuation:
        continuationSequences.add(event.sequence);
      case ExecutionTraceKind.terminal:
        terminalKey = event.display.key;
      case ExecutionTraceKind.goal:
      case ExecutionTraceKind.reconciliation:
        break;
    }
    if (event.terminal) break;
  }

  final attachedPermissions = <_TracePermissionFact>{};
  for (final permission in permissions) {
    final action = _actionForPermission(actions, permission);
    if (action != null) {
      action.waitedForPermission = true;
      attachedPermissions.add(permission);
    }
  }

  final recoveries = <_RecoveryFact>[];
  final recoveredActions = <_TraceActionFact>{};
  for (final failed in actions) {
    if (recoveredActions.contains(failed) ||
        failed.outcome != _TraceOutcome.needsAttention) {
      continue;
    }
    final failedAt = failed.outcomeSequence == 0
        ? failed.sequence
        : failed.outcomeSequence;
    final continuation = continuationSequences
        .where((sequence) => sequence > failedAt)
        .firstOrNull;
    if (continuation == null) continue;
    final failedCandidates = actions
        .where(
          (action) =>
              !recoveredActions.contains(action) &&
              action.outcome == _TraceOutcome.needsAttention &&
              (action.outcomeSequence == 0
                      ? action.sequence
                      : action.outcomeSequence) <
                  continuation,
        )
        .toList(growable: false);
    final succeededCandidates = actions
        .where(
          (action) =>
              !recoveredActions.contains(action) &&
              action.sequence > continuation &&
              action.outcome == _TraceOutcome.completed,
        )
        .toList(growable: false);
    if (failedCandidates.length != 1 ||
        failedCandidates.single != failed ||
        succeededCandidates.length != 1) {
      continue;
    }
    final succeeded = succeededCandidates.single;
    recoveries.add(_RecoveryFact(failed: failed, succeeded: succeeded));
    recoveredActions
      ..add(failed)
      ..add(succeeded);
  }

  final items = <_NarrativeItem>[];
  for (final action in actions) {
    if (recoveredActions.contains(action)) continue;
    switch (action.outcome) {
      case _TraceOutcome.completed:
        items.add(
          _NarrativeItem(
            sequence: action.sequence,
            kind: _NarrativeKind.completedAction,
            actionKey: action.displayKey,
          ),
        );
      case _TraceOutcome.needsAttention:
        items.add(
          _NarrativeItem(
            sequence: action.sequence,
            kind: _NarrativeKind.blocker,
            actionKey: action.waitedForPermission ? '' : action.displayKey,
            textKey: action.waitedForPermission ? 'permission_unavailable' : '',
          ),
        );
      case _TraceOutcome.cancelled:
        items.add(
          _NarrativeItem(
            sequence: action.sequence,
            kind: _NarrativeKind.blocker,
            actionKey: action.waitedForPermission ? '' : action.displayKey,
            textKey: action.waitedForPermission
                ? 'permission_unavailable'
                : 'step_cancelled',
          ),
        );
      case _TraceOutcome.pending:
        if (action.waitedForPermission) {
          items.add(
            _NarrativeItem(
              sequence: action.sequence,
              kind: terminalKey == 'execution.terminal.blocked'
                  ? _NarrativeKind.blocker
                  : _NarrativeKind.neutral,
              textKey: terminalKey == 'execution.terminal.blocked'
                  ? 'permission_unavailable'
                  : 'waiting_permission',
            ),
          );
        }
    }
  }
  for (final recovery in recoveries) {
    items.add(
      _NarrativeItem(
        sequence: recovery.failed.sequence,
        kind: _NarrativeKind.recovery,
        actionKey: recovery.succeeded.displayKey,
      ),
    );
  }
  for (final result in genericResults) {
    items.add(
      _NarrativeItem(
        sequence: result.sequence,
        kind: result.displayKey == 'execution.result.completed'
            ? _NarrativeKind.neutral
            : _NarrativeKind.blocker,
        textKey: switch (result.displayKey) {
          'execution.result.completed' => 'completed_step',
          'execution.result.cancelled' => 'step_cancelled',
          _ => 'blocked_step',
        },
      ),
    );
  }
  for (final permission in permissions) {
    if (!attachedPermissions.contains(permission)) {
      items.add(
        _NarrativeItem(
          sequence: permission.sequence,
          kind: terminalKey == 'execution.terminal.blocked'
              ? _NarrativeKind.blocker
              : _NarrativeKind.neutral,
          textKey: terminalKey == 'execution.terminal.blocked'
              ? 'permission_unavailable'
              : 'waiting_permission',
        ),
      );
    }
  }
  items.sort((a, b) => a.sequence.compareTo(b.sequence));

  final deduplicated = <_NarrativeItem>[];
  final seenGenericFacts = <String>{};
  for (final item in items) {
    if (item.actionKey.isEmpty && item.textKey.isNotEmpty) {
      final factKey = '${item.kind.name}:${item.textKey}';
      if (!seenGenericFacts.add(factKey)) continue;
    }
    deduplicated.add(item);
  }
  final hasBlocker = deduplicated.any(
    (item) => item.kind == _NarrativeKind.blocker,
  );
  final orderedItems = hasBlocker
      ? <_NarrativeItem>[
          ...deduplicated.where((item) => item.kind != _NarrativeKind.blocker),
          ...deduplicated.where((item) => item.kind == _NarrativeKind.blocker),
        ]
      : deduplicated;
  final bounded = orderedItems.take(executionTraceSummaryMaxClauses).toList();
  final sentences = <_NarrativeSentence>[];
  var index = 0;
  while (index < bounded.length) {
    final item = bounded[index];
    if (item.kind == _NarrativeKind.completedAction) {
      final actionKeys = <String>[];
      while (index < bounded.length &&
          bounded[index].kind == _NarrativeKind.completedAction) {
        actionKeys.add(bounded[index].actionKey);
        index++;
      }
      sentences.add(
        _NarrativeSentence(
          text: strings.executionTraceCompletedActions(actionKeys),
          kind: _NarrativeKind.completedAction,
        ),
      );
      continue;
    }
    final text = switch (item.kind) {
      _NarrativeKind.recovery => strings.executionTraceRecoveredAction(
        item.actionKey,
      ),
      _NarrativeKind.blocker when item.actionKey.isNotEmpty =>
        strings.executionTraceBlockedAction(item.actionKey),
      _ => strings.executionTraceNaturalText(item.textKey),
    };
    if (text.isNotEmpty) {
      sentences.add(_NarrativeSentence(text: text, kind: item.kind));
    }
    index++;
  }

  if (sentences.isEmpty) {
    return strings.executionTraceNaturalText(switch (terminalKey) {
      'execution.terminal.blocked' => 'blocked_request',
      'execution.terminal.cancelled' => 'cancelled_request',
      'execution.terminal.safety_block' => 'safety_block',
      'execution.terminal.success' => 'simple_request',
      _ => ordered.isEmpty ? '' : 'in_progress',
    });
  }

  final prose = <String>[];
  for (
    var sentenceIndex = 0;
    sentenceIndex < sentences.length;
    sentenceIndex++
  ) {
    final sentence = sentences[sentenceIndex];
    if (sentence.kind == _NarrativeKind.completedAction &&
        sentenceIndex + 1 < sentences.length &&
        sentences[sentenceIndex + 1].kind == _NarrativeKind.blocker) {
      prose.add(
        strings.executionTraceJoinWithBlocker(
          sentence.text,
          sentences[sentenceIndex + 1].text,
        ),
      );
      sentenceIndex++;
    } else {
      prose.add(sentence.text);
    }
  }
  return prose.join(' ');
}

_TraceActionFact? _matchingAction(
  List<_TraceActionFact> actions,
  ExecutionTraceEvent result,
) {
  if (result.toolAttemptId.isNotEmpty) {
    for (final action in actions.reversed) {
      if (action.toolAttemptId == result.toolAttemptId) return action;
    }
  }
  final candidates = actions.reversed
      .where(
        (action) =>
            action.sequence < result.sequence &&
            action.outcome == _TraceOutcome.pending &&
            (result.toolAttemptId.isEmpty || action.toolAttemptId.isEmpty),
      )
      .take(2)
      .toList(growable: false);
  return candidates.length == 1 ? candidates.single : null;
}

_TraceActionFact? _actionForPermission(
  List<_TraceActionFact> actions,
  _TracePermissionFact permission,
) {
  if (permission.toolAttemptId.isNotEmpty) {
    for (final action in actions.reversed) {
      if (action.toolAttemptId == permission.toolAttemptId) return action;
    }
  }
  _TraceActionFact? preceding;
  _TraceActionFact? following;
  for (final action in actions) {
    if (action.sequence < permission.sequence) {
      preceding = action;
    } else {
      following ??= action;
    }
  }
  if (permission.toolAttemptId.isNotEmpty) {
    if ((preceding?.toolAttemptId.isEmpty ?? false) &&
        permission.sequence - preceding!.sequence == 1) {
      return preceding;
    }
    if ((following?.toolAttemptId.isEmpty ?? false) &&
        following!.sequence - permission.sequence == 1) {
      return following;
    }
    return null;
  }
  if (preceding != null && permission.sequence - preceding.sequence == 1) {
    return preceding;
  }
  if (following != null && following.sequence - permission.sequence == 1) {
    return following;
  }
  return null;
}

class ExecutionTraceBlock extends StatefulWidget {
  const ExecutionTraceBlock({
    super.key,
    required this.snapshot,
    this.collapsed = false,
  });

  final ExecutionTraceSnapshot snapshot;
  final bool collapsed;

  @override
  State<ExecutionTraceBlock> createState() => _ExecutionTraceBlockState();
}

class _ExecutionTraceBlockState extends State<ExecutionTraceBlock> {
  late bool _expanded = !widget.collapsed;

  @override
  void didUpdateWidget(covariant ExecutionTraceBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.key != widget.snapshot.key) {
      _expanded = !widget.collapsed;
    } else if (!oldWidget.collapsed && widget.collapsed) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final summary = formatExecutionTraceSummary(strings, widget.snapshot);
    final duration = Motion.duration(context, MotionDurations.medium);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            excludeSemantics: true,
            label: strings.executionTraceTitle,
            child: InkWell(
              key: const ValueKey('execution_trace_toggle'),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.executionTraceTitle,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    AnimatedSwitcher(
                      duration: duration,
                      switchInCurve: MotionCurves.enter,
                      switchOutCurve: MotionCurves.exit,
                      child: Icon(
                        _expanded
                            ? Icons.expand_more_rounded
                            : Icons.chevron_right_rounded,
                        key: ValueKey(_expanded),
                        color: palette.textMuted,
                        size: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: duration,
            curve: Motion.curve(context, MotionCurves.enter),
            alignment: Alignment.topLeft,
            child: _expanded && summary.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: Text(
                      summary,
                      key: const ValueKey('execution_trace_summary'),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        height: 1.38,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
