import 'package:flutter_test/flutter_test.dart';

import 'package:osia_mobile/main.dart';

void main() {
  testWidgets('OSIA app loads without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const OsiaApp());
    await tester.pump();

    // The app should render (either loading, settings, or chat depending
    // on whether secure storage is configured).
    expect(find.byType(OsiaApp), findsOneWidget);
  });
}
