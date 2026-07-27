import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/providers_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

const _trustedOauthUrl =
    'https://accounts.google.com/o/oauth2/v2/auth?response_type=code'
    '&client_id=public&state=public-state&code_challenge=public-challenge'
    '&code_challenge_method=S256&redirect_uri='
    'https%3A%2F%2Fosia-rendezvous.aymengherbi06.workers.dev%2Foauth%2Fcb%2F'
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

class _FakeWebSocketService extends ws.WebSocketService {
  _FakeWebSocketService()
    : super(ip: '127.0.0.1', token: 'token', autoReconnect: false);

  final StreamController<ws.ConnectionState> _connection =
      StreamController<ws.ConnectionState>.broadcast();
  final StreamController<ws.ConfigData> _config =
      StreamController<ws.ConfigData>.broadcast();
  final StreamController<ws.ApiKeysMessage> _apiKeys =
      StreamController<ws.ApiKeysMessage>.broadcast();
  final StreamController<ws.McpStatusMessage> _mcpStatus =
      StreamController<ws.McpStatusMessage>.broadcast();
  final StreamController<ws.McpOauthUrl> _oauth =
      StreamController<ws.McpOauthUrl>.broadcast();

  final List<Map<String, String>> connectRequests = <Map<String, String>>[];
  final List<Map<String, String>> cancelRequests = <Map<String, String>>[];
  final List<String> disconnectRequests = <String>[];
  final List<MapEntry<String, dynamic>> settingWrites =
      <MapEntry<String, dynamic>>[];
  int configRequests = 0;

  @override
  ws.ConnectionState get state => ws.ConnectionState.connected;

  @override
  Stream<ws.ConnectionState> get connectionStream => _connection.stream;

  @override
  Stream<ws.ConfigData> get configStream => _config.stream;

  @override
  Stream<ws.ApiKeysMessage> get apiKeysStream => _apiKeys.stream;

  @override
  Stream<ws.McpStatusMessage> get mcpStatusStream => _mcpStatus.stream;

  @override
  Stream<ws.McpOauthUrl> get mcpOauthUrlStream => _oauth.stream;

  @override
  Future<void> ensureConnected({
    String reason = 'unspecified',
    bool forceReconnect = false,
  }) async {}

  @override
  void sendGetConfig() {
    configRequests++;
  }

  @override
  void sendGetModels() {}

  @override
  void sendGetApiKeys() {}

  @override
  void sendMcpStatus([String? id]) {}

  @override
  void sendSetSetting(String key, dynamic value) {
    settingWrites.add(MapEntry<String, dynamic>(key, value));
  }

  @override
  void sendMcpConnect(String id, {String? requestId}) {
    connectRequests.add(<String, String>{
      'id': id,
      'request_id': requestId ?? '',
    });
  }

  @override
  void sendMcpOauthCancel(String id, {String? requestId, String? attemptId}) {
    cancelRequests.add(<String, String>{
      'id': id,
      'request_id': requestId ?? '',
      'attempt_id': attemptId ?? '',
    });
  }

  @override
  void sendMcpDisconnect(String id) {
    disconnectRequests.add(id);
  }

  void emitConfig(
    Map<String, dynamic> gmail, {
    List<Map<String, dynamic>> mcpServers = const <Map<String, dynamic>>[],
  }) {
    _config.add(
      ws.ConfigData.fromJson(<String, dynamic>{
        'gmail_rest': gmail,
        'settings': <String, dynamic>{
          'mcp_servers': mcpServers,
          'mcp_confirm_writes': true,
          'mcp_allow_unattended_writes': false,
        },
      }),
    );
  }

  void emitOauth(ws.McpOauthUrl event) => _oauth.add(event);

  @override
  void dispose() {
    _connection.close();
    _config.close();
    _apiKeys.close();
    _mcpStatus.close();
    _oauth.close();
    super.dispose();
  }
}

Map<String, dynamic> _gmail({
  bool connected = false,
  bool connecting = false,
  bool configured = true,
  bool canConnect = true,
  bool canReconnect = false,
  bool canDisconnect = false,
  String status = 'authorization_required',
  String? attemptId,
  double? expiresAt,
  Map<String, bool> capabilities = const <String, bool>{},
}) {
  return <String, dynamic>{
    'type': 'native_rest',
    'id': 'gmail-rest',
    'connected': connected,
    'connecting': connecting,
    'status': status,
    'oauthClientConfigured': configured,
    'mobileOAuthConfigured': configured,
    'userActionRequired': !connected && !connecting,
    'canConnect': canConnect,
    'canCancel': connecting,
    'canReconnect': canReconnect,
    'canDisconnect': canDisconnect,
    'configureOnPc': !configured,
    'guideAvailable': true,
    'attemptId': attemptId,
    'attemptExpiresAt': expiresAt,
    'capabilities': capabilities,
  };
}

Future<void> _openGmailConnector(
  WidgetTester tester,
  _FakeWebSocketService service,
  Map<String, dynamic> gmail, {
  Future<bool> Function(Uri uri)? launcher,
  List<Map<String, dynamic>> mcpServers = const <Map<String, dynamic>>[],
}) async {
  await tester.pumpWidget(
    OsiaTheme(
      palette: osiaPaletteViolet,
      child: OsiaL10n(
        strings: osiaStringsForCode('en'),
        child: MaterialApp(
          home: Scaffold(
            body: SystemSettingsSection(
              wsService: service,
              oauthUrlLauncher: launcher,
            ),
          ),
        ),
      ),
    ),
  );
  service.emitConfig(gmail, mcpServers: mcpServers);
  await tester.pump();
  final strings = osiaStringsForCode('en');
  await tester.ensureVisible(find.text(strings.catConnectors));
  await tester.tap(find.text(strings.catConnectors));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(strings.gmailRestName).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'WOR-198 Connectors has no duplicate permission controls or placeholders',
    (tester) async {
      final service = _FakeWebSocketService();
      addTearDown(service.dispose);
      await _openGmailConnector(tester, service, _gmail());
      final strings = osiaStringsForCode('en');

      expect(find.text(strings.mcpConfirmWritesLabel), findsNothing);
      expect(find.text(strings.mcpConfirmWritesSub), findsNothing);
      expect(find.text(strings.mcpUnattendedWritesLabel), findsNothing);
      expect(find.text(strings.mcpUnattendedWritesSub), findsNothing);
      expect(service.settingWrites, isEmpty);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(find.text(strings.connectorLabel), findsOneWidget);
      expect(find.text(strings.gmailRestTitle), findsOneWidget);
    },
  );

  testWidgets(
    'shows native Gmail disconnected and configuration-missing states',
    (tester) async {
      final service = _FakeWebSocketService();
      addTearDown(service.dispose);
      final legacy = <String, dynamic>{
        'id': 'gmail-mcp-legacy',
        'name': 'Gmail (legacy MCP)',
        'url': 'https://gmailmcp.googleapis.com/mcp/v1',
        'hidden': true,
      };

      await _openGmailConnector(
        tester,
        service,
        _gmail(
          configured: false,
          canConnect: false,
          status: 'configuration_missing',
        ),
        mcpServers: <Map<String, dynamic>>[legacy],
      );
      final strings = osiaStringsForCode('en');

      expect(find.text(strings.gmailRestTitle), findsOneWidget);
      expect(find.text(strings.gmailRestConfigureOnPc), findsWidgets);
      expect(find.text('${strings.mcpConnect} Gmail'), findsNothing);
      expect(find.text('Gmail (legacy MCP)'), findsNothing);
      expect(find.text(strings.gmailRestPcHostedAuth), findsOneWidget);
    },
  );

  testWidgets('connect is sent once and one authorization browser opens', (
    tester,
  ) async {
    final service = _FakeWebSocketService();
    addTearDown(service.dispose);
    final opened = <Uri>[];
    await _openGmailConnector(
      tester,
      service,
      _gmail(),
      launcher: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    final strings = osiaStringsForCode('en');
    final connect = find.text('${strings.mcpConnect} Gmail');

    await tester.ensureVisible(connect);
    await tester.tap(connect);
    await tester.tap(connect);
    await tester.pump();

    expect(service.connectRequests, hasLength(1));
    expect(service.connectRequests.single['id'], 'gmail-rest');
    final requestId = service.connectRequests.single['request_id']!;
    expect(requestId, isNotEmpty);
    expect(find.text(strings.mcpStatusConnecting), findsWidgets);

    final event = ws.McpOauthUrl(
      id: 'gmail-rest',
      url: _trustedOauthUrl,
      requestId: requestId,
      attemptId: 'attempt-one',
      expiresAt:
          DateTime.now()
              .add(const Duration(minutes: 2))
              .millisecondsSinceEpoch /
          1000,
    );
    service.emitOauth(event);
    service.emitOauth(event);
    await tester.pump();
    expect(opened, hasLength(1));

    await tester.ensureVisible(find.text(strings.mcpCancel));
    await tester.tap(find.text(strings.mcpCancel));
    await tester.pump();
    expect(service.cancelRequests, hasLength(1));
    expect(service.cancelRequests.single['id'], 'gmail-rest');
    expect(service.cancelRequests.single['attempt_id'], 'attempt-one');
  });

  testWidgets('rejects an untrusted Gmail authorization URL', (tester) async {
    final service = _FakeWebSocketService();
    addTearDown(service.dispose);
    final opened = <Uri>[];
    await _openGmailConnector(
      tester,
      service,
      _gmail(),
      launcher: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    final strings = osiaStringsForCode('en');
    final connect = find.text('${strings.mcpConnect} Gmail');
    await tester.ensureVisible(connect);
    await tester.tap(connect);
    await tester.pump();

    final requestId = service.connectRequests.single['request_id']!;
    service.emitOauth(
      const ws.McpOauthUrl(
        id: 'gmail-rest',
        url: _trustedOauthUrl,
        attemptId: 'uncorrelated-attempt',
      ),
    );
    await tester.pump();
    expect(opened, isEmpty);
    expect(service.cancelRequests, isEmpty);

    service.emitOauth(
      ws.McpOauthUrl(
        id: 'gmail-rest',
        url: 'https://example.com/oauth?code=not-trusted',
        requestId: requestId,
        attemptId: 'untrusted-attempt',
      ),
    );
    await tester.pump();

    expect(opened, isEmpty);
    expect(service.cancelRequests, hasLength(1));
    expect(service.cancelRequests.single['attempt_id'], 'untrusted-attempt');
    expect(find.text(strings.linkOpenFailed), findsWidgets);
  });

  testWidgets('expired attempt becomes retryable without restarting the app', (
    tester,
  ) async {
    final service = _FakeWebSocketService();
    addTearDown(service.dispose);
    await _openGmailConnector(
      tester,
      service,
      _gmail(
        connecting: true,
        canConnect: false,
        status: 'authorization_pending',
        attemptId: 'expiring-attempt',
        expiresAt:
            DateTime.now()
                .add(const Duration(seconds: 10))
                .millisecondsSinceEpoch /
            1000,
      ),
    );
    final strings = osiaStringsForCode('en');

    await tester.pump(const Duration(seconds: 12));

    expect(find.text('${strings.mcpConnect} Gmail'), findsOneWidget);
    expect(service.configRequests, greaterThan(0));
  });

  testWidgets(
    'connected capabilities and reconnect/disconnect controls update live',
    (tester) async {
      final service = _FakeWebSocketService();
      addTearDown(service.dispose);
      await _openGmailConnector(tester, service, _gmail());
      final strings = osiaStringsForCode('en');

      service.emitConfig(
        _gmail(
          connected: true,
          status: 'connected',
          canConnect: false,
          canReconnect: true,
          canDisconnect: true,
          capabilities: const <String, bool>{
            'readonly': true,
            'compose': true,
            'modify': true,
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(strings.gmailRestReconnect), findsOneWidget);
      expect(find.text('${strings.mcpDisconnect} Gmail'), findsOneWidget);
      expect(find.text(strings.gmailRestReadOnly), findsOneWidget);
      expect(find.text(strings.gmailRestDraftsSend), findsOneWidget);
      expect(find.text(strings.gmailRestMailboxActions), findsOneWidget);

      await tester.ensureVisible(find.text(strings.gmailRestReconnect));
      await tester.tap(find.text(strings.gmailRestReconnect));
      await tester.pump();
      expect(service.connectRequests, hasLength(1));
      expect(service.connectRequests.single['id'], 'gmail-rest');
    },
  );

  testWidgets('sensitive Gmail fields are neither modeled nor rendered', (
    tester,
  ) async {
    final service = _FakeWebSocketService();
    addTearDown(service.dispose);
    final snapshot = _gmail()
      ..addAll(<String, dynamic>{
        'access_token': 'sensitive-access',
        'refresh_token': 'sensitive-refresh',
        'client_secret': 'sensitive-secret',
        'credential_path': r'C:\private\oauth.json',
      });
    await _openGmailConnector(tester, service, snapshot);

    for (final value in <String>[
      'sensitive-access',
      'sensitive-refresh',
      'sensitive-secret',
      r'C:\private\oauth.json',
    ]) {
      expect(find.textContaining(value), findsNothing);
    }
  });
}
