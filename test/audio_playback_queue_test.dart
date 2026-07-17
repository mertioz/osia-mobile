import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/audio_service.dart';

void main() {
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
