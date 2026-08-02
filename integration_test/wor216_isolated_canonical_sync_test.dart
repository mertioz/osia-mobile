import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/chat_screen.dart';
import 'package:osia_mobile/services/background_connection_service.dart';
import 'package:osia_mobile/services/connection_lifecycle_service.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

import 'wor216_gate_input.dart';

const String _gateToken = String.fromEnvironment('WOR216_GATE_TOKEN');
const String _gateTitle = String.fromEnvironment('WOR216_GATE_TITLE');
const String _desktopMessage = String.fromEnvironment(
  'WOR216_GATE_DESKTOP_MESSAGE',
);
const String _mobileMessage = String.fromEnvironment(
  'WOR216_GATE_MOBILE_MESSAGE',
);

class _NoopBackgroundPlatform implements BackgroundConnectionPlatform {
  @override
  Future<bool> isRunning() async => false;

  @override
  Future<bool> start() async => false;

  @override
  Future<void> stop() async {}
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 30),
  String reason = 'condition',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $reason');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

List<ws.ConversationHistoryMessage> _histories(List<ws.OsiaMessage> messages) =>
    messages.whereType<ws.ConversationHistoryMessage>().toList();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'isolated physical PC and Mobile canonical history gate',
    (tester) async {
      expect(
        kReleaseMode,
        isTrue,
        reason: 'gate must run in the official release variant',
      );
      expect(_gateToken, isNotEmpty);
      expect(_gateTitle, isNotEmpty);
      expect(_desktopMessage, isNotEmpty);
      expect(_mobileMessage, isNotEmpty);

      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'osia_token': _gateToken,
        'osia_background_connection_enabled': 'false',
        'osia_auto_tts': 'false',
      });
      final storage = StorageService();
      final service = ws.WebSocketService(
        ip: InternetAddress.loopbackIPv4.address,
        token: _gateToken,
        autoReconnect: false,
        allowLegacyRendezvousFallback: false,
        relayFallbackV1: false,
        lanDirectV1: false,
        webRtcDirectV1: false,
      );
      final received = <ws.OsiaMessage>[];
      final subscription = service.messageStream.listen(received.add);
      addTearDown(() async {
        await subscription.cancel();
        service.dispose();
      });

      await service.ensureConnected(reason: 'wor216_isolated_gate');
      await _waitUntil(
        tester,
        () =>
            service.state == ws.ConnectionState.connected &&
            received.whereType<ws.ConversationsMessage>().isNotEmpty,
        reason: 'authenticated production WebSocket conversation list',
      );

      // The PC launcher observes this authenticated connection and then performs
      // the desktop-originated create + commit through the real canonical store.
      await _waitUntil(
        tester,
        () => _histories(received).any(
          (history) =>
              history.messages.length == 1 &&
              history.messages.single.content == _desktopMessage,
        ),
        reason: 'desktop canonical broadcast',
      );
      final desktopHistory = _histories(received).lastWhere(
        (history) =>
            history.messages.length == 1 &&
            history.messages.single.content == _desktopMessage,
      );
      final conversationId = desktopHistory.id;
      expect(conversationId, isNotNull);
      expect(conversationId, isNotEmpty);
      expect(desktopHistory.messages.single.role, 'user');
      expect(desktopHistory.messages.single.messageId, isNotEmpty);

      final background = BackgroundConnectionService(
        storage: storage,
        platform: _NoopBackgroundPlatform(),
      );
      final lifecycle = ConnectionLifecycleService(
        backgroundConnectionService: background,
      );
      final themeController = ThemeController();
      final languageController = LanguageController();
      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPaletteViolet,
          child: OsiaL10n(
            strings: osiaStringsEn,
            child: MaterialApp(
              theme: buildOsiaTheme(),
              home: ChatScreen(
                storage: storage,
                themeController: themeController,
                languageController: languageController,
                connectionLifecycle: lifecycle,
                backgroundConnectionService: background,
                handoff: ChatHandoff(
                  service: service,
                  bufferedMessages: List<ws.OsiaMessage>.of(received),
                ),
              ),
            ),
          ),
        ),
      );
      await _waitUntil(
        tester,
        () =>
            find.text(_gateTitle).evaluate().isNotEmpty &&
            find.text(_desktopMessage).evaluate().length == 1,
        reason: 'ChatScreen desktop history reconciliation',
      );

      final input = find.byType(TextField);
      expect(input, findsOneWidget);
      expect(service.isConversationBusy(conversationId!), isFalse);
      await enterWor216GateDraft(tester, input, _mobileMessage);
      expect(tester.widget<TextField>(input).controller?.text, _mobileMessage);
      final sendControl = find.ancestor(
        of: find.byIcon(Icons.arrow_upward_rounded),
        matching: find.byType(InkWell),
      );
      expect(sendControl, findsOneWidget);
      expect(tester.widget<InkWell>(sendControl).onTap, isNotNull);
      await tester.tap(sendControl);
      await tester.pump();
      await _waitUntil(
        tester,
        () => find.text(_mobileMessage).evaluate().length == 1,
        timeout: const Duration(seconds: 5),
        reason: 'Mobile optimistic item after enabled send',
      );

      await _waitUntil(
        tester,
        () => _histories(received).any(
          (history) =>
              history.id == conversationId &&
              history.messages.length == 2 &&
              history.messages[0].content == _desktopMessage &&
              history.messages[1].content == _mobileMessage,
        ),
        reason: 'Mobile-originated canonical commit broadcast',
      );
      final mobileHistory = _histories(received).lastWhere(
        (history) =>
            history.id == conversationId && history.messages.length == 2,
      );
      expect(mobileHistory.messages.map((item) => item.role), <String>[
        'user',
        'user',
      ]);
      expect(
        mobileHistory.messages.map((item) => item.messageId).toSet(),
        hasLength(2),
      );
      final canonicalMobile = mobileHistory.messages[1];
      expect(canonicalMobile.messageId, isNotEmpty);
      expect(canonicalMobile.clientRequestId, isNotEmpty);
      expect(canonicalMobile.turnId, isNotEmpty);
      await _waitUntil(
        tester,
        () =>
            find.text(_desktopMessage).evaluate().length == 1 &&
            find.text(_mobileMessage).evaluate().length == 1,
        reason: 'optimistic Mobile item canonical reconciliation',
      );
      expect(
        tester.getTopLeft(find.text(_desktopMessage)).dy,
        lessThan(tester.getTopLeft(find.text(_mobileMessage)).dy),
      );

      await _waitUntil(
        tester,
        () => !service.isConversationBusy(conversationId),
        reason: 'first Mobile turn completion',
      );
      final retrySent = service.sendText(
        _mobileMessage,
        conversationId: conversationId,
        clientRequestId: canonicalMobile.clientRequestId,
        ttsEnabled: false,
      );
      expect(retrySent, isTrue);
      await _waitUntil(
        tester,
        () => !service.isConversationBusy(conversationId),
        reason: 'idempotent retry terminal receipt',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(_desktopMessage), findsOneWidget);
      expect(find.text(_mobileMessage), findsOneWidget);

      final historiesBeforeReconnect = _histories(received).length;
      await service.ensureConnected(
        reason: 'wor216_isolated_gate_reconnect',
        forceReconnect: true,
      );
      await _waitUntil(
        tester,
        () =>
            service.state == ws.ConnectionState.connected &&
            _histories(received).length > historiesBeforeReconnect &&
            _histories(received).last.messages.length == 2,
        reason: 'reconnected canonical two-message history',
      );
      await _waitUntil(
        tester,
        () =>
            find.text(_desktopMessage).evaluate().length == 1 &&
            find.text(_mobileMessage).evaluate().length == 1,
        reason: 'ChatScreen reconnect reconciliation',
      );

      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      final tile = find.byKey(ValueKey<String>('conv_$conversationId'));
      expect(tile, findsOneWidget);
      await tester.drag(tile, const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(osiaStringsEn.deleteConversationTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, osiaStringsEn.delete));
      await tester.pump(const Duration(milliseconds: 500));
      await _waitUntil(
        tester,
        () =>
            find.text(_desktopMessage).evaluate().isEmpty &&
            find.text(_mobileMessage).evaluate().isEmpty,
        reason: 'canonical deletion reflected by ChatScreen',
      );

      // Sanitized success marker consumed by the PC launcher. It contains no
      // message body, credential, device id or filesystem path.
      // ignore: avoid_print
      print('WOR216_PHYSICAL_ASSERTIONS_PASS');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
