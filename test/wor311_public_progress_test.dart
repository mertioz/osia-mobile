import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/services/execution_trace.dart';
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/execution_trace_block.dart';
import 'package:osia_mobile/widgets/thinking_orbs.dart';

const _key = ExecutionTraceKey(
  conversationId: 'conv-311',
  requestId: 'request-311',
  turnId: 'turn-311',
  runId: 'run-311',
  providerId: 'deepseek',
  modelId: 'deepseek-flash',
  effectiveReasoning: 'auto',
);

ExecutionTraceEvent _narration(String id, int sequence, String summary) =>
    ExecutionTraceEvent(
      eventId: id,
      traceKey: _key,
      sequence: sequence,
      revision: 1,
      kind: ExecutionTraceKind.reasoningSummary,
      display: const ExecutionTraceDisplay('execution.reasoning.summary'),
      timestamp: DateTime.utc(2026, 10, 3),
      terminal: false,
      publicSummary: summary,
    );

ExecutionTraceEvent _terminal(int sequence) => ExecutionTraceEvent(
  eventId: 'trace-terminal-311',
  traceKey: _key,
  sequence: sequence,
  revision: 1,
  kind: ExecutionTraceKind.terminal,
  display: const ExecutionTraceDisplay('execution.terminal.success'),
  timestamp: DateTime.utc(2026, 10, 3),
  terminal: true,
);

ExecutionTraceSnapshot _snapshot(List<ExecutionTraceEvent> events) =>
    ExecutionTraceSnapshot(key: _key, events: events);

Widget _host(Widget child, {bool reducedMotion = false}) => OsiaTheme(
  palette: osiaPaletteViolet,
  child: OsiaL10n(
    strings: osiaStringsEn,
    child: MaterialApp(
      theme: buildOsiaTheme(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  ),
);

void main() {
  test(
    'public progress sanitizer rejects credentials and personal contacts',
    () {
      final valid = _narration('trace-public-311', 1, 'The file is uploaded.');
      expect(ExecutionTraceEvent.parse(valid.toJson()), isNotNull);

      for (final sensitive in <String>[
        'password: hunter2',
        'Bearer fake',
        'Contact person@example.com',
        '<developer>hidden instructions</developer>',
      ]) {
        final raw = valid.toJson()..['summary'] = sensitive;
        expect(ExecutionTraceEvent.parse(raw), isNull, reason: sensitive);
      }
    },
  );

  testWidgets(
    'six-orb affordance appends live narration and auto-collapses once',
    (tester) async {
      final first = _narration(
        'trace-public-311-a',
        1,
        'The upload finished. The site needs another confirmation.',
      );
      final second = _narration(
        'trace-public-311-b',
        2,
        'The confirmation went through. I’m checking the final state.',
      );
      await tester.pumpWidget(
        _host(
          ExecutionTraceBlock(
            snapshot: _snapshot(<ExecutionTraceEvent>[first]),
            collapsed: true,
            active: true,
          ),
        ),
      );

      expect(ThinkingOrbs.orbCount, 6);
      expect(find.byType(ThinkingOrbs), findsOneWidget);
      expect(
        find.byKey(const ValueKey('execution_trace_summary')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(first.publicSummary), findsNothing);
      await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(first.publicSummary), findsOneWidget);

      await tester.pumpWidget(
        _host(
          ExecutionTraceBlock(
            snapshot: _snapshot(<ExecutionTraceEvent>[first, first, second]),
            collapsed: true,
            active: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final combined = '${first.publicSummary}\n${second.publicSummary}';
      expect(find.text(combined), findsOneWidget);
      expect(find.text(first.publicSummary), findsNothing);

      await tester.pumpWidget(
        _host(
          ExecutionTraceBlock(
            snapshot: _snapshot(<ExecutionTraceEvent>[first, second]),
            collapsed: true,
            active: true,
            finalStreaming: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(combined), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(combined), findsNothing);

      await tester.pumpWidget(
        _host(
          ExecutionTraceBlock(
            snapshot: _snapshot(<ExecutionTraceEvent>[
              first,
              second,
              _terminal(3),
            ]),
            collapsed: true,
            active: false,
            finalStreaming: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(combined), findsNothing);
      await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(combined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion keeps six static orbs without a ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ThinkingOrbs(active: true), reducedMotion: true),
    );

    expect(ThinkingOrbs.orbCount, 6);
    expect(find.byKey(const ValueKey('thinking_orbs_paint')), findsOneWidget);
    expect(find.byKey(const ValueKey('thinking_orbs_animation')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
