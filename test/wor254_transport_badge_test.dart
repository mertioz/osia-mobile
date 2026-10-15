import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/services/execution_trace.dart';
import 'package:osia_mobile/services/transport_coordinator.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/connection_badge.dart';
import 'package:osia_mobile/widgets/execution_trace_block.dart';
import 'package:osia_mobile/widgets/transport_status_sheet.dart';

Widget host(
  Widget child, {
  OsiaStrings strings = osiaStringsEn,
  double textScale = 1,
  bool disableAnimations = false,
}) => OsiaTheme(
  palette: osiaPaletteViolet,
  child: OsiaL10n(
    strings: strings,
    child: MaterialApp(
      theme: buildOsiaTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  ),
);

ws.WebSocketService service() => ws.WebSocketService(
  ip: '127.0.0.1',
  token: 'wor-254-route-token',
  autoReconnect: false,
  relayFallbackV1: false,
  lanDirectV1: false,
  webRtcDirectV1: false,
);

Map<String, dynamic> traceEvent({
  required String id,
  required int sequence,
  required String kind,
  required String displayKey,
  int revision = 1,
  bool terminal = false,
}) => <String, dynamic>{
  'schema_version': executionTraceSchemaVersion,
  'event_id': id,
  'conversation_id': 'conv-254',
  'request_id': 'request-254',
  'turn_id': 'turn-254',
  'run_id': 'run-254',
  'provider_id': 'deepseek',
  'model_id': 'deepseek-flash',
  'effective_reasoning': 'high',
  'sequence': sequence,
  'revision': revision,
  'kind': kind,
  'display': <String, Object?>{'key': displayKey, 'args': <String, Object?>{}},
  'timestamp': '2026-08-10T10:00:00Z',
  'terminal': terminal,
  'redaction_class': executionTraceRedactionClass,
};

ExecutionTraceSnapshot snapshot(List<Map<String, dynamic>> events) =>
    ExecutionTraceSnapshot.parseHistory(<String, dynamic>{
      'schema_version': executionTraceSchemaVersion,
      'conversation_id': 'conv-254',
      'request_id': 'request-254',
      'turn_id': 'turn-254',
      'run_id': 'run-254',
      'provider_id': 'deepseek',
      'model_id': 'deepseek-flash',
      'effective_reasoning': 'high',
      'redaction_class': executionTraceRedactionClass,
      'events': events,
    })!;

ExecutionTraceSnapshot uncheckedSnapshot(List<Map<String, dynamic>> events) =>
    ExecutionTraceSnapshot(
      key: const ExecutionTraceKey(
        conversationId: 'conv-254',
        requestId: 'request-254',
        turnId: 'turn-254',
        runId: 'run-254',
        providerId: 'deepseek',
        modelId: 'deepseek-flash',
        effectiveReasoning: 'high',
      ),
      events: events
          .map((event) => ExecutionTraceEvent.parse(event)!)
          .toList(growable: false),
    );

void main() {
  testWidgets('green health dot opens a live committed-route sheet', (
    tester,
  ) async {
    final client = service();
    addTearDown(client.dispose);
    expect(
      client.acquireApplicationTransportForTest(ApplicationTransportKind.lan),
      isTrue,
    );
    client.markDirectTransportConnectedForTest(ApplicationTransportKind.lan);

    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => ConnectionBadge(
            state: ws.ConnectionState.connected,
            onTap: () => showTransportStatusSheet(context, client),
          ),
        ),
      ),
    );
    expect(find.byTooltip(osiaStringsEn.connected), findsOneWidget);
    expect(find.byType(ConnectionBadge), findsOneWidget);

    await tester.tap(find.byType(ConnectionBadge));
    await tester.pumpAndSettle();
    expect(find.text(osiaStringsEn.activeTransportTitle), findsOneWidget);
    expect(
      find.text(
        osiaStringsEn.transportStateText(
          ws.CommittedTransportState.lanDirect.name,
        ),
      ),
      findsOneWidget,
    );

    client.disconnect();
    await tester.pump();
    expect(
      find.text(
        osiaStringsEn.transportStateText(
          ws.CommittedTransportState.switching.name,
        ),
      ),
      findsOneWidget,
    );
  });

  test('committed route is rejected without an authority lease', () {
    final client = service();
    addTearDown(client.dispose);
    client.markDirectTransportConnectedForTest(ApplicationTransportKind.lan);
    expect(
      client.committedTransportState,
      ws.CommittedTransportState.switching,
    );
  });

  testWidgets('completed trace is only a subtle collapsed metadata row', (
    tester,
  ) async {
    final goal = traceEvent(
      id: 'trace-goal',
      sequence: 1,
      kind: 'action',
      displayKey: 'execution.action.shell',
    );
    final terminal = traceEvent(
      id: 'trace-terminal',
      sequence: 2,
      kind: 'terminal',
      displayKey: 'execution.terminal.success',
      terminal: true,
    );
    await tester.pumpWidget(
      host(
        ExecutionTraceBlock(
          snapshot: snapshot(<Map<String, dynamic>>[goal, terminal]),
          collapsed: true,
        ),
      ),
    );

    expect(find.byType(ExecutionTraceBlock), findsOneWidget);
    expect(find.text(osiaStringsEn.executionTraceTitle), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    expect(find.byKey(const ValueKey('execution_trace_summary')), findsNothing);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
    expect(find.text('Completed'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ExecutionTraceBlock),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(ExecutionTraceBlock),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'tap expands to prose, changes chevron, and second tap collapses',
    (tester) async {
      final trace = snapshot(<Map<String, dynamic>>[
        traceEvent(
          id: 'trace-goal',
          sequence: 1,
          kind: 'public_reasoning_summary',
          displayKey: 'execution.reasoning.summary',
        )..['summary'] = 'Checking the public browser status.',
        traceEvent(
          id: 'trace-browser',
          sequence: 2,
          kind: 'action',
          displayKey: 'execution.action.browser',
        ),
        traceEvent(
          id: 'trace-result',
          sequence: 3,
          kind: 'result',
          displayKey: 'execution.result.completed',
        ),
        traceEvent(
          id: 'trace-continuation',
          sequence: 4,
          kind: 'continuation',
          displayKey: 'execution.continuation.new_strategy',
        ),
        traceEvent(
          id: 'trace-verify',
          sequence: 5,
          kind: 'reconciliation',
          displayKey: 'execution.reconciliation.verifying',
        ),
        traceEvent(
          id: 'trace-terminal',
          sequence: 6,
          kind: 'terminal',
          displayKey: 'execution.terminal.success',
          terminal: true,
        ),
      ]);
      final prose = formatExecutionTraceSummary(osiaStringsEn, trace);

      await tester.pumpWidget(
        host(ExecutionTraceBlock(snapshot: trace, collapsed: true)),
      );
      await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
      expect(find.text(prose), findsOneWidget);
      expect(prose, 'Checking the public browser status.');
      expect(prose, isNot(contains('•')));
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(ListTile), findsNothing);

      await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(
        find.byKey(const ValueKey('execution_trace_summary')),
        findsNothing,
      );
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    },
  );

  test(
    'formatter preserves order and latest revisions without lifecycle prose',
    () {
      final trace = uncheckedSnapshot(<Map<String, dynamic>>[
        traceEvent(
          id: 'trace-result',
          sequence: 3,
          kind: 'result',
          displayKey: 'execution.result.completed',
        ),
        traceEvent(
          id: 'trace-goal',
          sequence: 1,
          revision: 1,
          kind: 'goal',
          displayKey: 'execution.goal.answer',
        ),
        traceEvent(
          id: 'trace-browser-a',
          sequence: 2,
          kind: 'action',
          displayKey: 'execution.action.browser',
        ),
        traceEvent(
          id: 'trace-browser-b',
          sequence: 4,
          kind: 'action',
          displayKey: 'execution.action.browser',
        ),
        traceEvent(
          id: 'trace-goal',
          sequence: 1,
          revision: 2,
          kind: 'goal',
          displayKey: 'execution.goal.complete_task',
        ),
      ]);
      const expected = '';

      expect(formatExecutionTraceSummary(osiaStringsEn, trace), expected);
      expect(formatExecutionTraceSummary(osiaStringsEn, trace), expected);
    },
  );

  test('formatter skips unsafe, non-public, and cross-turn events', () {
    const key = ExecutionTraceKey(
      conversationId: 'conv-254',
      requestId: 'request-254',
      turnId: 'turn-254',
      runId: 'run-254',
      providerId: 'deepseek',
      modelId: 'deepseek-flash',
      effectiveReasoning: 'high',
    );
    final safe = ExecutionTraceEvent.parse(
      traceEvent(
        id: 'trace-safe',
        sequence: 2,
        kind: 'action',
        displayKey: 'execution.action.browser',
      ),
    )!;
    final unsafe = ExecutionTraceEvent(
      eventId: 'trace-unsafe',
      traceKey: key,
      sequence: 1,
      revision: 1,
      kind: ExecutionTraceKind.action,
      display: const ExecutionTraceDisplay(
        'execution.action.browser',
        <String, Object?>{'command': 'secret --token=value'},
      ),
      timestamp: DateTime.utc(2026, 8, 10),
      terminal: false,
    );
    final unknown = ExecutionTraceEvent(
      eventId: 'trace-private',
      traceKey: key,
      sequence: 3,
      revision: 1,
      kind: ExecutionTraceKind.action,
      display: const ExecutionTraceDisplay('provider.private_reasoning'),
      timestamp: DateTime.utc(2026, 8, 10),
      terminal: false,
    );
    final stale = ExecutionTraceEvent(
      eventId: 'trace-stale',
      traceKey: const ExecutionTraceKey(
        conversationId: 'conv-254',
        requestId: 'request-stale',
        turnId: 'turn-stale',
      ),
      sequence: 4,
      revision: 1,
      kind: ExecutionTraceKind.action,
      display: const ExecutionTraceDisplay('execution.action.shell'),
      timestamp: DateTime.utc(2026, 8, 10),
      terminal: false,
    );
    final trace = ExecutionTraceSnapshot(
      key: key,
      events: <ExecutionTraceEvent>[unsafe, safe, unknown, stale],
    );
    final prose = formatExecutionTraceSummary(osiaStringsEn, trace);

    expect(prose, '');
    expect(prose, isNot(contains('secret')));
    expect(prose, isNot(contains('provider')));
  });

  test('persisted events reconstruct exactly the same prose', () {
    final original = snapshot(<Map<String, dynamic>>[
      traceEvent(
        id: 'trace-goal',
        sequence: 1,
        kind: 'goal',
        displayKey: 'execution.goal.answer',
      ),
      traceEvent(
        id: 'trace-shell',
        sequence: 2,
        kind: 'action',
        displayKey: 'execution.action.shell',
      ),
      traceEvent(
        id: 'trace-terminal',
        sequence: 3,
        kind: 'terminal',
        displayKey: 'execution.terminal.success',
        terminal: true,
      ),
    ]);
    final restored = ExecutionTraceSnapshot.parseHistory(original.toJson())!;

    expect(
      formatExecutionTraceSummary(osiaStringsFr, restored),
      formatExecutionTraceSummary(osiaStringsFr, original),
    );
  });

  testWidgets('live expanded prose updates without becoming event rows', (
    tester,
  ) async {
    final action = traceEvent(
      id: 'trace-action',
      sequence: 1,
      kind: 'public_reasoning_summary',
      displayKey: 'execution.reasoning.summary',
    )..['summary'] = 'Checking the visible browser status.';
    final initial = snapshot(<Map<String, dynamic>>[action]);
    await tester.pumpWidget(
      host(ExecutionTraceBlock(snapshot: initial, active: true)),
    );
    final initialProse = formatExecutionTraceSummary(osiaStringsEn, initial);
    expect(initialProse, 'Checking the visible browser status.');
    expect(
      find.byKey(const ValueKey('execution_trace_summary')),
      findsOneWidget,
    );

    final updated = snapshot(<Map<String, dynamic>>[
      action,
      traceEvent(
        id: 'trace-result',
        sequence: 2,
        kind: 'public_reasoning_summary',
        displayKey: 'execution.reasoning.summary',
      )..['summary'] = 'Comparing the returned public value.',
    ]);
    await tester.pumpWidget(
      host(ExecutionTraceBlock(snapshot: updated, active: true)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(formatExecutionTraceSummary(osiaStringsEn, updated)),
      findsOneWidget,
    );
    expect(find.text(initialProse), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('large text scaling wraps without clipping or speak controls', (
    tester,
  ) async {
    final trace = snapshot(<Map<String, dynamic>>[
      traceEvent(
        id: 'trace-goal',
        sequence: 1,
        kind: 'public_reasoning_summary',
        displayKey: 'execution.reasoning.summary',
      )..['summary'] = 'Checking the public values in the connected document.',
      traceEvent(
        id: 'trace-connector',
        sequence: 2,
        kind: 'action',
        displayKey: 'execution.action.connector',
      ),
      traceEvent(
        id: 'trace-attention',
        sequence: 3,
        kind: 'result',
        displayKey: 'execution.result.needs_attention',
      ),
    ]);
    await tester.pumpWidget(
      host(
        ExecutionTraceBlock(snapshot: trace, active: true),
        textScale: 3,
        disableAnimations: true,
      ),
    );
    // Exercise reduced-motion close/reopen as well as automatic first layout.
    await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    final summary = tester.widget<Text>(
      find.byKey(const ValueKey('execution_trace_summary')),
    );
    expect(summary.maxLines, isNull);
    expect(summary.overflow, isNull);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    expect(find.byTooltip('Speak'), findsNothing);
  });

  testWidgets(
    'French and English preserve model wording and localize the header',
    (tester) async {
      final trace = snapshot(<Map<String, dynamic>>[
        traceEvent(
          id: 'trace-goal',
          sequence: 1,
          kind: 'public_reasoning_summary',
          displayKey: 'execution.reasoning.summary',
        )..['summary'] = 'Checking the public values before answering.',
        traceEvent(
          id: 'trace-result',
          sequence: 2,
          kind: 'result',
          displayKey: 'execution.result.completed',
        ),
      ]);
      await tester.pumpWidget(
        host(ExecutionTraceBlock(snapshot: trace, active: true)),
      );
      final accessibility = tester.ensureSemantics();
      expect(find.text(osiaStringsEn.executionTraceTitle), findsNothing);
      expect(
        find.bySemanticsLabel(osiaStringsEn.executionTraceTitle),
        findsOneWidget,
      );
      expect(
        find.text(formatExecutionTraceSummary(osiaStringsEn, trace)),
        findsOneWidget,
      );

      await tester.pumpWidget(
        host(
          ExecutionTraceBlock(snapshot: trace, active: true),
          strings: osiaStringsFr,
        ),
      );
      expect(find.text('Réflexion'), findsNothing);
      expect(find.bySemanticsLabel('Réflexion'), findsOneWidget);
      expect(
        formatExecutionTraceSummary(osiaStringsFr, trace),
        'Checking the public values before answering.',
      );
      expect(
        find.text(formatExecutionTraceSummary(osiaStringsFr, trace)),
        findsOneWidget,
      );
      await tester.pumpWidget(
        host(
          ExecutionTraceBlock(snapshot: trace, active: false),
          strings: osiaStringsFr,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Réflexion'), findsOneWidget);
      accessibility.dispose();
    },
  );

  test('WOR-254 labels exist in every supported language', () {
    for (final code in osiaSupportedLanguages) {
      final strings = osiaStringsForCode(code);
      expect(strings.activeTransportTitle, isNotEmpty);
      expect(strings.executionTraceTitle, isNotEmpty);
      for (final state in ws.CommittedTransportState.values) {
        expect(strings.transportStateText(state.name), isNotEmpty);
      }
    }
  });
}
