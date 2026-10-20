import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/services/execution_trace.dart';
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/execution_trace_block.dart';

const traceKey = ExecutionTraceKey(
  conversationId: 'conv-257',
  requestId: 'request-257',
  turnId: 'turn-257',
  runId: 'run-257',
  providerId: 'deepseek',
  modelId: 'deepseek-flash',
  effectiveReasoning: 'high',
);

Map<String, dynamic> traceEvent({
  required String id,
  required int sequence,
  required String kind,
  required String displayKey,
  int revision = 1,
  bool terminal = false,
  String toolAttemptId = '',
  String permissionRequestId = '',
  String conversationId = 'conv-257',
  String requestId = 'request-257',
  String turnId = 'turn-257',
}) => <String, dynamic>{
  'schema_version': executionTraceSchemaVersion,
  'event_id': id,
  'conversation_id': conversationId,
  'request_id': requestId,
  'turn_id': turnId,
  'run_id': traceKey.runId,
  'provider_id': traceKey.providerId,
  'model_id': traceKey.modelId,
  'effective_reasoning': traceKey.effectiveReasoning,
  'sequence': sequence,
  'revision': revision,
  'kind': kind,
  'display': <String, Object?>{'key': displayKey, 'args': <String, Object?>{}},
  'timestamp': '2026-08-10T10:00:00Z',
  'terminal': terminal,
  'redaction_class': executionTraceRedactionClass,
  if (toolAttemptId.isNotEmpty) 'tool_attempt_id': toolAttemptId,
  if (permissionRequestId.isNotEmpty)
    'permission_request_id': permissionRequestId,
};

ExecutionTraceSnapshot snapshot(List<Map<String, dynamic>> events) =>
    ExecutionTraceSnapshot.parseHistory(<String, dynamic>{
      'schema_version': executionTraceSchemaVersion,
      'conversation_id': traceKey.conversationId,
      'request_id': traceKey.requestId,
      'turn_id': traceKey.turnId,
      'run_id': traceKey.runId,
      'provider_id': traceKey.providerId,
      'model_id': traceKey.modelId,
      'effective_reasoning': traceKey.effectiveReasoning,
      'redaction_class': executionTraceRedactionClass,
      'events': events,
    })!;

ExecutionTraceSnapshot uncheckedSnapshot(List<Map<String, dynamic>> events) =>
    ExecutionTraceSnapshot(
      key: traceKey,
      events: events.map((event) => ExecutionTraceEvent.parse(event)!).toList(),
    );

List<Map<String, dynamic>> successfulActions() => <Map<String, dynamic>>[
  traceEvent(
    id: 'browser-action',
    sequence: 1,
    kind: 'action',
    displayKey: 'execution.action.browser',
    toolAttemptId: 'attempt-browser',
  ),
  traceEvent(
    id: 'browser-result',
    sequence: 2,
    kind: 'result',
    displayKey: 'execution.result.completed',
    toolAttemptId: 'attempt-browser',
  ),
  traceEvent(
    id: 'document-action',
    sequence: 3,
    kind: 'action',
    displayKey: 'execution.action.document',
    toolAttemptId: 'attempt-document',
  ),
  traceEvent(
    id: 'document-result',
    sequence: 4,
    kind: 'result',
    displayKey: 'execution.result.completed',
    toolAttemptId: 'attempt-document',
  ),
  traceEvent(
    id: 'files-action',
    sequence: 5,
    kind: 'action',
    displayKey: 'execution.action.filesystem',
    toolAttemptId: 'attempt-files',
  ),
  traceEvent(
    id: 'files-result',
    sequence: 6,
    kind: 'result',
    displayKey: 'execution.result.completed',
    toolAttemptId: 'attempt-files',
  ),
  traceEvent(
    id: 'terminal',
    sequence: 7,
    kind: 'terminal',
    displayKey: 'execution.terminal.success',
    terminal: true,
  ),
];

Widget host(Widget child, {OsiaStrings strings = osiaStringsEn}) => OsiaTheme(
  palette: osiaPaletteViolet,
  child: OsiaL10n(
    strings: strings,
    child: MaterialApp(
      theme: buildOsiaTheme(),
      home: Scaffold(body: child),
    ),
  ),
);

// WOR-340 supersedes local first-person prose generation. Retain the real
// activity/privacy/order contracts without inventing model statements.
void main() {
  const successfulFacts = '';

  test(
    'successful actions remain factual activity, without model impersonation',
    () {
      final text = formatExecutionTraceSummary(
        osiaStringsEn,
        snapshot(successfulActions()),
      );
      expect(text, successfulFacts);
      expect(text, isNot(contains('I ')));
      expect(text, isNot(contains('verified')));
    },
  );

  test(
    'repetition preserves distinct observed actions instead of inferring a story',
    () {
      final trace = snapshot([
        traceEvent(
          id: 'one',
          sequence: 1,
          kind: 'action',
          displayKey: 'execution.action.browser',
        ),
        traceEvent(
          id: 'two',
          sequence: 2,
          kind: 'action',
          displayKey: 'execution.action.browser',
        ),
      ]);
      expect(formatExecutionTraceSummary(osiaStringsEn, trace), '');
    },
  );

  test('latest revision wins and event order survives replay', () {
    final old = traceEvent(
      id: 'a',
      sequence: 1,
      kind: 'action',
      displayKey: 'execution.action.browser',
    );
    final updated = traceEvent(
      id: 'a',
      sequence: 1,
      revision: 2,
      kind: 'action',
      displayKey: 'execution.action.shell',
    );
    final result = traceEvent(
      id: 'b',
      sequence: 2,
      kind: 'result',
      displayKey: 'execution.result.needs_attention',
    );
    final trace = uncheckedSnapshot([result, old, updated, old]);
    expect(formatExecutionTraceSummary(osiaStringsEn, trace), '');
  });

  test(
    'terminal and planner metadata never manufacture a model explanation',
    () {
      for (final terminalKey in [
        'success',
        'blocked',
        'cancelled',
        'safety_block',
      ]) {
        final trace = snapshot([
          traceEvent(
            id: 'goal',
            sequence: 1,
            kind: 'goal',
            displayKey: 'execution.goal.complete_task',
          ),
          traceEvent(
            id: 'preparing',
            sequence: 2,
            kind: 'action',
            displayKey: 'execution.action.preparing',
          ),
          traceEvent(
            id: 'verify',
            sequence: 3,
            kind: 'reconciliation',
            displayKey: 'execution.reconciliation.verifying',
          ),
          traceEvent(
            id: 'terminal',
            sequence: 4,
            kind: 'terminal',
            displayKey: 'execution.terminal.$terminalKey',
            terminal: true,
          ),
        ]);
        expect(formatExecutionTraceSummary(osiaStringsEn, trace), isEmpty);
      }
    },
  );

  test('public model wording and activity stay separate, in order', () {
    final raw = traceEvent(
      id: 'model',
      sequence: 1,
      kind: 'public_reasoning_summary',
      displayKey: 'execution.reasoning.summary',
    )..['summary'] = 'I checked  both visible values.';
    final trace = snapshot([
      raw,
      traceEvent(
        id: 'tool',
        sequence: 2,
        kind: 'action',
        displayKey: 'execution.action.shell',
      ),
      traceEvent(
        id: 'returned',
        sequence: 3,
        kind: 'result',
        displayKey: 'execution.result.observed',
      ),
    ]);
    expect(
      formatExecutionTraceSummary(osiaStringsEn, trace),
      'I checked  both visible values.',
    );
    expect(
      formatExecutionTraceSummary(osiaStringsFr, trace),
      'I checked  both visible values.',
    );
  });

  test(
    'history reconstruction keeps exact text and localizes only activity',
    () {
      final original = snapshot(successfulActions());
      final restored = ExecutionTraceSnapshot.parseHistory(original.toJson())!;
      expect(
        formatExecutionTraceSummary(osiaStringsEn, restored),
        successfulFacts,
      );
      for (final code in osiaSupportedLanguages) {
        final text = formatExecutionTraceSummary(
          osiaStringsForCode(code),
          restored,
        );
        expect(text, isEmpty);
        expect(text, isNot(contains('execution.')));
        expect(text, isNot(contains('attempt-')));
      }
    },
  );

  test('late activity after a terminal cannot create more Thinking', () {
    final events = successfulActions();
    final late = traceEvent(
      id: 'late',
      sequence: 8,
      kind: 'action',
      displayKey: 'execution.action.shell',
    );
    final trace = uncheckedSnapshot([...events, late]);
    expect(formatExecutionTraceSummary(osiaStringsEn, trace), successfulFacts);
  });

  testWidgets(
    'completed tool-only history keeps a control without fabricated prose',
    (tester) async {
      await tester.pumpWidget(
        host(
          ExecutionTraceBlock(
            snapshot: snapshot(successfulActions()),
            collapsed: true,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('execution_trace_toggle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('execution_trace_summary')),
        findsNothing,
      );
    },
  );
}
