import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/build_release.dart' as release;

void main() {
  test('Android release signing is production-only and fails closed', () {
    final source = File('android/app/build.gradle.kts').readAsStringSync();
    expect(source, contains('signingConfigs.create("release")'));
    expect(source, contains('signingConfig = releaseSigningConfig'));
    expect(source, isNot(contains('signingConfigs.getByName("debug")')));
    for (final task in <String>[
      'validateSigningRelease',
      'packageRelease',
      'packageReleaseBundle',
      'signReleaseBundle',
    ]) {
      expect(source, contains('"$task"'));
    }
    expect(source, contains('OSIA production signing is not configured.'));
    expect(source, contains('productionSigningConfigurationError'));
  });

  test(
    'Android signing sources are ignored local config or complete CI env',
    () {
      final source = File('android/app/build.gradle.kts').readAsStringSync();
      expect(source, contains('rootProject.file("key.properties")'));
      for (final name in <String>[
        'OSIA_ANDROID_KEYSTORE_PATH',
        'OSIA_ANDROID_KEYSTORE_PASSWORD',
        'OSIA_ANDROID_KEY_ALIAS',
        'OSIA_ANDROID_KEY_PASSWORD',
      ]) {
        expect(source, contains(name));
      }
      expect(source, contains('environmentSigningComplete'));
      expect(source, contains('environmentSigningPresent -> null'));

      final ignored = Process.runSync('git', <String>[
        'check-ignore',
        '-q',
        '--no-index',
        '--',
        'android/key.properties',
      ]);
      expect(ignored.exitCode, 0);

      final tracked = Process.runSync('git', <String>['ls-files']);
      expect(tracked.exitCode, 0);
      final trackedPaths = (tracked.stdout as String).split('\n');
      expect(
        trackedPaths.where(
          (path) =>
              path == 'android/key.properties' ||
              RegExp(
                r'\.(?:jks|keystore|p12|pfx)$',
                caseSensitive: false,
              ).hasMatch(path),
        ),
        isEmpty,
      );
    },
  );

  test('Android attachments use a permissionless document picker', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    for (final permission in <String>[
      'READ_EXTERNAL_STORAGE',
      'WRITE_EXTERNAL_STORAGE',
      'MANAGE_EXTERNAL_STORAGE',
      'READ_MEDIA_IMAGES',
      'READ_MEDIA_VIDEO',
      'READ_MEDIA_AUDIO',
      'READ_MEDIA_DOCUMENTS',
      'READ_MEDIA_VISUAL_USER_SELECTED',
    ]) {
      expect(manifest, isNot(contains(permission)), reason: permission);
    }

    final picker = File('lib/screens/chat_screen.dart').readAsStringSync();
    final start = picker.indexOf('Future<void> _onAttach()');
    final end = picker.indexOf('\n  Future<', start + 1);
    final attachFlow = picker.substring(start, end);
    expect(attachFlow, contains('FilePicker.platform.pickFiles'));
    expect(attachFlow, contains('type: FileType.any'));
    expect(attachFlow, isNot(contains('Permission.')));
    expect(attachFlow, isNot(contains('requestPermissions')));
  });

  test('Android background service is bounded remote messaging', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_REMOTE_MESSAGING'),
    );
    expect(
      manifest,
      contains('android:foregroundServiceType="remoteMessaging"'),
    );
    expect(manifest, contains('android:exported="false"'));
    expect(manifest, isNot(contains('FOREGROUND_SERVICE_DATA_SYNC')));
    expect(
      manifest,
      isNot(contains('android:foregroundServiceType="dataSync"')),
    );

    final service = File(
      'android/app/src/main/kotlin/space/osia/app/'
      'BackgroundConnectionForegroundService.kt',
    ).readAsStringSync();
    expect(service, contains('override fun onTimeout('));
    expect(service, contains('Build.VERSION_CODES.UPSIDE_DOWN_CAKE'));
    expect(service, contains('FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING'));
    expect(service, contains('stopForeground(STOP_FOREGROUND_REMOVE)'));
    expect(service, contains('stopSelf()'));
    expect(service, contains('START_NOT_STICKY'));
    expect(service, isNot(contains('START_STICKY')));
    expect(service, isNot(contains('Timer(')));
    expect(service, isNot(contains('WakeLock')));
  });

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
