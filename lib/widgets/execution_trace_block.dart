import 'package:flutter/material.dart';

import '../l10n.dart';
import '../motion.dart';
import '../services/execution_trace.dart';
import '../theme.dart';

const int executionTraceSummaryMaxClauses = 12;

/// Converts only the validated public execution ledger into bounded prose.
///
/// The formatter is deliberately local and deterministic: it keeps event
/// order, keeps only the latest revision of an event, removes equivalent
/// semantic duplicates, and never consumes free-form event data.
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
  final displayKeys = <String>[];
  final seenDisplayKeys = <String>{};
  for (final event in ordered) {
    if (seenDisplayKeys.add(event.display.key) &&
        strings.executionTraceSummaryClause(event.display.key) != null) {
      displayKeys.add(event.display.key);
    }
    if (displayKeys.length == executionTraceSummaryMaxClauses ||
        event.terminal) {
      break;
    }
  }
  return strings.executionTraceSummary(displayKeys);
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
