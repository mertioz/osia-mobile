import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/thinking_indicator.dart';

void main() {
  Widget host() => OsiaTheme(
    palette: osiaPaletteViolet,
    child: const MaterialApp(home: Scaffold(body: ThinkingIndicator())),
  );

  testWidgets('renders three dots', (tester) async {
    await tester.pumpWidget(host());
    // Three positioned dots inside the indicator's stack.
    expect(find.byType(Positioned), findsNWidgets(3));
  });

  testWidgets('keeps animating across slide cycles without errors', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    // Drive through several 600 ms slide cycles; each cycle commits a move
    // and restarts the controller. Any setState-after-dispose or index bug
    // would throw here.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(Positioned), findsNWidgets(3));

    // Tear down mid-animation: must not leak the ticker or throw.
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
