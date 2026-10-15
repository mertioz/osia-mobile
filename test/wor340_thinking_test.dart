import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/services/execution_trace.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/execution_trace_block.dart';

const identity = ExecutionTraceKey(
  conversationId: 'conv340',
  requestId: 'req340',
  turnId: 'turn340',
  runId: 'run340',
  providerId: 'deepseek',
  modelId: 'deepseek-flash',
  effectiveReasoning: 'high',
);

ExecutionTraceEvent event({
  String text = 'I checked the visible values.',
  bool terminal = false,
  int revision = 1,
  ExecutionTraceKey key = identity,
}) => ExecutionTraceEvent(
  eventId: terminal ? 'terminal340' : 'summary340',
  traceKey: key,
  sequence: terminal ? 2 : 1,
  revision: revision,
  kind: terminal
      ? ExecutionTraceKind.terminal
      : ExecutionTraceKind.reasoningSummary,
  display: ExecutionTraceDisplay(
    terminal ? 'execution.terminal.success' : 'execution.reasoning.summary',
  ),
  timestamp: DateTime.utc(2026, 10, 10),
  terminal: terminal,
  publicSummary: terminal ? '' : text,
);

Widget host(
  ExecutionTraceSnapshot trace, {
  bool active = true,
  bool streaming = false,
  Key? key,
  ExecutionTraceDisclosureState? disclosure,
}) => OsiaTheme(
  palette: osiaPaletteViolet,
  child: OsiaL10n(
    strings: osiaStringsEn,
    child: MaterialApp(
      home: Scaffold(
        body: ExecutionTraceBlock(
          key: key,
          snapshot: trace,
          active: active,
          collapsed: true,
          finalStreaming: streaming,
          disclosureState: disclosure,
        ),
      ),
    ),
  ),
);

ExecutionTraceSnapshot trace(
  List<ExecutionTraceEvent> events, {
  ExecutionTraceKey key = identity,
}) => ExecutionTraceSnapshot(key: key, events: events);

void main() {
  for (final provider in [
    'chatgpt_account',
    'deepseek',
    'openai',
    'google',
    'groq',
    'xai',
    'mistral',
    'ollama',
    'anthropic',
  ]) {
    testWidgets(
      '$provider projects PC commentary with revisions and completion',
      (tester) async {
        final binding = ExecutionTraceKey(
          conversationId: 'conv_v3',
          requestId: 'request_v3',
          turnId: 'turn_v3',
          runId: 'turn_v3',
          providerId: provider,
          modelId: provider == 'deepseek' ? 'deepseek-flash' : 'fixture',
          effectiveReasoning: 'auto',
        );
        final accumulator = ExecutionTraceAccumulator(binding);
        final first = event(key: binding, text: 'I will inspect the folder.');
        final live = accumulator.merge(
          ExecutionTraceEnvelope(event: first, snapshot: [first]),
        );
        await tester.pumpWidget(host(live!));
        expect(find.text(osiaStringsEn.executionTraceTitle), findsNothing);
        expect(find.text(first.publicSummary), findsOneWidget);
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();
        final revised = event(
          key: binding,
          revision: 2,
          text: 'I will inspect the folder. The first listing arrived.',
        );
        final update = accumulator.merge(
          ExecutionTraceEnvelope(event: revised, snapshot: [revised]),
        );
        await tester.pumpWidget(host(update!));
        expect(find.text(revised.publicSummary), findsNothing);
        // An exact replay must not duplicate text or reopen manual collapse.
        accumulator.merge(
          ExecutionTraceEnvelope(event: revised, snapshot: [revised]),
        );
        final done = event(key: binding, terminal: true);
        final completed = accumulator.merge(
          ExecutionTraceEnvelope(event: done, snapshot: [done]),
        );
        await tester.pumpWidget(host(completed!, active: false));
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();
        expect(find.text(revised.publicSummary), findsOneWidget);
        expect(
          completed.events
              .where((e) => e.kind == ExecutionTraceKind.reasoningSummary)
              .length,
          1,
        );
      },
    );
  }
  test(
    'Desktop accepted turn feeds the same Mobile trace without a local send',
    () async {
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'synthetic-wor340-test',
        autoReconnect: false,
        lanDirectV1: false,
        webRtcDirectV1: false,
        relayFallbackV1: false,
      );
      addTearDown(service.dispose);
      final observed = <ExecutionTraceSnapshot>[];
      final subscription = service.executionTraceStream.listen(observed.add);
      addTearDown(subscription.cancel);
      final binding = <String, dynamic>{
        'conversation_id': identity.conversationId,
        'request_id': identity.requestId,
        'turn_id': identity.turnId,
        'run_id': identity.runId,
        'provider_id': identity.providerId,
        'model_id': identity.modelId,
        'effective_reasoning': identity.effectiveReasoning,
      };
      service.handleIncomingFrameForTest({'type': 'turn_accepted', ...binding});
      final summary = event().toJson();
      service.handleIncomingFrameForTest({
        'type': 'execution_trace',
        ...summary,
        'snapshot': [summary],
      });
      final terminal = event(terminal: true).toJson();
      service.handleIncomingFrameForTest({
        'type': 'execution_trace',
        ...terminal,
        'snapshot': [terminal],
      });
      await Future<void>.delayed(Duration.zero);
      expect(observed.last.terminal, isTrue);
      expect(
        observed.last.events.first.publicSummary,
        'I checked the visible values.',
      );
      service.handleIncomingFrameForTest({
        'type': 'turn_status',
        ...binding,
        'status': 'done',
        'terminal': true,
      });
      expect(
        service.isConversationWorkActive(identity.conversationId),
        isFalse,
      );
    },
  );

  testWidgets(
    'manual close before commentary survives the waiting row transition',
    (tester) async {
      final memory = ExecutionTraceDisclosureState();
      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPalette,
          child: OsiaL10n(
            strings: osiaStringsEn,
            child: MaterialApp(
              home: Scaffold(body: ThinkingDisclosure(disclosureState: memory)),
            ),
          ),
        ),
      );
      expect(find.text(osiaStringsEn.executionTraceTitle), findsNothing);
      await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
      await tester.pumpWidget(host(trace([event()]), disclosure: memory));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('execution_trace_summary')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('I checked the visible values.'), findsOneWidget);
    },
  );

  testWidgets('partial tool and terminal snapshots retain exact public text', (
    tester,
  ) async {
    final initial = trace([event()]);
    final tool = ExecutionTraceEvent(
      eventId: 'tool340',
      traceKey: identity,
      sequence: 2,
      revision: 1,
      kind: ExecutionTraceKind.action,
      display: const ExecutionTraceDisplay('execution.action.shell'),
      timestamp: DateTime.utc(2026, 10, 11),
      terminal: false,
    );
    final terminal = ExecutionTraceEvent(
      eventId: 'terminal340',
      traceKey: identity,
      sequence: 3,
      revision: 1,
      kind: ExecutionTraceKind.terminal,
      display: const ExecutionTraceDisplay('execution.terminal.cancelled'),
      timestamp: DateTime.utc(2026, 10, 11),
      terminal: true,
    );
    await tester.pumpWidget(host(initial));
    await tester.pumpWidget(host(trace([tool])));
    expect(find.text('I checked the visible values.'), findsOneWidget);
    await tester.pumpWidget(host(trace([terminal]), active: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('execution_trace_summary')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('I checked the visible values.'), findsOneWidget);
    expect(find.textContaining('Activity:'), findsNothing);
  });

  test(
    'canonical history preserves long commentary and more than 24 statements',
    () {
      final events = List.generate(
        35,
        (index) => ExecutionTraceEvent(
          eventId: 'summary$index',
          traceKey: identity,
          sequence: index + 1,
          revision: 1,
          kind: ExecutionTraceKind.reasoningSummary,
          display: const ExecutionTraceDisplay('execution.reasoning.summary'),
          timestamp: DateTime.utc(2026, 10, 11),
          terminal: false,
          publicSummary: index == 0
              ? 'Original public wording. ' * 400
              : 'Checked value $index.',
        ),
      );
      final canonical = trace(events);
      final restored = ExecutionTraceSnapshot.parseHistory(canonical.toJson())!;
      expect(restored.events.length, 35);
      expect(restored.events.first.publicSummary, events.first.publicSummary);
      final compact = trace([events.last]);
      final merged = mergeExecutionTraceSnapshots(restored, compact);
      expect(merged.events.length, 35);
      final accumulator = ExecutionTraceAccumulator(identity);
      expect(
        accumulator
            .merge(
              ExecutionTraceEnvelope(event: events.last, snapshot: events),
            )!
            .events
            .length,
        35,
      );
      expect(
        accumulator
            .merge(
              ExecutionTraceEnvelope(
                event: events.last,
                snapshot: [events.last],
              ),
            )!
            .events
            .length,
        35,
      );
    },
  );

  testWidgets(
    'expanded content has no box and retains text size across themes',
    (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          OsiaTheme(
            palette: osiaPalette,
            child: OsiaL10n(
              strings: osiaStringsEn,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: Scaffold(
                  body: ExecutionTraceBlock(
                    snapshot: trace([event()]),
                    active: true,
                  ),
                ),
              ),
            ),
          ),
        );
        final summaryFinder = find.byKey(
          const ValueKey('execution_trace_summary'),
        );
        final text = tester.widget<Text>(summaryFinder);
        expect(text.style!.fontSize, 13);
        expect(text.style!.height, 1.38);
        expect(
          find.ancestor(of: summaryFinder, matching: find.byType(Card)),
          findsNothing,
        );
        expect(
          find.ancestor(of: summaryFinder, matching: find.byType(DecoratedBox)),
          findsNothing,
        );
      }
    },
  );

  testWidgets('empty indicator auto-expands and respects manual collapse', (
    tester,
  ) async {
    await tester.pumpWidget(host(trace([])));
    expect(find.text(osiaStringsEn.executionTraceTitle), findsNothing);
    expect(find.byKey(const ValueKey('execution_trace_summary')), findsNothing);
    await tester.pumpWidget(host(trace([event()])));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('I checked the visible values.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(
      host(trace([event(text: 'I checked both values.', revision: 2)])),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('execution_trace_summary')), findsNothing);
  });

  testWidgets(
    'answer chunks do not collapse; completion collapses and duplicate terminal preserves reopen',
    (tester) async {
      final initial = trace([event()]);
      final completed = trace([event(), event(terminal: true)]);
      await tester.pumpWidget(host(initial));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(host(initial, streaming: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('execution_trace_summary')),
        findsOneWidget,
      );
      await tester.pumpWidget(host(completed, active: false));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('execution_trace_summary')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(completed, active: false));
      await tester.pumpAndSettle();
      expect(find.text('I checked the visible values.'), findsOneWidget);
    },
  );

  testWidgets('manual collapse survives moving into an answer slot', (
    tester,
  ) async {
    final memory = ExecutionTraceDisclosureState();
    final initial = trace([event()]);
    await tester.pumpWidget(
      host(initial, key: const ValueKey('trailer'), disclosure: memory),
    );
    await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(
      host(
        initial,
        key: const ValueKey('bubble'),
        disclosure: memory,
        streaming: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('execution_trace_summary')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('execution_trace_summary')),
      findsOneWidget,
    );
    // Completion without a trace tombstone must also collapse a remounted row.
    await tester.pumpWidget(
      host(
        initial,
        key: const ValueKey('final'),
        disclosure: memory,
        active: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('execution_trace_summary')), findsNothing);
  });

  testWidgets(
    'historical public text is collapsed and terminal-only trace disappears',
    (tester) async {
      await tester.pumpWidget(host(trace([event()]), active: false));
      expect(
        find.byKey(const ValueKey('execution_trace_summary')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
      await tester.pumpAndSettle();
      expect(find.text('I checked the visible values.'), findsOneWidget);
      await tester.pumpWidget(
        host(
          trace(
            [
              event(
                terminal: true,
                key: const ExecutionTraceKey(
                  conversationId: 'empty',
                  requestId: 'empty',
                  turnId: 'empty',
                  runId: 'empty',
                  providerId: 'deepseek',
                  modelId: 'deepseek-flash',
                  effectiveReasoning: 'high',
                ),
              ),
            ],
            key: const ExecutionTraceKey(
              conversationId: 'empty',
              requestId: 'empty',
              turnId: 'empty',
              runId: 'empty',
              providerId: 'deepseek',
              modelId: 'deepseek-flash',
              effectiveReasoning: 'high',
            ),
          ),
          active: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('execution_trace_toggle')),
        findsNothing,
      );
    },
  );

  testWidgets('new exact turn auto-expands after an older manual collapse', (
    tester,
  ) async {
    const next = ExecutionTraceKey(
      conversationId: 'convNext',
      requestId: 'reqNext',
      turnId: 'turnNext',
      runId: 'runNext',
      providerId: 'deepseek',
      modelId: 'deepseek-flash',
      effectiveReasoning: 'high',
    );
    await tester.pumpWidget(host(trace([event()])));
    await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(host(trace([], key: next)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('I checked the visible values.'), findsNothing);
    expect(find.byKey(const ValueKey('execution_trace_summary')), findsNothing);
    await tester.pumpWidget(
      host(trace([event(key: next, text: 'New turn text.')], key: next)),
    );
    expect(find.text('New turn text.'), findsOneWidget);
  });

  test('unchecked private text and stale events cannot reach display', () {
    final text = formatExecutionTraceSummary(
      osiaStringsEn,
      trace([event(text: '<think>hidden</think>')]),
    );
    expect(text, isEmpty);
    for (final markup in [
      '<｜DSML｜invoke>private</｜DSML｜invoke>',
      '<|im_start|>analysis',
    ]) {
      expect(
        formatExecutionTraceSummary(
          osiaStringsEn,
          trace([event(text: markup)]),
        ),
        isEmpty,
      );
    }
    final raw = event().toJson()..['request_id'] = 'stale';
    final stale = ExecutionTraceEvent.parse(raw)!;
    expect(formatExecutionTraceSummary(osiaStringsEn, trace([stale])), isEmpty);
  });
}
