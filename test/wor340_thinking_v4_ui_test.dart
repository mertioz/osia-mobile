import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/services/execution_trace.dart';
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/execution_trace_block.dart';
import 'package:osia_mobile/widgets/thinking_orbs.dart';

import 'wor340_thinking_test.dart' show host, trace, event;

const toggleKey = ValueKey('execution_trace_toggle');
const summaryKey = ValueKey('execution_trace_summary');

void main() {
  testWidgets(
    'new turn auto-expands received text and live revisions without a tap',
    (tester) async {
      final memory = ExecutionTraceDisclosureState();
      final initial = trace([event(text: 'Received public commentary.')]);
      await tester.pumpWidget(host(initial, disclosure: memory));
      expect(find.text(osiaStringsEn.executionTraceTitle), findsNothing);
      expect(find.byType(ThinkingOrbs), findsOneWidget);
      expect(find.byKey(summaryKey), findsOneWidget);
      expect(
        tester.getSize(find.byKey(toggleKey)).height,
        greaterThanOrEqualTo(48),
      );
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(osiaStringsEn.executionTraceTitle),
        findsOneWidget,
      );
      expect(find.text('Received public commentary.'), findsOneWidget);
      final revision = trace([
        event(
          text: 'Received public commentary. Another value arrived.',
          revision: 2,
        ),
      ]);
      await tester.pumpWidget(
        host(revision, disclosure: memory, streaming: true),
      );
      expect(find.text(revision.events.first.publicSummary), findsOneWidget);
      expect(find.text(osiaStringsEn.executionTraceTitle), findsNothing);
      await tester.pumpWidget(
        host(revision, disclosure: memory, streaming: true),
      );
      expect(find.byKey(summaryKey), findsOneWidget);
      await tester.tap(find.byKey(toggleKey));
      await tester.pump();
      await tester.pumpWidget(host(revision, disclosure: memory));
      expect(find.byKey(summaryKey), findsNothing);
      final done = trace([revision.events.first, event(terminal: true)]);
      await tester.pumpWidget(host(done, active: false, disclosure: memory));
      await tester.pumpAndSettle();
      expect(find.text(osiaStringsEn.executionTraceTitle), findsOneWidget);
      expect(find.byType(ThinkingOrbs), findsNothing);
      expect(find.byKey(summaryKey), findsNothing);
      await tester.tap(find.byKey(toggleKey));
      await tester.pumpAndSettle();
      expect(find.text(revision.events.first.publicSummary), findsOneWidget);
      await tester.pumpWidget(host(done, active: false, disclosure: memory));
      await tester.pumpAndSettle();
      expect(find.byKey(summaryKey), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'open empty control renders first receipt and has keyboard access',
    (tester) async {
      final memory = ExecutionTraceDisclosureState();
      await tester.pumpWidget(host(trace([]), disclosure: memory));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pumpWidget(host(trace([event()]), disclosure: memory));
      expect(find.byKey(summaryKey), findsNothing); // First Enter collapsed.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byKey(summaryKey), findsOneWidget);
      final ink = tester.widget<InkWell>(find.byKey(toggleKey));
      expect(ink.focusColor, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fresh exact turn resets even a reused disclosure memory', (
    tester,
  ) async {
    final memory = ExecutionTraceDisclosureState();
    await tester.pumpWidget(host(trace([event()]), disclosure: memory));
    await tester.tap(find.byKey(toggleKey));
    await tester.pump();
    const next = ExecutionTraceKey(
      conversationId: 'next',
      requestId: 'next',
      turnId: 'next',
      runId: 'next',
      providerId: 'deepseek',
      modelId: 'deepseek-flash',
      effectiveReasoning: 'high',
    );
    await tester.pumpWidget(
      host(
        trace([event(text: 'New turn text.', key: next)], key: next),
        disclosure: memory,
      ),
    );
    expect(find.byKey(summaryKey), findsOneWidget);
    expect(find.text('New turn text.'), findsOneWidget);
    expect(find.text('I checked the visible values.'), findsNothing);
  });

  test(
    'six-orb position scale and opacity input match at the cycle boundary',
    () {
      const size = Size(54, 20);
      const epsilon = 0.00001;
      final start = thinkingOrbPoints(size, 0);
      final end = thinkingOrbPoints(size, 1);
      for (var i = 0; i < ThinkingOrbs.orbCount; i++) {
        expect((start[i].center - end[i].center).distance, lessThan(1e-10));
        expect(start[i].radius, closeTo(end[i].radius, 1e-10));
        expect(start[i].depth, closeTo(end[i].depth, 1e-10));
        final before =
            (thinkingOrbPoints(size, epsilon)[i].center -
                thinkingOrbPoints(size, -epsilon)[i].center) /
            (2 * epsilon);
        final after =
            (thinkingOrbPoints(size, 1 + epsilon)[i].center -
                thinkingOrbPoints(size, 1 - epsilon)[i].center) /
            (2 * epsilon);
        expect((before - after).distance, lessThan(1e-7));
        expect(start[i].radius, greaterThan(0));
      }
    },
  );

  testWidgets(
    'animation cleans up for inactive hidden background and reduced motion',
    (tester) async {
      Widget orbs({
        bool active = true,
        bool reduced = false,
        bool enabled = true,
      }) => OsiaTheme(
        palette: osiaPalette,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: TickerMode(
              enabled: enabled,
              child: ThinkingOrbs(active: active),
            ),
          ),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(orbs());
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byKey(const ValueKey('thinking_orbs_animation')),
        findsOneWidget,
      );
      await tester.pumpWidget(orbs(reduced: true));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('thinking_orbs_animation')),
        findsNothing,
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(orbs(enabled: false));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('thinking_orbs_animation')),
        findsNothing,
      );
      await tester.pumpWidget(orbs(active: false));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(orbs());
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
