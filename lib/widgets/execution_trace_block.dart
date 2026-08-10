import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/execution_trace.dart';
import '../theme.dart';

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
    final events = widget.snapshot.events;
    final summary = events.isEmpty
        ? strings.thinkingLabel
        : strings.executionTraceText(events.last.display.key);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.snapshot.terminal
                          ? Icons.check_circle_outline_rounded
                          : Icons.auto_awesome_rounded,
                      color: widget.snapshot.terminal
                          ? palette.success
                          : palette.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.executionTraceTitle,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            summary,
                            maxLines: _expanded ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: palette.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final event in events)
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: BoxDecoration(
                                color: event.terminal
                                    ? palette.success
                                    : palette.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                strings.executionTraceText(event.display.key),
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 12.5,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
