import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/autonomous_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

class _RecordingService extends ws.WebSocketService {
  _RecordingService()
    : super(ip: '127.0.0.1', token: 'test', autoReconnect: false);

  final starts = <(String, String)>[];
  final StreamController<ws.AutonomousProgressMessage> _autonomous =
      StreamController<ws.AutonomousProgressMessage>.broadcast();

  @override
  Stream<ws.AutonomousProgressMessage> get autonomousStream =>
      _autonomous.stream;

  void emit(ws.AutonomousProgressMessage message) => _autonomous.add(message);

  @override
  void sendGetConfig() {}

  @override
  void sendGetModels() {}

  @override
  void sendGetAutonomousStatus() {}

  @override
  void sendAutonomousStart(String objective, String model) {
    starts.add((objective, model));
  }

  @override
  void dispose() {
    _autonomous.close();
    super.dispose();
  }
}

Widget _app(ws.WebSocketService service) {
  return OsiaTheme(
    palette: osiaPaletteViolet,
    child: OsiaL10n(
      strings: osiaStringsForCode('en'),
      child: MaterialApp(home: AutonomousScreen(wsService: service)),
    ),
  );
}

Map<String, dynamic> _catalogueFrame({
  required List<Map<String, dynamic>> providers,
  String? current,
  String? currentProvider,
}) {
  return {
    'type': 'models_list',
    'catalogue': {'version': 1, 'providers': providers},
    'current': ?current,
    'current_provider': ?currentProvider,
  };
}

void main() {
  const openAi = ws.OsiaModel(
    id: 'shared',
    label: 'OpenAI Shared',
    provider: 'openai',
  );
  const deepSeek = ws.OsiaModel(
    id: 'shared',
    label: 'DeepSeek Shared',
    provider: 'deepseek',
  );
  const account = ws.OsiaModel(
    id: 'account-only',
    label: 'Account',
    provider: 'chatgpt_account',
  );

  test('retains the full provider/model selection for duplicate model ids', () {
    final resolved = resolveAutonomousModelSelection(
      const [openAi, deepSeek],
      serverProvider: 'deepseek',
      serverModel: 'shared',
    );
    expect(resolved.selected, same(deepSeek));
    expect(resolved.fallbackOccurred, isFalse);
    expect(autonomousModelWireValue(resolved.selected!), 'deepseek:shared');
  });

  test('manual duplicate-id selection remains pinned to its provider', () {
    final resolved = resolveAutonomousModelSelection(
      const [openAi, deepSeek],
      current: openAi,
      serverProvider: 'deepseek',
      serverModel: 'shared',
      userPicked: true,
    );
    expect(resolved.selected, same(openAi));
    expect(sameAutonomousModelIdentity(resolved.selected, openAi), isTrue);
  });

  test('a valid server preference change is not reported as stale', () {
    final resolved = resolveAutonomousModelSelection(
      const [openAi, deepSeek],
      current: openAi,
      serverProvider: 'deepseek',
      serverModel: 'shared',
    );
    expect(resolved.selected, same(deepSeek));
    expect(resolved.fallbackOccurred, isFalse);
  });

  test('stable wire value preserves colons inside a model id', () {
    const local = ws.OsiaModel(
      id: 'family:latest',
      label: 'Local',
      provider: 'ollama',
    );
    expect(autonomousModelWireValue(local), 'ollama:family:latest');
  });

  test('stale account selection falls back explicitly after disconnect', () {
    final resolved = resolveAutonomousModelSelection(
      const [openAi],
      current: account,
      serverProvider: 'chatgpt_account',
      serverModel: 'account-only',
      userPicked: true,
    );
    expect(resolved.selected, same(openAi));
    expect(resolved.fallbackOccurred, isTrue);
  });

  test('stale-selection notice is localized in every supported language', () {
    for (final code in osiaSupportedLanguages) {
      expect(
        osiaStringsForCode(code).autonomousModelFallback.trim(),
        isNotEmpty,
      );
    }
  });

  test('empty catalogue clears a stale selection truthfully', () {
    final resolved = resolveAutonomousModelSelection(
      const [],
      current: account,
      userPicked: true,
    );
    expect(resolved.selected, isNull);
    expect(resolved.fallbackOccurred, isTrue);
  });

  test('model identity and wire values contain no credential fields', () {
    final wire = autonomousModelWireValue(openAi);
    expect(wire, 'openai:shared');
    for (final forbidden in ['key', 'token', 'oauth', 'credential']) {
      expect(wire.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  testWidgets('Autonomous start sends the exact provider:model identity', (
    tester,
  ) async {
    final service = _RecordingService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_app(service));
    service.handleIncomingFrameForTest(
      _catalogueFrame(
        current: 'shared',
        currentProvider: 'deepseek',
        providers: const [
          {
            'providerId': 'openai',
            'displayName': 'OpenAI',
            'models': [
              {'id': 'shared', 'providerId': 'openai'},
            ],
          },
          {
            'providerId': 'deepseek',
            'displayName': 'DeepSeek',
            'models': [
              {'id': 'shared', 'providerId': 'deepseek'},
            ],
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Harmless objective');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Start'));
    await tester.pump();
    expect(service.starts, [('Harmless objective', 'deepseek:shared')]);
  });

  testWidgets(
    'active chat-inherited run displays its pair without changing manual selection',
    (tester) async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      await tester.pumpWidget(_app(service));
      service.handleIncomingFrameForTest(
        _catalogueFrame(
          current: 'shared',
          currentProvider: 'deepseek',
          providers: const [
            {
              'providerId': 'deepseek',
              'displayName': 'DeepSeek',
              'models': [
                {
                  'id': 'shared',
                  'displayName': 'DeepSeek Shared',
                  'providerId': 'deepseek',
                },
              ],
            },
            {
              'providerId': 'chatgpt_account',
              'displayName': 'ChatGPT',
              'models': [
                {
                  'id': 'gpt-5.6-luna',
                  'displayName': 'GPT-5.6 Luna',
                  'providerId': 'chatgpt_account',
                },
              ],
            },
          ],
        ),
      );
      await tester.pumpAndSettle();

      Map<String, dynamic> progress({
        required int sequence,
        required String event,
        required bool terminal,
      }) => {
        'type': 'autonomous_progress',
        'schema_version': 1,
        'event_id': 'wor224-event-$sequence',
        'sequence': sequence,
        'server_id': service.expectedPermissionServerIdForTest,
        'session_id': 'wor224-session',
        'run_id': 'wor224-run',
        'plan_revision': 1,
        'authorization_revision': 1,
        'event': event,
        'terminal': terminal,
        'tasks_done': terminal ? 1 : 0,
        'tasks_total': 1,
        'provider': 'chatgpt_account',
        'model': 'gpt-5.6-luna',
      };

      service.emit(
        ws.AutonomousProgressMessage.fromJson(
          progress(sequence: 1, event: 'running', terminal: false),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      final runModel = find.byKey(
        const ValueKey('autonomous-run-model'),
      );
      expect(runModel, findsOneWidget);
      final modelText = tester.widget<RichText>(
        find.descendant(of: runModel, matching: find.byType(RichText)),
      );
      expect(
        modelText.text.toPlainText(),
        contains('chatgpt_account — gpt-5.6-luna'),
      );

      service.emit(
        ws.AutonomousProgressMessage.fromJson(
          progress(sequence: 2, event: 'done', terminal: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.enterText(find.byType(TextField), 'Manual objective');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Start'));
      await tester.pump();
      expect(service.starts, [('Manual objective', 'deepseek:shared')]);
    },
  );
}
