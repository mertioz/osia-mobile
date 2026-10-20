import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/execution_trace_block.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Thinking has no pressed ink in $brightness', (tester) async {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPalette,
          child: OsiaL10n(
            strings: osiaStringsEn,
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: Scaffold(
                  body: RepaintBoundary(
                    key: boundaryKey,
                    child: const ThinkingDisclosure(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<List<int>> pixels() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!.buffer.asUint8List().toList();
      }

      final toggle = find.byKey(const ValueKey('execution_trace_toggle'));
      final ink = tester.widget<InkWell>(toggle);
      expect(ink.splashFactory, NoSplash.splashFactory);
      expect(ink.highlightColor, Colors.transparent);
      expect(ink.focusColor, isNot(Colors.transparent));
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
      final semantics = tester.ensureSemantics();
      final control = find.bySemanticsLabel(osiaStringsEn.executionTraceTitle);
      expect(
        tester
            .getSemantics(control)
            .getSemanticsData()
            .flagsCollection
            .isExpanded
            .toBoolOrNull(),
        isTrue,
      );
      final before = await tester.runAsync(pixels);
      final touch = await tester.startGesture(tester.getCenter(toggle));
      await tester.pump(const Duration(milliseconds: 150));
      expect(await tester.runAsync(pixels), before);
      await touch.up();
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(control)
            .getSemanticsData()
            .flagsCollection
            .isExpanded
            .toBoolOrNull(),
        isFalse,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(control)
            .getSemanticsData()
            .flagsCollection
            .isExpanded
            .toBoolOrNull(),
        isTrue,
      );
      semantics.dispose();
    });
  }
}
