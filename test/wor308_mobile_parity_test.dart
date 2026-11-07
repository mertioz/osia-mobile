import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/transport_coordinator.dart';
import 'package:osia_mobile/services/websocket_service.dart';

void main() {
  test('config parsing discards credential values but keeps safe status', () {
    final config = ConfigData.fromJson(<String, dynamic>{
      'api_keys_set': <String, dynamic>{'openai': true, 'mcp:github': true},
      'api_key_fallbacks_set': <String, dynamic>{
        'openai': <bool>[true, true],
      },
      'ui_theme': 'azure',
      'personal_browser_enabled': true,
      'personal_browser_preference': 'brave',
      'personal_browser_instance_hint': 'private-target',
      'api_key_fallbacks': <String, dynamic>{
        'openai': <String>['sk-private-fallback'],
      },
      'mcp_tokens': <String, String>{'github': 'ghp-private-token'},
      'api_keys': <String, String>{'openai': 'sk-private-key'},
    });

    expect(config.apiKeysSet['openai'], isTrue);
    expect(config.apiKeysSet['mcp:github'], isTrue);
    expect(config.settings['ui_theme'], 'azure');
    expect(config.settings.containsKey('personal_browser_enabled'), isFalse);
    expect(config.settings.containsKey('personal_browser_preference'), isFalse);
    expect(
      config.settings.containsKey('personal_browser_instance_hint'),
      isFalse,
    );
    expect(config.settings['api_key_fallbacks_set'], <String, dynamic>{
      'openai': <bool>[true, true],
    });
    expect(config.settings.containsKey('api_key_fallbacks'), isFalse);
    expect(config.settings.containsKey('mcp_tokens'), isFalse);
    expect(config.settings.containsKey('api_keys'), isFalse);
    expect(config.settings.toString(), isNot(contains('sk-private')));
    expect(config.settings.toString(), isNot(contains('ghp-private')));
  });

  test('legacy API-key frames cannot retain raw credential values', () {
    final message = ApiKeysMessage.fromJson(<String, dynamic>{
      'type': 'api_keys',
      'keys': <String, String>{
        'openai': 'sk-private-key',
        'mcp:github': 'ghp-private-token',
      },
      'keys_set': <String, bool>{'openai': true, 'mcp:github': true},
    });

    expect(message.keys, isEmpty);
    expect(message.keysSet, <String, bool>{'openai': true, 'mcp:github': true});
  });

  test('obsolete Mobile product controls are not reachable in current UI', () {
    final main = File('lib/main.dart').readAsStringSync();
    final chat = File('lib/screens/chat_screen.dart').readAsStringSync();
    final settings = File(
      'lib/screens/settings_screen.dart',
    ).readAsStringSync();
    final providers = File(
      'lib/screens/providers_screen.dart',
    ).readAsStringSync();
    final attachments = File(
      'lib/services/attachment_service.dart',
    ).readAsStringSync();

    expect(main, isNot(contains('autonomous_screen.dart')));
    expect(main, isNot(contains("case '/autonomous'")));
    expect(chat, isNot(contains('autonomousStream')));
    expect(chat, isNot(contains('McpConfirmRequest')));
    expect(settings, isNot(contains('PermissionsSettingsEntry')));
    expect(settings, isNot(contains('PermissionsScreen')));
    expect(providers, isNot(contains('vision_provider')));
    expect(providers, isNot(contains('scheduled_task_authorization')));
    expect(attachments, isNot(contains('AutonomousSourceCapability')));
    expect(attachments, isNot(contains("'autonomous'")));
  });

  test('Mobile removes the obsolete browser-session settings surface', () {
    final providers = File(
      'lib/screens/providers_screen.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/screens/settings_screen.dart',
    ).readAsStringSync();

    expect(providers, contains("'stt_fallback_provider'"));
    expect(providers, contains("'stt_local_model'"));
    expect(providers, contains("'stt_groq_model'"));
    expect(providers, isNot(contains('personal_browser_preference')));
    expect(providers, isNot(contains('_BrowserPreferenceScreen')));
    expect(
      File('lib/screens/chat_screen.dart').readAsStringSync(),
      isNot(contains('browserBackendOverride')),
    );
    expect(settings, contains("sendSetSetting('ui_theme', key)"));
  });

  test('PC browser progress is parsed and projected in canonical Chat', () {
    final progress = BrowserProgressMessage.tryParse(<String, dynamic>{
      'type': 'browser_progress',
      'schema_version': 1,
      'event_id': 'browser-event:parity-test',
      'sequence': 1,
      'server_id': 'server-id',
      'session_id': 'browser-session:parity-test',
      'browser_session_id': '',
      'run_id': 'chat',
      'plan_revision': 0,
      'authorization_revision': 0,
      'safe_operation_phase': 'downloading',
      'safe_site_display': 'https://example.test',
      'safe_progress_text': 'Downloading to private storage',
      'artifact_safe_summary': null,
      'terminal': false,
    });

    expect(progress, isNotNull);
    expect(progress!.safeProgressText, 'Downloading to private storage');
    final chat = File('lib/screens/chat_screen.dart').readAsStringSync();
    expect(chat, contains('browserProgressStream'));
    expect(chat, contains('_BrowserProgressProjection'));
    expect(chat, contains('chat-browser-progress'));
  });

  test('browser progress follows a fresh PC session after direct reconnect', () async {
    const token = 'synthetic-pair-token';
    final serverId = sha256
        .convert(utf8.encode('osia-permission-server-v1\u0000$token'))
        .toString();
    final service = WebSocketService(
      ip: '127.0.0.1', token: token, autoReconnect: false,
    );
    addTearDown(service.dispose);
    final sessions = <String>[];
    final subscription = service.browserProgressStream.listen(
      (progress) => sessions.add(progress.sessionId),
    );
    addTearDown(subscription.cancel);

    void emit(String session, int sequence) {
      service.handleIncomingFrameForTest(<String, dynamic>{
        'type': 'browser_progress',
        'schema_version': 1,
        'event_id': '$session-$sequence',
        'sequence': sequence,
        'server_id': serverId,
        'session_id': session,
        'browser_session_id': '',
        'run_id': 'chat',
        'plan_revision': 0,
        'authorization_revision': 0,
        'safe_operation_phase': 'snapshot',
        'safe_site_display': '',
        'safe_progress_text': 'Browser state refreshed',
        'artifact_safe_summary': null,
        'terminal': false,
      });
    }

    service.markDirectTransportConnectedForTest(ApplicationTransportKind.lan);
    emit('before', 2);
    emit('unexpected', 1);
    await Future<void>.delayed(Duration.zero);
    expect(sessions, ['before']);

    service.disconnect();
    service.markDirectTransportConnectedForTest(ApplicationTransportKind.lan);
    emit('after', 1);
    emit('before', 3);
    await Future<void>.delayed(Duration.zero);
    expect(sessions, ['before', 'after']);
  });
}
