import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/chat_screen.dart';
import 'package:osia_mobile/services/background_connection_service.dart';
import 'package:osia_mobile/services/connection_lifecycle_service.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/services/transport_coordinator.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

class _NoopBackgroundPlatform implements BackgroundConnectionPlatform {
  @override
  Future<bool> isRunning() async => false;

  @override
  Future<bool> start() async => true;

  @override
  Future<void> stop() async {}
}

class _WaitingWebSocketService extends ws.WebSocketService {
  _WaitingWebSocketService()
    : super(ip: '127.0.0.1', token: 'token', autoReconnect: false);

  final StreamController<ws.OsiaMessage> _messages =
      StreamController<ws.OsiaMessage>.broadcast(sync: true);
  final List<String> waitingCommands = <String>[];
  final List<String> normalTurns = <String>[];
  bool waiting = true;
  bool busy = true;
  String waitingStatus = 'waiting_verification';

  @override
  Stream<ws.OsiaMessage> get messageStream => _messages.stream;

  @override
  ws.ConnectionState get state => ws.ConnectionState.connected;

  @override
  bool isConversationBusy(String id) => busy;

  @override
  bool isConversationWaiting(String id) => waiting;

  @override
  String waitingTurnStatus(String id) => waiting ? waitingStatus : '';

  @override
  bool sendWaitingTurnCommand(
    String content, {
    required String conversationId,
    bool allowPreDispatchCancel = false,
  }) {
    waitingCommands.add(content);
    return (waiting || busy) && conversationId == 'conv-waiting';
  }

  @override
  bool sendText(
    String content, {
    String? conversationId,
    String? clientRequestId,
    bool ttsEnabled = true,
  }) {
    normalTurns.add(content);
    return true;
  }

  void emitStatus(String status) {
    waitingStatus = status;
    _messages.add(
      ws.TurnAcceptedMessage(
        clientRequestId: 'request-waiting',
        turnId: 'turn-waiting',
        conversationId: 'conv-waiting',
        persisted: true,
        status: status,
      ),
    );
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
    super.dispose();
  }
}

Map<String, dynamic> _turnFrame(
  String type,
  int sequence, {
  String status = '',
  bool terminal = false,
  bool recovered = false,
  String content = '',
}) => <String, dynamic>{
  'type': type,
  'conversation_id': 'conv-recovered',
  'request_id': 'request-recovered',
  'client_request_id': 'request-recovered',
  'turn_id': 'turn-recovered',
  'message_id': type == 'turn_accepted'
      ? 'message-user-recovered'
      : 'message-assistant-recovered',
  'event_id': 'event-$sequence',
  'event_type': type,
  'sequence': sequence,
  'terminal': terminal,
  if (status.isNotEmpty) 'status': status,
  if (recovered) 'recovered': true,
  if (content.isNotEmpty) 'content': content,
};

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'osia_token': 'token',
    });
  });

  test(
    'recovered waiting turn rebinds and one terminal final clears it',
    () async {
      final sent = <Map<String, dynamic>>[];
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
        lanDirectV1: true,
        webRtcDirectV1: false,
        sendFrameForTest: (frame) {
          sent.add(frame);
          return true;
        },
      );
      final events = <ws.ConvStreamEvent>[];
      final subscription = service.convStreamStream.listen(events.add);

      service.handleIncomingFrameForTest(
        _turnFrame('turn_accepted', 1, recovered: true),
      );
      service.handleIncomingFrameForTest(
        _turnFrame(
          'turn_status',
          2,
          status: 'waiting_verification',
          recovered: true,
        ),
      );
      service.handleIncomingFrameForTest(<String, dynamic>{
        ..._turnFrame('conversation_busy_changed', 3, recovered: true),
        'busy': true,
      });

      expect(service.isConversationWaiting('conv-recovered'), isTrue);
      expect(service.isConversationBusy('conv-recovered'), isTrue);
      expect(
        service.isSamePendingRequest('conv-recovered', 'request-recovered'),
        isTrue,
      );
      expect(
        service.sendWaitingTurnCommand(
          'resume and verify the current action',
          conversationId: 'conv-recovered',
        ),
        isTrue,
      );
      expect(sent, hasLength(1));
      expect(sent.single['type'], 'text');
      expect(sent.single['waiting_turn_command'], isTrue);
      expect(sent.single['conversation_id'], 'conv-recovered');
      expect(sent.single['request_id'], isNot('request-recovered'));
      expect(
        service.isSamePendingRequest('conv-recovered', 'request-recovered'),
        isTrue,
        reason: 'the bounded command must not replace the suspended turn id',
      );

      service.handleIncomingFrameForTest(
        _turnFrame('response', 4, content: 'One canonical final.'),
      );
      final terminal = _turnFrame(
        'turn_status',
        5,
        status: 'done',
        terminal: true,
      );
      service.handleIncomingFrameForTest(terminal);
      service.handleIncomingFrameForTest(terminal);
      await Future<void>.delayed(Duration.zero);

      expect(service.bufferedText('conv-recovered'), 'One canonical final.');
      expect(events.where((event) => event.done), hasLength(1));
      expect(service.isConversationWaiting('conv-recovered'), isFalse);
      service.handleIncomingFrameForTest(<String, dynamic>{
        ..._turnFrame('media_status', 6),
        'media_terminal': true,
      });
      expect(service.isConversationBusy('conv-recovered'), isFalse);

      await subscription.cancel();
      service.dispose();
    },
  );

  testWidgets(
    'waiting composer stays available and routes French English and unrelated commands',
    (tester) async {
      final storage = StorageService();
      final service = _WaitingWebSocketService();
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
            strings: osiaStringsFr,
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
                        id: 'conv-waiting',
                        title: 'Waiting test',
                      ),
                    ]),
                    ws.ActiveConversationMessage(
                      id: 'conv-waiting',
                      title: 'Waiting test',
                    ),
                    ws.ConversationHistoryMessage(
                      id: 'conv-waiting',
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
      service.emitStatus('waiting_verification');
      await tester.pump();

      final input = find.byType(TextField);
      expect(input, findsOneWidget);
      expect(
        find.text('En attente de vérification — reprends, statut ou annuler…'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      service.emitStatus('action_starting');
      await tester.pump();
      expect(find.text('Démarrage de l’action…'), findsOneWidget);
      service.emitStatus('blocked_unknown_effect');
      await tester.pump();
      expect(
        find.text(
          'Résultat impossible à établir — l’action n’a pas été répétée.',
        ),
        findsOneWidget,
      );
      service.emitStatus('waiting_verification');
      await tester.pump();

      for (final command in <String>[
        'reprends et vérifie',
        'resume and verify the current action',
        'ouvre une nouvelle recette',
      ]) {
        await tester.enterText(input, command);
        await tester.pump();
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pump();
      }

      expect(service.waitingCommands, <String>[
        'reprends et vérifie',
        'resume and verify the current action',
        'ouvre une nouvelle recette',
      ]);
      expect(service.normalTurns, isEmpty);
      await tester.pump(const Duration(minutes: 6));
      expect(find.text("OSIA didn't respond."), findsNothing);
      expect(find.text('Retry'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      themeController.dispose();
      languageController.dispose();
    },
  );

  test('busy pre-dispatch turn accepts only a bounded cancel command', () {
    final sent = <Map<String, dynamic>>[];
    final service = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
      lanDirectV1: true,
      webRtcDirectV1: false,
      sendFrameForTest: (frame) {
        sent.add(frame);
        return true;
      },
    );
    addTearDown(service.dispose);

    expect(
      service.sendText(
        'original request',
        conversationId: 'conv-recovered',
        clientRequestId: 'request-recovered',
      ),
      isTrue,
    );
    service.handleIncomingFrameForTest(
      _turnFrame('turn_accepted', 1, status: 'working'),
    );
    service.handleIncomingFrameForTest(<String, dynamic>{
      ..._turnFrame('conversation_busy_changed', 2),
      'busy': false,
    });

    expect(service.isConversationBusy('conv-recovered'), isFalse);
    expect(service.isConversationWaiting('conv-recovered'), isFalse);
    expect(
      service.sendWaitingTurnCommand(
        'status',
        conversationId: 'conv-recovered',
      ),
      isFalse,
    );
    expect(
      service.sendWaitingTurnCommand(
        'cancel',
        conversationId: 'conv-recovered',
        allowPreDispatchCancel: true,
      ),
      isTrue,
    );
    expect(sent, hasLength(2));
    expect(sent.last['content'], 'cancel');
    expect(sent.last['waiting_turn_command'], isTrue);
  });

  testWidgets('busy composer sends cancel before an attempt exists', (
    tester,
  ) async {
    final storage = StorageService();
    final service = _WaitingWebSocketService()
      ..waiting = false
      ..busy = true;
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
                    ws.Conversation(id: 'conv-waiting', title: 'Busy test'),
                  ]),
                  ws.ActiveConversationMessage(
                    id: 'conv-waiting',
                    title: 'Busy test',
                  ),
                  ws.ConversationHistoryMessage(
                    id: 'conv-waiting',
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
    expect(input, findsOneWidget);
    expect(
      find.text('OSIA is working â€” type cancel before the action startsâ€¦'),
      findsOneWidget,
    );
    await tester.enterText(input, 'cancel');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();

    expect(service.waitingCommands, <String>['cancel']);
    expect(service.normalTurns, isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    themeController.dispose();
    languageController.dispose();
  });

  test('relay channel close preserves an active direct transport lease', () {
    final direct = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
    );
    final competing = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'token',
      autoReconnect: false,
    );
    addTearDown(direct.dispose);
    addTearDown(competing.dispose);

    expect(
      direct.acquireApplicationTransportForTest(ApplicationTransportKind.lan),
      isTrue,
    );
    direct.markDirectTransportConnectedForTest(ApplicationTransportKind.lan);

    direct.handleChannelDoneForTest();

    expect(direct.state, ws.ConnectionState.connected);
    expect(
      applicationTransportCoordinator.activeKind,
      ApplicationTransportKind.lan,
    );
    expect(
      competing.acquireApplicationTransportForTest(
        ApplicationTransportKind.relay,
      ),
      isFalse,
    );
  });
}
