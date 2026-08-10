import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/chat_screen.dart';
import 'package:osia_mobile/services/background_connection_service.dart';
import 'package:osia_mobile/services/connection_lifecycle_service.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

class _SentTurn {
  const _SentTurn(this.content, this.clientRequestId);

  final String content;
  final String clientRequestId;
}

class _RecordingWebSocketService extends ws.WebSocketService {
  _RecordingWebSocketService()
    : super(ip: '127.0.0.1', token: 'token', autoReconnect: false);

  final List<_SentTurn> sentTurns = <_SentTurn>[];
  final StreamController<ws.OsiaMessage> _messages =
      StreamController<ws.OsiaMessage>.broadcast(sync: true);
  final StreamController<ws.RelayTransferEvent> _relayTransfers =
      StreamController<ws.RelayTransferEvent>.broadcast();

  @override
  Stream<ws.OsiaMessage> get messageStream => _messages.stream;

  void emitMessage(ws.OsiaMessage message) {
    _messages.add(message);
  }

  @override
  Stream<ws.RelayTransferEvent> get relayTransferStream =>
      _relayTransfers.stream;

  void emitRelayTransfer(ws.RelayTransferEvent event) {
    _relayTransfers.add(event);
  }

  @override
  ws.ConnectionState get state => ws.ConnectionState.connected;

  @override
  bool sendText(
    String content, {
    String? conversationId,
    String? clientRequestId,
    bool ttsEnabled = true,
    Map<String, dynamic>? turnDirectives,
  }) {
    sentTurns.add(_SentTurn(content, clientRequestId ?? ''));
    return true;
  }

  @override
  void sendGetConfig() {}

  @override
  void sendGetModels() {}

  @override
  void sendLoadConversation(String id) {}

  @override
  void dispose() {
    unawaited(_messages.close());
    unawaited(_relayTransfers.close());
    super.dispose();
  }
}

class _NoopBackgroundPlatform implements BackgroundConnectionPlatform {
  @override
  Future<bool> isRunning() async => false;

  @override
  Future<bool> start() async => true;

  @override
  Future<void> stop() async {}
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'osia_token': 'token',
    });
  });

  testWidgets(
    'terminal cancels watchdog and one retry tap resends the same id once',
    (tester) async {
      final storage = StorageService();
      final service = _RecordingWebSocketService();
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
                  bufferedMessages: const <ws.OsiaMessage>[
                    ws.ConversationsMessage(<ws.Conversation>[
                      ws.Conversation(
                        id: 'conv-watchdog',
                        title: 'Watchdog test',
                      ),
                    ]),
                    ws.ActiveConversationMessage(
                      id: 'conv-watchdog',
                      title: 'Watchdog test',
                    ),
                    ws.ConversationHistoryMessage(
                      id: 'conv-watchdog',
                      messages: <ws.HistoryMessage>[],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final input = find.byType(TextField);
      final firstWatchdogs = <Timer>[];
      await runZoned(
        () async {
          await tester.enterText(input, 'first turn');
          await tester.pump();
          await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
          await tester.pump();
        },
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) {
            final timer = parent.createTimer(zone, duration, callback);
            if (duration == const Duration(seconds: 12)) {
              firstWatchdogs.add(timer);
            }
            return timer;
          },
        ),
      );

      expect(service.sentTurns, hasLength(1));
      final firstRequestId = service.sentTurns.single.clientRequestId;
      expect(firstRequestId, isNotEmpty);
      expect(firstWatchdogs, hasLength(1));
      expect(firstWatchdogs.single.isActive, isTrue);

      await tester.pump(const Duration(seconds: 6));
      // A terminal frame alone must cancel turn 1's still-armed first-token
      // watchdog; no earlier chunk or accepted frame stands it down for us.
      service.rememberRequestForTest('conv-watchdog', firstRequestId);
      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'status',
        'conversation_id': 'conv-watchdog',
        'request_id': firstRequestId,
        'client_request_id': firstRequestId,
        'turn_id': 'turn-1',
        'message_id': 'message-turn-1-done',
        'event_id': 'event-turn-1-done',
        'event_type': 'status',
        'sequence': 1,
        'terminal': true,
        'content': 'done',
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(firstWatchdogs.single.isActive, isFalse);

      // Pass turn 1's original deadline before creating any turn-2 timer. This
      // isolates terminal cancellation from _armFirstTokenTimer's own cleanup.
      await tester.pump(const Duration(seconds: 6, milliseconds: 100));
      expect(find.text("OSIA didn't respond."), findsNothing);

      await tester.enterText(input, 'second turn');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      expect(service.sentTurns, hasLength(2));
      final secondRequestId = service.sentTurns.last.clientRequestId;
      expect(secondRequestId, isNotEmpty);
      expect(secondRequestId, isNot(firstRequestId));

      // Turn 2 is only halfway through its own independent watchdog.
      await tester.pump(const Duration(seconds: 6));
      expect(find.text("OSIA didn't respond."), findsNothing);

      // Turn 2 owns a fresh 12-second watchdog and must time out independently.
      await tester.pump(const Duration(seconds: 6, milliseconds: 100));
      expect(find.text("OSIA didn't respond."), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(service.sentTurns, hasLength(3));
      expect(service.sentTurns.last.content, 'second turn');
      expect(service.sentTurns.last.clientRequestId, secondRequestId);

      // Let the retry's delayed scroll request and animation finish; ChatScreen
      // owns and cancels the actual turn watchdog when it is disposed below.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      themeController.dispose();
      languageController.dispose();
    },
  );

  testWidgets(
    'chunk transfer grace and failure retry keep the same request id',
    (tester) async {
      final storage = StorageService();
      final service = _RecordingWebSocketService();
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
                  bufferedMessages: const <ws.OsiaMessage>[
                    ws.ConversationsMessage(<ws.Conversation>[
                      ws.Conversation(
                        id: 'conv-transfer',
                        title: 'Transfer test',
                      ),
                    ]),
                    ws.ActiveConversationMessage(
                      id: 'conv-transfer',
                      title: 'Transfer test',
                    ),
                    ws.ConversationHistoryMessage(
                      id: 'conv-transfer',
                      messages: <ws.HistoryMessage>[],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final input = find.byType(TextField);
      await tester.enterText(input, 'large relay turn');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      expect(service.sentTurns, hasLength(1));
      final requestId = service.sentTurns.single.clientRequestId;
      service.emitRelayTransfer(
        ws.RelayTransferEvent(
          direction: ws.RelayTransferDirection.outbound,
          state: ws.RelayTransferState.started,
          chunkId: 'A' * 22,
          clientRequestId: requestId,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 12, milliseconds: 100));
      expect(find.text("OSIA didn't respond."), findsNothing);

      service.emitRelayTransfer(
        ws.RelayTransferEvent(
          direction: ws.RelayTransferDirection.outbound,
          state: ws.RelayTransferState.completed,
          chunkId: 'A' * 22,
          clientRequestId: requestId,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 34, milliseconds: 900));
      expect(find.text("OSIA didn't respond."), findsNothing);

      service.emitRelayTransfer(
        ws.RelayTransferEvent(
          direction: ws.RelayTransferDirection.outbound,
          state: ws.RelayTransferState.failed,
          chunkId: 'A' * 22,
          clientRequestId: requestId,
          errorKind: ws.RelayTransferErrorKind.chunkFailed,
        ),
      );
      await tester.pump();
      expect(find.text("OSIA didn't respond."), findsNothing);
      expect(find.text('The encrypted relay transfer failed.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(service.sentTurns, hasLength(2));
      expect(service.sentTurns.last.clientRequestId, requestId);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      themeController.dispose();
      languageController.dispose();
    },
  );

  testWidgets(
    'read-aloud media request survives the completed text turn id guard',
    (tester) async {
      final storage = StorageService();
      final service = _RecordingWebSocketService();
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
                  bufferedMessages: const <ws.OsiaMessage>[
                    ws.ConversationsMessage(<ws.Conversation>[
                      ws.Conversation(
                        id: 'conv-read-aloud',
                        title: 'Read aloud test',
                      ),
                    ]),
                    ws.ActiveConversationMessage(
                      id: 'conv-read-aloud',
                      title: 'Read aloud test',
                    ),
                    ws.ConversationHistoryMessage(
                      id: 'conv-read-aloud',
                      messages: <ws.HistoryMessage>[],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'completed turn');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      final textRequestId = service.sentTurns.single.clientRequestId;

      service.rememberRequestForTest('conv-read-aloud', textRequestId);
      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'status',
        'conversation_id': 'conv-read-aloud',
        'request_id': textRequestId,
        'client_request_id': textRequestId,
        'turn_id': 'text-turn',
        'message_id': 'text-message',
        'event_id': 'text-terminal',
        'event_type': 'status',
        'sequence': 1,
        'terminal': true,
        'content': 'done',
      });
      await tester.pump();

      final logs = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      try {
        service.emitMessage(
          const ws.AudioMessage(
            'AA==',
            source: 'speak',
            conversationId: 'conv-read-aloud',
            clientRequestId: 'media-request',
            turnId: 'media-turn',
            messageId: 'text-message',
          ),
        );
        await tester.pump();
      } finally {
        debugPrint = previousDebugPrint;
      }

      expect(
        logs.where((line) => line.contains('playing (read-aloud)')),
        hasLength(1),
      );
      expect(
        logs.where(
          (line) =>
              line.contains('ignored stale frame for a non-current request'),
        ),
        isEmpty,
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      themeController.dispose();
      languageController.dispose();
    },
  );
}
