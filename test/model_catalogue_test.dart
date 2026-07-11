import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';
import 'package:osia_mobile/widgets/model_selector_sheet.dart';

class _InitialSyncService extends ws.WebSocketService {
  _InitialSyncService()
    : super(ip: '127.0.0.1', token: 'test', autoReconnect: false);

  int accountRequests = 0;
  int catalogueRequests = 0;

  @override
  void sendGetChatGptAccount() => accountRequests++;

  @override
  void sendGetModels() => catalogueRequests++;
}

void main() {
  group('sanitized model catalogue parsing', () {
    test('first authenticated ack requests account and catalogue once', () {
      final service = _InitialSyncService();
      addTearDown(service.dispose);
      service.expectAuthenticatedInitialSyncForTest();
      service.handleIncomingFrameForTest({'type': 'status', 'content': 'done'});
      service.handleIncomingFrameForTest({'type': 'status', 'content': 'done'});
      expect(service.accountRequests, 1);
      expect(service.catalogueRequests, 1);
    });

    test(
      'deduplicates providers/models and drops malformed empty entries',
      () async {
        final service = ws.WebSocketService(
          ip: '127.0.0.1',
          token: 'test',
          autoReconnect: false,
        );
        addTearDown(service.dispose);
        final messageFuture = service.messageStream
            .where((message) => message is ws.ModelsListMessage)
            .cast<ws.ModelsListMessage>()
            .first;

        service.handleIncomingFrameForTest({
          'type': 'models_list',
          'catalogue': {
            'version': 1,
            'providers': [
              {
                'providerId': 'ollama',
                'displayName': 'Local (Ollama)',
                'kind': 'local',
                'models': [
                  {
                    'id': 'llama3',
                    'displayName': 'Llama 3',
                    'providerId': 'ollama',
                    'usable': true,
                    'selectable': true,
                  },
                  {
                    'id': 'llama3',
                    'displayName': 'Duplicate',
                    'providerId': 'ollama',
                  },
                  {'id': '', 'providerId': 'ollama'},
                ],
              },
              {
                'providerId': 'ollama',
                'models': [
                  {'id': 'ignored-second-provider', 'providerId': 'ollama'},
                ],
              },
              {'providerId': 'openai', 'models': []},
              {'providerId': '', 'models': []},
            ],
          },
          'current': 'llama3',
          'current_provider': 'ollama',
        });

        final message = await messageFuture;
        expect(message.providers, hasLength(1));
        expect(message.providers.single.id, 'ollama');
        expect(message.models.map((model) => model.id), ['llama3']);
        expect(message.currentProvider, 'ollama');
      },
    );

    test(
      'parses account reasoning metadata without credential fields',
      () async {
        final service = ws.WebSocketService(
          ip: '127.0.0.1',
          token: 'test',
          autoReconnect: false,
        );
        addTearDown(service.dispose);
        final messageFuture = service.messageStream
            .where((message) => message is ws.ModelsListMessage)
            .cast<ws.ModelsListMessage>()
            .first;
        final accountFuture = service.chatGptAccountStream.first;

        service.handleIncomingFrameForTest({
          'type': 'models_list',
          'catalogue': {
            'version': 1,
            'providers': [
              {
                'providerId': 'chatgpt_account',
                'displayName': 'ChatGPT',
                'kind': 'chatgpt_account',
                'models': [
                  {
                    'id': 'gpt-account',
                    'displayName': 'GPT Account',
                    'providerId': 'chatgpt_account',
                    'reasoning': {
                      'selected': 'high',
                      'options': [
                        {'id': 'auto', 'label': 'Default', 'default': true},
                        {'id': 'high', 'label': 'High'},
                      ],
                    },
                  },
                ],
              },
            ],
          },
          'account': {
            'connected': true,
            'available': true,
            'email': 'safe@example.test',
            'plan': 'plus',
            'accessToken': 'must-not-be-represented',
          },
        });

        final message = await messageFuture;
        final account = await accountFuture;
        expect(
          message.models.single.reasoningOptions.map((option) => option.id),
          ['auto', 'high'],
        );
        expect(message.models.single.selectedReasoning, 'high');
        expect(account.email, 'safe@example.test');
        expect(account.plan, 'plus');
        expect(account.toString(), isNot(contains('must-not-be-represented')));
      },
    );

    test('empty catalogue is handled cleanly and idempotently', () async {
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'test',
        autoReconnect: false,
      );
      addTearDown(service.dispose);
      final messages = <ws.ModelsListMessage>[];
      final sub = service.messageStream
          .where((message) => message is ws.ModelsListMessage)
          .cast<ws.ModelsListMessage>()
          .listen(messages.add);
      addTearDown(sub.cancel);
      final frame = {
        'type': 'models_list',
        'catalogue': {'version': 1, 'providers': <Object>[]},
        'models': <Object>[],
      };

      service.handleIncomingFrameForTest(frame);
      service.handleIncomingFrameForTest(frame);
      await pumpEventQueue();

      expect(messages, hasLength(2));
      expect(messages.every((message) => message.models.isEmpty), isTrue);
    });

    test(
      'authoritative empty catalogue never falls back to legacy models',
      () async {
        final service = ws.WebSocketService(
          ip: '127.0.0.1',
          token: 'test',
          autoReconnect: false,
        );
        addTearDown(service.dispose);
        final messageFuture = service.messageStream
            .where((message) => message is ws.ModelsListMessage)
            .cast<ws.ModelsListMessage>()
            .first;

        service.handleIncomingFrameForTest({
          'type': 'models_list',
          'catalogue': {'version': 1, 'providers': <Object>[]},
          'models': [
            {
              'id': 'static-claude',
              'provider': 'anthropic',
              'selectable': true,
            },
            {'id': 'static-grok', 'provider': 'xai', 'selectable': true},
          ],
        });

        final message = await messageFuture;
        expect(message.providers, isEmpty);
        expect(message.models, isEmpty);
      },
    );

    test('cached connected state wins a reconnect catalogue race', () async {
      final service = ws.WebSocketService(
        ip: '127.0.0.1',
        token: 'test',
        autoReconnect: false,
      );
      addTearDown(service.dispose);
      final connectedFuture = service.chatGptAccountStream.first;
      service.handleIncomingFrameForTest({
        'type': 'chatgpt_account_state',
        'account': {
          'providerId': 'chatgpt_account',
          'connected': true,
          'available': true,
          'email': 'connected@example.test',
        },
      });
      expect((await connectedFuture).connected, isTrue);
      service.disconnect();

      final messageFuture = service.messageStream
          .where((message) => message is ws.ModelsListMessage)
          .cast<ws.ModelsListMessage>()
          .first;
      service.handleIncomingFrameForTest({
        'type': 'models_list',
        'catalogue': {'version': 1, 'providers': <Object>[]},
        'account': {
          'providerId': 'chatgpt_account',
          'connected': false,
          'available': false,
          'error': 'disconnected',
        },
      });

      final message = await messageFuture;
      expect(message.account.connected, isTrue);
      expect(service.chatGptAccountState.connected, isTrue);
      expect(service.chatGptAccountState.email, 'connected@example.test');
    });

    test(
      'disconnect clears device-code data but keeps safe account state',
      () async {
        final service = ws.WebSocketService(
          ip: '127.0.0.1',
          token: 'test',
          autoReconnect: false,
        );
        addTearDown(service.dispose);
        final events = <ws.ChatGptAccountState>[];
        final sub = service.chatGptAccountStream.listen(events.add);
        addTearDown(sub.cancel);
        service.handleIncomingFrameForTest({
          'type': 'chatgpt_account_state',
          'account': {
            'providerId': 'chatgpt_account',
            'connected': true,
            'connecting': true,
            'loginCancellable': true,
            'email': 'safe@example.test',
            'login': {
              'verificationUrl': 'https://auth.openai.com/device',
              'userCode': 'ONE-TIME',
            },
          },
        });
        await pumpEventQueue();
        service.disconnect();
        await pumpEventQueue();

        expect(events.last.connected, isTrue);
        expect(events.last.email, 'safe@example.test');
        expect(events.last.connecting, isFalse);
        expect(events.last.loginCancellable, isFalse);
        expect(events.last.verificationUrl, isEmpty);
        expect(events.last.userCode, isEmpty);
      },
    );
  });

  testWidgets('selector shows non-empty provider cards with name and count', (
    tester,
  ) async {
    final state = ValueNotifier(
      const ModelSelectorState(
        isLoading: false,
        models: [
          ws.OsiaModel(id: 'gpt-5.4', label: 'GPT 5.4', provider: 'openai'),
          ws.OsiaModel(id: 'gpt-4.1', label: 'GPT 4.1', provider: 'openai'),
          ws.OsiaModel(id: 'llama3', label: 'Llama 3', provider: 'ollama'),
        ],
      ),
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPaletteViolet,
        child: OsiaL10n(
          strings: osiaStringsForCode('en'),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showModelSelector(
                    context: context,
                    stateListenable: state,
                    currentModel: null,
                    hierarchyActive: false,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('OPENAI'), findsOneWidget);
    expect(find.text('2 models'), findsOneWidget);
    expect(find.text('LOCAL'), findsOneWidget);
    expect(find.text('1 model'), findsOneWidget);
    expect(find.text('GPT 5.4'), findsNothing);

    await tester.tap(find.text('OPENAI'));
    await tester.pumpAndSettle();
    expect(find.text('GPT 5.4'), findsOneWidget);
    expect(find.text('GPT 4.1'), findsOneWidget);
    expect(find.text('Llama 3'), findsNothing);
  });

  testWidgets(
    'selector uses stable keys and rapid taps settle on latest choice',
    (tester) async {
      final state = ValueNotifier(
        const ModelSelectorState(
          isLoading: false,
          models: [
            ws.OsiaModel(id: 'gpt-a', label: 'GPT A', provider: 'openai'),
            ws.OsiaModel(id: 'gpt-b', label: 'GPT B', provider: 'openai'),
            ws.OsiaModel(id: 'llama', label: 'Llama', provider: 'ollama'),
          ],
        ),
      );
      addTearDown(state.dispose);
      final selected = <ws.OsiaModel>[];
      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPaletteViolet,
          child: OsiaL10n(
            strings: osiaStringsForCode('en'),
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showModelSelector(
                      context: context,
                      stateListenable: state,
                      currentModel: null,
                      hierarchyActive: false,
                      onModelSelected: selected.add,
                    ),
                    child: const Text('open-stable'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open-stable'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('provider:openai')), findsOneWidget);
      expect(find.byKey(const ValueKey('provider:ollama')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('provider:openai')));
      await tester.tap(find.byKey(const ValueKey('provider:ollama')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('model:ollama:llama')), findsOneWidget);
      expect(find.byKey(const ValueKey('model:openai:gpt-a')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('models-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('provider:openai')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('model:openai:gpt-a')));
      await tester.tap(find.byKey(const ValueKey('model:openai:gpt-b')));
      await tester.pumpAndSettle();
      expect(selected.map((model) => model.id), ['gpt-b']);
    },
  );

  testWidgets(
    'unchanged refresh does not duplicate content and reduced motion is instant',
    (tester) async {
      final state = ValueNotifier(
        const ModelSelectorState(
          isLoading: false,
          models: [ws.OsiaModel(id: 'only', label: 'Only', provider: 'openai')],
        ),
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPaletteViolet,
          child: OsiaL10n(
            strings: osiaStringsForCode('en'),
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showModelSelector(
                      context: context,
                      stateListenable: state,
                      currentModel: null,
                      hierarchyActive: false,
                    ),
                    child: const Text('open-reduced'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open-reduced'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
            .any((switcher) => switcher.duration == Duration.zero),
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('provider:openai')));
      await tester.pump();
      expect(find.byKey(const ValueKey('model:openai:only')), findsOneWidget);

      state.value = const ModelSelectorState(
        isLoading: false,
        models: [ws.OsiaModel(id: 'only', label: 'Only', provider: 'openai')],
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('model:openai:only')), findsOneWidget);
    },
  );
}
