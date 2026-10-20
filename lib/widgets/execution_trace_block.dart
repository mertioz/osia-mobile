import 'package:flutter/material.dart';

import '../l10n.dart';
import '../motion.dart';
import '../services/execution_trace.dart';
import '../theme.dart';
import 'thinking_orbs.dart';

/// Retain the selected model's public text verbatim. Local labels describe
/// observed tool activity only, never model intentions or verification claims.
String formatExecutionTraceSummary(
  OsiaStrings strings,
  ExecutionTraceSnapshot snapshot,
) {
  if (!snapshot.key.valid) return '';
  final latest = <String, ExecutionTraceEvent>{};
  for (final event in snapshot.events) {
    if (event.traceKey != snapshot.key ||
        ExecutionTraceEvent.parse(event.toJson()) == null) {
      continue;
    }
    final previous = latest[event.eventId];
    if (previous == null || event.revision > previous.revision) {
      latest[event.eventId] = event;
    }
  }
  final ordered = latest.values.toList()
    ..sort((a, b) => a.sequence.compareTo(b.sequence));
  final lines = <String>[];
  for (final event in ordered) {
    if (event.kind == ExecutionTraceKind.reasoningSummary) {
      lines.add(event.publicSummary);
    }
    // Terminal facts govern presentation, not a synthetic Thinking summary.
    if (event.terminal) break;
  }
  return lines.join('\n');
}

/// Thinking-only presentation of simple whole-line bold headings.
/// Raw snapshots, provenance, inline Markdown and fenced code stay unchanged.
String formatThinkingPublicText(String text) {
  var fence = '';
  final fencePattern = RegExp(r'^(`{3,}|~{3,})');
  final headingPattern = RegExp(
    r'^( {0,3})\*\*([^*`\[\]<>\\_#~\n]+)\*\*([ \t]*)$',
  );
  return text
      .split('\n')
      .map((line) {
        final stripped = line.trimLeft();
        final marker = fencePattern.firstMatch(stripped);
        if (marker != null) {
          final token = marker.group(1)!;
          if (fence.isEmpty) {
            fence = token;
          } else if (token[0] == fence[0] &&
              token.length >= fence.length &&
              stripped.substring(token.length).trim().isEmpty) {
            fence = '';
          }
          return line;
        }
        final heading = fence.isEmpty ? headingPattern.firstMatch(line) : null;
        return heading == null
            ? line
            : '${heading.group(1)}${heading.group(2)}${heading.group(3)}';
      })
      .join('\n');
}

/// Optional per-turn UI memory when the trace moves into an answer bubble.
/// Retains received PC text and disclosure flags only, with no durable store
/// or execution/provider authority.
class ExecutionTraceDisclosureState {
  bool _expanded = false;
  bool _started = false;
  bool _completed = false;
  bool _wasActive = false;
  ExecutionTraceKey? _key;
  ExecutionTraceSnapshot? _snapshot;
}

class ExecutionTraceBlock extends StatefulWidget {
  const ExecutionTraceBlock({
    super.key,
    required this.snapshot,
    this.collapsed = false,
    this.active = false,
    this.finalStreaming = false,
    this.disclosureState,
  });

  final ExecutionTraceSnapshot snapshot;
  final bool collapsed;
  final bool active;
  final bool finalStreaming;
  final ExecutionTraceDisclosureState? disclosureState;

  @override
  State<ExecutionTraceBlock> createState() => _ExecutionTraceBlockState();
}

class _ExecutionTraceBlockState extends State<ExecutionTraceBlock> {
  late ExecutionTraceDisclosureState _disclosure;
  bool get _expanded => _disclosure._expanded;
  set _expanded(bool value) => _disclosure._expanded = value;
  bool get _completed => _disclosure._completed;
  set _completed(bool value) => _disclosure._completed = value;

  @override
  void initState() {
    super.initState();
    _disclosure = widget.disclosureState ?? ExecutionTraceDisclosureState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateDisclosure();
  }

  @override
  void didUpdateWidget(covariant ExecutionTraceBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.key != widget.snapshot.key) {
      _disclosure = widget.disclosureState ?? ExecutionTraceDisclosureState();
    }
    _updateDisclosure();
  }

  void _updateDisclosure() {
    if (_disclosure._key != null && _disclosure._key != widget.snapshot.key) {
      _disclosure._expanded = false;
      _disclosure._started = false;
      _disclosure._completed = false;
      _disclosure._wasActive = false;
      _disclosure._snapshot = null;
    }
    _disclosure._key = widget.snapshot.key;
    _disclosure._snapshot = mergeExecutionTraceSnapshots(
      _disclosure._snapshot,
      widget.snapshot,
    );
    // Keep completion coherent even when the trace moves between list slots
    // on the same frame, or Relay has no terminal trace to project.
    if ((widget.snapshot.terminal ||
            (_disclosure._wasActive && !widget.active)) &&
        !_completed) {
      _completed = true;
      _expanded = false;
    }
    _disclosure._wasActive = widget.active;
    if (widget.active && !_disclosure._started && !_completed) {
      _disclosure._started = true;
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    final summary = formatExecutionTraceSummary(
      strings,
      _disclosure._snapshot ?? widget.snapshot,
    );
    final duration = Motion.duration(context, MotionDurations.medium);
    final active = widget.active && !_completed;

    final detail = _expanded && summary.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: SelectionArea(
              child: Text(
                formatThinkingPublicText(summary),
                key: const ValueKey('execution_trace_summary'),
                style: TextStyle(
                  color:
                      Color.lerp(palette.textMuted, palette.accent, 0.14) ??
                      palette.textMuted,
                  fontSize: 13,
                  height: 1.38,
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ThinkingToggle(
            active: active,
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          // A zero-duration AnimatedSize can invalidate itself during layout
          // when disclosure changes. Reduced motion uses direct layout.
          if (duration == Duration.zero)
            detail
          else
            AnimatedSize(
              duration: duration,
              curve: Motion.curve(context, MotionCurves.enter),
              alignment: Alignment.topLeft,
              child: detail,
            ),
        ],
      ),
    );
  }
}

/// Compact truthful placeholder shown before the first displayable activity
/// event. It deliberately contains no synthetic status prose.
class ThinkingDisclosure extends StatefulWidget {
  const ThinkingDisclosure({
    super.key,
    this.disclosureState,
    this.active = true,
  });

  final ExecutionTraceDisclosureState? disclosureState;
  final bool active;

  @override
  State<ThinkingDisclosure> createState() => _ThinkingDisclosureState();
}

class _ThinkingDisclosureState extends State<ThinkingDisclosure> {
  late ExecutionTraceDisclosureState _disclosure;

  @override
  void initState() {
    super.initState();
    _disclosure = widget.disclosureState ?? ExecutionTraceDisclosureState();
    _updateDisclosure();
  }

  @override
  void didUpdateWidget(covariant ThinkingDisclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.disclosureState != widget.disclosureState) {
      _disclosure = widget.disclosureState ?? ExecutionTraceDisclosureState();
    }
    _updateDisclosure();
  }

  void _updateDisclosure() {
    if (_disclosure._wasActive && !widget.active && !_disclosure._completed) {
      _disclosure._completed = true;
      _disclosure._expanded = false;
    }
    if (widget.active && !_disclosure._started && !_disclosure._completed) {
      _disclosure._started = true;
      _disclosure._expanded = true;
    }
    _disclosure._wasActive = widget.active;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: _ThinkingToggle(
        active: widget.active && !_disclosure._completed,
        expanded: _disclosure._expanded,
        onTap: () =>
            setState(() => _disclosure._expanded = !_disclosure._expanded),
      ),
    );
  }
}

/// One accessible disclosure button. The active visual is dots only.
class _ThinkingToggle extends StatelessWidget {
  const _ThinkingToggle({
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OsiaTheme.of(context);
    final strings = OsiaL10n.of(context);
    return Semantics(
      button: true,
      expanded: expanded,
      excludeSemantics: true,
      label: strings.executionTraceTitle,
      onTap: onTap,
      child: InkWell(
        key: const ValueKey('execution_trace_toggle'),
        onTap: onTap,
        // The six orbs are their own feedback; inherited Material ink paints
        // a rectangular flash across this otherwise transparent surface.
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: palette.accent.withValues(alpha: 0.18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 54, minHeight: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active)
                const ThinkingOrbs(active: true)
              else ...[
                Text(
                  strings.executionTraceTitle,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  expanded
                      ? Icons.expand_more_rounded
                      : Icons.chevron_right_rounded,
                  color: palette.textMuted,
                  size: 17,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
