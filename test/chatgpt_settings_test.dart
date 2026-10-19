import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/providers_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

class _AccountWebSocketService extends ws.WebSocketService {
  _AccountWebSocketService({
    this.cachedAccount = const ws.ChatGptAccountState(),
  }) : super(ip: '127.0.0.1', token: 'test', autoReconnect: false);

  final _config = StreamController<ws.ConfigData>.broadcast();
  final _account = StreamController<ws.ChatGptAccountState>.broadcast();
  int loginCalls = 0;
  int cancelCalls = 0;
  int logoutCalls = 0;
  final writes = <(String, Object?)>[];
  final ws.ChatGptAccountState cachedAccount;

  @override
  ws.ConnectionState get state => ws.ConnectionState.connected;

  @override
  Stream<ws.ConfigData> get configStream => _config.stream;

  @override
  Stream<ws.ChatGptAccountState> get chatGptAccountStream => _account.stream;

  @override
  ws.ChatGptAccountState get chatGptAccountState => cachedAccount;

  @override
  Future<void> ensureConnected({
    String reason = 'unspecified',
    bool forceReconnect = false,
  }) => Future<void>.value();

  @override
  void sendGetConfig() {}

  @override
  void sendGetModels() {}

  @override
  void sendGetApiKeys() {}

  @override
  void sendGetChatGptAccount() {}

  @override
  void sendChatGptAccountLogin() => loginCalls++;

  @override
  void sendCancelChatGptAccountLogin() => cancelCalls++;

  @override
  void sendChatGptAccountLogout() => logoutCalls++;

  @override
  void sendSetSetting(String key, Object? value) => writes.add((key, value));

  @override
  void sendSetApiKey(String provider, String key) =>
      writes.add((provider, key));

  void emitConfig([Map<String, dynamic> settings = const {}]) {
    _config.add(ws.ConfigData.fromJson({'settings': settings}));
  }

  void emitAccount(ws.ChatGptAccountState state) => _account.add(state);

  @override
  void dispose() {
    _config.close();
    _account.close();
    super.dispose();
  }
}

void main() {
  testWidgets(
    'open provider list follows canonical key and workspace updates',
    (tester) async {
      final service = _AccountWebSocketService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPalette,
          child: OsiaL10n(
            strings: osiaStringsEn,
            child: MaterialApp(home: ProvidersScreen(wsService: service)),
          ),
        ),
      );
      service.emitConfig();
      await tester.pump();
      await tester.tap(find.text(osiaStringsEn.catAiProviders));
      await tester.pumpAndSettle();
      final row = find
          .ancestor(of: find.text('Claude API'), matching: find.byType(InkWell))
          .first;
      final badge = find.descendant(
        of: row,
        matching: find.byIcon(Icons.check_circle_rounded),
      );
      expect(badge, findsNothing);
      service._config.add(
        ws.ConfigData.fromJson({
          'api_keys_set': {'anthropic': true},
          'anthropic_workspace_id': 'workspace_live',
        }),
      );
      await tester.pump();
      await tester.pump();
      expect(badge, findsOneWidget);
      await tester.tap(find.text('Claude API'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('claude_api_workspace')),
            )
            .controller!
            .text,
        'workspace_live',
      );
    },
  );

  testWidgets(
    'Claude API workspace mirrors PC and saves without replacing a key',
    (tester) async {
      final service = _AccountWebSocketService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPalette,
          child: OsiaL10n(
            strings: osiaStringsEn,
            child: MaterialApp(home: ProvidersScreen(wsService: service)),
          ),
        ),
      );
      service.emitConfig({'anthropic_workspace_id': 'workspace_fixture'});
      await tester.pump();
      await tester.tap(find.text(osiaStringsEn.catAiProviders));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claude API'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('claude_api_workspace'));
      expect(
        tester.widget<TextField>(field).controller!.text,
        'workspace_fixture',
      );
      await tester.enterText(field, 'workspace_next');
      await tester.pump();
      await tester.ensureVisible(find.text(osiaStringsEn.save));
      await tester.tap(find.text(osiaStringsEn.save));
      await tester.pumpAndSettle();
      expect(service.writes, [('anthropic_workspace_id', 'workspace_next')]);
    },
  );

  testWidgets('canonical PC quota windows retain remaining percentages', (
    tester,
  ) async {
    final service = _AccountWebSocketService();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      OsiaTheme(
        palette: osiaPalette,
        child: OsiaL10n(
          strings: osiaStringsEn,
          child: MaterialApp(home: ProvidersScreen(wsService: service)),
        ),
      ),
    );
    service.emitConfig();
    await tester.pump();
    await tester.tap(find.text(osiaStringsEn.catAiProviders));
    await tester.pumpAndSettle();
    service.emitAccount(
      ws.ChatGptAccountState.fromJson({
        'connected': true,
        'available': true,
        'quotaWindows': [
          {'label': '5 h', 'remainingPercent': 88},
          {'label': 'Weekly', 'remainingPercent': 0},
          {'label': 'Invalid', 'remainingPercent': 101},
          {'label': 'Invalid', 'remainingPercent': true},
          {'label': '', 'remainingPercent': 12},
          'malformed',
        ],
        'usagePercent': 99,
        'access_token': 'test-only',
      }),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('5 h: 88% remaining'), findsOneWidget);
    expect(find.text('Weekly: 0% remaining'), findsOneWidget);
    expect(find.textContaining('Invalid'), findsNothing);
    expect(find.text(osiaStringsEn.chatGptUsage(99)), findsNothing);
    service.emitAccount(ws.ChatGptAccountState.fromJson({'connected': false}));
    await tester.pump();
    expect(find.text('5 h: 88% remaining'), findsNothing);
  });

  testWidgets(
    'ChatGPT settings mirrors disconnected, device-code and connected states',
    (tester) async {
      final service = _AccountWebSocketService();
      addTearDown(service.dispose);
      final strings = osiaStringsForCode('en');
      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPaletteViolet,
          child: OsiaL10n(
            strings: strings,
            child: MaterialApp(home: ProvidersScreen(wsService: service)),
          ),
        ),
      );
      service.emitConfig();
      await tester.pump();
      await tester.tap(find.text(strings.catAiProviders));
      await tester.pumpAndSettle();

      expect(find.text('ChatGPT'), findsOneWidget);
      expect(find.text(strings.chatGptConnect), findsOneWidget);
      await tester.tap(find.text(strings.chatGptConnect));
      expect(service.loginCalls, 1);

      service.emitAccount(
        const ws.ChatGptAccountState(
          runtimeAvailable: true,
          connecting: true,
          loginCancellable: true,
          verificationUrl: 'https://auth.openai.com/device',
          userCode: 'ABCD-EFGH',
        ),
      );
      await tester.pump();
      expect(find.text('ABCD-EFGH'), findsOneWidget);
      expect(find.text(strings.chatGptOpenLogin), findsOneWidget);
      expect(find.text(strings.cancel), findsOneWidget);
      await tester.tap(find.text(strings.cancel));
      expect(service.cancelCalls, 1);

      service.emitAccount(
        const ws.ChatGptAccountState(
          runtimeAvailable: true,
          connected: true,
          available: true,
          email: 'safe@example.test',
          plan: 'plus',
          usagePercent: 12,
        ),
      );
      await tester.pump();
      expect(find.text('safe@example.test · plus'), findsOneWidget);
      expect(find.text(strings.chatGptUsage(12)), findsOneWidget);
      expect(find.text(strings.chatGptConnect), findsNothing);
      expect(find.text(strings.chatGptDisconnect), findsOneWidget);
      await tester.tap(find.text(strings.chatGptDisconnect));
      expect(service.logoutCalls, 1);
    },
  );

  testWidgets(
    'already-connected cached account renders immediately without reset',
    (tester) async {
      final service = _AccountWebSocketService(
        cachedAccount: const ws.ChatGptAccountState(
          runtimeAvailable: true,
          connected: true,
          available: true,
          email: 'ready@example.test',
        ),
      );
      addTearDown(service.dispose);
      final strings = osiaStringsForCode('en');
      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPaletteViolet,
          child: OsiaL10n(
            strings: strings,
            child: MaterialApp(home: ProvidersScreen(wsService: service)),
          ),
        ),
      );
      service.emitConfig();
      await tester.pump();
      await tester.tap(find.text(strings.catAiProviders));
      await tester.pumpAndSettle();

      expect(find.text(strings.connected), findsOneWidget);
      expect(find.text('ready@example.test'), findsOneWidget);
      expect(find.text(strings.chatGptConnect), findsNothing);
      expect(find.text(strings.chatGptDisconnect), findsOneWidget);
    },
  );

  test('ChatGPT action and status translations stay semantically distinct', () {
    final french = osiaStringsForCode('fr');
    expect(french.chatGptConnect, 'Se connecter avec ChatGPT');
    expect(french.connected, 'Connecté');
    expect(french.connectingStatus, 'Connexion…');
    expect(french.chatGptDisconnect, 'Se déconnecter');
    for (final code in const ['en', 'fr', 'zh', 'ja', 'de', 'es']) {
      final strings = osiaStringsForCode(code);
      expect(strings.chatGptConnect, isNot(strings.connected));
      expect(strings.chatGptDisconnect, isNot(strings.disconnected));
    }
  });
}
