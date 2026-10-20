import 'dart:convert';
import 'dart:io';

const _policyPath = 'assets/production_capabilities.json';
const _allowedPolicyKeys = <String>{
  'build_type',
  'lan_capability',
  'webrtc_capability',
  'relay_capability',
  'transport_protocol_versions',
};

Never _fail(String message, [int code = 78]) {
  stderr.writeln(message);
  exit(code);
}

Map<String, Object?> validateProductionCapabilityPolicy(Object? decoded) {
  if (decoded is! Map<String, Object?>) {
    throw const FormatException(
      'Production capability policy must be a JSON object.',
    );
  }
  final keys = decoded.keys.toSet();
  if (keys.length != _allowedPolicyKeys.length ||
      !_allowedPolicyKeys.every(keys.contains)) {
    throw const FormatException(
      'Production capability policy contains missing or forbidden fields. '
      'Static hosts, pins, endpoints, identities, and credentials are forbidden.',
    );
  }
  if (decoded['build_type'] != 'production' ||
      decoded['lan_capability'] != true ||
      decoded['webrtc_capability'] != true ||
      decoded['relay_capability'] != true) {
    throw const FormatException(
      'Official releases require LAN, WebRTC, and relay capabilities.',
    );
  }
  final versions = decoded['transport_protocol_versions'];
  if (versions is! Map<String, Object?> ||
      versions.length != 3 ||
      versions['lan'] != 1 ||
      versions['webrtc'] != 1 ||
      versions['relay'] != 2) {
    throw const FormatException(
      'Production transport protocol versions are missing or invalid.',
    );
  }
  return decoded;
}

Map<String, Object?> _loadPolicy() {
  final file = File(_policyPath);
  if (!file.existsSync()) {
    _fail('Production capability policy is missing: $_policyPath');
  }
  try {
    return validateProductionCapabilityPolicy(
      jsonDecode(file.readAsStringSync()),
    );
  } on FormatException catch (error) {
    _fail(error.message);
  }
}

void validateAuthenticatedIceContractSources(
  String signalingSource,
  String websocketSource,
) {
  for (final marker in <String>[
    'webrtc_capabilities',
    'ice_servers',
    'configuration_id',
  ]) {
    if (!signalingSource.contains(marker)) {
      throw const FormatException(
        'Authenticated runtime ICE configuration contract is incomplete.',
      );
    }
  }
  for (final marker in <String>[
    "frame['type'] == 'webrtc_capabilities'",
    'WebRtcCapability.fromFrame(frame)',
    'await decryptFrame(',
  ]) {
    if (!websocketSource.contains(marker)) {
      throw const FormatException(
        'Authenticated runtime ICE configuration path is incomplete.',
      );
    }
  }
}

void _verifyAuthenticatedIceContract() {
  final signaling = File('lib/services/webrtc_signaling.dart');
  final websocket = File('lib/services/websocket_service.dart');
  if (!signaling.existsSync() || !websocket.existsSync()) {
    _fail('Authenticated runtime ICE configuration sources are missing.');
  }
  try {
    validateAuthenticatedIceContractSources(
      signaling.readAsStringSync(),
      websocket.readAsStringSync(),
    );
  } on FormatException catch (error) {
    _fail(error.message);
  }
}

String productionBuildTarget(String platform, {bool androidAppBundle = false}) {
  if (platform == 'ios') {
    if (androidAppBundle) {
      throw const FormatException('--artifact=appbundle is Android-only.');
    }
    return 'ios';
  }
  if (platform == 'android') {
    return androidAppBundle ? 'appbundle' : 'apk';
  }
  throw FormatException('Unsupported release platform: $platform');
}

String productionAndroidArtifactPath({bool appBundle = false}) => appBundle
    ? 'build/app/outputs/bundle/release/app-release.aab'
    : 'build/app/outputs/flutter-apk/app-release.apk';

int validatedIosBuildNumber(Map<String, String> environment) {
  final maximum = int.tryParse(environment['OSIA_IOS_STORE_MAX_BUILD'] ?? '');
  final selected = int.tryParse(environment['IOS_BUILD_NUMBER'] ?? '');
  if (maximum == null ||
      maximum < 0 ||
      selected == null ||
      selected <= maximum ||
      selected < 19) {
    throw const FormatException(
      'Query App Store Connect first, then supply OSIA_IOS_STORE_MAX_BUILD and a greater IOS_BUILD_NUMBER (minimum 19).',
    );
  }
  return selected;
}

Future<void> main(List<String> arguments) async {
  var platform = 'android';
  var validateOnly = false;
  var androidAppBundle = false;
  for (final argument in arguments) {
    if (argument == '--validate-only') {
      validateOnly = true;
    } else if (argument == '--platform=android' ||
        argument == '--platform=ios') {
      platform = argument.substring('--platform='.length);
    } else if (argument == '--artifact=appbundle') {
      androidAppBundle = true;
    } else {
      _fail('Unknown release build argument: $argument', 64);
    }
  }
  if (platform == 'ios' && androidAppBundle) {
    _fail('--artifact=appbundle is Android-only.', 64);
  }
  if (platform == 'ios' && !Platform.isMacOS && !validateOnly) {
    _fail('Official iOS releases must be built on macOS.', 69);
  }

  final policy = _loadPolicy();
  _verifyAuthenticatedIceContract();
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(policy));
  stdout.writeln(
    'Validated OSIA production release policy '
    '(LAN=true, WebRTC=true, relay=true, authenticated runtime ICE=v1).',
  );
  if (validateOnly) {
    return;
  }

  final target = productionBuildTarget(
    platform,
    androidAppBundle: androidAppBundle,
  );
  final command = <String>[
    'build',
    target,
    '--release',
    '--dart-define=osia_build_type=production',
    '--dart-define=lan_direct_v1=true',
    '--dart-define=webrtc_direct_v1=true',
    '--dart-define=relay_fallback_v1=true',
  ];
  if (platform == 'ios') {
    try {
      command.add(
        '--build-number=${validatedIosBuildNumber(Platform.environment)}',
      );
    } on FormatException catch (error) {
      _fail(error.message);
    }
  }
  stdout.writeln('Building the official OSIA $platform release.');
  if (platform == 'android') {
    stdout.writeln(
      'Expected artifact: ${productionAndroidArtifactPath(appBundle: androidAppBundle)}',
    );
  }
  final process = await Process.start(
    'flutter',
    command,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  exitCode = await process.exitCode;
}
