import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/heartbeat_settings.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/screens/providers_screen.dart';
import 'package:osia_mobile/services/websocket_service.dart' as ws;
import 'package:osia_mobile/theme.dart';

class _SentSetting {
  final String key;
  final Object? value;

  const _SentSetting(this.key, this.value);
}

class _FakeWebSocketService extends ws.WebSocketService {
  _FakeWebSocketService()
    : super(ip: '127.0.0.1', token: 'token', autoReconnect: false);

  final StreamController<ws.ConfigData> _configCtrl =
      StreamController<ws.ConfigData>.broadcast();
  final StreamController<ws.ConnectionState> _connCtrl =
      StreamController<ws.ConnectionState>.broadcast();
  final StreamController<ws.HeartbeatDataMessage> _heartbeatCtrl =
      StreamController<ws.HeartbeatDataMessage>.broadcast();

  final List<String> sentTypes = [];
  final List<_SentSetting> sentSettings = [];

  @override
  ws.ConnectionState get state => ws.ConnectionState.connected;

  @override
  Stream<ws.ConfigData> get configStream => _configCtrl.stream;

  @override
  Stream<ws.ConnectionState> get connectionStream => _connCtrl.stream;

  @override
  Stream<ws.HeartbeatDataMessage> get heartbeatStream => _heartbeatCtrl.stream;

  @override
  Future<void> ensureConnected({
    String reason = 'unspecified',
    bool forceReconnect = false,
  }) {
    return Future<void>.value();
  }

  @override
  void sendGetConfig() {
    sentTypes.add('get_config');
  }

  @override
  void sendGetModels() {
    sentTypes.add('get_models');
  }

  @override
  void sendGetApiKeys() {
    sentTypes.add('get_api_keys');
  }

  @override
  void sendSetSetting(String key, Object? value) {
    sentSettings.add(_SentSetting(key, value));
  }

  void emitConfig(Map<String, dynamic> settings) {
    _configCtrl.add(ws.ConfigData.fromJson(settings));
  }

  @override
  void dispose() {
    _configCtrl.close();
    _connCtrl.close();
    _heartbeatCtrl.close();
    super.dispose();
  }
}

void main() {
  group('HeartbeatSettings', () {
    test('parses heartbeat thresholds from config', () {
      final settings = HeartbeatSettings.fromSettings({
        heartbeatEnabledSettingKey: true,
        heartbeatIntervalSettingKey: 45,
        heartbeatChecksSettingKey: {
          'cpu': {'enabled': true, 'threshold': 88},
          'ram': {'enabled': false, 'threshold': '91'},
          'disk': {'enabled': true, 'threshold': 12.9},
          'network': {'enabled': false},
        },
      });

      expect(settings.enabled, isTrue);
      expect(settings.intervalSeconds, 45);
      expect(settings.checks['cpu']!.threshold, 88);
      expect(settings.checks['ram']!.enabled, isFalse);
      expect(settings.checks['ram']!.threshold, 91);
      expect(settings.checks['disk']!.threshold, 12);
      expect(settings.checks['network']!.enabled, isFalse);
      expect(settings.checks['network']!.threshold, isNull);
    });

    test('missing threshold config falls back safely', () {
      final absent = HeartbeatSettings.fromSettings({});
      expect(absent.intervalSeconds, HeartbeatSettings.defaultIntervalSeconds);
      expect(absent.checks['cpu']!.enabled, isTrue);
      expect(absent.checks['cpu']!.threshold, 80);
      expect(absent.checks['ram']!.threshold, 90);
      expect(absent.checks['disk']!.threshold, 10);

      final partial = HeartbeatSettings.fromSettings({
        heartbeatChecksSettingKey: {
          'cpu': {'enabled': true},
        },
      });
      expect(partial.checks['cpu']!.threshold, 80);
      expect(partial.checks['ram']!.enabled, isFalse);
      expect(partial.checks['ram']!.threshold, 90);
    });

    test('editing thresholds builds the PC heartbeat_checks payload', () {
      final settings = HeartbeatSettings.fromSettings({
        heartbeatChecksSettingKey: {
          'cpu': {'enabled': true, 'threshold': 80},
          'ram': {'enabled': true, 'threshold': 90},
          'disk': {'enabled': true, 'threshold': 10},
          'network': {'enabled': true},
        },
      }).withThreshold('cpu', '92');

      expect(settings.checksForSettings(), {
        'cpu': {'enabled': true, 'threshold': 92},
        'ram': {'enabled': true, 'threshold': 90},
        'disk': {'enabled': true, 'threshold': 10},
        'network': {'enabled': true},
      });
    });

    test('invalid numeric ranges are clamped like the PC threshold editor', () {
      expect(HeartbeatSettings.sanitizeThreshold('cpu', '-4'), 0);
      expect(HeartbeatSettings.sanitizeThreshold('ram', '150'), 100);
      expect(HeartbeatSettings.sanitizeThreshold('disk', ''), 10);
      expect(HeartbeatSettings.sanitizeInterval('5'), 10);
      expect(HeartbeatSettings.sanitizeInterval('500'), 300);
    });
  });

  group('System status heartbeat UI', () {
    Future<_FakeWebSocketService> pumpSystemStatus(
      WidgetTester tester,
      Map<String, dynamic> settings,
    ) async {
      final service = _FakeWebSocketService();
      addTearDown(service.dispose);

      await tester.pumpWidget(
        OsiaTheme(
          palette: osiaPaletteViolet,
          child: OsiaL10n(
            strings: osiaStringsForCode('en'),
            child: MaterialApp(
              home: Scaffold(body: SystemSettingsSection(wsService: service)),
            ),
          ),
        ),
      );
      await tester.pump();
      service.emitConfig(settings);
      await tester.pump();
      await tester.tap(find.text('System status'));
      await tester.pumpAndSettle();
      return service;
    }

    testWidgets('shows heartbeat threshold fields from config', (tester) async {
      await pumpSystemStatus(tester, {
        heartbeatChecksSettingKey: {
          'cpu': {'enabled': true, 'threshold': 83},
          'ram': {'enabled': true, 'threshold': 94},
          'disk': {'enabled': true, 'threshold': 15},
          'network': {'enabled': true},
        },
      });

      expect(find.byKey(const ValueKey('heartbeat_cpu_threshold')), findsOne);
      expect(find.byKey(const ValueKey('heartbeat_ram_threshold')), findsOne);
      expect(find.byKey(const ValueKey('heartbeat_disk_threshold')), findsOne);
      expect(find.byKey(const ValueKey('heartbeat_network_enabled')), findsOne);
    });

    testWidgets('editing a threshold sends heartbeat_checks', (tester) async {
      final service = await pumpSystemStatus(tester, {
        heartbeatChecksSettingKey: {
          'cpu': {'enabled': true, 'threshold': 80},
          'ram': {'enabled': true, 'threshold': 90},
          'disk': {'enabled': true, 'threshold': 10},
          'network': {'enabled': true},
        },
      });

      await tester.enterText(
        find.byKey(const ValueKey('heartbeat_cpu_threshold')),
        '92',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final sent = service.sentSettings.lastWhere(
        (setting) => setting.key == heartbeatChecksSettingKey,
      );
      final value = sent.value as Map<String, dynamic>;
      expect(value['cpu'], {'enabled': true, 'threshold': 92});
      expect(value['ram'], {'enabled': true, 'threshold': 90});
      expect(value['disk'], {'enabled': true, 'threshold': 10});
      expect(value['network'], {'enabled': true});
    });

    testWidgets('clamps invalid threshold edits before saving', (tester) async {
      final service = await pumpSystemStatus(tester, {
        heartbeatChecksSettingKey: {
          'cpu': {'enabled': true, 'threshold': 80},
          'ram': {'enabled': true, 'threshold': 90},
          'disk': {'enabled': true, 'threshold': 10},
          'network': {'enabled': true},
        },
      });

      await tester.enterText(
        find.byKey(const ValueKey('heartbeat_ram_threshold')),
        '150',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final sent = service.sentSettings.lastWhere(
        (setting) => setting.key == heartbeatChecksSettingKey,
      );
      final value = sent.value as Map<String, dynamic>;
      expect(value['ram'], {'enabled': true, 'threshold': 100});
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('heartbeat_ram_threshold')),
      );
      expect(field.controller!.text, '100');
    });

    testWidgets('interval editing still sends heartbeat interval seconds', (
      tester,
    ) async {
      final service = await pumpSystemStatus(tester, {
        heartbeatIntervalSettingKey: 30,
        heartbeatChecksSettingKey: {
          'cpu': {'enabled': true, 'threshold': 80},
          'ram': {'enabled': true, 'threshold': 90},
          'disk': {'enabled': true, 'threshold': 10},
          'network': {'enabled': true},
        },
      });

      await tester.enterText(
        find.byKey(const ValueKey('heartbeat_interval_seconds')),
        '5',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final sent = service.sentSettings.lastWhere(
        (setting) => setting.key == heartbeatIntervalSettingKey,
      );
      expect(sent.value, 10);
    });

    testWidgets('config refresh updates displayed heartbeat thresholds', (
      tester,
    ) async {
      final service = await pumpSystemStatus(tester, {
        heartbeatChecksSettingKey: {
          'cpu': {'enabled': true, 'threshold': 80},
          'ram': {'enabled': true, 'threshold': 90},
          'disk': {'enabled': true, 'threshold': 10},
          'network': {'enabled': true},
        },
      });

      service.emitConfig({
        heartbeatChecksSettingKey: {
          'cpu': {'enabled': true, 'threshold': 71},
          'ram': {'enabled': true, 'threshold': 89},
          'disk': {'enabled': true, 'threshold': 11},
          'network': {'enabled': true},
        },
      });
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('heartbeat_cpu_threshold')),
      );
      expect(field.controller!.text, '71');
    });
  });
}
