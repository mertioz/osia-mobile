import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/pairing_token.dart';
import 'package:osia_mobile/screens/connection_screen.dart';
import 'package:osia_mobile/screens/pairing_scanner_screen.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/theme.dart';

const _currentToken = '00000000000000000000';

String _repeat(String value, int count) => List.filled(count, value).join();

class _FakeScannerAdapter implements PairingScannerAdapter {
  _FakeScannerAdapter({this.failure, this.startGate});

  PairingScannerFailure? failure;
  Completer<PairingScannerFailure?>? startGate;
  ValueChanged<String?>? _onDetect;
  int startCount = 0;
  int stopCount = 0;
  int disposeCount = 0;

  void emit(String? value) => _onDetect?.call(value);

  @override
  Widget buildPreview(ValueChanged<String?> onDetect) {
    _onDetect = onDetect;
    return const ColoredBox(
      key: Key('fake-pairing-scanner-preview'),
      color: Colors.black,
    );
  }

  @override
  Future<PairingScannerFailure?> start() async {
    startCount++;
    if (startGate case final gate?) return gate.future;
    return failure;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}

Widget _app(Widget home) {
  return OsiaTheme(
    palette: osiaPaletteViolet,
    child: OsiaL10n(
      strings: osiaStringsForCode('en'),
      child: MaterialApp(home: home),
    ),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('pairing token contract', () {
    test('normalization is identical for current and legacy valid tokens', () {
      final current = parsePairingToken('  $_currentToken\n');
      final oldest = parsePairingToken('${_repeat('b', 16)}  ');
      final legacy = parsePairingToken('${_repeat('a', 64)}  ');

      expect(current.isValid, isTrue);
      expect(current.value, _currentToken);
      expect(oldest.isValid, isTrue);
      expect(oldest.value, _repeat('b', 16));
      expect(legacy.isValid, isTrue);
      expect(legacy.value, _repeat('a', 64));
    });

    test('empty oversized malformed and unrelated payloads fail closed', () {
      expect(parsePairingToken('   ').issue, PairingTokenIssue.empty);
      expect(
        parsePairingToken(_repeat('a', maxPairingTokenLength + 1)).issue,
        PairingTokenIssue.oversized,
      );
      expect(
        parsePairingToken('not-a-pairing-token').issue,
        PairingTokenIssue.malformed,
      );
      expect(
        parsePairingToken('https://example.com/pair').issue,
        PairingTokenIssue.malformed,
      );
    });
  });

  test('camera permission is limited to the QR scanner requirement', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.CAMERA'));
    expect(manifest, isNot(contains('READ_MEDIA_IMAGES')));
    expect(manifest, isNot(contains('ACCESS_FINE_LOCATION')));
  });

  testWidgets('scan action is present while manual entry stays available', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ConnectionScreen(storage: StorageService())));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pairing-token-field')), findsOneWidget);
    expect(find.byKey(const Key('pairing-scan-button')), findsOneWidget);
    expect(find.byKey(const Key('pairing-connect-button')), findsOneWidget);
  });

  testWidgets('valid scan populates the canonical manual field exactly once', (
    tester,
  ) async {
    final storage = StorageService();
    final scanner = _FakeScannerAdapter();
    await tester.pumpWidget(
      _app(
        ConnectionScreen(
          storage: storage,
          pairingScannerFactory: () => scanner,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pairing-scan-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pairing-scanner-screen')), findsOneWidget);

    scanner.emit('  $_currentToken\n');
    scanner.emit(_currentToken);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('pairing-token-field')),
    );
    expect(field.controller!.text, _currentToken);
    expect(scanner.stopCount, 1);
    expect(await storage.getToken(), isNull);
    expect(find.byKey(const Key('pairing-connect-button')), findsOneWidget);
  });

  for (final entry in <String, String?>{
    'empty': '',
    'oversized': _repeat('a', maxPairingTokenLength + 1),
    'malformed': 'invalid-token',
    'unrelated': 'https://example.com/pair',
  }.entries) {
    testWidgets('${entry.key} QR payload is rejected and scanner can retry', (
      tester,
    ) async {
      final scanner = _FakeScannerAdapter();
      await tester.pumpWidget(_app(PairingScannerScreen(adapter: scanner)));
      await tester.pump();

      scanner.emit(entry.value);
      await tester.pump();

      expect(find.byKey(const Key('pairing-scanner-screen')), findsOneWidget);
      expect(
        find.text(osiaStringsForCode('en').invalidPairingQr),
        findsOneWidget,
      );
      expect(scanner.stopCount, 0);

      scanner.emit(_currentToken);
      await tester.pumpAndSettle();
      expect(scanner.stopCount, 1);
    });
  }

  testWidgets('cancellation preserves existing manual token input', (
    tester,
  ) async {
    final scanner = _FakeScannerAdapter();
    await tester.pumpWidget(
      _app(
        ConnectionScreen(
          storage: StorageService(),
          pairingScannerFactory: () => scanner,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pairing-token-field')),
      _currentToken,
    );

    await tester.tap(find.byKey(const Key('pairing-scan-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pairing-scanner-cancel')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('pairing-token-field')),
    );
    expect(field.controller!.text, _currentToken);
    expect(find.byKey(const Key('pairing-connect-button')), findsOneWidget);
    expect(scanner.disposeCount, 1);
  });

  testWidgets('permission denial leaves manual pairing available', (
    tester,
  ) async {
    final scanner = _FakeScannerAdapter(
      failure: PairingScannerFailure.permissionDenied,
    );
    await tester.pumpWidget(
      _app(
        ConnectionScreen(
          storage: StorageService(),
          pairingScannerFactory: () => scanner,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pairing-token-field')),
      _currentToken,
    );

    await tester.tap(find.byKey(const Key('pairing-scan-button')));
    await tester.pumpAndSettle();
    expect(
      find.text(osiaStringsForCode('en').cameraPermissionDeniedForPairing),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('pairing-scanner-retry')));
    await tester.pump();
    expect(scanner.startCount, 2);
    await tester.tap(find.text(osiaStringsForCode('en').cancel).last);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('pairing-token-field')),
    );
    expect(field.controller!.text, _currentToken);
    expect(find.byKey(const Key('pairing-connect-button')), findsOneWidget);
  });

  testWidgets('scanner releases resources on background and disposal', (
    tester,
  ) async {
    final scanner = _FakeScannerAdapter();
    await tester.pumpWidget(_app(PairingScannerScreen(adapter: scanner)));
    await tester.pump();
    expect(scanner.startCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(scanner.stopCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(scanner.startCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(scanner.disposeCount, 1);
  });

  testWidgets('backgrounding during camera start still stops the camera', (
    tester,
  ) async {
    final gate = Completer<PairingScannerFailure?>();
    final scanner = _FakeScannerAdapter(startGate: gate);
    await tester.pumpWidget(_app(PairingScannerScreen(adapter: scanner)));
    await tester.pump();
    expect(scanner.startCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(scanner.stopCount, 1);

    gate.complete(null);
    await tester.pump();
    expect(scanner.stopCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets(
    'manual malformed input uses the shared validation before pairing',
    (tester) async {
      await tester.pumpWidget(
        _app(ConnectionScreen(storage: StorageService())),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pairing-token-field')),
        'https://example.com/pair',
      );
      await tester.tap(find.byKey(const Key('pairing-connect-button')));
      await tester.pump();

      expect(find.text(osiaStringsForCode('en').invalidToken), findsOneWidget);
      expect(await StorageService().getToken(), isNull);
    },
  );
}
