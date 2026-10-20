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

void _expectPurposeString(
  String source,
  String key, {
  required List<String> requiredPhrases,
}) {
  final value = _plistString(source, key).trim();
  expect(value, isNotEmpty, reason: '$key must not be empty');
  expect(value.length, greaterThanOrEqualTo(40), reason: '$key is too vague');
  final normalized = value.toLowerCase();
  for (final placeholder in <String>{
    'this app needs access.',
    'required for the app.',
    'permission required.',
  }) {
    expect(normalized, isNot(placeholder), reason: '$key is a placeholder');
  }
  for (final phrase in requiredPhrases) {
    expect(normalized, contains(phrase), reason: '$key must mention $phrase');
  }
}

void main() {
  test('iOS export compliance metadata matches operator approval', () {
    final info = _read('ios/Runner/Info.plist');
    expect(
      info,
      contains('<key>ITSAppUsesNonExemptEncryption</key>\n\t<true/>'),
    );
    expect(
      _plistString(info, 'ITSEncryptionExportComplianceCode'),
      '1030850b-a772-4efa-bb8d-1f07a1c65030',
    );
  });

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

  test('iOS protected-resource purposes match exposed application flows', () {
    final info = _read('ios/Runner/Info.plist');
    final chat = _read('lib/screens/chat_screen.dart');

    _expectPurposeString(
      info,
      'NSPhotoLibraryUsageDescription',
      requiredPhrases: <String>[
        'photo library',
        'explicitly',
        'image',
        'attach',
        'conversation',
      ],
    );
    _expectPurposeString(
      info,
      'NSCameraUsageDescription',
      requiredPhrases: <String>[
        'camera',
        'explicitly',
        'capture',
        'image',
        'attach',
        'conversation',
        'pairing',
        'qr code',
      ],
    );
    _expectPurposeString(
      info,
      'NSMicrophoneUsageDescription',
      requiredPhrases: <String>['microphone', 'osia'],
    );
    expect(chat, contains('FilePicker.platform.pickFiles('));
    expect(chat, contains('type: FileType.any'));
  });

  test('iOS location permission is not declared or enabled', () {
    final info = _read('ios/Runner/Info.plist');
    final podfile = _read('ios/Podfile');
    final androidManifest = _read('android/app/src/main/AndroidManifest.xml');
    final appSource = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(info, isNot(contains('NSLocationWhenInUseUsageDescription')));
    expect(podfile, isNot(contains('PERMISSION_LOCATION=1')));
    expect(podfile, isNot(contains('PERMISSION_LOCATION_WHENINUSE=1')));
    expect(androidManifest, isNot(contains('ACCESS_FINE_LOCATION')));
    expect(androidManifest, isNot(contains('ACCESS_COARSE_LOCATION')));
    expect(
      appSource,
      isNot(
        matches(
          RegExp(
            r'Permission\.(?:location|locationWhenInUse|locationAlways)\b',
          ),
        ),
      ),
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

  test('Codemagic excludes only host-sensitive guide goldens', () {
    final workflow = _read('codemagic.yaml');
    final guideTests = _read('test/guide_asset_capture_test.dart');
    final testStep = RegExp(
      r'- name: Run Flutter tests\n\s+script:\s*([^\n]+)',
    ).firstMatch(workflow);

    expect(testStep, isNotNull);
    final testCommand = testStep!.group(1)!.trim();
    expect(testCommand, 'flutter test --exclude-tags guide-golden');
    final excludedTagMatches = RegExp(
      r'--exclude-tags(?:=|\s+)([^\s]+)',
    ).allMatches(workflow);
    expect(excludedTagMatches, hasLength(2));
    expect(excludedTagMatches.map((match) => match.group(1)).toSet(), <String?>{
      'guide-golden',
    });
    expect(workflow, isNot(contains('|| true')));
    expect(workflow, isNot(contains('continue_on_error')));
    expect(workflow, isNot(contains('ignore_failure')));
    expect(workflow, isNot(contains('allow_failure')));

    expect(guideTests, contains("const _guideGoldenTag = 'guide-golden';"));
    expect(
      RegExp(r'tags:\s*_guideGoldenTag').allMatches(guideTests),
      hasLength(3),
    );
    expect(RegExp(r'testWidgets\(').allMatches(guideTests), hasLength(3));
    expect(RegExp(r'matchesGoldenFile\(').allMatches(guideTests), hasLength(3));
    expect(guideTests, isNot(contains('skip:')));
    expect(guideTests, isNot(contains('Platform.isMacOS')));
    final testConfig = File('dart_test.yaml');
    expect(testConfig.existsSync(), isTrue);
    final testConfiguration = _read(testConfig.path);
    expect(testConfiguration, 'tags:\n  guide-golden:\n');
    expect(testConfiguration, isNot(contains('skip')));
    expect(
      testConfiguration,
      isNot(
        matches(RegExp(r'exclude[_-]tags?:.*guide-golden', multiLine: true)),
      ),
    );

    final tests = workflow.indexOf('- name: Run Flutter tests');
    final initialize = workflow.indexOf('- name: Initialize signing keychain');
    final fetch = workflow.indexOf(
      '- name: Fetch fresh App Store signing files',
    );
    final addCertificates = workflow.indexOf(
      '- name: Add signing certificate to keychain',
    );
    final useProfiles = workflow.indexOf(
      '- name: Apply App Store signing profile',
    );
    expect(tests, greaterThanOrEqualTo(0));
    expect(initialize, greaterThan(tests));
    expect(fetch, greaterThan(initialize));
    expect(addCertificates, greaterThan(fetch));
    expect(useProfiles, greaterThan(addCertificates));

    expect(workflow, contains('submit_to_testflight: true'));
    expect(workflow, contains('beta_groups:\n          - OSIA Internal'));
    expect(
      workflow,
      contains(
        "--custom-export-options='{\"testFlightInternalTestingOnly\": true}'",
      ),
    );
    expect(workflow, contains('submit_to_app_store: false'));
    expect(workflow, isNot(contains('submit_to_app_store: true')));
  });

  test(
    'release candidate keeps product version and queries all store builds',
    () {
      final pubspec = _read('pubspec.yaml');
      final workflow = _read('codemagic.yaml');

      expect(pubspec, contains('version: 0.9.5+19'));
      expect(pubspec, isNot(contains('version: 1.0.1+2')));
      final candidateStart = workflow.indexOf('  ios-release-candidate:\n');
      final internalStart = workflow.indexOf('  ios-testflight-internal:\n');
      expect(candidateStart, greaterThanOrEqualTo(0));
      expect(internalStart, greaterThan(candidateStart));
      final candidate = workflow.substring(candidateStart, internalStart);

      expect(candidate, contains('--all-versions'));
      expect(candidate, contains('--type IOS_APP_STORE'));
      expect(candidate, contains('xcode-project use-profiles'));
      expect(candidate, contains('flutter build ipa --release'));
      expect(candidate, contains('get-latest-build-number'));
      expect(candidate, contains('--build-number='));
      expect(candidate, isNot(contains('--build-name=')));
      expect(candidate, isNot(contains('testFlightInternalTestingOnly')));
      expect(candidate, isNot(contains('triggering:')));
      expect(candidate, contains('submit_to_testflight: true'));
      expect(candidate, contains('submit_to_app_store: false'));
    },
  );
}
