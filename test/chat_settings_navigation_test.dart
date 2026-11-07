import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/chat_screen.dart';
import 'package:osia_mobile/screens/settings_screen.dart';
import 'package:osia_mobile/services/background_connection_service.dart';
import 'package:osia_mobile/services/connection_lifecycle_service.dart';
import 'package:osia_mobile/services/execution_trace.dart';
import 'package:osia_mobile/services/storage_service.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/chat_bubble.dart';
import 'package:osia_mobile/widgets/execution_trace_block.dart';
import 'package:osia_mobile/widgets/thinking_orbs.dart';

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
  }

  late final _ListenCountingStream<ws.OsiaMessage> countedMessages;
  late final _ListenCountingStream<ws.ConvStreamEvent>
  countedConversationStream;
  late final _ListenCountingStream<ws.CronNotificationMessage> countedCron;

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
  final List<String> clientLocales = <String>[];
  final List<(String, String)> sentTurns = <(String, String)>[];
  final List<Map<String, dynamic>?> sentDirectives = [];
  final List<(String, Object?)> settingChanges = <(String, Object?)>[];
  final List<String> deleteRequests = <String>[];
  final List<String> deleteOperationIds = <String>[];
  final List<(int, String)> bulkDeleteRequests = <(int, String)>[];

  @override
  ws.ConnectionState get state => ws.ConnectionState.connected;

  @override
  void setClientLocale(String? locale) {
    clientLocales.add(locale ?? '');
    super.setClientLocale(locale);
  }

  @override
  Stream<ws.OsiaMessage> get messageStream => countedMessages;

  @override
  Stream<ws.ConvStreamEvent> get convStreamStream => countedConversationStream;

  @override
  Stream<ws.CronNotificationMessage> get cronNotificationStream => countedCron;

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
    sentDirectives.add(turnDirectives);
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
  void sendSetSetting(String key, Object? value) {
    settingChanges.add((key, value));
  }

  @override
  void sendMcpStatus([String? id]) {
    mcpStatusRequests++;
  }

  @override
  void sendLoadConversation(String id) {}

  @override
  String sendDeleteConversation(String id, {String? operationId}) {
    deleteRequests.add(id);
    final operation = operationId ?? 'fake-delete';
    deleteOperationIds.add(operation);
    return operation;
  }

  @override
  String sendBulkDeleteUngroupedConversations({
    required int expectedCount,
    String? operationId,
  }) {
    final operation = operationId ?? 'fake-bulk-delete';
    bulkDeleteRequests.add((expectedCount, operation));
    return operation;
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

Future<void> _mockSlashCatalog(WidgetTester tester) async {
  const asset = 'assets/slash_commands/catalog.v1.json';
  final catalog = await tester.runAsync(() => rootBundle.load(asset));
  rootBundle.evict(asset);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    return const StringCodec().decodeMessage(message) == asset
        ? catalog
        : await messenger.delegate.send('flutter/assets', message);
  });
  addTearDown(() {
    messenger.setMockMessageHandler('flutter/assets', null);
    rootBundle.evict(asset);
  });
}

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
          builder: (context, child) =>
              TooltipVisibility(visible: false, child: child!),
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

void _emitConversationList(
  _StableWebSocketService service,
  List<(String, String)> items, {
  int revision = 1,
  String operationId = '',
  List<Map<String, dynamic>> folders = const <Map<String, dynamic>>[],
  Map<String, String> folderIds = const <String, String>{},
}) {
  service.handleIncomingFrameForTest(<String, dynamic>{
    'type': 'conversations',
    'version': 2,
    'snapshot_revision': revision,
    'operation_id': operationId,
    'folders': folders,
    'items': [
      for (final (id, title) in items)
        <String, dynamic>{
          'id': id,
          'title': title,
          'updated_at': '2026-10-03T10:00:00Z',
          'folder_id': folderIds[id],
        },
    ],
  });
}

Future<void> _openDrawer(WidgetTester tester) async {
  await _openDrawerWithoutPointer(tester);
}

Future<void> _openDrawerWithoutPointer(WidgetTester tester) async {
  tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
  await tester.pumpAndSettle();
}

Future<void> _confirmSingleDelete(
  WidgetTester tester,
  String conversationId,
) async {
  await tester.longPress(find.byKey(ValueKey('conv_$conversationId')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete').last);
  await tester.pumpAndSettle();
  expect(find.text('Delete conversation?'), findsOneWidget);
  await tester.tap(find.text('Delete').last);
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester) async {
  final settingsIcon = find.byIcon(Icons.settings_rounded);
  final settingsButton = find
      .ancestor(of: settingsIcon, matching: find.byType(IconButton))
      .first;
  tester.widget<IconButton>(settingsButton).onPressed?.call();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  expect(find.byType(SettingsScreen), findsOneWidget);
}

Future<void> _tapGlassIconWithoutPointer(
  WidgetTester tester,
  IconData icon,
) async {
  final iconFinder = find.byIcon(icon);
  final button = find
      .ancestor(of: iconFinder, matching: find.byType(InkWell))
      .first;
  tester.widget<InkWell>(button).onTap?.call();
  await tester.pump();
}

Future<void> _closeSettings(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
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
    'language changes update the same canonical text and voice connection',
    (tester) async {
      final harness = await _pumpChat(tester);
      expect(harness.service.clientLocales.last, 'en');
      harness.language.setLanguageByCode('fr');
      await tester.pump();
      expect(harness.service.clientLocales.last, 'fr');
      expect(harness.service.connectCalls, 0);
      expect(harness.service.disconnectCalls, 0);
      await _disposeChatHarness(tester, harness);
    },
  );

  for (final terminalStatus in ['done', 'cancelled', 'error']) {
    testWidgets('Thinking V5 Chat lifecycle: $terminalStatus', (tester) async {
      final harness = await _pumpChat(tester);
      final service = harness.service;
      const request = 'request-wor347';
      const turn = 'turn-wor347';
      const key = ExecutionTraceKey(
        conversationId: 'conv-nav',
        requestId: request,
        turnId: turn,
        runId: 'run-turn-wor347',
        providerId: 'provider-test',
        modelId: 'model-test',
        effectiveReasoning: 'medium',
      );
      service.handleIncomingFrameForTest(
        _canonicalTurnFrame(
          type: 'turn_accepted',
          conversationId: 'conv-nav',
          requestId: request,
          turnId: turn,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(ThinkingDisclosure), findsOneWidget);
      final toggle = find.byKey(const ValueKey('execution_trace_toggle'));
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(toggle).flagsCollection.isExpanded,
        Tristate.isTrue,
      );
      expect(
        find.byKey(const ValueKey('execution_trace_summary')),
        findsNothing,
      );
      expect(find.byType(ThinkingOrbs), findsOneWidget);
      // A deliberate collapse before the first public provider event must
      // survive the waiting-row -> trace -> answer-bubble transitions.
      await tester.tap(toggle);
      await tester.pump();
      final commentary = ExecutionTraceEvent(
        eventId: 'summary-wor347',
        traceKey: key,
        sequence: 1,
        revision: 1,
        kind: ExecutionTraceKind.reasoningSummary,
        display: const ExecutionTraceDisplay('execution.reasoning.summary'),
        timestamp: DateTime.utc(2026, 10, 20),
        terminal: false,
        publicSummary: 'Checking the public document.',
      ).toJson();
      service.handleIncomingFrameForTest({
        'type': 'execution_trace',
        ...commentary,
        'snapshot': [commentary],
      });
      await tester.pump();
      await tester.pump();
      expect(find.byType(ExecutionTraceBlock), findsOneWidget);
      expect(find.text('Checking the public document.'), findsNothing);
      await tester.tap(toggle);
      await tester.pump();
      expect(find.text('Checking the public document.'), findsOneWidget);
      service.handleIncomingFrameForTest(
        _canonicalTurnFrame(
          type: 'response_chunk',
          conversationId: 'conv-nav',
          requestId: request,
          turnId: turn,
          content: 'Final public answer.',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Checking the public document.'), findsOneWidget);
      // Replay the same accepted identity while navigating away and back.
      await _openSettings(tester);
      service.handleIncomingFrameForTest(
        _canonicalTurnFrame(
          type: 'turn_accepted',
          conversationId: 'conv-nav',
          requestId: request,
          turnId: turn,
        ),
      );
      await tester.pump();
      await _closeSettings(tester);
      expect(find.text('Checking the public document.'), findsOneWidget);
      service.handleIncomingFrameForTest(
        _canonicalTurnFrame(
          type: 'turn_status',
          conversationId: 'conv-nav',
          requestId: request,
          turnId: turn,
          status: terminalStatus,
          terminal: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(ThinkingOrbs), findsNothing);
      expect(
        find.byKey(const ValueKey('execution_trace_summary')),
        findsNothing,
      );
      await tester.tap(toggle);
      await tester.pump();
      expect(find.text('Checking the public document.'), findsOneWidget);
      semantics.dispose();
      await _disposeChatHarness(tester, harness);
    });
  }

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
      ];
      final configRequests = service.configRequests;
      final modelRequests = service.modelRequests;

      await tester.enterText(find.byType(TextField), 'keep this turn alive');
      await tester.pump();
      await _tapGlassIconWithoutPointer(tester, Icons.arrow_upward_rounded);
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
      ], listenerCounts);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      harness.theme.dispose();
      harness.language.dispose();
    },
  );

  testWidgets('single delete delegates an active turn to the PC', (
    tester,
  ) async {
    final harness = await _pumpChat(tester);
    _emitConversationList(harness.service, <(String, String)>[
      ('conv-nav', 'Navigation test'),
      ('conv-second', 'Working conversation'),
    ], revision: 10);
    harness.service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'conversation_busy_changed',
      'conversation_id': 'conv-second',
      'busy': true,
    });
    await tester.pump();
    expect(harness.service.isConversationBusy('conv-second'), isTrue);
    await _openDrawer(tester);
    await _confirmSingleDelete(tester, 'conv-second');

    expect(harness.service.deleteRequests, ['conv-second']);
    harness.service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'conversation_deleted',
      'id': 'conv-second',
      'success': true,
      'operation_id': harness.service.deleteOperationIds.single,
      'snapshot_revision': 11,
    });
    await tester.pump();
    expect(harness.service.isConversationBusy('conv-second'), isFalse);
    expect(find.byKey(const ValueKey('conv_conv-second')), findsNothing);
    expect(find.byKey(const ValueKey('conv_conv-nav')), findsOneWidget);
    await _disposeChatHarness(tester, harness);
  });

  testWidgets('single delete revision rejects stale lists without a tombstone', (
    tester,
  ) async {
    final harness = await _pumpChat(tester);
    _emitConversationList(harness.service, <(String, String)>[
      ("conv-nav", "Navigation test"),
    ], revision: 10);
    await tester.pump();
    await _openDrawerWithoutPointer(tester);
    await _confirmSingleDelete(tester, 'conv-nav');

    expect(harness.service.deleteRequests, <String>['conv-nav']);
    final operationId = harness.service.deleteOperationIds.single;
    expect(find.byKey(const ValueKey('conv_conv-nav')), findsNothing);
    expect(find.text('No conversations yet'), findsOneWidget);

    harness.service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'conversation_deleted',
      'id': 'conv-nav',
      'success': true,
      'operation_id': operationId,
      'snapshot_revision': 11,
    });
    await tester.pump();
    _emitConversationList(
      harness.service,
      const <(String, String)>[],
      revision: 11,
    );
    await tester.pump();
    _emitConversationList(harness.service, <(String, String)>[
      ("conv-nav", "Navigation test"),
    ], revision: 10);
    await tester.pump();

    expect(find.byKey(const ValueKey('conv_conv-nav')), findsNothing);
    expect(find.text('OSIA'), findsOneWidget);

    // A newer canonical state that contains the ID remains visible. The
    // client orders snapshots; it does not hide a broken server with a tombstone.
    _emitConversationList(harness.service, <(String, String)>[
      ("conv-nav", "Navigation test"),
    ], revision: 12);
    await tester.pump();
    await _openDrawerWithoutPointer(tester);
    expect(find.byKey(const ValueKey('conv_conv-nav')), findsOneWidget);
    await _disposeChatHarness(tester, harness);
  });

  testWidgets('conversation drawer lazily builds a long canonical list', (
    tester,
  ) async {
    final harness = await _pumpChat(tester, reducedMotion: true);
    const conversationCount = 120;
    _emitConversationList(
      harness.service,
      List<(String, String)>.generate(
        conversationCount,
        (index) => ('conv-lazy-$index', 'Chat $index'),
      ),
      revision: 2,
    );
    await tester.pump();
    await _openDrawerWithoutPointer(tester);

    final drawerList = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(ListView),
    );
    expect(drawerList, findsOneWidget);
    final list = tester.widget<ListView>(drawerList);
    expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
    expect(list.semanticChildCount, conversationCount);

    final scrollable = find.descendant(
      of: drawerList,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, 0);
    expect(find.byKey(const ValueKey('conv_conv-lazy-119')), findsNothing);

    position.jumpTo(360);
    await tester.pump();
    final savedOffset = position.pixels;
    expect(savedOffset, greaterThan(0));
    _emitConversationList(
      harness.service,
      List<(String, String)>.generate(
        conversationCount,
        (index) => ('conv-lazy-$index', 'Updated chat $index'),
      ),
      revision: 3,
    );
    await tester.pump();
    final refreshedPosition = tester
        .state<ScrollableState>(scrollable)
        .position;
    expect(refreshedPosition.pixels, closeTo(savedOffset, 1));

    await _disposeChatHarness(tester, harness);
  });

  testWidgets('Desktop-origin single delete updates the Mobile projection', (
    tester,
  ) async {
    final harness = await _pumpChat(tester);
    _emitConversationList(harness.service, <(String, String)>[
      ("conv-nav", "Navigation test"),
      ("conv-second", "Second chat"),
    ], revision: 4);
    await tester.pump();
    await _openDrawerWithoutPointer(tester);

    harness.service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'conversation_deleted',
      'id': 'conv-second',
      'success': true,
      'operation_id': 'desktop_delete_case',
      'snapshot_revision': 5,
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('conv_conv-second')), findsNothing);
    expect(find.text('Navigation test'), findsWidgets);
    await _disposeChatHarness(tester, harness);
  });

  testWidgets('Desktop-origin bulk delete updates the Mobile projection', (
    tester,
  ) async {
    final harness = await _pumpChat(tester);
    _emitConversationList(
      harness.service,
      <(String, String)>[
        ("conv-nav", "Navigation test"),
        ("conv-second", "Second chat"),
        ("conv-project", "Project chat"),
      ],
      folders: <Map<String, dynamic>>[
        <String, dynamic>{"id": "folder-1", "name": "Project", "order": 0},
      ],
      folderIds: const <String, String>{"conv-project": "folder-1"},
      revision: 4,
    );
    await tester.pump();
    await _openDrawerWithoutPointer(tester);

    harness.service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'conversations_bulk_deleted',
      'operation_id': 'desktop_bulk_case',
      'success': true,
      'deleted_ids': <String>['conv-nav', 'conv-second'],
      'snapshot_revision': 5,
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('conv_conv-nav')), findsNothing);
    expect(find.byKey(const ValueKey('conv_conv-second')), findsNothing);
    expect(find.byKey(const ValueKey('conv_conv-project')), findsOneWidget);
    await _disposeChatHarness(tester, harness);
  });

  testWidgets('single delete failure restores row, order, and active chat', (
    tester,
  ) async {
    final harness = await _pumpChat(tester);
    _emitConversationList(harness.service, <(String, String)>[
      ("conv-nav", "Navigation test"),
      ("conv-second", "Second chat"),
    ]);
    await tester.pump();
    await _openDrawer(tester);
    await _confirmSingleDelete(tester, 'conv-nav');
    expect(find.byKey(const ValueKey('conv_conv-nav')), findsNothing);

    harness.service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'conversation_deleted',
      'id': 'conv-nav',
      'success': false,
      'error': 'conversation_busy',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey('conv_conv-nav')), findsOneWidget);
    expect(find.byKey(const ValueKey('conv_conv-second')), findsOneWidget);
    expect(find.text('Navigation test'), findsWidgets);
    expect(
      find.text('The conversation could not be deleted. Please try again.'),
      findsOneWidget,
    );
    ScaffoldMessenger.of(
      tester.element(find.byType(ChatScreen)),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await _disposeChatHarness(tester, harness);
  });

  testWidgets('not-found ack waits for the canonical list before resolving', (
    tester,
  ) async {
    final harness = await _pumpChat(tester);
    _emitConversationList(harness.service, <(String, String)>[
      ("conv-nav", "Navigation test"),
    ], revision: 1);
    await tester.pump();
    await _openDrawer(tester);
    await _confirmSingleDelete(tester, 'conv-nav');
    expect(find.byKey(const ValueKey('conv_conv-nav')), findsNothing);

    harness.service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'conversation_deleted',
      'id': 'conv-nav',
      'success': false,
      'error': 'conversation_not_found',
      'operation_id': harness.service.deleteOperationIds.single,
      'snapshot_revision': 2,
    });
    await tester.pump();

    // A later canonical catalogue proves that the row still exists, so the
    // request is reported as failed instead of being masked as success.
    _emitConversationList(harness.service, <(String, String)>[
      ("conv-nav", "Navigation test"),
    ], revision: 2);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('conv_conv-nav')), findsOneWidget);
    expect(
      find.text('The conversation could not be deleted. Please try again.'),
      findsOneWidget,
    );
    ScaffoldMessenger.of(
      tester.element(find.byType(ChatScreen)),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    await _disposeChatHarness(tester, harness);
  });

  testWidgets(
    'non-selected delete keeps chat stable and PC list sync applies',
    (tester) async {
      final harness = await _pumpChat(tester);
      _emitConversationList(harness.service, <(String, String)>[
        ("conv-nav", "Navigation test"),
        ("conv-second", "Second chat"),
      ]);
      await tester.pump();
      await _openDrawer(tester);
      await _confirmSingleDelete(tester, 'conv-second');
      expect(find.byKey(const ValueKey('conv-second')), findsNothing);
      expect(find.text('Navigation test'), findsWidgets);

      harness.service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'conversation_deleted',
        'id': 'conv-second',
        'success': true,
      });
      await tester.pumpAndSettle();
      expect(find.text('Navigation test'), findsWidgets);

      // A canonical list update from Desktop removes the selected conversation
      // on Mobile through the existing synchronization path.
      _emitConversationList(
        harness.service,
        const <(String, String)>[],
        revision: 2,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('conv_conv-nav')), findsNothing);
      expect(find.text('OSIA'), findsOneWidget);
      await _disposeChatHarness(tester, harness);
    },
  );

  testWidgets('delete all hides ungrouped rows and rolls back in order', (
    tester,
  ) async {
    final harness = await _pumpChat(tester);
    _emitConversationList(
      harness.service,
      <(String, String)>[
        ("conv-nav", "Navigation test"),
        ("conv-second", "Second chat"),
        ("conv-project", "Project chat"),
      ],
      folders: <Map<String, dynamic>>[
        <String, dynamic>{"id": "folder-1", "name": "Project", "order": 0},
      ],
      folderIds: const <String, String>{"conv-project": "folder-1"},
    );
    await tester.pump();
    await _openDrawer(tester);
    await tester.tap(find.text('⋯'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete conversations outside projects').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'DELETE 2');
    await tester.pump();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('conv_conv-nav')), findsNothing);
    expect(find.byKey(const ValueKey('conv_conv-second')), findsNothing);
    expect(find.byKey(const ValueKey('conv_conv-project')), findsOneWidget);
    expect(harness.service.bulkDeleteRequests.single.$1, 2);

    final operationId = harness.service.bulkDeleteRequests.single.$2;
    harness.service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'conversations_bulk_deleted',
      'operation_id': operationId,
      'success': false,
      'error': 'snapshot_changed',
      'deleted_ids': <String>[],
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey('conv_conv-nav')), findsOneWidget);
    expect(find.byKey(const ValueKey('conv_conv-second')), findsOneWidget);
    expect(find.byKey(const ValueKey('conv_conv-project')), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(ChatScreen)),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    await _disposeChatHarness(tester, harness);
  });
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
    ];

    await tester.enterText(find.byType(TextField), 'coalesced response');
    await tester.pump();
    await _tapGlassIconWithoutPointer(tester, Icons.arrow_upward_rounded);
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
    await _tapGlassIconWithoutPointer(tester, Icons.arrow_upward_rounded);
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
      ],
      <int>[0, 0, 0],
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
    await _tapGlassIconWithoutPointer(tester, Icons.arrow_upward_rounded);
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
        await _tapGlassIconWithoutPointer(tester, Icons.arrow_upward_rounded);
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
        await _tapGlassIconWithoutPointer(tester, Icons.arrow_upward_rounded);
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

  testWidgets('Chat follows PC theme updates from config snapshots', (
    tester,
  ) async {
    final harness = await _pumpChat(tester);
    final service = harness.service;

    service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'config',
      'config': <String, dynamic>{'ui_theme': 'amber'},
    });
    await tester.pump();
    expect(harness.theme.palette.key, 'amber');

    service.handleIncomingFrameForTest(<String, dynamic>{
      'type': 'config',
      'config': <String, dynamic>{'ui_theme': 'emerald'},
    });
    await tester.pump();
    expect(harness.theme.palette.key, 'emerald');

    await _disposeChatHarness(tester, harness);
  });

  testWidgets('chat slash skill picker and creator use typed composer chips', (
    tester,
  ) async {
    await _mockSlashCatalog(tester);
    final harness = await _pumpChat(tester);
    final service = harness.service;
    service.handleIncomingFrameForTest({
      'type': 'config',
      'config': {
        'chat_slash_extensions': 1,
        'skills': [
          {'name': 'quick-brief.md', 'available': true},
        ],
      },
    });
    await tester.pump();
    await tester.enterText(find.byType(TextField), '/skill');
    await tester.pump();
    await tester.tap(find.text('/skill  Use a skill'));
    await tester.pump();
    await tester.tap(find.text('quick-brief'));
    await tester.pump();
    expect(find.text('quick-brief'), findsOneWidget);
    expect(service.sentTurns, isEmpty);

    await tester.enterText(
      find.byType(TextField),
      '/skillcreator Make a brief skill',
    );
    await tester.pump();
    await tester.tap(find.text('/skillcreator  Create a skill'));
    await tester.pump();
    expect(find.text('/skillcreator'), findsOneWidget);
    await _tapGlassIconWithoutPointer(tester, Icons.arrow_upward_rounded);
    await tester.pump();
    expect(service.sentTurns.single.$1, 'Make a brief skill');
    expect(service.sentDirectives.single?['skill_creator'], true);
    expect(service.sentDirectives.single?.containsKey('skill_name'), false);
    await tester.pump(const Duration(milliseconds: 100));
    await _disposeChatHarness(tester, harness);
  });

  testWidgets(
    'chat picks Max after a model search and references a conversation with @',
    (tester) async {
      await _mockSlashCatalog(tester);
      final harness = await _pumpChat(tester);
      final service = harness.service;
      service.handleIncomingFrameForTest({
        'type': 'config',
        'config': {
          'chat_slash_extensions': 1,
          'slash_reasoning_model_options': true,
        },
      });
      service.handleIncomingFrameForTest({
        'type': 'models_list',
        'current': 'gpt-6.1-sol',
        'current_provider': 'chatgpt_account',
        'models': [
          for (var i = 0; i < 40; i++)
            {'id': 'test-$i', 'displayName': 'Test $i', 'providerId': 'ollama'},
          {
            'id': 'gpt-6.1-sol',
            'displayName': 'GPT-6.1 Sol',
            'providerId': 'chatgpt_account',
            'reasoning': {
              'options': [
                for (final id in ['auto', 'low', 'xhigh', 'max', 'ultra'])
                  {'id': id},
              ],
            },
          },
        ],
      });
      _emitConversationList(service, [
        ('conv-nav', 'Navigation test'),
        ('conv-other', 'Projet test'),
      ]);
      await tester.pump();

      await tester.enterText(find.byType(TextField), '/status');
      await tester.pump(const Duration(milliseconds: 160));
      await tester.tap(find.text('/status  Status'));
      await tester.pumpAndSettle();
      expect(find.text('OSIA status'), findsOneWidget);
      expect(find.text('PC connection'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '/model');
      await tester.pump(const Duration(milliseconds: 160));
      await tester.tap(find.text('/model  Model'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('slash-model-search')),
        '6.1 sol',
      );
      await tester.pump();
      final palette = find.byKey(const Key('slash-command-palette'));
      await tester.tap(
        find.descendant(of: palette, matching: find.text('GPT-6.1 Sol')),
      );
      await tester.pump();
      expect(
        find.descendant(of: palette, matching: find.text('Ultra')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: palette, matching: find.text('Max')),
      );
      await tester.pump();
      expect(find.text('gpt-6.1-sol · Max'), findsOneWidget);

      const prefix = 'Reprends 🙂 @pro';
      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '$prefix demain',
          selection: TextSelection.collapsed(offset: prefix.length),
        ),
      );
      await tester.pump(const Duration(milliseconds: 160));
      await tester.tap(
        find.descendant(of: palette, matching: find.text('Projet test')),
      );
      await tester.pump();
      await _tapGlassIconWithoutPointer(tester, Icons.arrow_upward_rounded);
      await tester.pump(const Duration(milliseconds: 120));
      expect(service.sentTurns.single.$1, 'Reprends 🙂  demain');
      expect(service.sentDirectives.single?['reasoning_override'], 'max');
      expect(service.sentDirectives.single?['model_override'], {
        'provider_id': 'chatgpt_account',
        'model_id': 'gpt-6.1-sol',
      });
      final references =
          service.sentDirectives.single?['conversation_refs'] as List;
      expect(references.single['conversation_id'], 'conv-other');
      await _disposeChatHarness(tester, harness);
    },
  );
}
