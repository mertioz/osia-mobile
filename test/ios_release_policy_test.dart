import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

String _plistString(String source, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]+)</string>',
  ).firstMatch(source);
  expect(match, isNotNull, reason: 'Missing plist string $key');
  return match!.group(1)!;
}

void main() {
  test('iOS bundle identifier and multicast entitlement stay wired', () {
    final project = _read('ios/Runner.xcodeproj/project.pbxproj');
    final entitlements = _read('ios/Runner/Runner.entitlements');
    final workflow = _read('codemagic.yaml');

    expect(
      RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER = space\.osia\.app;',
      ).allMatches(project),
      hasLength(3),
    );
    expect(
      RegExp(
        r'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;',
      ).allMatches(project),
      hasLength(3),
    );
    expect(
      entitlements,
      contains(
        '<key>com.apple.developer.networking.multicast</key>\n\t<true/>',
      ),
    );
    expect(workflow, contains('BUNDLE_ID: space.osia.app'));
  });

  test('iOS local-network disclosure matches the exact Bonjour browser', () {
    final info = _read('ios/Runner/Info.plist');
    final discovery = _read('lib/services/lan_discovery_service.dart');
    final usage = _plistString(info, 'NSLocalNetworkUsageDescription');
    final servicesBlock = RegExp(
      r'<key>NSBonjourServices</key>\s*<array>([\s\S]*?)</array>',
    ).firstMatch(info);

    expect(usage, contains('réseau local'));
    expect(usage, contains('PC associé'));
    expect(usage, contains('chiffrée'));
    expect(servicesBlock, isNotNull);
    expect(
      RegExp(
        r'<string>([^<]+)</string>',
      ).allMatches(servicesBlock!.group(1)!).map((match) => match.group(1)),
      <String?>['_osia._tcp'],
    );
    expect(
      discovery,
      contains("const String lanDiscoveryServiceType = '_osia._tcp.local';"),
    );
    expect(
      discovery,
      contains('ResourceRecordQuery.serverPointer(lanDiscoveryServiceType)'),
    );
  });

  test('Codemagic uses scripted signing and TestFlight internal only', () {
    final workflow = _read('codemagic.yaml');

    expect(workflow, contains('ios-testflight-internal:'));
    expect(workflow, contains('app_store_connect: osia-testflight'));
    expect(workflow, contains('groups:\n        - osia_app_store'));
    expect(workflow, isNot(contains('ios_signing:')));
    expect(workflow, isNot(contains('distribution_type:')));
    expect(workflow, contains('BUNDLE_ID: space.osia.app'));
    expect(workflow, contains(r'${APP_STORE_APPLE_ID:-}'));
    expect(
      workflow,
      contains(
        'app-store-connect fetch-signing-files "\$BUNDLE_ID" \\\n'
        '            --type IOS_APP_STORE \\\n'
        '            --create',
      ),
    );
    expect(workflow, contains('script: keychain initialize'));
    expect(workflow, contains('script: keychain add-certificates'));
    expect(
      workflow,
      contains(
        "--custom-export-options='{\"testFlightInternalTestingOnly\": true}'",
      ),
    );
    expect(workflow, contains('auth: integration'));
    expect(workflow, contains('submit_to_testflight: true'));
    expect(workflow, contains('beta_groups:\n          - OSIA Internal'));
    expect(workflow, contains('submit_to_app_store: false'));
    expect(workflow, isNot(contains('submit_to_app_store: true')));

    final initialize = workflow.indexOf('script: keychain initialize');
    final fetch = workflow.indexOf('app-store-connect fetch-signing-files');
    final addCertificates = workflow.indexOf(
      'script: keychain add-certificates',
    );
    final useProfiles = workflow.indexOf('xcode-project use-profiles');
    expect(initialize, greaterThanOrEqualTo(0));
    expect(fetch, greaterThan(initialize));
    expect(addCertificates, greaterThan(fetch));
    expect(useProfiles, greaterThan(addCertificates));

    expect(
      workflow,
      isNot(
        matches(
          RegExp(
            r'^\s*(provisioning_profiles|certificates|certificate|profile):',
            multiLine: true,
          ),
        ),
      ),
    );
  });

  test(
    'Codemagic preserves pubspec version until App Store requires a bump',
    () {
      final pubspec = _read('pubspec.yaml');
      final workflow = _read('codemagic.yaml');

      expect(pubspec, contains('version: 1.0.1+2'));
      expect(workflow, contains(r'configured="$(sed -nE'));
      expect(workflow, contains(r'if [ "$latest" -ge "$configured" ]; then'));
      expect(workflow, contains(r'selected=$((latest + 1))'));
      expect(workflow, contains(r'selected="$configured"'));
      expect(workflow, contains(r'--build-number="$IOS_BUILD_NUMBER"'));
      expect(workflow, isNot(contains('--build-name=')));
    },
  );
}
