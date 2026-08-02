import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/chat_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/glass_input_bar.dart';

import '../integration_test/wor216_gate_input.dart';

const _desktopMessage = 'wor216 synthetic desktop origin';
const _mobileMessage = 'wor216 synthetic mobile origin';
const _conversationId = 'wor216-gate-conversation';

Map<String, dynamic> _capturedDesktopSeedFrame() => <String, dynamic>{
  'type': 'conversation_history',
  'id': _conversationId,
  'conversation_id': _conversationId,
  'title': 'WOR216 isolated canonical gate',
  'revision': 2,
  'operation_id': 'op_wor216_gate_desktop',
  'messages': <Map<String, dynamic>>[
    <String, dynamic>{
      'role': 'user',
      'content': _desktopMessage,
      'conversation_id': _conversationId,
      'request_id': 'req_wor216_gate_desktop',
      'client_request_id': 'req_wor216_gate_desktop',
      'turn_id': 'turn_wor216_gate_desktop',
      'message_id': 'msg_wor216_gate_desktop',
    },
  ],
};

void main() {
  testWidgets(
    'captured desktop seed reconciles before deterministic draft injection',
    (tester) async {
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'wor216-host-only-token',
        autoReconnect: false,
        sendFrameForTest: (_) => true,
      );
      addTearDown(service.dispose);
      final ledger = CanonicalHistoryLedger();
      final reconciliationGate = Completer<void>();
      final parsed = Completer<ws.ConversationHistoryMessage>();
      final reconciled = Completer<List<ws.HistoryMessage>>();
      final subscription = service.messageStream.listen((message) async {
        if (message is! ws.ConversationHistoryMessage) return;
        if (!parsed.isCompleted) parsed.complete(message);
        await reconciliationGate.future;
        if (!reconciled.isCompleted &&
            ledger.accept(message.id ?? '', message.messages)) {
          reconciled.complete(List<ws.HistoryMessage>.of(message.messages));
        }
      });
      addTearDown(subscription.cancel);

      service.handleIncomingFrameForTest(_capturedDesktopSeedFrame());
      final history = await parsed.future;
      expect(reconciled.isCompleted, isFalse);
      expect(history.id, _conversationId);
      expect(history.messages.single.content, _desktopMessage);
      expect(history.messages.single.messageId, 'msg_wor216_gate_desktop');
      reconciliationGate.complete();
      final fakeMobileState = await reconciled.future;
      expect(fakeMobileState.single.content, _desktopMessage);

      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var sendTapped = false;
      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPaletteViolet,
          child: OsiaL10n(
            strings: osiaStringsEn,
            child: MaterialApp(
              theme: buildOsiaTheme(),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => GlassInputBar(
                    textController: controller,
                    enabled: true,
                    isRecording: false,
                    hasText: controller.text.trim().isNotEmpty,
                    onSend: () => sendTapped = true,
                    onMicTap: () {},
                    onAttach: () {},
                    modelLabel: 'Model',
                    onModelTap: () {},
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final input = find.byType(TextField);
      expect(input, findsOneWidget);
      expect(service.isConversationBusy(_conversationId), isFalse);
      expect(tester.widget<TextField>(input).enabled, isTrue);
      await enterWor216GateDraft(tester, input, _mobileMessage);
      expect(tester.widget<TextField>(input).controller?.text, _mobileMessage);

      final sendControl = find.ancestor(
        of: find.byIcon(Icons.arrow_upward_rounded),
        matching: find.byType(InkWell),
      );
      expect(sendControl, findsOneWidget);
      expect(tester.widget<InkWell>(sendControl).onTap, isNotNull);
      await tester.tap(sendControl);
      expect(sendTapped, isTrue);
    },
  );
}
