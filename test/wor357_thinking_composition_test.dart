import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/chat_screen.dart';
import 'package:osia_mobile/services/background_connection_service.dart';
import 'package:osia_mobile/services/connection_lifecycle_service.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/services/execution_trace.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/chat_bubble.dart';
import 'package:osia_mobile/widgets/execution_trace_block.dart';
import 'wor340_thinking_test.dart' as fixture;

class Service extends ws.WebSocketService {
  Service() : super(ip: '127.0.0.1', token: 'test-only', autoReconnect: false);
  final messages = StreamController<ws.OsiaMessage>.broadcast(sync: true);
  @override
  Stream<ws.OsiaMessage> get messageStream => messages.stream;
  @override
  ws.ConnectionState get state => ws.ConnectionState.connected;
  @override
  void sendGetConfig() {}
  @override
  void sendGetModels() {}
  @override
  void sendLoadConversation(String id) {}
  @override
  void dispose() {
    unawaited(messages.close());
    super.dispose();
  }
}

class Background implements BackgroundConnectionPlatform {
  @override
  Future<bool> isRunning() async => false;
  @override
  Future<bool> start() async => true;
  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets(
    'real ChatScreen binds history and reconnect Thinking only above replies',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({'osia_token': 'test-only'});
      final service = Service();
      final storage = StorageService();
      final background = BackgroundConnectionService(
        storage: storage,
        platform: Background(),
      );
      final lifecycle = ConnectionLifecycleService(
        backgroundConnectionService: background,
      );
      final key = fixture.identity;
      final done = fixture.trace([
        fixture.event(),
        fixture.event(terminal: true),
      ]);
      ws.HistoryMessage message(
        String role,
        String text,
        String id, {
        bool withTrace = false,
      }) => ws.HistoryMessage(
        role: role,
        content: text,
        messageId: id,
        conversationId: key.conversationId,
        clientRequestId: key.requestId,
        turnId: key.turnId,
        runId: key.runId,
        providerId: key.providerId,
        modelId: key.modelId,
        effectiveReasoning: key.effectiveReasoning,
        executionTrace: withTrace ? done : null,
      );
      final history = [
        message('user', 'First question', 'u1'),
        message('assistant', 'First answer', 'a1', withTrace: true),
      ];
      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPaletteViolet,
          child: OsiaL10n(
            strings: osiaStringsEn,
            child: MaterialApp(
              theme: buildOsiaTheme(),
              home: ChatScreen(
                storage: storage,
                themeController: ThemeController(),
                languageController: LanguageController(),
                connectionLifecycle: lifecycle,
                backgroundConnectionService: background,
                handoff: ChatHandoff(
                  service: service,
                  bufferedMessages: [
                    ws.ConversationsMessage([
                      ws.Conversation(
                        id: key.conversationId,
                        title: 'Composition',
                      ),
                    ]),
                    ws.ActiveConversationMessage(
                      id: key.conversationId,
                      title: 'Composition',
                    ),
                    ws.ConversationHistoryMessage(
                      id: key.conversationId,
                      messages: history,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ExecutionTraceBlock), findsOneWidget);
      // A longer reconnect snapshot reuses retained trace by identity. Both
      // roles intentionally share identity; a user must never acquire that trace.
      service.messages.add(
        ws.ConversationHistoryMessage(
          id: key.conversationId,
          messages: [
            ...history,
            const ws.HistoryMessage(
              role: 'user',
              content: 'Next question',
              messageId: 'u2',
            ),
            const ws.HistoryMessage(
              role: 'assistant',
              content: 'Next answer',
              messageId: 'a2',
            ),
          ],
          replayed: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ExecutionTraceBlock), findsOneWidget);
      final thinking = find.byType(ExecutionTraceBlock);
      final user = find.byWidgetPredicate(
        (w) => w is ChatBubble && w.text == 'First question',
      );
      final reply = find.byWidgetPredicate(
        (w) => w is ChatBubble && w.text == 'First answer',
      );
      expect(
        tester.getTopLeft(user).dy,
        lessThan(tester.getTopLeft(thinking).dy),
      );
      expect(
        tester.getBottomLeft(thinking).dy,
        lessThanOrEqualTo(tester.getTopLeft(reply).dy),
      );
      await tester.tap(
        find.descendant(of: thinking, matching: find.byType(InkWell)).first,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('I checked the visible values.'), findsOneWidget);
      const next = ExecutionTraceKey(
        conversationId: 'conv340',
        requestId: 'r3',
        turnId: 't3',
        runId: 'run3',
        providerId: 'deepseek',
        modelId: 'deepseek-flash',
        effectiveReasoning: 'high',
      );
      final binding = <String, dynamic>{
        'conversation_id': next.conversationId,
        'request_id': next.requestId,
        'turn_id': next.turnId,
        'run_id': next.runId,
        'provider_id': next.providerId,
        'model_id': next.modelId,
        'effective_reasoning': next.effectiveReasoning,
      };
      service.handleIncomingFrameForTest({'type': 'turn_accepted', ...binding});
      final summary = fixture
          .event(key: next, text: 'Third turn commentary.')
          .toJson();
      service.handleIncomingFrameForTest({
        'type': 'execution_trace',
        ...summary,
        'snapshot': [summary],
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ExecutionTraceBlock), findsNWidgets(2));
      expect(find.text('Third turn commentary.'), findsOneWidget);
      service.handleIncomingFrameForTest({
        'type': 'response_chunk',
        ...binding,
        'content': 'Third answer',
        'message_id': 'a3',
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ExecutionTraceBlock), findsNWidgets(2));
      final third = find.byWidgetPredicate(
        (w) => w is ExecutionTraceBlock && w.snapshot.key == next,
      );
      final thirdReply = find.byWidgetPredicate(
        (w) => w is ChatBubble && w.text == 'Third answer',
      );
      expect(
        tester.getBottomLeft(third).dy,
        lessThanOrEqualTo(tester.getTopLeft(thirdReply).dy),
      );
      final terminal = fixture.event(key: next, terminal: true).toJson();
      service.handleIncomingFrameForTest({
        'type': 'execution_trace',
        ...terminal,
        'snapshot': [terminal],
      });
      service.handleIncomingFrameForTest({
        'type': 'status',
        ...binding,
        'content': 'done',
        'terminal': true,
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ExecutionTraceBlock), findsNWidgets(2));
      expect(find.text('Third turn commentary.'), findsNothing);
      await tester.tap(
        find.descendant(of: third, matching: find.byType(InkWell)).first,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Third turn commentary.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
