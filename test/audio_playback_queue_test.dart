import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:osia_mobile/services/audio_service.dart';

String _clip(String value) => base64Encode(utf8.encode(value));

class _SetFileGate {
  _SetFileGate({this.error});

  final Object? error;
  final Completer<String> entered = Completer<String>();
  final Completer<void> release = Completer<void>();
}

class _VolumeGate {
  final Completer<double> entered = Completer<double>();
  final Completer<void> release = Completer<void>();
}

class _PlayGate {
  final Completer<String> entered = Completer<String>();
  final Completer<void> release = Completer<void>();
}

class _GatedAudioPlayer implements AudioPlaybackPlayer {
  final StreamController<PlayerState> _states =
      StreamController<PlayerState>.broadcast(sync: true);
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast(sync: true);
  final ListQueue<_SetFileGate> _setFileGates = ListQueue<_SetFileGate>();
  final ListQueue<_VolumeGate> _volumeGates = ListQueue<_VolumeGate>();
  final ListQueue<_PlayGate> _playGates = ListQueue<_PlayGate>();

  final List<String> setFileAttempts = <String>[];
  final List<String> setFileMutations = <String>[];
  final List<String> playInvocations = <String>[];
  final List<String> audiblePlays = <String>[];
  final List<double> volumeAttempts = <double>[];

  String? _loaded;
  _PlayGate? _activePlayGate;
  bool _playing = false;
  bool disposed = false;
  double _volume = 1;
  int stopCalls = 0;
  int activePlays = 0;
  int maxActivePlays = 0;

  _SetFileGate gateNextSetFile({Object? error}) {
    final gate = _SetFileGate(error: error);
    _setFileGates.add(gate);
    return gate;
  }

  _VolumeGate gateNextVolume() {
    final gate = _VolumeGate();
    _volumeGates.add(gate);
    return gate;
  }

  _PlayGate gateNextPlay() {
    final gate = _PlayGate();
    _playGates.add(gate);
    return gate;
  }

  @override
  bool get playing => _playing;

  @override
  double get volume => _volume;

  @override
  Stream<PlayerState> get playerStateStream => _states.stream;

  @override
  Stream<Duration> get positionStream => _positions.stream;

  @override
  Future<Duration?> setFilePath(String path) async {
    final payload = utf8.decode(await File(path).readAsBytes());
    setFileAttempts.add(payload);
    if (_setFileGates.isNotEmpty) {
      final gate = _setFileGates.removeFirst();
      gate.entered.complete(payload);
      await gate.release.future;
      if (gate.error != null) throw gate.error!;
    }
    _loaded = payload;
    setFileMutations.add(payload);
    return null;
  }

  @override
  Future<void> play() async {
    final payload = _loaded ?? '<unloaded>';
    playInvocations.add(payload);
    if (_volume > 0) audiblePlays.add(payload);
    activePlays += 1;
    if (activePlays > maxActivePlays) maxActivePlays = activePlays;
    _playing = true;
    _states.add(PlayerState(true, ProcessingState.ready));
    try {
      if (_playGates.isNotEmpty) {
        final gate = _playGates.removeFirst();
        _activePlayGate = gate;
        gate.entered.complete(payload);
        await gate.release.future;
      }
    } finally {
      _activePlayGate = null;
      _playing = false;
      activePlays -= 1;
      _states.add(PlayerState(false, ProcessingState.completed));
    }
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    _playing = false;
    final gate = _activePlayGate;
    if (gate != null && !gate.release.isCompleted) gate.release.complete();
    _states.add(PlayerState(false, ProcessingState.ready));
  }

  @override
  Future<void> setVolume(double volume) async {
    volumeAttempts.add(volume);
    if (_volumeGates.isNotEmpty) {
      final gate = _volumeGates.removeFirst();
      gate.entered.complete(volume);
      await gate.release.future;
    }
    _volume = volume;
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await _states.close();
    await _positions.close();
  }
}

class _PlaybackHarness {
  _PlaybackHarness(this.directory, this.player, this.controller);

  final Directory directory;
  final _GatedAudioPlayer player;
  final AudioPlaybackController controller;

  static Future<_PlaybackHarness> create({bool playerPrimed = true}) async {
    final directory = await Directory.systemTemp.createTemp('osia_wor135_');
    final player = _GatedAudioPlayer();
    final controller = AudioPlaybackController(
      player,
      playerPrimed: playerPrimed,
      temporaryDirectory: () async => directory,
    );
    return _PlaybackHarness(directory, player, controller);
  }

  Future<List<FileSystemEntity>> files() => directory.list().toList();

  Future<void> dispose() async {
    await controller.dispose();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

Future<void> _expectSetupCancellationRecovery({
  required bool playerPrimed,
}) async {
  final harness = await _PlaybackHarness.create(playerPrimed: playerPrimed);
  addTearDown(harness.dispose);
  final gate = harness.player.gateNextSetFile();

  final stale = harness.controller.playMp3(_clip('generation-a'));
  expect(await gate.entered.future, 'generation-a');

  var cancellationCompleted = false;
  final cancellation = harness.controller.stopPlayback();
  unawaited(cancellation.then((_) => cancellationCompleted = true));
  final current = harness.controller.playMp3(_clip('generation-b'));

  expect(cancellationCompleted, isFalse);
  expect(harness.player.playInvocations, isEmpty);
  gate.release.complete();
  await Future.wait<void>(<Future<void>>[stale, cancellation, current]);

  expect(harness.player.playInvocations, isNot(contains('generation-a')));
  expect(harness.player.audiblePlays, <String>['generation-b']);
  expect(harness.player.setFileMutations.last, 'generation-b');
  expect(harness.player.maxActivePlays, 1);
  expect(await harness.files(), isEmpty);
}

void main() {
  test('native stopped state releases a hanging play future', () async {
    final states = StreamController<PlayerState>.broadcast();
    final hangingPlay = Completer<void>();

    final playback = playUntilStopped(() => hangingPlay.future, states.stream);
    states.add(PlayerState(false, ProcessingState.ready));
    states.add(PlayerState(true, ProcessingState.ready));
    states.add(PlayerState(false, ProcessingState.ready));

    await playback.timeout(const Duration(seconds: 1));
    expect(hangingPlay.isCompleted, isFalse);
    await states.close();
  });

  test('stale completed state before playback starts is ignored', () async {
    final states = StreamController<PlayerState>.broadcast();
    final hangingPlay = Completer<void>();
    var finished = false;

    final playback = playUntilStopped(() => hangingPlay.future, states.stream);
    unawaited(playback.then((_) => finished = true));
    states.add(PlayerState(false, ProcessingState.completed));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(finished, isFalse);

    states.add(PlayerState(true, ProcessingState.ready));
    states.add(PlayerState(false, ProcessingState.completed));
    await playback.timeout(const Duration(seconds: 1));
    expect(finished, isTrue);
    await states.close();
  });

  test('play future completion remains a valid terminal signal', () async {
    final states = StreamController<PlayerState>.broadcast();
    final playFinished = Completer<void>();

    final playback = playUntilStopped(() => playFinished.future, states.stream);
    playFinished.complete();

    await playback.timeout(const Duration(seconds: 1));
    await states.close();
  });

  test(
    'cancellation releases hanging playback and terminal listeners',
    () async {
      final states = StreamController<PlayerState>.broadcast();
      final hangingPlay = Completer<void>();
      final cancellation = Completer<void>();

      final playback = playUntilStopped(
        () => hangingPlay.future,
        states.stream,
        cancellation: cancellation.future,
        expectedDuration: const Duration(hours: 1),
      );
      cancellation.complete();

      await playback.timeout(const Duration(seconds: 1));
      expect(hangingPlay.isCompleted, isFalse);
      await states.close();
    },
  );

  test(
    'decoded duration releases playback when all platform signals hang',
    () async {
      final states = StreamController<PlayerState>.broadcast();
      final hangingPlay = Completer<void>();

      final playback = playUntilStopped(
        () => hangingPlay.future,
        states.stream,
        expectedDuration: const Duration(milliseconds: 1),
        completionGrace: Duration.zero,
      );

      await playback.timeout(const Duration(seconds: 1));
      expect(hangingPlay.isCompleted, isFalse);
      await states.close();
    },
  );

  test('position idle releases playback when terminal signals hang', () async {
    final states = StreamController<PlayerState>.broadcast();
    final positions = StreamController<Duration>.broadcast();
    final hangingPlay = Completer<void>();

    final playback = playUntilStopped(
      () => hangingPlay.future,
      states.stream,
      positions: positions.stream,
      progressIdleGrace: const Duration(milliseconds: 10),
    );
    states.add(PlayerState(true, ProcessingState.ready));
    positions.add(const Duration(milliseconds: 100));
    positions.add(const Duration(milliseconds: 200));

    await playback.timeout(const Duration(seconds: 1));
    expect(hangingPlay.isCompleted, isFalse);
    await states.close();
    await positions.close();
  });

  test('successive clips play in exact FIFO order without overlap', () async {
    final started = <String>[];
    final gates = <String, Completer<void>>{};
    var active = 0;
    var maxActive = 0;
    final queue = AudioPlaybackQueue((data) async {
      started.add(data);
      active += 1;
      maxActive = active > maxActive ? active : maxActive;
      final gate = Completer<void>();
      gates[data] = gate;
      await gate.future;
      active -= 1;
    }, () async {});

    final first = queue.add('first');
    final second = queue.add('second');
    final third = queue.add('third');
    await Future<void>.delayed(Duration.zero);
    expect(started, <String>['first']);

    gates['first']!.complete();
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(started, <String>['first', 'second']);

    gates['second']!.complete();
    await second;
    await Future<void>.delayed(Duration.zero);
    expect(started, <String>['first', 'second', 'third']);
    gates['third']!.complete();
    await third;

    expect(maxActive, 1);
    await queue.dispose();
    expect(queue.workerActive, isFalse);
  });

  test(
    'cancel clears pending clips and a new generation stays isolated',
    () async {
      final started = <String>[];
      Completer<void>? activeGate;
      final queue = AudioPlaybackQueue(
        (data) async {
          started.add(data);
          activeGate = Completer<void>();
          await activeGate!.future;
        },
        () async {
          if (activeGate != null && !activeGate!.isCompleted) {
            activeGate!.complete();
          }
        },
      );

      final oldActive = queue.add('old-active');
      final oldPending = queue.add('old-pending');
      await Future<void>.delayed(Duration.zero);
      expect(started, <String>['old-active']);

      await queue.cancel();
      await oldActive;
      await oldPending;
      expect(started, <String>['old-active']);

      final current = queue.add('current');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(started, <String>['old-active', 'current']);
      activeGate!.complete();
      await current;
      await queue.dispose();
    },
  );

  test('cold blocked setFilePath never plays stale generation', () async {
    await _expectSetupCancellationRecovery(playerPrimed: false);
  });

  test('primed blocked setFilePath never plays stale generation', () async {
    await _expectSetupCancellationRecovery(playerPrimed: true);
  });

  test('cancellation before temporary file creation skips all setup', () async {
    final directory = await Directory.systemTemp.createTemp('osia_wor135_');
    final player = _GatedAudioPlayer();
    final temporaryDirectoryRequested = Completer<void>();
    final temporaryDirectory = Completer<Directory>();
    final controller = AudioPlaybackController(
      player,
      playerPrimed: true,
      temporaryDirectory: () {
        if (!temporaryDirectoryRequested.isCompleted) {
          temporaryDirectoryRequested.complete();
        }
        return temporaryDirectory.future;
      },
    );
    addTearDown(() async {
      await controller.dispose();
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final stale = controller.playMp3(_clip('generation-a'));
    await temporaryDirectoryRequested.future;
    final cancellation = controller.stopPlayback();
    final current = controller.playMp3(_clip('generation-b'));
    temporaryDirectory.complete(directory);
    await Future.wait<void>(<Future<void>>[stale, cancellation, current]);

    expect(player.setFileAttempts, <String>['generation-b']);
    expect(player.audiblePlays, <String>['generation-b']);
    expect(await directory.list().toList(), isEmpty);
  });

  test(
    'cancellation after file creation but before setFilePath cleans the file',
    () async {
      final harness = await _PlaybackHarness.create(playerPrimed: false);
      addTearDown(harness.dispose);
      final volumeGate = harness.player.gateNextVolume();

      final stale = harness.controller.playMp3(_clip('generation-a'));
      expect(await volumeGate.entered.future, 0);
      expect(await harness.files(), hasLength(1));

      final cancellation = harness.controller.stopPlayback();
      final current = harness.controller.playMp3(_clip('generation-b'));
      volumeGate.release.complete();
      await Future.wait<void>(<Future<void>>[stale, cancellation, current]);

      expect(harness.player.setFileAttempts, isNot(contains('generation-a')));
      expect(harness.player.audiblePlays, <String>['generation-b']);
      expect(await harness.files(), isEmpty);
    },
  );

  test(
    'cancellation after setFilePath but before play rejects stale play',
    () async {
      final harness = await _PlaybackHarness.create();
      addTearDown(harness.dispose);
      final gate = harness.player.gateNextSetFile();

      final stale = harness.controller.playMp3(_clip('generation-a'));
      expect(await gate.entered.future, 'generation-a');
      gate.release.complete();
      final cancellation = harness.controller.stopPlayback();
      final current = harness.controller.playMp3(_clip('generation-b'));
      await Future.wait<void>(<Future<void>>[stale, cancellation, current]);

      expect(harness.player.playInvocations, isNot(contains('generation-a')));
      expect(harness.player.audiblePlays, <String>['generation-b']);
      expect(await harness.files(), isEmpty);
    },
  );

  for (final reason in <String>[
    'voice disable',
    'conversation switch',
    'explicit user cancel',
    'reconnect reset',
  ]) {
    test('$reason during setup cancels stale audio and recovers', () async {
      await _expectSetupCancellationRecovery(playerPrimed: true);
    });
  }

  test(
    'background and foreground preserve queued FIFO without overlap',
    () async {
      final harness = await _PlaybackHarness.create();
      addTearDown(harness.dispose);
      final firstPlay = harness.player.gateNextPlay();

      final first = harness.controller.playMp3(_clip('first'));
      expect(await firstPlay.entered.future, 'first');
      final second = harness.controller.playMp3(_clip('second'));

      expect(harness.player.audiblePlays, <String>['first']);
      expect(harness.player.activePlays, 1);
      firstPlay.release.complete();
      await Future.wait<void>(<Future<void>>[first, second]);

      expect(harness.player.audiblePlays, <String>['first', 'second']);
      expect(harness.player.maxActivePlays, 1);
      expect(await harness.files(), isEmpty);
    },
  );

  test(
    'shutdown during setup drains worker and emits no stale start',
    () async {
      final harness = await _PlaybackHarness.create();
      addTearDown(harness.dispose);
      final gate = harness.player.gateNextSetFile();

      final stale = harness.controller.playMp3(_clip('generation-a'));
      await gate.entered.future;
      final shutdown = harness.controller.dispose();
      expect(harness.player.disposed, isFalse);
      gate.release.complete();
      await Future.wait<void>(<Future<void>>[stale, shutdown]);

      expect(harness.player.playInvocations, isEmpty);
      expect(harness.player.disposed, isTrue);
      expect(harness.controller.workerActive, isFalse);
      expect(await harness.files(), isEmpty);

      final recovery = await _PlaybackHarness.create();
      addTearDown(recovery.dispose);
      await recovery.controller.playMp3(_clip('generation-b'));
      expect(recovery.player.audiblePlays, <String>['generation-b']);
    },
  );

  test('temporary files are removed after cold playback success', () async {
    final harness = await _PlaybackHarness.create(playerPrimed: false);
    addTearDown(harness.dispose);

    await harness.controller.playMp3(_clip('success'));

    expect(harness.player.audiblePlays, <String>['success']);
    expect(await harness.files(), isEmpty);
  });

  test('temporary files are removed after setup cancellation', () async {
    final harness = await _PlaybackHarness.create();
    addTearDown(harness.dispose);
    final gate = harness.player.gateNextSetFile();

    final stale = harness.controller.playMp3(_clip('cancelled'));
    await gate.entered.future;
    final cancellation = harness.controller.stopPlayback();
    gate.release.complete();
    await Future.wait<void>(<Future<void>>[stale, cancellation]);

    expect(harness.player.playInvocations, isEmpty);
    expect(await harness.files(), isEmpty);
  });

  test('temporary files are removed after setup exception', () async {
    final harness = await _PlaybackHarness.create();
    addTearDown(harness.dispose);
    final gate = harness.player.gateNextSetFile(
      error: StateError('setFilePath failed'),
    );

    final failed = harness.controller.playMp3(_clip('failed'));
    await gate.entered.future;
    gate.release.complete();
    await expectLater(failed, throwsStateError);

    expect(await harness.files(), isEmpty);
    await harness.controller.playMp3(_clip('recovered'));
    expect(harness.player.audiblePlays, <String>['recovered']);
  });

  test('repeated stopPlayback calls are idempotent and recover', () async {
    final harness = await _PlaybackHarness.create();
    addTearDown(harness.dispose);

    await Future.wait<void>(<Future<void>>[
      harness.controller.stopPlayback(),
      harness.controller.stopPlayback(),
      harness.controller.stopPlayback(),
    ]);
    await harness.controller.playMp3(_clip('current'));

    expect(harness.player.audiblePlays, <String>['current']);
    expect(harness.player.maxActivePlays, 1);
  });

  test('cancellation during active playback has no duplicate tail', () async {
    final harness = await _PlaybackHarness.create();
    addTearDown(harness.dispose);
    final playGate = harness.player.gateNextPlay();

    final stale = harness.controller.playMp3(_clip('active'));
    await playGate.entered.future;
    await harness.controller.stopPlayback();
    await stale;
    await harness.controller.playMp3(_clip('current'));

    expect(harness.player.audiblePlays, <String>['active', 'current']);
    expect(harness.player.playing, isFalse);
    expect(harness.player.maxActivePlays, 1);
  });

  test('queue cancellation waits for the active setup worker', () async {
    final setupEntered = Completer<void>();
    final releaseSetup = Completer<void>();
    final queue = AudioPlaybackQueue((_) async {
      setupEntered.complete();
      await releaseSetup.future;
    }, () async {});
    addTearDown(queue.dispose);

    final active = queue.add('active');
    await setupEntered.future;
    var cancellationCompleted = false;
    final cancellation = queue.cancel();
    unawaited(cancellation.then((_) => cancellationCompleted = true));

    await Future<void>.microtask(() {});
    expect(cancellationCompleted, isFalse);
    releaseSetup.complete();
    await Future.wait<void>(<Future<void>>[active, cancellation]);
    expect(cancellationCompleted, isTrue);
  });

  test('disposed controller rejects new clips and leaves no worker', () async {
    final harness = await _PlaybackHarness.create();
    addTearDown(harness.dispose);

    await harness.controller.dispose();

    await expectLater(
      harness.controller.playMp3(_clip('late')),
      throwsStateError,
    );
    expect(harness.controller.workerActive, isFalse);
    expect(harness.player.disposed, isTrue);
  });

  test('pending storage is bounded', () async {
    final gate = Completer<void>();
    final queue = AudioPlaybackQueue((_) => gate.future, () async {
      if (!gate.isCompleted) gate.complete();
    }, maxPending: 2);

    final active = queue.add('active');
    await Future<void>.delayed(Duration.zero);
    final firstPending = queue.add('pending-one');
    final secondPending = queue.add('pending-two');
    expect(queue.pendingCount, 2);
    await expectLater(queue.add('overflow'), throwsStateError);

    await queue.cancel();
    await active;
    await firstPending;
    await secondPending;
    await queue.dispose();
  });
}
