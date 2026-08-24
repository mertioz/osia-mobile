import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/services/execution_trace.dart';
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/chat_bubble.dart';
import 'package:osia_mobile/widgets/execution_trace_block.dart';

const _traceKey = ExecutionTraceKey(
  conversationId: 'conv-wor265-thinking',
  requestId: 'req-wor265-thinking',
  turnId: 'turn-wor265-thinking',
  runId: 'run-wor265-thinking',
  providerId: 'chatgpt_account',
  modelId: 'gpt-5.6-terra',
  effectiveReasoning: 'high',
);

ExecutionTraceSnapshot _publicSummaryTrace() => ExecutionTraceSnapshot(
  key: _traceKey,
  events: <ExecutionTraceEvent>[
    ExecutionTraceEvent(
      eventId: 'event-wor265-summary',
      traceKey: _traceKey,
      sequence: 1,
      revision: 1,
      kind: ExecutionTraceKind.reasoningSummary,
      display: const ExecutionTraceDisplay('execution.reasoning.summary'),
      timestamp: DateTime.utc(2026, 8, 24, 12),
      terminal: false,
      publicSummary: 'Checked the visible calculator result.',
    ),
  ],
);

ExecutionTraceSnapshot _realActivityTrace({bool withPublicSummary = false}) =>
    ExecutionTraceSnapshot(
      key: _traceKey,
      events: <ExecutionTraceEvent>[
        if (withPublicSummary)
          ExecutionTraceEvent(
            eventId: 'event-wor265-summary',
            traceKey: _traceKey,
            sequence: 1,
            revision: 1,
            kind: ExecutionTraceKind.reasoningSummary,
            display: const ExecutionTraceDisplay('execution.reasoning.summary'),
            timestamp: DateTime.utc(2026, 8, 24, 12),
            terminal: false,
            publicSummary: 'Checked the visible calculator result.',
          ),
        ExecutionTraceEvent(
          eventId: 'event-wor265-action',
          traceKey: _traceKey,
          sequence: withPublicSummary ? 2 : 1,
          revision: 1,
          kind: ExecutionTraceKind.action,
          display: const ExecutionTraceDisplay('execution.action.shell'),
          timestamp: DateTime.utc(2026, 8, 24, 12, 0, 1),
          terminal: false,
          toolAttemptId: 'attempt-wor265-shell',
        ),
        ExecutionTraceEvent(
          eventId: 'event-wor265-result',
          traceKey: _traceKey,
          sequence: withPublicSummary ? 3 : 2,
          revision: 1,
          kind: ExecutionTraceKind.result,
          display: const ExecutionTraceDisplay('execution.result.completed'),
          timestamp: DateTime.utc(2026, 8, 24, 12, 0, 2),
          terminal: false,
          toolAttemptId: 'attempt-wor265-shell',
        ),
      ],
    );

Widget _host(Widget child) => OsiaTheme(
  palette: osiaPaletteViolet,
  child: OsiaL10n(
    strings: osiaStringsEn,
    child: MaterialApp(
      theme: buildOsiaTheme(),
      home: Scaffold(body: child),
    ),
  ),
);

void main() {
  test('mobile navigation keeps Autonomous out of the user-facing Chat', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final chatSource = File('lib/screens/chat_screen.dart').readAsStringSync();

    expect(mainSource, isNot(contains('AutonomousScreen(')));
    expect(mainSource, isNot(contains("case '/autonomous'")));
    expect(chatSource, isNot(contains('AutonomousScreen(')));
    expect(chatSource, isNot(contains('autonomousTitle')));
    expect(chatSource, isNot(contains('sendAutonomousStart')));
    expect(chatSource, isNot(contains('Agent activity')));
    expect(chatSource, isNot(contains('0/2 steps')));
    expect(chatSource, isNot(contains('Reste à faire')));
    expect(chatSource, contains('_LegacyRunProjection'));
    expect(chatSource, contains('requestLegacyAutonomousResume'));
  });

  test('mobile transport preserves the correlated provider public summary', () {
    final eventJson = _publicSummaryTrace().events.single.toJson();
    final envelope = ExecutionTraceEnvelope.parse(<String, dynamic>{
      'type': 'execution_trace',
      ...eventJson,
      'snapshot': <Object?>[eventJson],
    });

    expect(envelope, isNotNull);
    expect(envelope!.event.kind, ExecutionTraceKind.reasoningSummary);
    expect(
      envelope.event.publicSummary,
      'Checked the visible calculator result.',
    );
    expect(envelope.event.traceKey, _traceKey);
  });

  test('Thinking accepts only the exact conversation request turn and run', () {
    final trace = _publicSummaryTrace();
    ExecutionTraceSnapshot? match({
      String? conversationId,
      String? requestId,
      String? turnId,
      String? runId,
      String? providerId,
      String? modelId,
      String? effectiveReasoning,
    }) => executionTraceForExactIdentity(
      trace,
      conversationId: conversationId ?? _traceKey.conversationId,
      requestId: requestId ?? _traceKey.requestId,
      turnId: turnId ?? _traceKey.turnId,
      runId: runId ?? _traceKey.runId,
      providerId: providerId ?? _traceKey.providerId,
      modelId: modelId ?? _traceKey.modelId,
      effectiveReasoning: effectiveReasoning ?? _traceKey.effectiveReasoning,
    );

    expect(match(), same(trace));
    expect(match(conversationId: 'conv-stale'), isNull);
    expect(match(requestId: 'req-stale'), isNull);
    expect(match(turnId: 'turn-stale'), isNull);
    expect(match(runId: 'run-stale'), isNull);
    expect(match(providerId: 'provider-stale'), isNull);
    expect(match(modelId: 'model-stale'), isNull);
    expect(match(effectiveReasoning: 'low'), isNull);
  });

  test('public summary has priority over real activity fallback', () {
    expect(
      formatExecutionTraceSummary(
        osiaStringsEn,
        _realActivityTrace(withPublicSummary: true),
      ),
      'Checked the visible calculator result.',
    );
  });

  test('real activity is shown without synthetic remaining-work prose', () {
    final english = formatExecutionTraceSummary(
      osiaStringsEn,
      _realActivityTrace(),
    );
    final french = formatExecutionTraceSummary(
      osiaStringsFr,
      _realActivityTrace(),
    );

    expect(english, isNotEmpty);
    expect(french, isNotEmpty);
    expect(french, isNot(contains('Reste à faire')));
    expect(french, isNot(contains('Aucun moyen valide')));
  });

  test('no public summary or displayable activity yields no fake content', () {
    final empty = ExecutionTraceSnapshot(
      key: _traceKey,
      events: const <ExecutionTraceEvent>[],
    );
    expect(formatExecutionTraceSummary(osiaStringsEn, empty), isEmpty);
  });

  testWidgets('Thinking is compact and reveals only a real public summary', (
    tester,
  ) async {
    const summary = 'Checked the visible calculator result.';
    await tester.pumpWidget(
      _host(
        ExecutionTraceBlock(
          snapshot: _publicSummaryTrace(),
          collapsed: true,
          active: true,
        ),
      ),
    );

    expect(find.text(osiaStringsEn.executionTraceTitle), findsOneWidget);
    expect(find.text(summary), findsNothing);
    expect(find.text('Agent activity'), findsNothing);
    expect(find.text('Planning...'), findsNothing);
    expect(find.text('Working...'), findsNothing);

    await tester.tap(find.text(osiaStringsEn.executionTraceTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(summary), findsOneWidget);
    expect(find.text('Analyzing...'), findsNothing);

    final summaryText = tester.widget<Text>(find.text(summary));
    expect(
      summaryText.style?.color,
      Color.lerp(osiaPaletteViolet.textMuted, osiaPaletteViolet.accent, 0.14),
    );

    await tester.tap(find.text(osiaStringsEn.executionTraceTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(summary), findsNothing);
  });

  testWidgets('empty Thinking disclosure invents no activity prose', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ThinkingDisclosure()));

    expect(find.text(osiaStringsEn.executionTraceTitle), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    for (final fake in <String>[
      'Planning...',
      'Working...',
      'Analyzing...',
      'Thinking about the next step...',
    ]) {
      expect(find.text(fake), findsNothing);
    }
  });

  testWidgets('streaming bubble preserves Markdown code links and Unicode', (
    tester,
  ) async {
    const message =
        'Résumé 🚀 **bold** [OpenAI](https://openai.com)\n'
        '```dart\nfinal value = 28;\n```';
    await tester.pumpWidget(
      _host(const ChatBubble(text: message, isStreaming: true)),
    );
    await tester.pump();

    final rendered = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');
    expect(rendered, contains('Résumé 🚀'));
    expect(rendered, contains('bold'));
    expect(rendered, contains('OpenAI'));
    expect(rendered, contains('final value = 28;'));
    expect(rendered, isNot(contains('```')));
  });
}
