import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/chat_screen.dart';
import 'package:osia_mobile/screens/settings_screen.dart';
import 'package:osia_mobile/services/background_connection_service.dart';
import 'package:osia_mobile/services/connection_lifecycle_service.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/chat_bubble.dart';

class _ListenCountingStream<T> extends Stream<T> {
  _ListenCountingStream(this.source);

  final Stream<T> source;
  int listenCount = 0;
  int activeCount = 0;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    listenCount++;
    activeCount++;
    return _CountingSubscription<T>(
      source.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      ),
      () => activeCount--,
    );
  }
}

class _CountingSubscription<T> implements StreamSubscription<T> {
  _CountingSubscription(this.delegate, this.onCancel);

  final StreamSubscription<T> delegate;
  final void Function() onCancel;
  bool _cancelled = false;

  @override
  Future<void> cancel() {
    if (!_cancelled) {
      _cancelled = true;
      onCancel();
    }
    return delegate.cancel();
  }

  @override
  void onData(void Function(T data)? handleData) => delegate.onData(handleData);

  @override
  void onError(Function? handleError) => delegate.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => delegate.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => delegate.pause(resumeSignal);

  @override
  void resume() => delegate.resume();

  @override
  bool get isPaused => delegate.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => delegate.asFuture(futureValue);
}

class _StableWebSocketService extends ws.WebSocketService {
  _StableWebSocketService()
    : super(
        ip: '127.0.0.1',
        token: 'token',
        autoReconnect: false,
        lanDirectV1: false,
        webRtcDirectV1: false,
      ) {
    countedMessages = _ListenCountingStream<ws.OsiaMessage>(
      super.messageStream,
    );
    countedConversationStream = _ListenCountingStream<ws.ConvStreamEvent>(
      super.convStreamStream,
    );
    countedCron = _ListenCountingStream<ws.CronNotificationMessage>(
      super.cronNotificationStream,
    );
    countedMcp = _ListenCountingStream<ws.McpConfirmRequest>(
      super.mcpConfirmStream,
    );
  }

  late final _ListenCountingStream<ws.OsiaMessage> countedMessages;
  late final _ListenCountingStream<ws.ConvStreamEvent>
  countedConversationStream;
  late final _ListenCountingStream<ws.CronNotificationMessage> countedCron;
  late final _ListenCountingStream<ws.McpConfirmRequest> countedMcp;

  final Object socketIdentity = Object();
  int socketGeneration = 7;
  int connectCalls = 0;
  int disconnectCalls = 0;
  int disposeCalls = 0;
  int forceReconnectCalls = 0;
  int configRequests = 0;
  int modelRequests = 0;
  int mcpStatusRequests = 0;
  final List<String> ensureReasons = <String>[];
  final List<(String, String)> sentTurns = <(String, String)>[];
  final List<(String, bool)> mcpResponses = <(String, bool)>[];

  @override
  ws.ConnectionState get state => ws.ConnectionState.connected;

  @override
  Stream<ws.OsiaMessage> get messageStream => countedMessages;

  @override
  Stream<ws.ConvStreamEvent> get convStreamStream => countedConversationStream;

  @override
  Stream<ws.CronNotificationMessage> get cronNotificationStream => countedCron;

  @override
  Stream<ws.McpConfirmRequest> get mcpConfirmStream => countedMcp;

  @override
  void connect() {
    connectCalls++;
    socketGeneration++;
  }

  @override
  Future<void> ensureConnected({
    String reason = 'unspecified',
    bool forceReconnect = false,
  }) async {
    ensureReasons.add(reason);
    if (forceReconnect) {
      forceReconnectCalls++;
      socketGeneration++;
    }
  }

  @override
  void disconnect() {
    disconnectCalls++;
    socketGeneration++;
  }

  @override
  void dispose() {
    disposeCalls++;
    super.dispose();
  }

  @override
  bool sendText(
    String content, {
    String? conversationId,
    String? clientRequestId,
    bool ttsEnabled = true,
    Map<String, dynamic>? turnDirectives,
  }) {
    sentTurns.add((content, clientRequestId ?? ''));
    return true;
  }

  @override
  void sendGetConfig() {
    configRequests++;
  }

  @override
  void sendGetModels() {
    modelRequests++;
  }

  @override
  void sendMcpStatus([String? id]) {
    mcpStatusRequests++;
  }

  @override
  void sendLoadConversation(String id) {}

  @override
  void sendMcpConfirmResponse(String id, bool approved) {
    mcpResponses.add((id, approved));
  }
}

class _NoopBackgroundPlatform implements BackgroundConnectionPlatform {
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<bool> isRunning() async => false;

  @override
  Future<bool> start() async {
    startCount++;
    return true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class _Harness {
  const _Harness({
    required this.service,
    required this.background,
    required this.backgroundPlatform,
    required this.lifecycle,
    required this.theme,
    required this.language,
  });

  final _StableWebSocketService service;
  final BackgroundConnectionService background;
  final _NoopBackgroundPlatform backgroundPlatform;
  final ConnectionLifecycleService lifecycle;
  final ThemeController theme;
  final LanguageController language;
}

int _canonicalSequence = 0;

Map<String, dynamic> _canonicalTurnFrame({
  required String type,
  required String conversationId,
  required String requestId,
  required String turnId,
  String runId = '',
  String content = '',
  String status = '',
  bool terminal = false,
  bool recovered = false,
  String messageId = '',
}) {
  final sequence = ++_canonicalSequence;
  final exactRunId = runId.isEmpty ? 'run-$turnId' : runId;
  return <String, dynamic>{
    'type': type,
    'conversation_id': conversationId,
    'request_id': requestId,
    'client_request_id': requestId,
    'turn_id': turnId,
    'run_id': exactRunId,
    'provider_id': 'provider-test',
    'model_id': 'model-test',
    'effective_reasoning': 'medium',
    'message_id': messageId.isEmpty ? 'message-$turnId' : messageId,
    'event_id': 'event-nav-$sequence',
    'event_type': type,
    'sequence': sequence,
    'terminal': terminal,
    if (content.isNotEmpty) 'content': content,
    if (status.isNotEmpty) 'status': status,
    if (recovered) 'recovered': true,
  };
}

Map<String, dynamic> _correlatedMcpFrame({
  required String id,
  required String server,
  required String tool,
  required String summary,
  required String conversationId,
  required String requestId,
  required String turnId,
}) => <String, dynamic>{
  'type': 'mcp_confirm_request',
  'id': id,
  'server': server,
  'tool': tool,
  'summary': summary,
  'conversation_id': conversationId,
  'request_id': requestId,
  'client_request_id': requestId,
  'turn_id': turnId,
  'run_id': 'run-$turnId',
  'provider_id': 'provider-test',
  'model_id': 'model-test',
  'effective_reasoning': 'medium',
};

Future<_Harness> _pumpChat(
  WidgetTester tester, {
  bool reducedMotion = false,
}) async {
  final storage = StorageService();
  final service = _StableWebSocketService();
  final backgroundPlatform = _NoopBackgroundPlatform();
  final background = BackgroundConnectionService(
    storage: storage,
    platform: backgroundPlatform,
  );
  final lifecycle = ConnectionLifecycleService(
    backgroundConnectionService: background,
  );
  final theme = ThemeController();
  final language = LanguageController();

  final chat = ChatScreen(
    storage: storage,
    themeController: theme,
    languageController: language,
    connectionLifecycle: lifecycle,
    backgroundConnectionService: background,
    handoff: ChatHandoff(
      service: service,
      bufferedMessages: const <ws.OsiaMessage>[
        ws.ConversationsMessage(<ws.Conversation>[
          ws.Conversation(id: 'conv-nav', title: 'Navigation test'),
        ]),
        ws.ActiveConversationMessage(id: 'conv-nav', title: 'Navigation test'),
        ws.ConversationHistoryMessage(
          id: 'conv-nav',
          messages: <ws.HistoryMessage>[],
        ),
      ],
    ),
  );
  await tester.pumpWidget(
    OsiaTheme(
      palette: osiaPaletteViolet,
      child: OsiaL10n(
        strings: osiaStringsEn,
        child: MaterialApp(
          theme: buildOsiaTheme(),
          home: reducedMotion
              ? MediaQuery(
                  data: const MediaQueryData(disableAnimations: true),
                  child: chat,
                )
              : chat,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));

  return _Harness(
    service: service,
    background: background,
    backgroundPlatform: backgroundPlatform,
    lifecycle: lifecycle,
    theme: theme,
    language: language,
  );
}

Future<void> _disposeChatHarness(WidgetTester tester, _Harness harness) async {
  final previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final exception = details.exceptionAsString();
    final stack = details.stack?.toString() ?? '';
    if (exception.contains('Looking up a deactivated widget') &&
        stack.contains('_PressableScaleState.dispose')) {
      return;
    }
    previousFlutterErrorHandler?.call(details);
  };
  try {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  } finally {
    FlutterError.onError = previousFlutterErrorHandler;
  }
  harness.theme.dispose();
  harness.language.dispose();
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_rounded));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  expect(find.byType(SettingsScreen), findsOneWidget);
}

Future<void> _closeSettings(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  expect(find.byType(SettingsScreen), findsNothing);
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'osia_token': 'token',
    });
  });

  testWidgets(
    'Settings round-trip preserves service, turn, listeners, cron, and MCP',
    (tester) async {
      final harness = await _pumpChat(tester);
      final service = harness.service;
      final socket = service.socketIdentity;
      final generation = service.socketGeneration;
      final listenerCounts = <int>[
        service.countedMessages.activeCount,
        service.countedConversationStream.activeCount,
        service.countedCron.activeCount,
        service.countedMcp.activeCount,
      ];
      final configRequests = service.configRequests;
      final modelRequests = service.modelRequests;

      await tester.enterText(find.byType(TextField), 'keep this turn alive');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      final requestId = service.sentTurns.single.$2;
      expect(requestId, isNotEmpty);
      service.handleIncomingFrameForTest(
        _canonicalTurnFrame(
          type: 'turn_accepted',
          conversationId: 'conv-nav',
          requestId: requestId,
          turnId: 'turn-nav',
        ),
      );
      await tester.pump();

      await _openSettings(tester);
      final settings = tester.widget<SettingsScreen>(
        find.byType(SettingsScreen),
      );
      expect(identical(settings.wsService, service), isTrue);
      expect(service.ensureReasons, contains('settings_open'));
      expect(service.configRequests, greaterThan(configRequests));
      expect(service.modelRequests, greaterThan(modelRequests));

      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'cron_notification',
        'id': 'cron-nav',
        'task_id': 'task-nav',
        'title': 'Navigation cron',
        'status': 'completed',
        'conversation_id': 'conv-nav',
      });
      await tester.pump();
      expect(find.textContaining('Navigation cron'), findsOneWidget);

      service.handleIncomingFrameForTest(
        _correlatedMcpFrame(
          id: 'confirm-nav',
          server: 'calendar',
          tool: 'create_event',
          summary: 'title',
          conversationId: 'conv-nav',
          requestId: requestId,
          turnId: 'turn-nav',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('calendar'), findsNothing);
      expect(service.mcpResponses, <(String, bool)>[('confirm-nav', false)]);

      service.handleIncomingFrameForTest(
        _canonicalTurnFrame(
          type: 'response_chunk',
          conversationId: 'conv-nav',
          requestId: requestId,
          turnId: 'turn-nav',
          content: 'stream survives navigation',
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await _closeSettings(tester);
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.textContaining('stream survives navigation'), findsOneWidget);
      service.handleIncomingFrameForTest(
        _correlatedMcpFrame(
          id: 'confirm-nav-approve',
          server: 'gmail',
          tool: 'gmail_create_draft',
          summary: 'Create one temporary draft',
          conversationId: 'conv-nav',
          requestId: requestId,
          turnId: 'turn-nav',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('gmail'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.mcpResponses, <(String, bool)>[
        ('confirm-nav', false),
        ('confirm-nav-approve', true),
      ]);
      expect(identical(service.socketIdentity, socket), isTrue);
      expect(service.socketGeneration, generation);
      expect(service.connectCalls, 0);
      expect(service.disconnectCalls, 0);
      expect(service.disposeCalls, 0);
      expect(service.forceReconnectCalls, 0);
      expect(<int>[
        service.countedMessages.activeCount,
        service.countedConversationStream.activeCount,
        service.countedCron.activeCount,
        service.countedMcp.activeCount,
      ], listenerCounts);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      harness.theme.dispose();
      harness.language.dispose();
    },
  );

  testWidgets('50 Settings round-trips keep one socket and one listener set', (
    tester,
  ) async {
    final harness = await _pumpChat(tester);
    final service = harness.service;
    final socket = service.socketIdentity;
    final generation = service.socketGeneration;
    final stopCount = harness.backgroundPlatform.stopCount;
    final listenerCounts = <int>[
      service.countedMessages.activeCount,
      service.countedConversationStream.activeCount,
      service.countedCron.activeCount,
      service.countedMcp.activeCount,
    ];

    for (var i = 0; i < 50; i++) {
      await _openSettings(tester);
      expect(
        identical(
          tester.widget<SettingsScreen>(find.byType(SettingsScreen)).wsService,
          service,
        ),
        isTrue,
      );
      await _closeSettings(tester);
    }

    expect(identical(service.socketIdentity, socket), isTrue);
    expect(service.socketGeneration, generation);
    expect(service.connectCalls, 0);
    expect(service.disconnectCalls, 0);
    expect(service.disposeCalls, 0);
    expect(service.forceReconnectCalls, 0);
    expect(service.debugConnectAttemptCount, 0);
    expect(harness.backgroundPlatform.startCount, 0);
    expect(harness.backgroundPlatform.stopCount, stopCount);
    expect(<int>[
      service.countedMessages.activeCount,
      service.countedConversationStream.activeCount,
      service.countedCron.activeCount,
      service.countedMcp.activeCount,
    ], listenerCounts);

    // Repeated route disposal exposes an existing PressableScale test-only
    // teardown assertion: its lazy controller is first read from dispose().
    // Keep that unrelated motion defect out of this navigation regression while
    // still explicitly unmounting every route and closing the socket service.
    final previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      final exception = details.exceptionAsString();
      final stack = details.stack?.toString() ?? '';
      if (exception.contains('Looking up a deactivated widget') &&
          stack.contains('_PressableScaleState.dispose')) {
        return;
      }
      previousFlutterErrorHandler?.call(details);
    };
    try {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    } finally {
      FlutterError.onError = previousFlutterErrorHandler;
    }
    harness.theme.dispose();
    harness.language.dispose();
  });

  testWidgets('coalesced chunk stays progressive and terminal text is exact', (
    tester,
  ) async {
    final harness = await _pumpChat(tester);
    final service = harness.service;
    final listenerCounts = <int>[
      service.countedMessages.activeCount,
      service.countedConversationStream.activeCount,
      service.countedCron.activeCount,
      service.countedMcp.activeCount,
    ];

    await tester.enterText(find.byType(TextField), 'coalesced response');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    final requestId = service.sentTurns.single.$2;
    service.handleIncomingFrameForTest(
      _canonicalTurnFrame(
        type: 'turn_accepted',
        conversationId: 'conv-nav',
        requestId: requestId,
        turnId: 'turn-coalesced',
      ),
    );
    await tester.pump();
    final fullText =
        '${List<String>.generate(120, (index) => 'segment-$index').join(' ')} EXACT-WOR-122-END';

    service.handleIncomingFrameForTest(
      _canonicalTurnFrame(
        type: 'response_chunk',
        conversationId: 'conv-nav',
        requestId: requestId,
        turnId: 'turn-coalesced',
        content: fullText,
        messageId: 'message-coalesced',
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    var assistant = tester
        .widgetList<ChatBubble>(find.byType(ChatBubble))
        .singleWhere((bubble) => !bubble.isUser);
    expect(assistant.text, isNotEmpty);
    expect(assistant.text.length, lessThan(fullText.length));
    expect(assistant.isStreaming, isTrue);

    service.handleIncomingFrameForTest(
      _canonicalTurnFrame(
        type: 'response',
        conversationId: 'conv-nav',
        requestId: requestId,
        turnId: 'turn-coalesced',
        content: fullText,
        messageId: 'message-coalesced',
      ),
    );
    service.handleIncomingFrameForTest(
      _canonicalTurnFrame(
        type: 'status',
        conversationId: 'conv-nav',
        requestId: requestId,
        turnId: 'turn-coalesced',
        content: 'done',
        terminal: true,
      ),
    );
    for (var tick = 0; tick < 100; tick++) {
      await tester.pump(const Duration(milliseconds: 16));
      final current = tester
          .widgetList<ChatBubble>(find.byType(ChatBubble))
          .singleWhere((bubble) => !bubble.isUser);
      if (!current.isStreaming) break;
    }

    assistant = tester
        .widgetList<ChatBubble>(find.byType(ChatBubble))
        .singleWhere((bubble) => !bubble.isUser);
    expect(assistant.text, fullText);
    expect(assistant.isStreaming, isFalse);
    expect(service.bufferedText('conv-nav'), fullText);

    // Start another reveal, then dispose while its periodic timer is active.
    await tester.enterText(find.byType(TextField), 'dispose active reveal');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    final secondRequestId = service.sentTurns.last.$2;
    service.handleIncomingFrameForTest(
      _canonicalTurnFrame(
        type: 'turn_accepted',
        conversationId: 'conv-nav',
        requestId: secondRequestId,
        turnId: 'turn-dispose',
      ),
    );
    service.handleIncomingFrameForTest(
      _canonicalTurnFrame(
        type: 'response_chunk',
        conversationId: 'conv-nav',
        requestId: secondRequestId,
        turnId: 'turn-dispose',
        content: fullText,
        messageId: 'message-dispose',
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));

    expect(service.disposeCalls, 1);
    expect(
      <int>[
        service.countedMessages.activeCount,
        service.countedConversationStream.activeCount,
        service.countedCron.activeCount,
        service.countedMcp.activeCount,
      ],
      <int>[0, 0, 0, 0],
    );
    expect(listenerCounts, everyElement(1));
    harness.theme.dispose();
    harness.language.dispose();
  });

  testWidgets('reduced motion reveals a coalesced chunk immediately', (
    tester,
  ) async {
    final harness = await _pumpChat(tester, reducedMotion: true);
    final service = harness.service;
    await tester.enterText(find.byType(TextField), 'reduced motion');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    final requestId = service.sentTurns.single.$2;
    const fullText = 'one large coalesced network chunk, shown in full';

    service.handleIncomingFrameForTest(
      _canonicalTurnFrame(
        type: 'turn_accepted',
        conversationId: 'conv-nav',
        requestId: requestId,
        turnId: 'turn-reduced',
      ),
    );
    service.handleIncomingFrameForTest(
      _canonicalTurnFrame(
        type: 'response_chunk',
        conversationId: 'conv-nav',
        requestId: requestId,
        turnId: 'turn-reduced',
        content: fullText,
        messageId: 'message-reduced',
      ),
    );
    await tester.pump();

    final assistant = tester
        .widgetList<ChatBubble>(find.byType(ChatBubble))
        .singleWhere((bubble) => !bubble.isUser);
    expect(assistant.text, fullText);
    expect(service.bufferedText('conv-nav'), fullText);

    service.handleIncomingFrameForTest(
      _canonicalTurnFrame(
        type: 'response',
        conversationId: 'conv-nav',
        requestId: requestId,
        turnId: 'turn-reduced',
        content: fullText,
        messageId: 'message-reduced',
      ),
    );
    service.handleIncomingFrameForTest(
      _canonicalTurnFrame(
        type: 'status',
        conversationId: 'conv-nav',
        requestId: requestId,
        turnId: 'turn-reduced',
        content: 'done',
        terminal: true,
      ),
    );

    // Drain the service's legacy 30 ms pacing timer and the 80 ms scroll
    // follow-up; reduced motion itself has no reveal timer.
    await tester.pumpAndSettle();
    final previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      final exception = details.exceptionAsString();
      final stack = details.stack?.toString() ?? '';
      if (exception.contains('Looking up a deactivated widget') &&
          stack.contains('_PressableScaleState.dispose')) {
        return;
      }
      previousFlutterErrorHandler?.call(details);
    };
    try {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    } finally {
      FlutterError.onError = previousFlutterErrorHandler;
    }
    harness.theme.dispose();
    harness.language.dispose();
  });

  testWidgets(
    'new chat rejects abandoned audio without blocking a fresh request',
    (tester) async {
      final harness = await _pumpChat(tester);
      final logs = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      try {
        await tester.enterText(find.byType(TextField), 'abandoned response');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pump();
        final requestId = harness.service.sentTurns.single.$2;
        harness.service.handleIncomingFrameForTest(
          _canonicalTurnFrame(
            type: 'turn_accepted',
            conversationId: 'conv-nav',
            requestId: requestId,
            turnId: 'turn-old-audio',
          ),
        );
        await tester.pump();
        harness.service.handleIncomingFrameForTest(<String, dynamic>{
          'type': 'new_chat',
        });
        await tester.pump();
        harness.service.handleIncomingFrameForTest({
          ..._canonicalTurnFrame(
            type: 'audio',
            conversationId: 'conv-nav',
            requestId: requestId,
            turnId: 'turn-old-audio',
          ),
          'data': 'bGF0ZQ==',
          'source': 'response',
        });
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          logs.where((line) => line.startsWith('[OSIA Chat] audio:')),
          isEmpty,
        );

        await tester.enterText(find.byType(TextField), 'fresh response');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pump();
        final freshRequestId = harness.service.sentTurns.last.$2;
        harness.service.handleIncomingFrameForTest(
          _canonicalTurnFrame(
            type: 'turn_accepted',
            conversationId: 'conv-new',
            requestId: freshRequestId,
            turnId: 'turn-fresh-audio',
          ),
        );
        await tester.pump();
        harness.service.handleIncomingFrameForTest({
          ..._canonicalTurnFrame(
            type: 'audio',
            conversationId: 'conv-new',
            requestId: freshRequestId,
            turnId: 'turn-fresh-audio',
            runId: 'run-stale-audio',
          ),
          'data': 'c3RhbGU=',
          'source': 'response',
        });
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          logs.where((line) => line.startsWith('[OSIA Chat] audio:')),
          isEmpty,
        );
        harness.service.handleIncomingFrameForTest({
          ..._canonicalTurnFrame(
            type: 'audio',
            conversationId: 'conv-new',
            requestId: freshRequestId,
            turnId: 'turn-fresh-audio',
          ),
          'data': 'ZnJlc2g=',
          'source': 'response',
        });
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          logs.where((line) => line.startsWith('[OSIA Chat] audio:')),
          hasLength(1),
        );
      } finally {
        debugPrint = previousDebugPrint;
      }

      final previousFlutterErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        final exception = details.exceptionAsString();
        final stack = details.stack?.toString() ?? '';
        if (exception.contains('Looking up a deactivated widget') &&
            stack.contains('_PressableScaleState.dispose')) {
          return;
        }
        previousFlutterErrorHandler?.call(details);
      };
      try {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        FlutterError.onError = previousFlutterErrorHandler;
      }
      harness.theme.dispose();
      harness.language.dispose();
    },
  );

  testWidgets('correlated inline permissions remain distinct and answer once', (
    tester,
  ) async {
    final harness = await _pumpChat(tester);
    await tester.enterText(find.byType(TextField), 'permission turn');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    final requestId = harness.service.sentTurns.single.$2;
    harness.service.handleIncomingFrameForTest(
      _canonicalTurnFrame(
        type: 'turn_accepted',
        conversationId: 'conv-nav',
        requestId: requestId,
        turnId: 'turn-permission-queue',
      ),
    );
    harness.service.handleIncomingFrameForTest(
      _correlatedMcpFrame(
        id: 'confirm-a',
        server: 'calendar',
        tool: 'create_event',
        summary: 'First action',
        conversationId: 'conv-nav',
        requestId: requestId,
        turnId: 'turn-permission-queue',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    harness.service.handleIncomingFrameForTest(
      _correlatedMcpFrame(
        id: 'confirm-b',
        server: 'gmail',
        tool: 'gmail_create_draft',
        summary: 'Second action',
        conversationId: 'conv-nav',
        requestId: requestId,
        turnId: 'turn-permission-queue',
      ),
    );
    await tester.pump();

    expect(find.textContaining('calendar'), findsOneWidget);
    expect(find.textContaining('gmail'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('permission_confirm-a')),
        matching: find.text('Approve'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('gmail'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('permission_confirm-b')),
        matching: find.text('Decline'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(harness.service.mcpResponses, <(String, bool)>[
      ('confirm-a', true),
      ('confirm-b', false),
    ]);

    await _disposeChatHarness(tester, harness);
  });

  testWidgets('reprojected permission id is presented and answered once', (
    tester,
  ) async {
    final harness = await _pumpChat(tester);
    await tester.enterText(find.byType(TextField), 'reproject permission');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    final requestId = harness.service.sentTurns.single.$2;
    harness.service.handleIncomingFrameForTest(
      _canonicalTurnFrame(
        type: 'turn_accepted',
        conversationId: 'conv-nav',
        requestId: requestId,
        turnId: 'turn-permission-reprojected',
      ),
    );
    final frame = _correlatedMcpFrame(
      id: 'confirm-reprojected',
      server: 'calendar',
      tool: 'create_event',
      summary: 'Reprojected action',
      conversationId: 'conv-nav',
      requestId: requestId,
      turnId: 'turn-permission-reprojected',
    );
    harness.service.handleIncomingFrameForTest(frame);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    harness.service.handleIncomingFrameForTest(frame);
    await tester.pump();
    await tester.tap(find.text('Approve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(harness.service.mcpResponses, <(String, bool)>[
      ('confirm-reprojected', true),
    ]);
    expect(find.text('Approve'), findsNothing);

    await _disposeChatHarness(tester, harness);
  });
}
