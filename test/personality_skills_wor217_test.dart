import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';
import 'package:osia_mobile/skill_activation_guard.dart';

void main() {
  test('personality and skills remain a PC-authoritative mirror', () {
    final source = File('lib/screens/providers_screen.dart').readAsStringSync();
    final websocket = File(
      'lib/services/websocket_service.dart',
    ).readAsStringSync();

    expect(source, contains('widget.config.personality'));
    expect(source, contains('widget.wsService.configStream.listen'));
    expect(source, contains('_personalityDirty'));
    expect(source, contains('!_personalityDirty'));
    expect(source, contains('_pendingPersonalitySave == data.personality'));
    expect(source, contains('_personalityCtrl.text = data.personality'));
    expect(source, contains('widget.wsService.sendSetPersonality'));
    expect(source, contains('SkillActivationGuard'));
    expect(source, contains("data.settings['skills_state_revision']"));
    expect(source, contains("data.settings['skills_enabled']"));
    expect(source, contains('widget.wsService.sendGetConfig()'));
    expect(source, isNot(contains("File('personality")));
    expect(websocket, contains("_send({'type': 'set_personality'"));
    expect(websocket, contains("'type': 'set_skill', 'name': name"));
    expect(websocket, contains('_send(msg)'));
  });

  test('localized copy does not advertise skills as new capabilities', () {
    expect(osiaStringsEn.personalityDesc, contains('do not add tools'));
    expect(osiaStringsEn.personalityDesc, contains('permissions'));
    expect(osiaStringsFr.personalityDesc, contains("n'ajoutent ni outils"));
    expect(osiaStringsFr.personalityDesc, contains('autorisations'));
    expect(osiaStringsZh.personalityDesc, contains('不会添加工具、权限或功能'));
    expect(osiaStringsJa.personalityDesc, contains('ツール・権限・機能を追加するものではありません'));
    expect(
      osiaStringsDe.personalityDesc,
      contains('keine Tools, Berechtigungen oder Fähigkeiten'),
    );
    expect(
      osiaStringsEs.personalityDesc,
      contains('no añaden herramientas, permisos ni capacidades'),
    );
  });

  test('skill activation ignores stale snapshots and honors PC rejection', () {
    final guard = SkillActivationGuard(initialRevision: 7);
    guard.begin('valid.md', true);

    expect(guard.acceptSnapshot(6), isFalse);
    expect(guard.acceptSnapshot(7), isTrue);
    final pending = guard.reconcile(
      name: 'valid.md',
      requested: false,
      effective: false,
    );
    expect(pending.enabled, isTrue);
    expect(pending.confirmed, isFalse);

    expect(guard.acceptSnapshot(8), isTrue);
    final enabled = guard.reconcile(
      name: 'valid.md',
      requested: true,
      effective: true,
    );
    expect(enabled.enabled, isTrue);
    expect(enabled.confirmed, isTrue);
    expect(enabled.rejected, isFalse);

    expect(guard.acceptSnapshot(9), isTrue);
    final edited = guard.reconcile(
      name: 'valid.md',
      requested: true,
      effective: true,
    );
    expect(edited.enabled, isTrue);

    // A frame queued before the confirmed mutation can no longer turn it off.
    expect(guard.acceptSnapshot(8), isFalse);

    guard.begin('invalid.md', true);
    expect(guard.acceptSnapshot(10), isTrue);
    final rejected = guard.reconcile(
      name: 'invalid.md',
      requested: true,
      effective: false,
    );
    expect(rejected.enabled, isFalse);
    expect(rejected.confirmed, isTrue);
    expect(rejected.rejected, isTrue);
    expect(osiaStringsEn.skillActivationRejected, contains('PC kept'));

    guard.begin('valid.md', false);
    expect(guard.acceptSnapshot(11), isTrue);
    final disabled = guard.reconcile(
      name: 'valid.md',
      requested: false,
      effective: false,
    );
    expect(disabled.enabled, isFalse);
    expect(disabled.confirmed, isTrue);
  });
}
