import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/widgets/execution_trace_block.dart';

import 'wor340_thinking_test.dart' show event, host, trace;

void main() {
  test(
    'Thinking presents only simple headings and preserves complex Markdown',
    () {
      final cases = <String, String>{
        '**Opening Steam and navigating website**':
            'Opening Steam and navigating website',
        '**Je vais ouvrir l’application.**': 'Je vais ouvrir l’application.',
        'Before\n  **Heading**  \nAfter': 'Before\n  Heading  \nAfter',
        'Inline **bold** text': 'Inline **bold** text',
        '**[site](https://fixture.invalid)**':
            '**[site](https://fixture.invalid)**',
        '**`code`**': '**`code`**',
        '**name_with_markup**': '**name_with_markup**',
        '**<b>HTML</b>**': '**<b>HTML</b>**',
        '    **indented code**': '    **indented code**',
        '\t**indented code**': '\t**indented code**',
        '```text\n**code**\n```\n**Heading**':
            '```text\n**code**\n```\nHeading',
        '~~~~\n**code**\n~~~\n**still code**\n~~~~':
            '~~~~\n**code**\n~~~\n**still code**\n~~~~',
        '**unfinished': '**unfinished',
      };
      for (final entry in cases.entries) {
        expect(formatThinkingPublicText(entry.key), entry.value);
      }
    },
  );

  testWidgets(
    'Live presentation preserves raw PC text, provenance and disclosure',
    (tester) async {
      const raw = '**Opening Steam and navigating website**';
      final memory = ExecutionTraceDisclosureState();
      final snapshot = trace([event(text: raw)]);
      final before = snapshot.events.first.toJson();
      await tester.pumpWidget(host(snapshot, disclosure: memory));
      expect(find.text('Opening Steam and navigating website'), findsOneWidget);
      expect(find.text(raw), findsNothing);
      expect(formatExecutionTraceSummary(osiaStringsEn, snapshot), raw);
      expect(snapshot.events.first.toJson(), before);
      await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
      await tester.pump(const Duration(milliseconds: 350));
      final revised = trace([event(text: '$raw\nJe poursuis.', revision: 2)]);
      await tester.pumpWidget(host(revised, disclosure: memory));
      expect(
        find.byKey(const ValueKey('execution_trace_summary')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.text('Opening Steam and navigating website\nJe poursuis.'),
        findsOneWidget,
      );
      expect(revised.events.first.publicSummary, '$raw\nJe poursuis.');
      await tester.pumpWidget(
        host(
          trace([revised.events.first, event(terminal: true)]),
          disclosure: memory,
          active: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('execution_trace_summary')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('execution_trace_toggle')));
      await tester.pumpAndSettle();
      expect(
        find.text('Opening Steam and navigating website\nJe poursuis.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
