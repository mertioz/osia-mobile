import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:osia_mobile/services/audio_service.dart';
import 'package:record/record.dart';

class _FakeRecorder implements AudioRecorder {
  bool failStart = false;
  bool failStop = false;
  bool failCancel = false;
  bool disposed = false;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  String? path;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startCalls += 1;
    this.path = path;
    await File(path).writeAsBytes(utf8.encode('private audio payload'));
    if (failStart) {
      throw StateError('start failed for $path with private audio payload');
    }
  }

  @override
  Future<String?> stop() async {
    stopCalls += 1;
    if (failStop) {
      throw StateError('stop failed for $path with private audio payload');
    }
    return path;
  }

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
    if (failCancel) {
      throw StateError('cancel failed for $path with private audio payload');
    }
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SilentPlayer implements AudioPlaybackPlayer {
  bool disposed = false;

  @override
  bool get playing => false;

  @override
  double get volume => 1;

  @override
  Stream<PlayerState> get playerStateStream =>
      const Stream<PlayerState>.empty();

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Future<Duration?> setFilePath(String path) async => null;

  @override
  Future<void> play() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _AudioHarness {
  _AudioHarness(this.directory, this.recorder, this.service);

  final Directory directory;
  final _FakeRecorder recorder;
  final AudioService service;

  static Future<_AudioHarness> create({
    bool failStart = false,
    bool failStop = false,
    bool failCancel = false,
    Future<String> Function(File)? consumeRecording,
    Future<void> Function(File)? deleteRecording,
  }) async {
    final directory = await Directory.systemTemp.createTemp('osia_f09_');
    final recorder = _FakeRecorder()
      ..failStart = failStart
      ..failStop = failStop
      ..failCancel = failCancel;
    final player = _SilentPlayer();
    final playback = AudioPlaybackController(
      player,
      playerPrimed: true,
      temporaryDirectory: () async => directory,
    );
    final service = AudioService(
      recorder: recorder,
      playbackController: playback,
      temporaryDirectory: () async => directory,
      consumeRecording: consumeRecording,
      deleteRecording: deleteRecording,
      recordingPermission: () async => true,
    );
    return _AudioHarness(directory, recorder, service);
  }

  File get recordingFile => File(recorder.path!);

  Future<void> dispose() async {
    await service.dispose();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

void main() {
  test('success keeps the WAV until its final consumer completes', () async {
    final consumerEntered = Completer<void>();
    final releaseConsumer = Completer<void>();
    final harness = await _AudioHarness.create(
      consumeRecording: (file) async {
        expect(await file.exists(), isTrue);
        consumerEntered.complete();
        await releaseConsumer.future;
        return base64Encode(await file.readAsBytes());
      },
    );
    addTearDown(harness.dispose);

    await harness.service.startRecording();
    final stopped = harness.service.stopRecording();
    await consumerEntered.future;

    expect(await harness.recordingFile.exists(), isTrue);
    expect(harness.service.hasOwnedRecording, isTrue);
    releaseConsumer.complete();

    expect(await stopped, isNotEmpty);
    expect(await harness.recordingFile.exists(), isFalse);
    expect(harness.service.hasOwnedRecording, isFalse);
  });

  test('cancellation deletes the file and clears ownership', () async {
    final harness = await _AudioHarness.create();
    addTearDown(harness.dispose);

    await harness.service.startRecording();
    expect(await harness.recordingFile.exists(), isTrue);

    await harness.service.cancelRecording();

    expect(await harness.recordingFile.exists(), isFalse);
    expect(harness.service.isRecording, isFalse);
    expect(harness.service.hasOwnedRecording, isFalse);
  });

  test('recorder cancellation failure still deletes the owned file', () async {
    final harness = await _AudioHarness.create(failCancel: true);
    addTearDown(harness.dispose);
    await harness.service.startRecording();

    await harness.service.cancelRecording();

    expect(harness.recorder.cancelCalls, 1);
    expect(await harness.recordingFile.exists(), isFalse);
    expect(harness.service.isRecording, isFalse);
    expect(harness.service.hasOwnedRecording, isFalse);
  });

  test('start failure after path creation deletes the file', () async {
    final harness = await _AudioHarness.create(failStart: true);
    addTearDown(harness.dispose);

    await expectLater(harness.service.startRecording(), throwsStateError);

    expect(await harness.recordingFile.exists(), isFalse);
    expect(harness.recorder.cancelCalls, 1);
    expect(harness.service.isRecording, isFalse);
    expect(harness.service.hasOwnedRecording, isFalse);
  });

  test('stop failure cancels the recorder and leaves no orphan', () async {
    final harness = await _AudioHarness.create(
      failStop: true,
      failCancel: true,
    );
    addTearDown(harness.dispose);
    await harness.service.startRecording();

    await expectLater(harness.service.stopRecording(), throwsStateError);

    expect(harness.recorder.cancelCalls, 1);
    expect(await harness.recordingFile.exists(), isFalse);
    expect(harness.service.isRecording, isFalse);
    expect(harness.service.hasOwnedRecording, isFalse);
  });

  test('consumer exception deletes the file in finally', () async {
    final harness = await _AudioHarness.create(
      consumeRecording: (file) async {
        expect(await file.exists(), isTrue);
        throw StateError('transcription failed with private audio payload');
      },
    );
    addTearDown(harness.dispose);
    await harness.service.startRecording();

    await expectLater(harness.service.stopRecording(), throwsStateError);

    expect(await harness.recordingFile.exists(), isFalse);
    expect(harness.service.hasOwnedRecording, isFalse);
  });

  test('repeated cleanup is idempotent', () async {
    final harness = await _AudioHarness.create();
    addTearDown(harness.dispose);
    await harness.service.startRecording();

    await harness.service.cancelRecording();
    await harness.service.cancelRecording();

    expect(await harness.recordingFile.exists(), isFalse);
    expect(harness.service.hasOwnedRecording, isFalse);
  });

  test('repeated start cannot silently abandon the owned file', () async {
    final harness = await _AudioHarness.create();
    addTearDown(harness.dispose);
    await harness.service.startRecording();
    final firstPath = harness.recorder.path;

    await expectLater(harness.service.startRecording(), throwsStateError);

    expect(harness.recorder.startCalls, 1);
    expect(harness.recorder.path, firstPath);
    expect(await File(firstPath!).exists(), isTrue);
    expect(harness.service.hasOwnedRecording, isTrue);
  });

  test('dispose best-effort cleans an active owned recording', () async {
    final harness = await _AudioHarness.create(failCancel: true);
    addTearDown(harness.dispose);
    await harness.service.startRecording();
    final file = harness.recordingFile;

    await harness.service.dispose();

    expect(harness.recorder.cancelCalls, 1);
    expect(harness.recorder.disposed, isTrue);
    expect(await file.exists(), isFalse);
    expect(harness.service.hasOwnedRecording, isFalse);
  });

  test('startup scrub deletes only exact regular owned WAV files', () async {
    final directory = await Directory.systemTemp.createTemp('osia_f09_scrub_');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final ownedOne = File('${directory.path}/osia_recording_1.wav');
    final ownedTwo = File('${directory.path}/osia_recording_200.wav');
    final unrelatedWav = File('${directory.path}/meeting.wav');
    final otherExtension = File('${directory.path}/osia_recording_3.mp3');
    final upperExtension = File('${directory.path}/osia_recording_4.WAV');
    final similarName = File('${directory.path}/osia_recording_private.wav');
    final prefixedName = File('${directory.path}/old_osia_recording_5.wav');
    final matchingDirectory = Directory(
      '${directory.path}/osia_recording_6.wav',
    );
    for (final file in <File>[
      ownedOne,
      ownedTwo,
      unrelatedWav,
      otherExtension,
      upperExtension,
      similarName,
      prefixedName,
    ]) {
      await file.writeAsString('not inspected');
    }
    await matchingDirectory.create();
    await File('${matchingDirectory.path}/nested.wav').writeAsString('keep');

    await AudioService.cleanupOrphanedRecordings(
      temporaryDirectory: () async => directory,
    );

    expect(await ownedOne.exists(), isFalse);
    expect(await ownedTwo.exists(), isFalse);
    expect(await unrelatedWav.exists(), isTrue);
    expect(await otherExtension.exists(), isTrue);
    expect(await upperExtension.exists(), isTrue);
    expect(await similarName.exists(), isTrue);
    expect(await prefixedName.exists(), isTrue);
    expect(await matchingDirectory.exists(), isTrue);
    expect(await File('${matchingDirectory.path}/nested.wav').exists(), isTrue);
  });

  test('application startup awaits the orphan scrub before runApp', () async {
    final source = await File('lib/main.dart').readAsString();
    final cleanup = source.indexOf(
      'await AudioService.cleanupOrphanedRecordings();',
    );
    final launch = source.indexOf('runApp(const OsiaApp());');

    expect(cleanup, greaterThanOrEqualTo(0));
    expect(launch, greaterThan(cleanup));
  });

  test('deletion failure clears state and emits no path or audio', () async {
    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    addTearDown(() => debugPrint = originalDebugPrint);
    final harness = await _AudioHarness.create(
      deleteRecording: (file) async {
        throw FileSystemException('private audio payload', file.path);
      },
    );
    addTearDown(harness.dispose);
    await harness.service.startRecording();

    await harness.service.cancelRecording();

    expect(harness.service.hasOwnedRecording, isFalse);
    final diagnostic = logs.join('\n');
    expect(diagnostic, contains('Recording cleanup failed'));
    expect(diagnostic, isNot(contains(harness.directory.path)));
    expect(diagnostic, isNot(contains('private audio payload')));
  });

  test(
    'WebSocket service matches reviewed PC-canonical parity contract checksum',
    () async {
      final bytes = await File(
        'lib/services/websocket_service.dart',
      ).readAsBytes();

      expect(
        sha256.convert(bytes).toString().toUpperCase(),
      'D5B73BA5F31766B245325115242491CF750A5154E66415759BC0C974BA89691E',
      );
    },
  );
}
