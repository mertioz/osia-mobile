import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/build_release.dart' as release;

void main() {
  test(
    'official production capability manifest is direct-first and secret-free',
    () {
      final raw = File(
        'assets/production_capabilities.json',
      ).readAsStringSync();
      final manifest = jsonDecode(raw) as Map<String, dynamic>;
      expect(manifest.keys.toSet(), <String>{
        'build_type',
        'lan_capability',
        'webrtc_capability',
        'relay_capability',
        'transport_protocol_versions',
      });
      expect(manifest['build_type'], 'production');
      expect(manifest['lan_capability'], isTrue);
      expect(manifest['webrtc_capability'], isTrue);
      expect(manifest['relay_capability'], isTrue);
      expect(manifest['transport_protocol_versions'], <String, dynamic>{
        'lan': 1,
        'webrtc': 1,
        'relay': 2,
      });

      final lowercase = raw.toLowerCase();
      for (final forbidden in <String>[
        'host',
        'ip',
        'certificate',
        'pin',
        'pairing',
        'stun',
        'token',
        'secret',
        'credential',
      ]) {
        expect(lowercase, isNot(contains(forbidden)), reason: forbidden);
      }
    },
  );

  test('release policy refuses missing, false, static, or secret fields', () {
    final valid =
        jsonDecode(
              File('assets/production_capabilities.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    expect(release.validateProductionCapabilityPolicy(valid), valid);

    for (final key in <String>[
      'lan_capability',
      'webrtc_capability',
      'relay_capability',
    ]) {
      expect(
        () => release.validateProductionCapabilityPolicy(<String, Object?>{
          ...valid,
          key: false,
        }),
        throwsFormatException,
        reason: key,
      );
      final missing = Map<String, Object?>.from(valid)..remove(key);
      expect(
        () => release.validateProductionCapabilityPolicy(missing),
        throwsFormatException,
        reason: 'missing $key',
      );
    }
    for (final forbidden in <String>[
      'lan_direct_host',
      'certificate_pin',
      'stun_resolved_address',
      'credential',
    ]) {
      expect(
        () => release.validateProductionCapabilityPolicy(<String, Object?>{
          ...valid,
          forbidden: 'forbidden',
        }),
        throwsFormatException,
        reason: forbidden,
      );
    }
  });

  test('release policy requires authenticated runtime ICE consumption', () {
    const signaling = 'webrtc_capabilities ice_servers configuration_id';
    const websocket =
        "frame['type'] == 'webrtc_capabilities' "
        'WebRtcCapability.fromFrame(frame) await decryptFrame(';
    release.validateAuthenticatedIceContractSources(signaling, websocket);
    expect(
      () => release.validateAuthenticatedIceContractSources(
        signaling.replaceFirst('ice_servers', ''),
        websocket,
      ),
      throwsFormatException,
    );
    expect(
      () => release.validateAuthenticatedIceContractSources(
        signaling,
        websocket.replaceFirst('await decryptFrame(', ''),
      ),
      throwsFormatException,
    );
  });

  test('production selection remains LAN then WebRTC then explicit relay', () {
    final source = File(
      'lib/services/websocket_service.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _doConnect({');
    final end = source.indexOf('\n  void _', start);
    final selection = source.substring(start, end);
    final firstLan = selection.indexOf('await _tryLanConnect(');
    final firstWebRtc = selection.indexOf('await _tryWebRtcConnect(');
    final firstRelayCommit = selection.indexOf('await _commitRelayStandby(');
    expect(firstLan, greaterThanOrEqualTo(0));
    expect(firstWebRtc, greaterThan(firstLan));
    expect(firstRelayCommit, greaterThan(firstWebRtc));
    expect(
      selection,
      contains('reconnect blocked while an application request is active'),
    );
    expect(selection, contains('!_hasActiveApplicationTurn'));
  });
}
