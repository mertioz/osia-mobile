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
import 'package:osia_mobile/widgets/chat_bubble.dart';

const _id = 'context_compaction_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _original = <ws.HistoryMessage>[
  ws.HistoryMessage(
    role: 'user',
    content: 'Existing question',
    messageId: 'user-old',
  ),
  ws.HistoryMessage(
    role: 'assistant',
    content: 'Existing reply',
    messageId: 'reply-old',
  ),
];

ws.HistoryMessage _notice(String requestId) => ws.HistoryMessage(
  role: 'system',
  content: 'PRIVATE SYSTEM TEXT MUST NOT BE RENDERED',
  messageId: 'fixture-completed-notice',
  contextCompactionId: _id,
  contextCompactionState: 'completed',
  contextCompactionRequestId: requestId,
);

class _Service extends ws.WebSocketService {
  _Service()
    : super(ip: '127.0.0.1', token: 'fixture-token', autoReconnect: false);
  final _messages = StreamController<ws.OsiaMessage>.broadcast(sync: true);
  final compact = Completer<bool>();
  String? compactRequest;
  final sent = <String>[];
  @override
  Stream<ws.OsiaMessage> get messageStream => _messages.stream;
  @override
  ws.ConnectionState get state => ws.ConnectionState.connected;
  void emit(ws.OsiaMessage message) => _messages.add(message);
  @override
  void sendGetConfig() {}
  @override
  void sendGetModels() {}
  @override
  void sendLoadConversation(String id) {}
  @override
  Future<bool> compactConversationContext(String id, {String? operationId}) {
    compactRequest = operationId;
    return compact.future;
  }

  @override
  bool sendText(
    String content, {
    String? conversationId,
    String? clientRequestId,
    bool ttsEnabled = true,
    Map<String, dynamic>? turnDirectives,
  }) {
    sent.add(content);
    return true;
  }

  @override
  void dispose() {
    if (!_messages.isClosed) unawaited(_messages.close());
    super.dispose();
  }
}

class _Platform implements BackgroundConnectionPlatform {
  @override
  Future<bool> isRunning() async => false;
  @override
  Future<bool> start() async => true;
  @override
  Future<void> stop() async {}
}

Future<void> _host(WidgetTester tester, _Service service) async {
  final storage = StorageService();
  final theme = ThemeController();
  final language = LanguageController();
  final background = BackgroundConnectionService(
    storage: storage,
    platform: _Platform(),
  );
  final lifecycle = ConnectionLifecycleService(
    backgroundConnectionService: background,
  );
  await tester.pumpWidget(
    OsiaTheme(
      palette: osiaPaletteViolet,
      child: OsiaL10n(
        strings: osiaStringsEn,
        child: MaterialApp(
          theme: buildOsiaTheme(),
          home: ChatScreen(
            storage: storage,
            themeController: theme,
            languageController: language,
            connectionLifecycle: lifecycle,
            backgroundConnectionService: background,
            handoff: ChatHandoff(
              service: service,
              bufferedMessages: const [
                ws.ConversationsMessage([
                  ws.Conversation(id: 'a', title: 'Alpha conversation'),
                  ws.Conversation(id: 'b', title: 'Beta conversation'),
                ]),
                ws.ActiveConversationMessage(
                  id: 'a',
                  title: 'Alpha conversation',
                ),
                ws.ConversationHistoryMessage(
                  id: 'a',
                  messages: _original,
                  revision: 1,
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
  service.handleIncomingFrameForTest({
    'type': 'config',
    'config': {
      'conversation_context_compaction': true,
      'chat_slash_extensions': true,
    },
  });
  await tester.pump();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    theme.dispose();
    language.dispose();
  });
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'osia_token': 'fixture-token'});
  });
  test('compaction metadata validates the application marker', () {
    final legacy = ws.HistoryMessage.fromJson({
      'role': 'system',
      'content': 'private instructions',
    });
    expect(legacy.isContextCompactionNotice, isFalse);
    final parsed = ws.HistoryMessage.fromJson({
      'role': 'system',
      'content': 'Context compacted.',
      'context_compaction_state': 'completed',
      'context_compaction_id': _id,
      'context_compaction_request_id': 'compact_fixture',
    });
    expect(parsed.isContextCompactionNotice, isTrue);
    expect(parsed.contextCompactionRequestId, 'compact_fixture');
    expect(
      ws.HistoryMessage.fromJson({
        'role': 'assistant',
        'context_compaction_state': 'completed',
        'context_compaction_id': _id,
      }).isContextCompactionNotice,
      isFalse,
    );
  });

  test('wire progress and exact acknowledgement remain separate', () async {
    final frames = <Map<String, dynamic>>[];
    final service = ws.WebSocketService(
      ip: '127.0.0.1',
      token: 'fixture-token',
      autoReconnect: false,
      sendFrameForTest: (frame) {
        frames.add(frame);
        return true;
      },
    );
    addTearDown(service.dispose);
    final snapshots = <ws.ConversationHistoryMessage>[];
    final subscription = service.messageStream.listen((message) {
      if (message is ws.ConversationHistoryMessage) snapshots.add(message);
    });
    addTearDown(subscription.cancel);
    final result = service.compactConversationContext(
      'a',
      operationId: 'compact_fixture',
    );
    service.handleIncomingFrameForTest({
      'type': 'conversation_history',
      'id': 'a',
      'revision': 1,
      'context_compacting': true,
      'context_compaction_update': true,
      'messages': [],
    });
    await Future<void>.delayed(Duration.zero);
    expect(snapshots.single.contextCompacting, isTrue);
    expect(snapshots.single.contextCompactionUpdate, isTrue);
    expect(snapshots.single.revision, 1);
    service.handleIncomingFrameForTest({
      'type': 'conversations',
      'operation_id': 'compact_other',
      'compact_conversation_id': 'b',
      'compact_changed': false,
      'items': [],
    });
    service.handleIncomingFrameForTest({
      'type': 'conversations',
      'operation_id': 'compact_fixture',
      'compact_conversation_id': 'a',
      'compact_changed': true,
      'items': [],
    });
    expect(await result, isTrue);
    expect(frames.single['operation_id'], 'compact_fixture');
  });

  testWidgets('manual compaction is visible and completion is not duplicated', (
    tester,
  ) async {
    final service = _Service();
    await _host(tester, service);
    await _send(tester, '/compact');
    expect(service.compactRequest, isNotNull);
    expect(find.text('Compacting context…'), findsOneWidget);
    expect(service.sent, isEmpty);
    service.emit(
      ws.ConversationHistoryMessage(
        id: 'a',
        revision: 2,
        contextCompactionUpdate: true,
        messages: [..._original, _notice(service.compactRequest!)],
      ),
    );
    await tester.pump();
    service.compact.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Context compacted.'), findsOneWidget);
    expect(find.text('Compacting context…'), findsNothing);
    service.emit(
      const ws.ConversationHistoryMessage(
        id: 'a',
        revision: 1,
        contextCompactionUpdate: true,
        contextCompacting: true,
        messages: _original,
      ),
    );
    await tester.pump();
    expect(find.text('Compacting context…'), findsNothing);
    expect(find.textContaining('PRIVATE SYSTEM TEXT'), findsNothing);
    final notice = tester.widget<ChatBubble>(
      find.byWidgetPredicate(
        (widget) => widget is ChatBubble && widget.text == 'Context compacted.',
      ),
    );
    expect(notice.isSystem, isTrue);
  });

  testWidgets('compaction snapshot cannot reset a new pending user turn', (
    tester,
  ) async {
    final service = _Service();
    await _host(tester, service);
    await _send(tester, 'New pending task');
    expect(find.text('New pending task'), findsOneWidget);
    service.emit(
      ws.ConversationHistoryMessage(
        id: 'a',
        revision: 2,
        contextCompactionUpdate: true,
        messages: [..._original, _notice('compact_peer')],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('New pending task'), findsOneWidget);
    expect(find.text('Context compacted.'), findsOneWidget);
    expect(service.sent, ['New pending task']);
  });

  testWidgets(
    'other conversation completion cannot redirect the selected chat',
    (tester) async {
      final service = _Service();
      await _host(tester, service);
      await _send(tester, '/compact');
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta conversation'));
      await tester.pumpAndSettle();
      service.emit(
        const ws.ConversationHistoryMessage(
          id: 'b',
          revision: 1,
          messages: [
            ws.HistoryMessage(role: 'assistant', content: 'Beta reply'),
          ],
        ),
      );
      await tester.pump();
      service.emit(
        ws.ConversationHistoryMessage(
          id: 'a',
          revision: 2,
          contextCompactionUpdate: true,
          messages: [..._original, _notice(service.compactRequest!)],
        ),
      );
      service.compact.complete(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Beta reply'), findsOneWidget);
      expect(find.text('Context compacted.'), findsNothing);
      expect(find.text('Compacting context…'), findsNothing);
    },
  );
}
