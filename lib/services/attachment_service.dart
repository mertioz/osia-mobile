import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const int attachmentProtocolVersion = 1;
const int attachmentMaxFiles = 10;
const int attachmentMaxBytes = 20 * 1024 * 1024;
const int attachmentChunkBytes = 20 * 1024;
const int attachmentMaxDisplayNameChars = 180;
const int attachmentMaxMimeChars = 127;
const Duration attachmentBatchTtl = Duration(minutes: 15);

enum AttachmentPhase {
  idle,
  preparing,
  hashing,
  uploading,
  verifying,
  ready,
  sent,
  failed,
  canceled,
}

class AttachmentProgress {
  final AttachmentPhase phase;
  final int completedBytes;
  final int totalBytes;
  final int completedFiles;
  final int totalFiles;
  final String category;

  const AttachmentProgress({
    required this.phase,
    this.completedBytes = 0,
    this.totalBytes = 0,
    this.completedFiles = 0,
    this.totalFiles = 0,
    this.category = '',
  });

  double get fraction =>
      totalBytes <= 0 ? 0 : (completedBytes / totalBytes).clamp(0.0, 1.0);
}

class AttachmentCancellation {
  bool _canceled = false;
  final Completer<void> _completer = Completer<void>();

  bool get isCanceled => _canceled;
  Future<void> get whenCanceled => _completer.future;

  void cancel() {
    if (_canceled) return;
    _canceled = true;
    _completer.complete();
  }
}

Future<String> ensureAttachmentTransportReady({
  required Future<void> Function() ensureConnected,
  required String Function() transportSession,
}) async {
  await ensureConnected();
  final session = transportSession();
  if (session.isEmpty) {
    throw const AttachmentException('transport_unavailable');
  }
  return session;
}

class AttachmentException implements Exception {
  final String category;
  final String displayName;

  const AttachmentException(this.category, {this.displayName = ''});

  @override
  String toString() => category;
}

class AttachmentSource {
  final String displayName;
  final int declaredSize;
  final String declaredMime;
  final Stream<List<int>> Function() openRead;

  const AttachmentSource({
    required this.displayName,
    required this.declaredSize,
    required this.openRead,
    this.declaredMime = 'application/octet-stream',
  });
}

class PreparedAttachment {
  final String fileId;
  final String displayName;
  final String stagedPath;
  final int byteSize;
  final String sha256;
  final String declaredMime;
  final String detectedCategory;
  final String extension;

  const PreparedAttachment({
    required this.fileId,
    required this.displayName,
    required this.stagedPath,
    required this.byteSize,
    required this.sha256,
    required this.declaredMime,
    required this.detectedCategory,
    required this.extension,
  });

  int get expectedChunkCount =>
      (byteSize + attachmentChunkBytes - 1) ~/ attachmentChunkBytes;

  Future<void> delete() async {
    try {
      final file = File(stagedPath);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Bounded best-effort cleanup. Startup orphan cleanup is the fallback.
    }
  }
}

bool attachmentIsDuplicate(
  Iterable<PreparedAttachment> existing,
  PreparedAttachment candidate,
) => existing.any(
  (file) =>
      file.byteSize == candidate.byteSize && file.sha256 == candidate.sha256,
);

String attachmentSafeDisplayName(String value) {
  var name = value.replaceAll('\\', '/').split('/').last;
  if (name.length >= 2 && name[1] == ':') name = name.substring(2);
  name = name
      .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
      .replaceAll('..', '.')
      .trim();
  name = name.replaceAll(RegExp(r'^[ .]+|[ .]+$'), '');
  if (name.isEmpty) name = 'attachment.bin';
  final dot = name.lastIndexOf('.');
  final suffix = dot > 0 ? name.substring(dot) : '';
  final extension = suffix.length <= 17 ? suffix : '';
  final stemSource = dot > 0 ? name.substring(0, dot) : name;
  var stem = _boundedRunes(
    stemSource,
    max(1, attachmentMaxDisplayNameChars - extension.runes.length),
  ).replaceAll(RegExp(r'^[ .]+|[ .]+$'), '');
  if (stem.isEmpty) stem = 'attachment';
  const reserved = <String>{
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };
  if (reserved.contains(stem.toUpperCase())) stem = '_$stem';
  return _boundedRunes('$stem$extension', attachmentMaxDisplayNameChars);
}

String _boundedRunes(String value, int maxRunes) =>
    String.fromCharCodes(value.runes.take(maxRunes));

String _safeExtension(String displayName) {
  final dot = displayName.lastIndexOf('.');
  if (dot <= 0 || dot == displayName.length - 1) return '';
  final extension = displayName.substring(dot + 1).toLowerCase();
  return extension.length <= 16 && RegExp(r'^[a-z0-9]+$').hasMatch(extension)
      ? extension
      : '';
}

String _mimeForExtension(String extension) {
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'txt' || 'md' || 'csv' || 'json' || 'xml' => 'text/plain',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}

String _detectedCategory(Uint8List prefix) {
  if (prefix.length >= 8 &&
      prefix[0] == 0x89 &&
      prefix[1] == 0x50 &&
      prefix[2] == 0x4e &&
      prefix[3] == 0x47 &&
      prefix[4] == 0x0d &&
      prefix[5] == 0x0a &&
      prefix[6] == 0x1a &&
      prefix[7] == 0x0a) {
    return 'image';
  }
  if (prefix.length >= 3 &&
      prefix[0] == 0xff &&
      prefix[1] == 0xd8 &&
      prefix[2] == 0xff) {
    return 'image';
  }
  if (prefix.length >= 6 &&
      ascii
          .decode(prefix.sublist(0, 6), allowInvalid: true)
          .startsWith('GIF8')) {
    return 'image';
  }
  if (prefix.length >= 12 &&
      ascii.decode(prefix.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(prefix.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return 'image';
  }
  return 'file';
}

String _newProtocolId(String prefix) {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${prefix}_$hex';
}

class AttachmentPreparer {
  final Directory root;
  final DateTime Function() now;

  AttachmentPreparer({required this.root, DateTime Function()? now})
    : now = now ?? DateTime.now;

  Future<List<PreparedAttachment>> prepare(
    List<AttachmentSource> sources, {
    List<PreparedAttachment> existing = const [],
    AttachmentCancellation? cancellation,
    void Function(AttachmentProgress progress)? onProgress,
  }) async {
    if (sources.isEmpty) return const [];
    if (existing.length + sources.length > attachmentMaxFiles) {
      throw AttachmentException(
        'too_many_files',
        displayName: attachmentSafeDisplayName(sources.last.displayName),
      );
    }
    var declaredTotal = existing.fold<int>(
      0,
      (sum, file) => sum + file.byteSize,
    );
    for (final source in sources) {
      final safeName = attachmentSafeDisplayName(source.displayName);
      if (source.declaredSize <= 0) {
        throw AttachmentException('empty_file', displayName: safeName);
      }
      if (source.declaredSize > attachmentMaxBytes) {
        throw AttachmentException('file_too_large', displayName: safeName);
      }
      declaredTotal += source.declaredSize;
      if (declaredTotal > attachmentMaxBytes) {
        throw AttachmentException('aggregate_too_large', displayName: safeName);
      }
    }

    await root.create(recursive: true);
    await cleanupAttachmentStaging(root, now: now());
    final prepared = <PreparedAttachment>[];
    var completedBytes = existing.fold<int>(
      0,
      (sum, file) => sum + file.byteSize,
    );
    final totalFiles = existing.length + sources.length;
    final totalBytes = declaredTotal;
    onProgress?.call(
      AttachmentProgress(
        phase: AttachmentPhase.preparing,
        completedBytes: completedBytes,
        totalBytes: totalBytes,
        completedFiles: existing.length,
        totalFiles: totalFiles,
      ),
    );

    try {
      for (var index = 0; index < sources.length; index++) {
        final source = sources[index];
        final safeName = attachmentSafeDisplayName(source.displayName);
        if (cancellation?.isCanceled == true) {
          throw const AttachmentException('canceled');
        }
        final fileId = _newProtocolId('file');
        final staged = File(
          '${root.path}${Platform.pathSeparator}$fileId.stage',
        );
        IOSink? sink;
        var byteCount = 0;
        final digestSink = _DigestSink();
        final hashSink = sha256.startChunkedConversion(digestSink);
        final prefix = BytesBuilder(copy: false);
        try {
          await staged.create(exclusive: true);
          sink = staged.openWrite(mode: FileMode.writeOnly);
          await for (final rawChunk in source.openRead()) {
            if (cancellation?.isCanceled == true) {
              throw const AttachmentException('canceled');
            }
            if (rawChunk.isEmpty) continue;
            final chunk = rawChunk is Uint8List
                ? rawChunk
                : Uint8List.fromList(rawChunk);
            byteCount += chunk.length;
            if (byteCount > source.declaredSize ||
                completedBytes + byteCount > attachmentMaxBytes) {
              throw AttachmentException('file_changed', displayName: safeName);
            }
            if (prefix.length < 16) {
              final remaining = 16 - prefix.length;
              prefix.add(chunk.sublist(0, min(remaining, chunk.length)));
            }
            hashSink.add(chunk);
            sink.add(chunk);
            onProgress?.call(
              AttachmentProgress(
                phase: AttachmentPhase.hashing,
                completedBytes: completedBytes + byteCount,
                totalBytes: totalBytes,
                completedFiles: existing.length + index,
                totalFiles: totalFiles,
              ),
            );
          }
          await sink.flush();
          await sink.close();
          sink = null;
          hashSink.close();
          if (byteCount == 0) {
            throw AttachmentException('empty_file', displayName: safeName);
          }
          if (byteCount != source.declaredSize) {
            throw AttachmentException('file_changed', displayName: safeName);
          }
          final extension = _safeExtension(safeName);
          final advisoryMime =
              source.declaredMime.length <= attachmentMaxMimeChars
              ? source.declaredMime
              : _mimeForExtension(extension);
          prepared.add(
            PreparedAttachment(
              fileId: fileId,
              displayName: safeName,
              stagedPath: staged.path,
              byteSize: byteCount,
              sha256: digestSink.value.toString(),
              declaredMime: advisoryMime.isEmpty
                  ? _mimeForExtension(extension)
                  : advisoryMime,
              detectedCategory: _detectedCategory(prefix.takeBytes()),
              extension: extension,
            ),
          );
          completedBytes += byteCount;
        } on AttachmentException {
          try {
            await sink?.close();
          } on Object {
            // Preserve the original terminal category.
          }
          try {
            if (await staged.exists()) await staged.delete();
          } on FileSystemException {
            // Startup cleanup owns any file a failing sink still holds.
          }
          rethrow;
        } on Object catch (error) {
          try {
            await sink?.close();
          } on Object {
            // The read/write failure below remains the user-facing category.
          }
          try {
            if (await staged.exists()) await staged.delete();
          } on FileSystemException {
            // Startup cleanup owns any file a failing sink still holds.
          }
          final permissionDenied =
              error is FileSystemException &&
              (error.osError?.errorCode == 5 ||
                  error.osError?.errorCode == 13 ||
                  error.message.toLowerCase().contains('permission'));
          throw AttachmentException(
            permissionDenied ? 'permission_denied' : 'read_failed',
            displayName: safeName,
          );
        }
      }
      return prepared;
    } catch (_) {
      for (final file in prepared) {
        await file.delete();
      }
      rethrow;
    }
  }
}

Future<int> cleanupAttachmentStaging(
  Directory root, {
  DateTime? now,
  Duration maxAge = const Duration(hours: 24),
  int maxEntries = 128,
}) async {
  if (!await root.exists()) return 0;
  final current = now ?? DateTime.now();
  var removed = 0;
  var inspected = 0;
  await for (final entity in root.list(followLinks: false)) {
    if (inspected++ >= maxEntries) break;
    if (entity is! File || !entity.path.endsWith('.stage')) continue;
    try {
      final stat = await entity.stat();
      if (current.difference(stat.modified) >= maxAge) {
        await entity.delete();
        removed++;
      }
    } on FileSystemException {
      // Another cleanup or upload may own it; leave it alone.
    }
  }
  return removed;
}

typedef AttachmentSendFrame =
    Future<bool> Function(
      Map<String, dynamic> frame,
      String expectedTransportSession,
    );

/// Opaque Autonomous source authority plus display-safe metadata.
///
/// Instances are runtime-only. The capability is submitted to the PC but is
/// never persisted, displayed, or included in diagnostics.
class AutonomousSourceCapability {
  final String sourceRef;
  final String typeLabel;
  final String documentFamily;
  final String state;
  final List<String> warnings;

  const AutonomousSourceCapability({
    required this.sourceRef,
    required this.typeLabel,
    required this.documentFamily,
    required this.state,
    this.warnings = const [],
  });
}

class AttachmentUploadResult {
  final String batchId;
  final String clientRequestId;
  final int fileCount;
  final int aggregateSize;
  final String transportSession;
  final int finalSequence;
  final String attachmentPurpose;
  final List<AutonomousSourceCapability> autonomousSources;

  const AttachmentUploadResult({
    required this.batchId,
    required this.clientRequestId,
    required this.fileCount,
    required this.aggregateSize,
    required this.transportSession,
    required this.finalSequence,
    this.attachmentPurpose = 'chat',
    this.autonomousSources = const [],
  });
}

class AttachmentTransferClient {
  final AttachmentSendFrame sendFrame;
  final Stream<Map<String, dynamic>> events;
  final String Function() transportSession;
  final DateTime Function() now;
  final Duration responseTimeout;

  AttachmentTransferClient({
    required this.sendFrame,
    required this.events,
    required this.transportSession,
    DateTime Function()? now,
    this.responseTimeout = const Duration(seconds: 30),
  }) : now = now ?? DateTime.now;

  Future<AttachmentUploadResult> upload({
    required List<PreparedAttachment> files,
    required String conversationId,
    required String clientRequestId,
    String attachmentPurpose = 'chat',
    AttachmentCancellation? cancellation,
    void Function(AttachmentProgress progress)? onProgress,
  }) async {
    if (!const {'chat', 'autonomous'}.contains(attachmentPurpose) ||
        (attachmentPurpose == 'autonomous' && conversationId.isNotEmpty)) {
      throw const AttachmentException('invalid_attachment_purpose');
    }
    _validatePrepared(files);
    final batchId = _newProtocolId('batch');
    final expectedSession = transportSession();
    if (expectedSession.isEmpty) {
      throw const AttachmentException('transport_unavailable');
    }
    final aggregateSize = files.fold<int>(
      0,
      (sum, file) => sum + file.byteSize,
    );
    var sequence = 0;
    Map<String, dynamic> common() => <String, dynamic>{
      'protocol_version': attachmentProtocolVersion,
      'batch_id': batchId,
      'conversation_id': conversationId,
      'client_request_id': clientRequestId,
      'request_id': clientRequestId,
      'event_id': _newProtocolId('event'),
      'sequence': ++sequence,
      'attachment_purpose': attachmentPurpose,
    };

    final accept = Completer<Map<String, dynamic>>();
    final committed = Completer<Map<String, dynamic>>();
    final failed = Completer<Map<String, dynamic>>();
    late final StreamSubscription<Map<String, dynamic>> subscription;
    subscription = events.listen((event) {
      if (event['batch_id'] != batchId) return;
      final type = event['type']?.toString() ?? '';
      if (type == 'attachment_batch_accept' && !accept.isCompleted) {
        accept.complete(event);
      } else if (type == 'attachment_batch_commit_ack' &&
          !committed.isCompleted) {
        committed.complete(event);
      } else if ((type == 'attachment_batch_reject' ||
              type == 'attachment_batch_failed') &&
          !failed.isCompleted) {
        failed.complete(event);
      }
    });

    Future<bool> send(Map<String, dynamic> frame) async {
      if (cancellation?.isCanceled == true) {
        throw const AttachmentException('canceled');
      }
      if (transportSession() != expectedSession) {
        throw const AttachmentException('transport_changed');
      }
      if (!await sendFrame(frame, expectedSession)) {
        throw const AttachmentException('transfer_failed');
      }
      return true;
    }

    Future<Map<String, dynamic>> waitFor(
      Completer<Map<String, dynamic>> success,
    ) async {
      final result = await Future.any<Object>([
        success.future.then<Object>((value) => _TransferSignal(true, value)),
        failed.future.then<Object>((value) => _TransferSignal(false, value)),
        if (cancellation != null)
          cancellation.whenCanceled.then<Object>(
            (_) => const AttachmentException('canceled'),
          ),
        Future<Object>.delayed(
          responseTimeout,
          () => const AttachmentException('response_timeout'),
        ),
      ]);
      if (result is AttachmentException) throw result;
      final signal = result as _TransferSignal;
      if (!signal.success) {
        throw AttachmentException(
          signal.frame['category']?.toString() ?? 'remote_rejected',
        );
      }
      return signal.frame;
    }

    var committedSuccessfully = false;
    try {
      final createdAt = now().toUtc();
      await send(<String, dynamic>{
        'type': 'attachment_batch_prepare',
        ...common(),
        'source_device_role': 'mobile',
        'file_count': files.length,
        'aggregate_size': aggregateSize,
        'created_at': createdAt.toIso8601String(),
        'expiry': createdAt.add(attachmentBatchTtl).toIso8601String(),
        'files': <Map<String, dynamic>>[
          for (var index = 0; index < files.length; index++)
            <String, dynamic>{
              'file_id': files[index].fileId,
              'logical_order': index,
              'display_name': files[index].displayName,
              'original_extension': files[index].extension,
              'declared_mime': files[index].declaredMime,
              'detected_type_category': files[index].detectedCategory,
              'declared_byte_size': files[index].byteSize,
              'sha256': files[index].sha256,
              'chunk_size': attachmentChunkBytes,
              'expected_chunk_count': files[index].expectedChunkCount,
            },
        ],
      });
      await waitFor(accept);

      var uploadedBytes = 0;
      for (var fileIndex = 0; fileIndex < files.length; fileIndex++) {
        final file = files[fileIndex];
        await send(<String, dynamic>{
          'type': 'attachment_file_begin',
          ...common(),
          'file_id': file.fileId,
          'logical_order': fileIndex,
        });
        final reader = await File(file.stagedPath).open();
        try {
          var chunkIndex = 0;
          var offset = 0;
          while (offset < file.byteSize) {
            final requested = min(attachmentChunkBytes, file.byteSize - offset);
            final bytes = await reader.read(requested);
            if (bytes.length != requested) {
              throw AttachmentException(
                'staged_file_changed',
                displayName: file.displayName,
              );
            }
            await send(<String, dynamic>{
              'type': 'attachment_file_chunk',
              ...common(),
              'file_id': file.fileId,
              'chunk_index': chunkIndex,
              'expected_chunk_count': file.expectedChunkCount,
              'byte_offset': offset,
              'payload_length': bytes.length,
              'data': base64Encode(bytes),
            });
            offset += bytes.length;
            uploadedBytes += bytes.length;
            chunkIndex++;
            onProgress?.call(
              AttachmentProgress(
                phase: AttachmentPhase.uploading,
                completedBytes: uploadedBytes,
                totalBytes: aggregateSize,
                completedFiles: fileIndex,
                totalFiles: files.length,
              ),
            );
            if (failed.isCompleted) {
              await waitFor(Completer<Map<String, dynamic>>());
            }
          }
          if (await reader.position() != file.byteSize ||
              await File(file.stagedPath).length() != file.byteSize) {
            throw AttachmentException(
              'staged_file_changed',
              displayName: file.displayName,
            );
          }
        } finally {
          await reader.close();
        }
        await send(<String, dynamic>{
          'type': 'attachment_file_complete',
          ...common(),
          'file_id': file.fileId,
          'declared_byte_size': file.byteSize,
          'sha256': file.sha256,
        });
      }

      onProgress?.call(
        AttachmentProgress(
          phase: AttachmentPhase.verifying,
          completedBytes: aggregateSize,
          totalBytes: aggregateSize,
          completedFiles: files.length,
          totalFiles: files.length,
        ),
      );
      await send(<String, dynamic>{
        'type': 'attachment_batch_commit',
        ...common(),
        'file_count': files.length,
        'aggregate_size': aggregateSize,
      });
      final ack = await waitFor(committed);
      if (ack['file_count'] != files.length ||
          ack['aggregate_size'] != aggregateSize) {
        throw const AttachmentException('commit_ack_mismatch');
      }
      final ackFiles = ack['attachments'];
      if (ackFiles is! List || ackFiles.length != files.length) {
        throw const AttachmentException('commit_ack_mismatch');
      }
      for (var index = 0; index < files.length; index++) {
        final acknowledged = ackFiles[index];
        if (acknowledged is! Map ||
            acknowledged['file_id'] != files[index].fileId ||
            acknowledged['logical_order'] != index ||
            acknowledged['byte_size'] != files[index].byteSize ||
            acknowledged['hash_match'] != true ||
            !RegExp(
              r'^att_[0-9a-f]{32}$',
            ).hasMatch(acknowledged['attachment_id']?.toString() ?? '')) {
          throw const AttachmentException('commit_ack_mismatch');
        }
      }
      final autonomousSources = <AutonomousSourceCapability>[];
      final rawSources = ack['autonomous_sources'];
      if (attachmentPurpose == 'autonomous') {
        if (rawSources is! List || rawSources.length != files.length) {
          throw const AttachmentException('commit_ack_mismatch');
        }
        const allowedKeys = <String>{
          'source_ref',
          'type_label',
          'document_family',
          'state',
          'warnings',
          'logical_order',
        };
        final sourcePattern = RegExp(r'^src_[0-9a-f]{32}$');
        final safeLabelPattern = RegExp(r'^[a-z0-9][a-z0-9.+_-]{0,63}$');
        for (var index = 0; index < rawSources.length; index++) {
          final raw = rawSources[index];
          if (raw is! Map ||
              raw.keys.any(
                (key) => key is! String || !allowedKeys.contains(key),
              ) ||
              raw.length != allowedKeys.length ||
              raw['logical_order'] != index) {
            throw const AttachmentException('commit_ack_mismatch');
          }
          final sourceRef = raw['source_ref']?.toString() ?? '';
          final typeLabel = raw['type_label']?.toString() ?? '';
          final family = raw['document_family']?.toString() ?? '';
          final state = raw['state']?.toString() ?? '';
          final rawWarnings = raw['warnings'];
          if (!sourcePattern.hasMatch(sourceRef) ||
              !safeLabelPattern.hasMatch(typeLabel) ||
              !safeLabelPattern.hasMatch(family) ||
              state != 'ready' ||
              rawWarnings is! List ||
              rawWarnings.length > 8 ||
              rawWarnings.any(
                (warning) =>
                    warning is! String || !safeLabelPattern.hasMatch(warning),
              )) {
            throw const AttachmentException('commit_ack_mismatch');
          }
          autonomousSources.add(
            AutonomousSourceCapability(
              sourceRef: sourceRef,
              typeLabel: typeLabel,
              documentFamily: family,
              state: state,
              warnings: List<String>.unmodifiable(rawWarnings.cast<String>()),
            ),
          );
        }
      } else if (rawSources != null) {
        throw const AttachmentException('commit_ack_mismatch');
      }
      committedSuccessfully = true;
      onProgress?.call(
        AttachmentProgress(
          phase: AttachmentPhase.ready,
          completedBytes: aggregateSize,
          totalBytes: aggregateSize,
          completedFiles: files.length,
          totalFiles: files.length,
        ),
      );
      return AttachmentUploadResult(
        batchId: batchId,
        clientRequestId: clientRequestId,
        fileCount: files.length,
        aggregateSize: aggregateSize,
        transportSession: expectedSession,
        finalSequence: sequence,
        attachmentPurpose: attachmentPurpose,
        autonomousSources: List<AutonomousSourceCapability>.unmodifiable(
          autonomousSources,
        ),
      );
    } on AttachmentException catch (error) {
      onProgress?.call(
        AttachmentProgress(
          phase: error.category == 'canceled'
              ? AttachmentPhase.canceled
              : AttachmentPhase.failed,
          completedBytes: 0,
          totalBytes: aggregateSize,
          completedFiles: 0,
          totalFiles: files.length,
          category: error.category,
        ),
      );
      rethrow;
    } finally {
      if (!committedSuccessfully && transportSession() == expectedSession) {
        final cancelFrame = <String, dynamic>{
          'type': 'attachment_batch_cancel',
          ...common(),
          'category': cancellation?.isCanceled == true ? 'canceled' : 'failed',
        };
        try {
          await sendFrame(cancelFrame, expectedSession);
        } on Object {
          // Transport failure already makes the batch terminal locally.
        }
      }
      await subscription.cancel();
    }
  }

  Future<bool> cancelCommitted(
    AttachmentUploadResult result, {
    required String conversationId,
    String category = 'turn_not_sent',
  }) async {
    if (transportSession() != result.transportSession) return false;
    try {
      return await sendFrame(<String, dynamic>{
        'type': 'attachment_batch_cancel',
        'protocol_version': attachmentProtocolVersion,
        'batch_id': result.batchId,
        'conversation_id': conversationId,
        'client_request_id': result.clientRequestId,
        'request_id': result.clientRequestId,
        'event_id': _newProtocolId('event'),
        'sequence': result.finalSequence + 1,
        'attachment_purpose': result.attachmentPurpose,
        'category': category,
      }, result.transportSession);
    } on Object {
      return false;
    }
  }

  void _validatePrepared(List<PreparedAttachment> files) {
    if (files.isEmpty || files.length > attachmentMaxFiles) {
      throw const AttachmentException('invalid_file_count');
    }
    final ids = <String>{};
    var total = 0;
    for (final file in files) {
      if (!ids.add(file.fileId)) {
        throw AttachmentException(
          'duplicate_file',
          displayName: file.displayName,
        );
      }
      if (file.byteSize <= 0 || file.byteSize > attachmentMaxBytes) {
        throw AttachmentException(
          'file_too_large',
          displayName: file.displayName,
        );
      }
      total += file.byteSize;
      if (total > attachmentMaxBytes) {
        throw AttachmentException(
          'aggregate_too_large',
          displayName: file.displayName,
        );
      }
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(file.sha256)) {
        throw AttachmentException(
          'invalid_hash',
          displayName: file.displayName,
        );
      }
    }
  }
}

class _TransferSignal {
  final bool success;
  final Map<String, dynamic> frame;

  const _TransferSignal(this.success, this.frame);
}

class _DigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value {
    final result = _value;
    if (result == null) throw StateError('SHA-256 digest was not completed');
    return result;
  }

  @override
  void add(Digest data) {
    if (_value != null) throw StateError('SHA-256 digest completed twice');
    _value = data;
  }

  @override
  void close() {}
}
