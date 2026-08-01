import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/l10n.dart';

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
}
