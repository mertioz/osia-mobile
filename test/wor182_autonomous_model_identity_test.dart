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
}
