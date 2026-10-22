import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/services/content_report_service.dart';
import 'package:osia_mobile/widgets/content_report_dialog.dart';

const receipt = '382b5c70-c0e1-4d45-9104-161ced820251';

class RecordingReports extends ContentReportService {
  RecordingReports({this.fail = false});
  final bool fail;
  final sent = <Map<String, String>>[];

  @override
  Future<String> submit({
    required String text,
    required String category,
    required String details,
  }) async {
    sent.add({'text': text, 'category': category, 'details': details});
    if (fail) throw const HttpException('private server diagnostic');
    return receipt;
  }
}

Widget host(RecordingReports reports) => OsiaL10n(
  strings: osiaStringsEn,
  child: MaterialApp(
    home: Scaffold(
      body: ContentReportDialog(
        text: 'An answer with private information to remove',
        service: reports,
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'report requires review, supports redaction and sends only edited fields',
    (tester) async {
      final reports = RecordingReports();
      await tester.pumpWidget(host(reports));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(reports.sent, isEmpty);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('report-text')),
        'Redacted answer',
      );
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(reports.sent, [
        {'text': 'Redacted answer', 'category': 'other', 'details': ''},
      ]);
      expect(find.text(receipt), findsOneWidget);
      expect(find.textContaining('Report received.'), findsOneWidget);
    },
  );

  testWidgets('failed submission never displays a receipt or raw diagnostics', (
    tester,
  ) async {
    final reports = RecordingReports(fail: true);
    await tester.pumpWidget(host(reports));
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Send report'));
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();
    expect(reports.sent, hasLength(1));
    expect(find.text(receipt), findsNothing);
    expect(find.textContaining('could not confirm receipt'), findsOneWidget);
    expect(find.textContaining('private server diagnostic'), findsNothing);
    expect(find.text('Send report'), findsOneWidget);
  });
}
