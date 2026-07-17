import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:osia_mobile/services/audio_service.dart';

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
