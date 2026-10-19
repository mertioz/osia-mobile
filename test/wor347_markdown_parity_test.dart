import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/chat_bubble.dart';

Widget host(String text, {bool streaming = false, bool user = false}) =>
    OsiaTheme(
      palette: osiaPalette,
      child: OsiaL10n(
        strings: osiaStringsEn,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatBubble(
                text: text,
                isStreaming: streaming,
                isUser: user,
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('narrow phone keeps long code and tables inside the viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(
        '# Compact\n\n'
        '| Column | Other |\n| --- | --- |\n| ${'word' * 40} | Value |\n\n'
        '```\n${'long_code_' * 80}\n```',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Table), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'completed canonical answer renders GitHub headings lists and tables',
    (tester) async {
      await tester.pumpWidget(
        host(
          '# Title\n\n- Item\n\n> Quote\n\n'
          '| Name | Value |\n| --- | --- |\n| Metric | 42 |\n\n'
          '*Emphasis* and ~~removed~~\n\n```dart\nprint(42);\n```',
        ),
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Item'), findsOneWidget);
      expect(find.text('Quote'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Metric'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'user text stays literal and streaming retains partial delimiters',
    (tester) async {
      const literal = '# User **text**';
      await tester.pumpWidget(host(literal, user: true));
      expect(find.text(literal), findsOneWidget);
      await tester.pumpWidget(host('```dart\npartial', streaming: true));
      expect(find.textContaining('```dart\npartial'), findsOneWidget);
      await tester.pumpWidget(host('```dart\ncomplete\n```'));
      expect(find.textContaining('complete'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('raw HTML and device-local image paths do not load resources', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        '<script>private()</script>\n\n'
        '![Local image](file:///private/local.png)\n\n'
        '[Unsafe](javascript:alert(1))',
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('Local image'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
