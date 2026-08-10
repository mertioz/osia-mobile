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
      'redaction_class': executionTraceRedactionClass,
      'events': events,
    })!;

ExecutionTraceSnapshot uncheckedSnapshot(List<ExecutionTraceEvent> events) =>
    ExecutionTraceSnapshot(key: traceKey, events: events);

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

void main() {
  test('three successful actions become one natural ordered sentence', () {
    final prose = formatExecutionTraceSummary(
      osiaStringsEn,
      snapshot(successfulActions()),
    );

    expect(
      prose,
      'I worked in the browser, then handled a document and worked with files.',
    );
    expect('I '.allMatches(prose), hasLength(1));
    expect(prose, isNot(contains('Step completed')));
    expect(prose, isNot(contains('result')));
  });

  test('permission allow collapses into the resulting action', () {
    final trace = snapshot(<Map<String, dynamic>>[
      traceEvent(
        id: 'action',
        sequence: 1,
        kind: 'action',
        displayKey: 'execution.action.browser',
        toolAttemptId: 'attempt-allow',
      ),
      traceEvent(
        id: 'permission',
        sequence: 2,
        kind: 'waiting_permission',
        displayKey: 'execution.permission.waiting',
        toolAttemptId: 'attempt-allow',
        permissionRequestId: 'permission-allow',
      ),
      traceEvent(
        id: 'result',
        sequence: 3,
        kind: 'result',
        displayKey: 'execution.result.completed',
        toolAttemptId: 'attempt-allow',
      ),
    ]);

    final prose = formatExecutionTraceSummary(osiaStringsEn, trace);
    expect(prose, 'I worked in the browser.');
    expect(prose.toLowerCase(), isNot(contains('permission')));
    expect(prose.toLowerCase(), isNot(contains('authorization')));
  });

  test('permission denial stays truthful without blaming the user', () {
    final trace = snapshot(<Map<String, dynamic>>[
      traceEvent(
        id: 'action',
        sequence: 1,
        kind: 'action',
        displayKey: 'execution.action.connector',
        toolAttemptId: 'attempt-denied',
      ),
      traceEvent(
        id: 'permission',
        sequence: 2,
        kind: 'waiting_permission',
        displayKey: 'execution.permission.waiting',
        toolAttemptId: 'attempt-denied',
        permissionRequestId: 'permission-denied',
      ),
      traceEvent(
        id: 'result',
        sequence: 3,
        kind: 'result',
        displayKey: 'execution.result.needs_attention',
        toolAttemptId: 'attempt-denied',
      ),
      traceEvent(
        id: 'terminal',
        sequence: 4,
        kind: 'terminal',
        displayKey: 'execution.terminal.blocked',
        terminal: true,
      ),
    ]);

    final prose = formatExecutionTraceSummary(osiaStringsEn, trace);
    expect(prose, contains('authorization was unavailable'));
    expect(prose.toLowerCase(), isNot(contains('you denied')));
    expect(prose.toLowerCase(), isNot(contains('you rejected')));
  });

  test('three sibling actions with one safe category stay natural', () {
    final events = <Map<String, dynamic>>[];
    for (var index = 0; index < 3; index++) {
      final attempt = 'attempt-$index';
      events
        ..add(
          traceEvent(
            id: 'action-$index',
            sequence: index * 2 + 1,
            kind: 'action',
            displayKey: 'execution.action.capability',
            toolAttemptId: attempt,
          ),
        )
        ..add(
          traceEvent(
            id: 'result-$index',
            sequence: index * 2 + 2,
            kind: 'result',
            displayKey: 'execution.result.completed',
            toolAttemptId: attempt,
          ),
        );
    }

    expect(
      formatExecutionTraceSummary(osiaStringsEn, snapshot(events)),
      'I completed 3 related actions with OSIA.',
    );
  });

  test('presentation failure never reads as a user denial', () {
    final trace = snapshot(<Map<String, dynamic>>[
      traceEvent(
        id: 'action',
        sequence: 1,
        kind: 'action',
        displayKey: 'execution.action.connector',
        toolAttemptId: 'attempt-presentation',
      ),
      traceEvent(
        id: 'permission',
        sequence: 2,
        kind: 'waiting_permission',
        displayKey: 'execution.permission.waiting',
        toolAttemptId: 'attempt-presentation',
        permissionRequestId: 'permission-presentation',
      ),
      traceEvent(
        id: 'result',
        sequence: 3,
        kind: 'result',
        displayKey: 'execution.result.needs_attention',
        toolAttemptId: 'attempt-presentation',
      ),
      traceEvent(
        id: 'terminal',
        sequence: 4,
        kind: 'terminal',
        displayKey: 'execution.terminal.blocked',
        terminal: true,
      ),
    ]);

    final prose = formatExecutionTraceSummary(osiaStringsEn, trace);
    expect(prose, contains('authorization was unavailable'));
    for (final forbidden in <String>[
      'denied',
      'declined',
      'rejected',
      'user',
    ]) {
      expect(prose.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  test(
    'failed first method and successful fallback form one recovery sentence',
    () {
      final trace = snapshot(<Map<String, dynamic>>[
        traceEvent(
          id: 'first-action',
          sequence: 1,
          kind: 'action',
          displayKey: 'execution.action.shell',
          toolAttemptId: 'attempt-first',
        ),
        traceEvent(
          id: 'first-result',
          sequence: 2,
          kind: 'result',
          displayKey: 'execution.result.needs_attention',
          toolAttemptId: 'attempt-first',
        ),
        traceEvent(
          id: 'fallback',
          sequence: 3,
          kind: 'continuation',
          displayKey: 'execution.continuation.new_strategy',
        ),
        traceEvent(
          id: 'second-action',
          sequence: 4,
          kind: 'action',
          displayKey: 'execution.action.browser',
          toolAttemptId: 'attempt-second',
        ),
        traceEvent(
          id: 'second-result',
          sequence: 5,
          kind: 'result',
          displayKey: 'execution.result.completed',
          toolAttemptId: 'attempt-second',
        ),
      ]);

      expect(
        formatExecutionTraceSummary(osiaStringsEn, trace),
        'The first method did not work, so I tried another and worked in the browser.',
      );
    },
  );

  test('ambiguous fallback order does not invent a relationship', () {
    final trace = snapshot(<Map<String, dynamic>>[
      traceEvent(
        id: 'failed-action',
        sequence: 1,
        kind: 'action',
        displayKey: 'execution.action.shell',
        toolAttemptId: 'attempt-failed',
      ),
      traceEvent(
        id: 'failed-result',
        sequence: 2,
        kind: 'result',
        displayKey: 'execution.result.needs_attention',
        toolAttemptId: 'attempt-failed',
      ),
      traceEvent(
        id: 'continuation',
        sequence: 3,
        kind: 'continuation',
        displayKey: 'execution.continuation.new_strategy',
      ),
      traceEvent(
        id: 'browser-action',
        sequence: 4,
        kind: 'action',
        displayKey: 'execution.action.browser',
        toolAttemptId: 'attempt-browser',
      ),
      traceEvent(
        id: 'browser-result',
        sequence: 5,
        kind: 'result',
        displayKey: 'execution.result.completed',
        toolAttemptId: 'attempt-browser',
      ),
      traceEvent(
        id: 'document-action',
        sequence: 6,
        kind: 'action',
        displayKey: 'execution.action.document',
        toolAttemptId: 'attempt-document',
      ),
      traceEvent(
        id: 'document-result',
        sequence: 7,
        kind: 'result',
        displayKey: 'execution.result.completed',
        toolAttemptId: 'attempt-document',
      ),
    ]);

    final prose = formatExecutionTraceSummary(osiaStringsEn, trace);
    expect(
      prose,
      "I worked in the browser, then handled a document, but I couldn't complete the local operation.",
    );
    expect(prose, isNot(contains('first method')));
  });

  test('partial success states completed work before the concrete blocker', () {
    final trace = snapshot(<Map<String, dynamic>>[
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
        displayKey: 'execution.result.needs_attention',
        toolAttemptId: 'attempt-document',
      ),
      traceEvent(
        id: 'terminal',
        sequence: 5,
        kind: 'terminal',
        displayKey: 'execution.terminal.blocked',
        terminal: true,
      ),
    ]);

    expect(
      formatExecutionTraceSummary(osiaStringsEn, trace),
      "I worked in the browser, but I couldn't complete the document step.",
    );
  });

  test(
    'physical partial shape deduplicates blockers and keeps success first',
    () {
      final trace = snapshot(<Map<String, dynamic>>[
        traceEvent(
          id: 'shell-action',
          sequence: 1,
          kind: 'action',
          displayKey: 'execution.action.shell',
          toolAttemptId: 'attempt-shell',
        ),
        traceEvent(
          id: 'shell-result',
          sequence: 2,
          kind: 'result',
          displayKey: 'execution.result.completed',
          toolAttemptId: 'attempt-shell',
        ),
        traceEvent(
          id: 'generic-failure-a',
          sequence: 3,
          kind: 'result',
          displayKey: 'execution.result.needs_attention',
          toolAttemptId: 'unmatched-a',
        ),
        traceEvent(
          id: 'generic-failure-b',
          sequence: 4,
          kind: 'result',
          displayKey: 'execution.result.needs_attention',
          toolAttemptId: 'unmatched-b',
        ),
        traceEvent(
          id: 'capability-action-a',
          sequence: 5,
          kind: 'action',
          displayKey: 'execution.action.capability',
          toolAttemptId: 'attempt-capability-a',
        ),
        traceEvent(
          id: 'capability-result-a',
          sequence: 6,
          kind: 'result',
          displayKey: 'execution.result.completed',
          toolAttemptId: 'attempt-capability-a',
        ),
        traceEvent(
          id: 'capability-action-b',
          sequence: 7,
          kind: 'action',
          displayKey: 'execution.action.capability',
          toolAttemptId: 'attempt-capability-b',
        ),
        traceEvent(
          id: 'capability-result-b',
          sequence: 8,
          kind: 'result',
          displayKey: 'execution.result.completed',
          toolAttemptId: 'attempt-capability-b',
        ),
        traceEvent(
          id: 'terminal',
          sequence: 9,
          kind: 'terminal',
          displayKey: 'execution.terminal.blocked',
          terminal: true,
        ),
      ]);

      expect(
        formatExecutionTraceSummary(osiaStringsEn, trace),
        "I ran a local operation. I completed 2 related actions with OSIA, but I couldn't complete the next step.",
      );
    },
  );

  test(
    'reconciliation-only information becomes a short jargon-free summary',
    () {
      final trace = snapshot(<Map<String, dynamic>>[
        traceEvent(
          id: 'goal',
          sequence: 1,
          kind: 'goal',
          displayKey: 'execution.goal.complete_task',
        ),
        traceEvent(
          id: 'reconciliation',
          sequence: 2,
          kind: 'reconciliation',
          displayKey: 'execution.reconciliation.verifying',
        ),
        traceEvent(
          id: 'terminal',
          sequence: 3,
          kind: 'terminal',
          displayKey: 'execution.terminal.blocked',
          terminal: true,
        ),
      ]);

      final prose = formatExecutionTraceSummary(osiaStringsEn, trace);
      expect(prose, 'I had to stop before the request was complete.');
      for (final forbidden in <String>[
        'reconciliation',
        'postcondition',
        'terminal',
        'strategy',
        'evidence',
        'invocation',
      ]) {
        expect(prose.toLowerCase(), isNot(contains(forbidden)));
      }
    },
  );

  test('latest revision wins without repeating the action', () {
    final oldAction = ExecutionTraceEvent.parse(
      traceEvent(
        id: 'revised-action',
        sequence: 1,
        revision: 1,
        kind: 'action',
        displayKey: 'execution.action.browser',
        toolAttemptId: 'attempt-revised',
      ),
    )!;
    final revisedAction = ExecutionTraceEvent.parse(
      traceEvent(
        id: 'revised-action',
        sequence: 1,
        revision: 2,
        kind: 'action',
        displayKey: 'execution.action.document',
        toolAttemptId: 'attempt-revised',
      ),
    )!;
    final result = ExecutionTraceEvent.parse(
      traceEvent(
        id: 'result',
        sequence: 2,
        kind: 'result',
        displayKey: 'execution.result.completed',
        toolAttemptId: 'attempt-revised',
      ),
    )!;

    expect(
      formatExecutionTraceSummary(
        osiaStringsEn,
        uncheckedSnapshot(<ExecutionTraceEvent>[
          oldAction,
          revisedAction,
          result,
        ]),
      ),
      'I handled a document.',
    );
  });

  test('event order is preserved', () {
    final prose = formatExecutionTraceSummary(
      osiaStringsEn,
      snapshot(successfulActions()),
    );
    expect(prose.indexOf('browser'), lessThan(prose.indexOf('document')));
    expect(prose.indexOf('document'), lessThan(prose.indexOf('files')));
  });

  test('unknown and cross-turn events are ignored safely', () {
    final unknown = ExecutionTraceEvent(
      eventId: 'unknown',
      traceKey: traceKey,
      sequence: 1,
      revision: 1,
      kind: ExecutionTraceKind.action,
      display: const ExecutionTraceDisplay('provider.private_reasoning'),
      timestamp: DateTime.utc(2026, 8, 10),
      terminal: false,
    );
    final crossTurn = ExecutionTraceEvent.parse(
      traceEvent(
        id: 'cross-turn',
        sequence: 2,
        kind: 'action',
        displayKey: 'execution.action.shell',
        conversationId: 'other-conversation',
        requestId: 'other-request',
        turnId: 'other-turn',
      ),
    )!;
    final safeAction = ExecutionTraceEvent.parse(
      traceEvent(
        id: 'safe-action',
        sequence: 3,
        kind: 'action',
        displayKey: 'execution.action.browser',
      ),
    )!;
    final safeResult = ExecutionTraceEvent.parse(
      traceEvent(
        id: 'safe-result',
        sequence: 4,
        kind: 'result',
        displayKey: 'execution.result.completed',
      ),
    )!;

    final prose = formatExecutionTraceSummary(
      osiaStringsEn,
      uncheckedSnapshot(<ExecutionTraceEvent>[
        unknown,
        crossTurn,
        safeAction,
        safeResult,
      ]),
    );
    expect(prose, 'I worked in the browser.');
    expect(prose, isNot(contains('provider')));
    expect(prose, isNot(contains('local operation')));
  });

  test('simple turns stay concise', () {
    final trace = snapshot(<Map<String, dynamic>>[
      traceEvent(
        id: 'goal',
        sequence: 1,
        kind: 'goal',
        displayKey: 'execution.goal.answer',
      ),
      traceEvent(
        id: 'terminal',
        sequence: 2,
        kind: 'terminal',
        displayKey: 'execution.terminal.success',
        terminal: true,
      ),
    ]);

    final prose = formatExecutionTraceSummary(osiaStringsEn, trace);
    expect(prose, 'I handled the request.');
    expect(prose.length, lessThan(40));
  });

  test('persistence reconstruction produces identical prose', () {
    final original = snapshot(successfulActions());
    final restored = ExecutionTraceSnapshot.parseHistory(original.toJson())!;

    expect(
      formatExecutionTraceSummary(osiaStringsFr, restored),
      formatExecutionTraceSummary(osiaStringsFr, original),
    );
  });

  test('French and English are natural and all six locales resolve', () {
    final trace = snapshot(successfulActions());
    expect(
      formatExecutionTraceSummary(osiaStringsFr, trace),
      'J’ai utilisé le navigateur, puis traité un document et travaillé avec des fichiers.',
    );
    expect(
      formatExecutionTraceSummary(osiaStringsEn, trace),
      'I worked in the browser, then handled a document and worked with files.',
    );
    for (final code in osiaSupportedLanguages) {
      final prose = formatExecutionTraceSummary(
        osiaStringsForCode(code),
        trace,
      );
      expect(prose, isNotEmpty, reason: code);
      expect(prose, isNot(contains('execution.')), reason: code);
      if (code != 'en') {
        expect(prose, isNot(contains('I worked')), reason: code);
      }
    }
  });

  test('public prose contains no internal terms or identifiers', () {
    final prose = formatExecutionTraceSummary(
      osiaStringsEn,
      snapshot(successfulActions()),
    ).toLowerCase();
    for (final forbidden in <String>[
      'postcondition',
      'terminality',
      'semantic equivalence',
      'strategy frontier',
      'evidence revision',
      'reconciliation',
      'invocation',
      'tool_attempt',
      'permission_request',
      'attempt-browser',
      'request-257',
      'turn-257',
    ]) {
      expect(prose, isNot(contains(forbidden)));
    }
  });

  testWidgets('collapsed Reflection UI and no-speak contract stay unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ExecutionTraceBlock(
          snapshot: snapshot(successfulActions()),
          collapsed: true,
        ),
        strings: osiaStringsFr,
      ),
    );

    expect(find.text('Réflexion'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('execution_trace_summary')), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    expect(find.byTooltip('Speak'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    expect(
      find.byKey(const ValueKey('execution_trace_summary')),
      findsOneWidget,
    );
    expect(find.byType(Card), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
  });
}
