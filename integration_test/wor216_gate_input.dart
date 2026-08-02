import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> enterWor216GateDraft(
  WidgetTester tester,
  FinderBase<Element> input,
  String text,
) async {
  final field = tester.widget<TextField>(input);
  expect(
    field.enabled,
    isTrue,
    reason: 'the physical gate must target the enabled production composer',
  );
  final editable = find.descendant(
    of: input,
    matching: find.byType(EditableText),
    matchRoot: true,
  );
  expect(editable, findsOneWidget);
  tester
      .state<EditableTextState>(editable)
      .updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
  await tester.pump();
}
