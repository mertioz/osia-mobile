import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/attachment_service.dart';

Stream<List<int>> _sizedStream(int size, {int marker = 0x61}) async* {
  var remaining = size;
  while (remaining > 0) {
    final length = min(64 * 1024, remaining);
    yield Uint8List(length)..fillRange(0, length, marker);
    remaining -= length;
  }
}

AttachmentSource _source(
  String name,
  int size, {
  int marker = 0x61,
  Stream<List<int>> Function()? openRead,
}) => AttachmentSource(
  displayName: name,
  declaredSize: size,
  openRead: openRead ?? () => _sizedStream(size, marker: marker),
);

class _FakeAttachmentWire {
  final StreamController<Map<String, dynamic>> controller =
      StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final List<Map<String, dynamic>> frames = [];
  String session;
  bool rejectPrepare = false;
  bool failChunkSend = false;
  bool failRemoteComplete = false;
  bool corruptCommitAck = false;
  bool changeSessionOnChunk = false;
  void Function()? onFirstChunk;
  Map<String, dynamic>? prepare;
  int chunkCount = 0;

  _FakeAttachmentWire(this.session);

  Stream<Map<String, dynamic>> get events => controller.stream;

  Future<bool> send(Map<String, dynamic> frame, String expectedSession) async {
    final type = frame['type']?.toString() ?? '';
    frames.add({
      'type': type,
      'batch_id': frame['batch_id'],
      'file_id': frame['file_id'],
      'sequence': frame['sequence'],
      'payload_length': frame['payload_length'],
    });
    if (type == 'attachment_batch_prepare') {
      prepare = Map<String, dynamic>.from(frame);
      controller.add({
        'type': rejectPrepare
            ? 'attachment_batch_reject'
            : 'attachment_batch_accept',
        'batch_id': frame['batch_id'],
        'client_request_id': frame['client_request_id'],
        if (rejectPrepare) 'category': 'synthetic_rejection',
      });
    } else if (type == 'attachment_file_chunk') {
      chunkCount++;
      onFirstChunk?.call();
      onFirstChunk = null;
      if (changeSessionOnChunk) session = 'replacement:2';
      if (failChunkSend) return false;
    } else if (type == 'attachment_file_complete' && failRemoteComplete) {
      controller.add({
        'type': 'attachment_batch_failed',
        'batch_id': frame['batch_id'],
        'client_request_id': frame['client_request_id'],
        'category': 'hash_mismatch',
      });
    } else if (type == 'attachment_batch_commit') {
      final metadata = (prepare!['files'] as List).cast<Map>();
      controller.add({
        'type': 'attachment_batch_commit_ack',
        'batch_id': frame['batch_id'],
        'client_request_id': frame['client_request_id'],
        'file_count': corruptCommitAck ? metadata.length + 1 : metadata.length,
        'aggregate_size': prepare!['aggregate_size'],
        'attachments': [
          for (var index = 0; index < metadata.length; index++)
            {
              'attachment_id':
                  'att_${index.toRadixString(16).padLeft(32, '0')}',
              'file_id': metadata[index]['file_id'],
              'logical_order': index,
              'byte_size': metadata[index]['declared_byte_size'],
              'hash_match': true,
            },
        ],
      });
    }
    return true;
  }

  Future<void> close() => controller.close();
}

void main() {
  test(
    'regression: bounded chunks replace the historical monolithic frame',
    () {
      const legacyRelayReassemblyLimit = 8 * 1024 * 1024;
      final historicalBase64Bytes = ((attachmentMaxBytes + 2) ~/ 3) * 4;
      final chunkBase64Bytes = ((attachmentChunkBytes + 2) ~/ 3) * 4;
      expect(historicalBase64Bytes, greaterThan(legacyRelayReassemblyLimit));
      expect(chunkBase64Bytes, lessThan(48 * 1024));
      expect(
        (attachmentMaxBytes + attachmentChunkBytes - 1) ~/ attachmentChunkBytes,
        1024,
      );
    },
  );

  group('attachment preparation', () {
    late Directory root;
    late AttachmentPreparer preparer;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('osia-attachment-test-');
      preparer = AttachmentPreparer(root: root);
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('prepares one, multiple, and exactly ten files', () async {
      for (final count in [1, 3, attachmentMaxFiles]) {
        final files = await preparer.prepare([
          for (var index = 0; index < count; index++)
            _source('public-$index.txt', index + 1, marker: 0x61 + index),
        ]);
        expect(files, hasLength(count));
        expect(files.map((file) => file.byteSize), [
          for (var index = 0; index < count; index++) index + 1,
        ]);
        expect(
          files.every((file) => File(file.stagedPath).existsSync()),
          isTrue,
        );
        for (final file in files) {
          await file.delete();
        }
      }
    });

    test('rejects eleven files before opening a source', () async {
      var opened = false;
      final sources = [
        for (var index = 0; index < 11; index++)
          _source(
            'public-$index.txt',
            1,
            openRead: () {
              opened = true;
              return _sizedStream(1);
            },
          ),
      ];
      await expectLater(
        preparer.prepare(sources),
        throwsA(
          isA<AttachmentException>().having(
            (error) => error.category,
            'category',
            'too_many_files',
          ),
        ),
      );
      expect(opened, isFalse);
    });

    test('accepts exact 20 MiB individual and aggregate boundary', () async {
      final progress = <AttachmentProgress>[];
      final files = await preparer.prepare([
        _source('public-limit.bin', attachmentMaxBytes),
      ], onProgress: progress.add);
      expect(files.single.byteSize, attachmentMaxBytes);
      expect(File(files.single.stagedPath).lengthSync(), attachmentMaxBytes);
      expect(files.single.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(progress.last.completedBytes, attachmentMaxBytes);
      await files.single.delete();
    });

    test(
      'rejects aggregate and individual 20 MiB plus one before read',
      () async {
        var opened = false;
        AttachmentSource unopened(String name, int size) => _source(
          name,
          size,
          openRead: () {
            opened = true;
            return _sizedStream(size);
          },
        );
        await expectLater(
          preparer.prepare([
            unopened('public-a.bin', attachmentMaxBytes),
            unopened('public-b.bin', 1),
          ]),
          throwsA(
            isA<AttachmentException>().having(
              (error) => error.category,
              'category',
              'aggregate_too_large',
            ),
          ),
        );
        await expectLater(
          preparer.prepare([
            unopened('public-big.bin', attachmentMaxBytes + 1),
          ]),
          throwsA(
            isA<AttachmentException>().having(
              (error) => error.category,
              'category',
              'file_too_large',
            ),
          ),
        );
        expect(opened, isFalse);
      },
    );

    test('empty picker and zero-byte file are explicit', () async {
      expect(await preparer.prepare(const []), isEmpty);
      await expectLater(
        preparer.prepare([_source('public-empty.txt', 0)]),
        throwsA(
          isA<AttachmentException>().having(
            (error) => error.category,
            'category',
            'empty_file',
          ),
        ),
      );
    });

    test(
      'read, permission, expired-source and changed-size failures clean staging',
      () async {
        final cases = <String, AttachmentSource>{
          'read_failed': _source(
            'public-read.txt',
            1,
            openRead: () => Stream<List<int>>.error(
              const FileSystemException('synthetic read failure'),
            ),
          ),
          'permission_denied': _source(
            'public-permission.txt',
            1,
            openRead: () => Stream<List<int>>.error(
              const FileSystemException(
                'synthetic permission failure',
                '',
                OSError('denied', 13),
              ),
            ),
          ),
          'source_expired': _source(
            'public-expired.txt',
            1,
            openRead: () => throw const AttachmentException('source_expired'),
          ),
          'file_changed': _source(
            'public-changed.txt',
            2,
            openRead: () => _sizedStream(1),
          ),
        };
        for (final entry in cases.entries) {
          await expectLater(
            preparer.prepare([entry.value]),
            throwsA(
              isA<AttachmentException>().having(
                (error) => error.category,
                'category',
                entry.key,
              ),
            ),
          );
          expect(root.listSync().whereType<File>(), isEmpty);
        }
      },
    );

    test(
      'hash, image signature, safe name and duplicate identity are stable',
      () async {
        final png = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1];
        final first = await preparer.prepare([
          AttachmentSource(
            displayName: r'C:\private\..\public.png',
            declaredSize: png.length,
            openRead: () => Stream.value(png),
          ),
        ]);
        final second = await preparer.prepare([
          AttachmentSource(
            displayName: 'copy.png',
            declaredSize: png.length,
            openRead: () => Stream.value(png),
          ),
        ]);
        expect(first.single.displayName, 'public.png');
        expect(first.single.detectedCategory, 'image');
        expect(
          first.single.sha256,
          '275f1bcbbb585c71e3b2184304eccfa0e37de92022ca3b6f4e9c10df32318d85',
        );
        expect(attachmentIsDuplicate(first, second.single), isTrue);
      },
    );

    test(
      'cancel during hashing is terminal and removes partial files',
      () async {
        final cancellation = AttachmentCancellation();
        final phases = <AttachmentPhase>[];
        await expectLater(
          preparer.prepare(
            [_source('public-cancel.bin', 128 * 1024)],
            cancellation: cancellation,
            onProgress: (progress) {
              phases.add(progress.phase);
              if (progress.phase == AttachmentPhase.hashing) {
                cancellation.cancel();
              }
            },
          ),
          throwsA(
            isA<AttachmentException>().having(
              (error) => error.category,
              'category',
              'canceled',
            ),
          ),
        );
        expect(phases, contains(AttachmentPhase.preparing));
        expect(phases, contains(AttachmentPhase.hashing));
        expect(root.listSync().whereType<File>(), isEmpty);
      },
    );

    test(
      'bounded startup cleanup removes only stale generated staging files',
      () async {
        final stale = File('${root.path}${Platform.pathSeparator}old.stage');
        final fresh = File('${root.path}${Platform.pathSeparator}fresh.stage');
        final unrelated = File(
          '${root.path}${Platform.pathSeparator}unrelated.txt',
        );
        await stale.writeAsString('public');
        await fresh.writeAsString('public');
        await unrelated.writeAsString('public');
        final now = DateTime.now();
        await stale.setLastModified(now.subtract(const Duration(days: 2)));
        expect(await cleanupAttachmentStaging(root, now: now), 1);
        expect(stale.existsSync(), isFalse);
        expect(fresh.existsSync(), isTrue);
        expect(unrelated.existsSync(), isTrue);
      },
    );
  });

  group('attachment transfer', () {
    late Directory root;
    late List<PreparedAttachment> files;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('osia-transfer-test-');
      files = await AttachmentPreparer(root: root).prepare([
        _source('public-one.txt', 3, marker: 0x61),
        _source('public-two.txt', 5, marker: 0x62),
      ]);
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<AttachmentUploadResult> upload(
      _FakeAttachmentWire wire, {
      List<PreparedAttachment>? selected,
      String requestId = 'request_test',
      AttachmentCancellation? cancellation,
      void Function(AttachmentProgress)? onProgress,
    }) =>
        AttachmentTransferClient(
          sendFrame: wire.send,
          events: wire.events,
          transportSession: () => wire.session,
          responseTimeout: const Duration(seconds: 1),
        ).upload(
          files: selected ?? files,
          conversationId: 'conv_test',
          clientRequestId: requestId,
          cancellation: cancellation,
          onProgress: onProgress,
        );

    test('LAN, WebRTC and relay use the same canonical lifecycle', () async {
      List<String>? reference;
      for (final transport in ['lan:1', 'webrtc:1', 'relay:1']) {
        final wire = _FakeAttachmentWire(transport);
        addTearDown(wire.close);
        final progress = <AttachmentProgress>[];
        final result = await upload(wire, onProgress: progress.add);
        expect(result.fileCount, 2);
        expect(result.aggregateSize, 8);
        final types = wire.frames
            .map((frame) => frame['type'] as String)
            .toList();
        reference ??= types;
        expect(types, reference);
        expect(types.first, 'attachment_batch_prepare');
        expect(types.last, 'attachment_batch_commit');
        expect(
          progress.map((item) => item.phase),
          contains(AttachmentPhase.uploading),
        );
        expect(progress.last.phase, AttachmentPhase.ready);
      }
    });

    test('transport change prevents fallback and never commits', () async {
      final wire = _FakeAttachmentWire('lan:1')..changeSessionOnChunk = true;
      addTearDown(wire.close);
      await expectLater(
        upload(wire),
        throwsA(
          isA<AttachmentException>().having(
            (error) => error.category,
            'category',
            'transport_changed',
          ),
        ),
      );
      expect(
        wire.frames.where(
          (frame) => frame['type'] == 'attachment_batch_commit',
        ),
        isEmpty,
      );
      expect(
        wire.frames.where(
          (frame) => frame['type'] == 'attachment_batch_prepare',
        ),
        hasLength(1),
      );
    });

    test(
      'send loss, remote hash failure and bad commit ack are terminal',
      () async {
        final cases = <String, void Function(_FakeAttachmentWire)>{
          'transfer_failed': (wire) => wire.failChunkSend = true,
          'hash_mismatch': (wire) => wire.failRemoteComplete = true,
          'commit_ack_mismatch': (wire) => wire.corruptCommitAck = true,
        };
        for (final entry in cases.entries) {
          final wire = _FakeAttachmentWire('relay:1');
          entry.value(wire);
          await expectLater(
            upload(wire),
            throwsA(
              isA<AttachmentException>().having(
                (error) => error.category,
                'category',
                entry.key,
              ),
            ),
          );
          expect(
            wire.frames.where(
              (frame) => frame['type'] == 'attachment_batch_cancel',
            ),
            hasLength(1),
          );
          await wire.close();
        }
      },
    );

    test('cancel during transfer sends cancel and no commit', () async {
      final cancellation = AttachmentCancellation();
      final wire = _FakeAttachmentWire('webrtc:1')
        ..onFirstChunk = cancellation.cancel;
      addTearDown(wire.close);
      await expectLater(
        upload(wire, cancellation: cancellation),
        throwsA(
          isA<AttachmentException>().having(
            (error) => error.category,
            'category',
            'canceled',
          ),
        ),
      );
      expect(
        wire.frames.where(
          (frame) => frame['type'] == 'attachment_batch_cancel',
        ),
        hasLength(1),
      );
      expect(
        wire.frames.where(
          (frame) => frame['type'] == 'attachment_batch_commit',
        ),
        isEmpty,
      );
    });

    test(
      'explicit retry creates a fresh batch and no automatic duplicate send',
      () async {
        final rejected = _FakeAttachmentWire('lan:1')..rejectPrepare = true;
        await expectLater(
          upload(rejected, requestId: 'request_failed'),
          throwsA(
            isA<AttachmentException>().having(
              (error) => error.category,
              'category',
              'synthetic_rejection',
            ),
          ),
        );
        final rejectedBatch = rejected.frames.first['batch_id'];
        expect(
          rejected.frames.where(
            (frame) => frame['type'] == 'attachment_batch_prepare',
          ),
          hasLength(1),
        );

        final retry = _FakeAttachmentWire('lan:1');
        final result = await upload(retry, requestId: 'request_retry');
        expect(result.batchId, isNot(rejectedBatch));
        expect(
          retry.frames.where(
            (frame) => frame['type'] == 'attachment_batch_prepare',
          ),
          hasLength(1),
        );
        await rejected.close();
        await retry.close();
      },
    );

    test(
      'an unassociated committed batch is canceled on the same transport',
      () async {
        final wire = _FakeAttachmentWire('lan:1');
        final client = AttachmentTransferClient(
          sendFrame: wire.send,
          events: wire.events,
          transportSession: () => wire.session,
        );
        final result = await client.upload(
          files: [files.first],
          conversationId: 'conv_test',
          clientRequestId: 'request_unassociated',
        );
        expect(
          await client.cancelCommitted(result, conversationId: 'conv_test'),
          isTrue,
        );
        final cancel = wire.frames.last;
        expect(cancel['type'], 'attachment_batch_cancel');
        expect(cancel['batch_id'], result.batchId);
        expect(cancel['sequence'], result.finalSequence + 1);
        await wire.close();
      },
    );

    test('staged file mutation and duplicate file ids are rejected', () async {
      await File(
        files.first.stagedPath,
      ).writeAsString('changed', mode: FileMode.append);
      final wire = _FakeAttachmentWire('lan:1');
      await expectLater(
        upload(wire),
        throwsA(
          isA<AttachmentException>().having(
            (error) => error.category,
            'category',
            'staged_file_changed',
          ),
        ),
      );
      await wire.close();

      final duplicateWire = _FakeAttachmentWire('lan:1');
      await expectLater(
        upload(duplicateWire, selected: [files.last, files.last]),
        throwsA(
          isA<AttachmentException>().having(
            (error) => error.category,
            'category',
            'duplicate_file',
          ),
        ),
      );
      expect(duplicateWire.frames, isEmpty);
      await duplicateWire.close();
    });

    test(
      'stress: fifty explicit canceled generations stay independent',
      () async {
        final one = [files.first];
        final batches = <String>{};
        for (var index = 0; index < 50; index++) {
          final cancellation = AttachmentCancellation();
          final wire = _FakeAttachmentWire('relay:$index')
            ..onFirstChunk = cancellation.cancel;
          await expectLater(
            upload(
              wire,
              selected: one,
              requestId: 'request_${index.toString().padLeft(3, '0')}',
              cancellation: cancellation,
            ),
            throwsA(isA<AttachmentException>()),
          );
          batches.add(wire.frames.first['batch_id'] as String);
          expect(
            wire.frames.where(
              (frame) => frame['type'] == 'attachment_batch_cancel',
            ),
            hasLength(1),
          );
          await wire.close();
        }
        expect(batches, hasLength(50));
      },
    );
  });

  test('display name normalization strips path syntax and bounds length', () {
    expect(attachmentSafeDisplayName(r'C:\private\public.txt'), 'public.txt');
    expect(attachmentSafeDisplayName('../../public.txt'), 'public.txt');
    expect(attachmentSafeDisplayName('CON.txt'), '_CON.txt');
    expect(attachmentSafeDisplayName('bad\u0000name.txt'), 'badname.txt');
    expect(
      attachmentSafeDisplayName(
        '${List.filled(500, 'x').join()}.txt',
      ).runes.length,
      lessThanOrEqualTo(attachmentMaxDisplayNameChars),
    );
    expect(utf8.encode(attachmentSafeDisplayName('é.txt')), isNotEmpty);
  });
}
