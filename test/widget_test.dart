import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:osia_mobile/main.dart';
import 'package:osia_mobile/screens/connection_screen.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  testWidgets('fresh app presents onboarding once before connection', (
    tester,
  ) async {
    await tester.pumpWidget(const OsiaApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('onboarding-screen')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-title-welcome')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ConnectionScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const OsiaApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('onboarding-screen')), findsNothing);
    expect(find.byType(ConnectionScreen), findsOneWidget);
  });

  testWidgets('existing app state suppresses automatic onboarding', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'osia_language': 'en',
    });
    await tester.pumpWidget(const OsiaApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('onboarding-screen')), findsNothing);
    expect(find.byType(ConnectionScreen), findsOneWidget);
  });
}
