import 'dart:io';

Future<void> main(List<String> arguments) async {
  const enableFlag = '--enable-webrtc';
  final unknown = arguments
      .where((argument) => argument != enableFlag)
      .toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown release build argument: ${unknown.first}');
    exitCode = 64;
    return;
  }

  final enableWebRtc = arguments.contains(enableFlag);
  if (enableWebRtc &&
      Platform.environment['OSIA_PRODUCTION_STUN_APPROVED'] != '1') {
    stderr.writeln(
      'WebRTC release activation requires '
      'OSIA_PRODUCTION_STUN_APPROVED=1 and a configured production endpoint.',
    );
    exitCode = 78;
    return;
  }

  final command = <String>[
    'build',
    'apk',
    '--release',
    '--dart-define=lan_direct_v1=true',
    '--dart-define=webrtc_direct_v1=$enableWebRtc',
  ];
  stdout.writeln(
    'Building OSIA Mobile release (LAN=true, WebRTC=$enableWebRtc).',
  );
  final process = await Process.start(
    'flutter',
    command,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  exitCode = await process.exitCode;
}
