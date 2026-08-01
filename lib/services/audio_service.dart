import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class _QueuedPlayback {
  const _QueuedPlayback(this.data, this.completer);

  final String data;
  final Completer<void> completer;
}

/// Wait for one player invocation to finish even when the platform's
/// [AudioPlayer.play] future does not complete after the native track ends.
///
/// Android can report the terminal player-state transition while leaving that
/// future pending, and can occasionally omit that state transition too.
/// Listening before [play] is invoked prevents a short clip's start/end event
/// from being missed. Decoded duration and local-file position idle are bounded
/// fallbacks when Android omits the terminal transition.
@visibleForTesting
Future<void> playUntilStopped(
  Future<void> Function() play,
  Stream<PlayerState> playerStates, {
  Stream<Duration>? positions,
  Future<void>? cancellation,
  Duration? expectedDuration,
  Duration completionGrace = const Duration(milliseconds: 500),
  Duration progressIdleGrace = const Duration(milliseconds: 750),
}) async {
  final stateEnded = Completer<void>();
  var started = false;
  var lastPosition = Duration.zero;
  Timer? completionTimer;
  Timer? progressIdleTimer;
  late final StreamSubscription<PlayerState> subscription;
  StreamSubscription<Duration>? positionSubscription;
  subscription = playerStates.listen(
    (state) {
      if (state.playing) started = true;
      if (!stateEnded.isCompleted &&
          started &&
          (state.processingState == ProcessingState.completed ||
              !state.playing)) {
        stateEnded.complete();
      }
    },
    onError: (Object error, StackTrace stack) {
      if (!stateEnded.isCompleted) stateEnded.completeError(error, stack);
    },
  );
  if (positions != null) {
    positionSubscription = positions.listen(
      (position) {
        if (!started || position <= lastPosition) return;
        lastPosition = position;
        progressIdleTimer?.cancel();
        progressIdleTimer = Timer(progressIdleGrace, () {
          if (!stateEnded.isCompleted) stateEnded.complete();
        });
      },
      onError: (Object error, StackTrace stack) {
        if (!stateEnded.isCompleted) stateEnded.completeError(error, stack);
      },
    );
  }
  try {
    final terminalSignals = <Future<void>>[play(), stateEnded.future];
    if (cancellation != null) terminalSignals.add(cancellation);
    if (expectedDuration != null) {
      final durationEnded = Completer<void>();
      completionTimer = Timer(expectedDuration + completionGrace, () {
        if (!durationEnded.isCompleted) durationEnded.complete();
      });
      terminalSignals.add(durationEnded.future);
    }
    await Future.any<void>(terminalSignals);
  } finally {
    completionTimer?.cancel();
    progressIdleTimer?.cancel();
    await subscription.cancel();
    await positionSubscription?.cancel();
  }
}

/// One bounded FIFO that serializes TTS clips and invalidates stale playback.
class AudioPlaybackQueue {
  AudioPlaybackQueue(this._play, this._stop, {this.maxPending = 64});

  final Future<void> Function(String data) _play;
  final Future<void> Function() _stop;
  final int maxPending;
  final ListQueue<_QueuedPlayback> _pending = ListQueue<_QueuedPlayback>();
  Future<void>? _worker;
  int _generation = 0;
  int _cancellationDepth = 0;
  bool _disposed = false;

  int get pendingCount => _pending.length;
  bool get workerActive => _worker != null;

  Future<void> add(String data) {
    if (_disposed) {
      return Future<void>.error(StateError('playback queue disposed'));
    }
    if (_pending.length >= maxPending) {
      return Future<void>.error(StateError('playback queue is full'));
    }
    final completer = Completer<void>();
    _pending.add(_QueuedPlayback(data, completer));
    _ensureWorker();
    return completer.future;
  }

  void _ensureWorker() {
    if (_worker != null ||
        _pending.isEmpty ||
        _cancellationDepth != 0 ||
        _disposed) {
      return;
    }
    final generation = _generation;
    late final Future<void> worker;
    worker = _drain(generation);
    _worker = worker;
    unawaited(
      worker.whenComplete(() {
        if (identical(_worker, worker)) _worker = null;
        if (!_disposed && _pending.isNotEmpty) _ensureWorker();
      }),
    );
  }

  Future<void> _drain(int generation) async {
    while (!_disposed && generation == _generation && _pending.isNotEmpty) {
      final item = _pending.removeFirst();
      try {
        await _play(item.data);
        if (!item.completer.isCompleted) item.completer.complete();
      } catch (error, stack) {
        if (!item.completer.isCompleted) {
          if (generation == _generation && !_disposed) {
            item.completer.completeError(error, stack);
          } else {
            item.completer.complete();
          }
        }
      }
    }
  }

  Future<void> cancel() async {
    final activeWorker = _worker;
    _generation += 1;
    _cancellationDepth += 1;
    while (_pending.isNotEmpty) {
      final item = _pending.removeFirst();
      if (!item.completer.isCompleted) item.completer.complete();
    }
    Object? cancellationError;
    StackTrace? cancellationStack;
    try {
      await _stop();
    } catch (error, stack) {
      cancellationError = error;
      cancellationStack = stack;
    }
    try {
      await activeWorker;
    } catch (error, stack) {
      cancellationError ??= error;
      cancellationStack ??= stack;
    } finally {
      _cancellationDepth -= 1;
      if (_cancellationDepth == 0 && !_disposed && _pending.isNotEmpty) {
        _ensureWorker();
      }
    }
    if (cancellationError != null) {
      Error.throwWithStackTrace(cancellationError, cancellationStack!);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancel();
  }
}

/// Minimal player surface used to deterministically verify native setup races.
@visibleForTesting
abstract interface class AudioPlaybackPlayer {
  bool get playing;
  double get volume;
  Stream<PlayerState> get playerStateStream;
  Stream<Duration> get positionStream;

  Future<Duration?> setFilePath(String path);
  Future<void> play();
  Future<void> stop();
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class _JustAudioPlaybackPlayer implements AudioPlaybackPlayer {
  _JustAudioPlaybackPlayer(this._player);

  final AudioPlayer _player;

  @override
  bool get playing => _player.playing;

  @override
  double get volume => _player.volume;

  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Future<Duration?> setFilePath(String path) => _player.setFilePath(path);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() => _player.dispose();
}

class _PlaybackOwnership {
  _PlaybackOwnership(this.generation, this.operation);

  final int generation;
  final int operation;
  final Completer<void> cancelled = Completer<void>();
}

/// Serializes setup/playback and prevents a cancelled setup from owning the
/// shared native player after a newer generation becomes eligible to start.
@visibleForTesting
class AudioPlaybackController {
  AudioPlaybackController(
    AudioPlaybackPlayer player, {
    Future<Directory> Function()? temporaryDirectory,
    bool playerPrimed = false,
  }) : this._(
         player,
         temporaryDirectory ?? getTemporaryDirectory,
         playerPrimed,
       );

  AudioPlaybackController._(
    this._player,
    this._temporaryDirectory,
    this._playerPrimed,
  ) {
    _queue = AudioPlaybackQueue(_playMp3Now, _player.stop);
  }

  final AudioPlaybackPlayer _player;
  final Future<Directory> Function() _temporaryDirectory;
  late final AudioPlaybackQueue _queue;

  bool _playerPrimed;
  int _playbackGeneration = 0;
  int _nextOperation = 0;
  bool _disposed = false;
  _PlaybackOwnership? _activeOwnership;

  bool get isPlaying => _player.playing;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  @visibleForTesting
  bool get workerActive => _queue.workerActive;

  Future<void> playMp3(String base64Mp3) => _queue.add(base64Mp3);

  bool _owns(_PlaybackOwnership ownership) =>
      !_disposed &&
      identical(_activeOwnership, ownership) &&
      ownership.generation == _playbackGeneration;

  void _invalidateActiveOwnership() {
    _playbackGeneration += 1;
    final ownership = _activeOwnership;
    if (ownership != null && !ownership.cancelled.isCompleted) {
      ownership.cancelled.complete();
    }
  }

  Future<void> _playMp3Now(String base64Mp3) async {
    File? tempFile;
    File? retryFile;
    final ownership = _PlaybackOwnership(_playbackGeneration, _nextOperation++);
    _activeOwnership = ownership;
    try {
      if (!_owns(ownership)) return;
      final bytes = base64Decode(base64Mp3);
      final tempDir = await _temporaryDirectory();
      if (!_owns(ownership)) return;

      final fileSuffix =
          '${ownership.generation}_${ownership.operation}_'
          '${DateTime.now().microsecondsSinceEpoch}';
      tempFile = File('${tempDir.path}/osia_tts_$fileSuffix.mp3');
      await tempFile.writeAsBytes(bytes);
      if (!_owns(ownership)) return;

      debugPrint(
        '[OSIA Audio] Playing MP3 → ${bytes.length} bytes from ${tempFile.path}',
      );

      var playbackFile = tempFile;
      if (!_playerPrimed) {
        final volume = _player.volume;
        Timer? warmupTimer;
        try {
          if (!_owns(ownership)) return;
          await _player.setVolume(0);
          if (!_owns(ownership)) return;
          await _player.setFilePath(tempFile.path);
          if (!_owns(ownership)) return;

          final warmup = _player.play().catchError((Object _) {});
          final warmupTimeout = Completer<void>();
          warmupTimer = Timer(const Duration(milliseconds: 500), () {
            if (!warmupTimeout.isCompleted) warmupTimeout.complete();
          });
          await Future.any<void>(<Future<void>>[
            warmup,
            warmupTimeout.future,
            ownership.cancelled.future,
          ]);
          if (!_owns(ownership)) return;
        } finally {
          warmupTimer?.cancel();
          await _player.stop();
          await _player.setVolume(volume);
        }
        if (!_owns(ownership)) return;
        _playerPrimed = true;
        retryFile = File('${tempDir.path}/osia_tts_retry_$fileSuffix.mp3');
        await retryFile.writeAsBytes(bytes);
        if (!_owns(ownership)) return;
        playbackFile = retryFile;
      }

      if (!_owns(ownership)) return;
      final duration = await _player.setFilePath(playbackFile.path);
      if (!_owns(ownership)) {
        await _player.stop();
        return;
      }
      if (!_owns(ownership)) return;
      await playUntilStopped(
        _player.play,
        _player.playerStateStream,
        positions: _player.positionStream,
        cancellation: ownership.cancelled.future,
        expectedDuration: duration,
      );
      if (!_owns(ownership)) return;
      await _player.stop();
      if (!_owns(ownership)) return;
    } catch (error, stack) {
      if (_owns(ownership)) {
        debugPrint('[OSIA Audio] playMp3 error: $error');
        Error.throwWithStackTrace(error, stack);
      }
    } finally {
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      if (retryFile != null) {
        try {
          await retryFile.delete();
        } catch (_) {}
      }
      if (identical(_activeOwnership, ownership)) {
        _activeOwnership = null;
      }
    }
  }

  Future<void> stopPlayback() async {
    if (_disposed) return;
    _invalidateActiveOwnership();
    try {
      await _queue.cancel();
    } catch (error) {
      debugPrint('[OSIA Audio] stopPlayback error: $error');
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _invalidateActiveOwnership();
    await _queue.dispose();
    await _player.dispose();
  }
}

/// Service for audio recording (mic → WAV base64) and playback (MP3 base64 → speaker).
///
/// Recording flow:
/// ```dart
/// final service = AudioService();
/// final allowed = await service.ensureMicrophonePermission();
/// if (allowed) {
///   await service.startRecording();
///   // ... user speaks ...
///   final base64Wav = await service.stopRecording();
/// }
/// ```
///
/// Playback flow:
/// ```dart
/// await service.playMp3(base64Mp3Data);
/// ```
class AudioService {
  final AudioRecorder _recorder;
  final AudioPlaybackController _playback;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<String> Function(File) _consumeRecording;
  final Future<void> Function(File) _deleteRecording;
  late final Future<bool> Function() _ensureRecordingPermission;

  String? _recordingPath;
  bool _isRecording = false;
  bool _disposed = false;
  Future<void>? _recordingTransition;

  static final RegExp _ownedRecordingName = RegExp(
    r'^osia_recording_[0-9]+\.wav$',
  );

  /// Whether microphone permission has been permanently denied.
  bool _permissionDenied = false;

  AudioService({
    AudioRecorder? recorder,
    AudioPlayer? player,
    @visibleForTesting AudioPlaybackController? playbackController,
    @visibleForTesting Future<Directory> Function()? temporaryDirectory,
    @visibleForTesting Future<String> Function(File)? consumeRecording,
    @visibleForTesting Future<void> Function(File)? deleteRecording,
    @visibleForTesting Future<bool> Function()? recordingPermission,
  }) : _recorder = recorder ?? AudioRecorder(),
       _playback =
           playbackController ??
           AudioPlaybackController(
             _JustAudioPlaybackPlayer(player ?? AudioPlayer()),
           ),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _consumeRecording = consumeRecording ?? _readRecording,
       _deleteRecording = deleteRecording ?? _deleteFile {
    _ensureRecordingPermission =
        recordingPermission ?? ensureMicrophonePermission;
  }

  static Future<String> _readRecording(File file) async {
    return base64Encode(await file.readAsBytes());
  }

  static Future<void> _deleteFile(File file) => file.delete();

  static String _fileName(String path) {
    return path.replaceAll('\\', '/').split('/').last;
  }

  static void _logCleanupFailure(Object error) {
    debugPrint('[OSIA Audio] Recording cleanup failed (${error.runtimeType}).');
  }

  /// Remove only orphaned OSIA recording WAVs from the application temp root.
  ///
  /// The scan is flat, does not follow links, and ignores non-regular files.
  static Future<void> cleanupOrphanedRecordings({
    @visibleForTesting Future<Directory> Function()? temporaryDirectory,
    @visibleForTesting Future<void> Function(File)? deleteRecording,
  }) async {
    try {
      final directory = await (temporaryDirectory ?? getTemporaryDirectory)();
      await for (final entity in directory.list(
        recursive: false,
        followLinks: false,
      )) {
        if (!_ownedRecordingName.hasMatch(_fileName(entity.path))) continue;

        FileSystemEntityType type;
        try {
          type = await FileSystemEntity.type(entity.path, followLinks: false);
        } on FileSystemException {
          // A concurrent cleanup may have removed the entry already.
          continue;
        }
        if (type != FileSystemEntityType.file) continue;

        try {
          await (deleteRecording ?? _deleteFile)(File(entity.path));
        } on FileSystemException catch (error) {
          final currentType = await FileSystemEntity.type(
            entity.path,
            followLinks: false,
          );
          if (currentType != FileSystemEntityType.notFound) {
            _logCleanupFailure(error);
          }
        } catch (error) {
          _logCleanupFailure(error);
        }
      }
    } catch (error) {
      _logCleanupFailure(error);
    }
  }

  @visibleForTesting
  bool get hasOwnedRecording => _recordingPath != null;

  Future<T> _runRecordingTransition<T>(Future<T> Function() operation) async {
    if (_recordingTransition != null) {
      throw StateError('recording transition already active');
    }
    final completed = Completer<void>();
    final transition = completed.future;
    _recordingTransition = transition;
    try {
      return await operation();
    } finally {
      completed.complete();
      if (identical(_recordingTransition, transition)) {
        _recordingTransition = null;
      }
    }
  }

  Future<void> _cleanupOwnedRecording() async {
    final path = _recordingPath;
    _recordingPath = null;
    if (path == null) return;

    try {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) return;
      if (type != FileSystemEntityType.file) return;
      await _deleteRecording(File(path));
    } catch (error) {
      _logCleanupFailure(error);
    }
  }

  // ── Permissions ────────────────────────────────────────────────────────

  /// Whether microphone permission has been permanently denied
  /// (user tapped "Don't ask again").
  bool get isPermissionPermanentlyDenied => _permissionDenied;

  /// Check and request microphone permission at runtime.
  ///
  /// Returns `true` if permission is granted.
  /// On permanent denial, sets [isPermissionPermanentlyDenied] to `true`.
  Future<bool> ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      _permissionDenied = false;
      return true;
    }

    if (status.isPermanentlyDenied) {
      _permissionDenied = true;
      debugPrint('[OSIA Audio] Microphone permission permanently denied.');
      return false;
    }

    // Request permission
    final result = await Permission.microphone.request();

    if (result.isGranted) {
      _permissionDenied = false;
      debugPrint('[OSIA Audio] Microphone permission granted.');
      return true;
    }

    if (result.isPermanentlyDenied) {
      _permissionDenied = true;
      debugPrint('[OSIA Audio] Microphone permission permanently denied.');
    } else {
      debugPrint('[OSIA Audio] Microphone permission denied.');
    }

    return false;
  }

  /// Open the app settings so the user can grant microphone permission.
  Future<void> openMicrophoneSettings() async {
    await openAppSettings();
  }

  // ── Recording ──────────────────────────────────────────────────────────

  /// Whether a recording is currently in progress.
  bool get isRecording => _isRecording;

  /// Start recording from the microphone.
  ///
  /// Call [ensureMicrophonePermission] first to check/request permission.
  /// Audio is saved to a temporary WAV file which will be returned
  /// as base64 when [stopRecording] is called.
  Future<void> startRecording() async {
    if (_disposed) throw StateError('audio service disposed');
    if (_isRecording || _recordingPath != null) {
      throw StateError('recording already active');
    }

    await _runRecordingTransition<void>(() async {
      // Double-check permission
      final allowed = await _ensureRecordingPermission();
      if (!allowed) {
        throw Exception('Microphone permission not granted.');
      }

      var recorderStartAttempted = false;
      try {
        final tempDir = await _temporaryDirectory();
        _recordingPath =
            '${tempDir.path}/osia_recording_${DateTime.now().microsecondsSinceEpoch}.wav';

        const config = RecordConfig(
          encoder: AudioEncoder.wav,
          numChannels: 1,
          sampleRate: 16000,
          bitRate: 256000,
        );

        recorderStartAttempted = true;
        await _recorder.start(config, path: _recordingPath!);
        _isRecording = true;
        debugPrint('[OSIA Audio] Recording started.');
      } catch (error, stack) {
        if (recorderStartAttempted) {
          try {
            await _recorder.cancel();
          } catch (_) {}
        }
        _isRecording = false;
        await _cleanupOwnedRecording();
        debugPrint(
          '[OSIA Audio] startRecording failed (${error.runtimeType}).',
        );
        Error.throwWithStackTrace(error, stack);
      }
    });
  }

  /// Stop recording and return the audio as a base64-encoded WAV string.
  ///
  /// Returns `null` if no recording was in progress or the file is missing.
  Future<String?> stopRecording() async {
    final activeTransition = _recordingTransition;
    if (activeTransition != null) await activeTransition;
    if (!_isRecording) {
      await _cleanupOwnedRecording();
      return null;
    }

    return _runRecordingTransition<String?>(() async {
      try {
        final stoppedPath = await _recorder.stop();
        _isRecording = false;

        final ownedPath = _recordingPath;
        if (ownedPath == null) {
          debugPrint('[OSIA Audio] Recording path unavailable after stop.');
          return null;
        }
        if (stoppedPath != null && stoppedPath != ownedPath) {
          debugPrint('[OSIA Audio] Recorder returned an unexpected path.');
        }

        final type = await FileSystemEntity.type(ownedPath, followLinks: false);
        if (type != FileSystemEntityType.file) {
          debugPrint('[OSIA Audio] Recording file unavailable after stop.');
          return null;
        }

        final base64 = await _consumeRecording(File(ownedPath));
        debugPrint(
          '[OSIA Audio] Recording consumed (base64_len=${base64.length}).',
        );
        return base64;
      } catch (error, stack) {
        try {
          await _recorder.cancel();
        } catch (_) {}
        debugPrint('[OSIA Audio] stopRecording failed (${error.runtimeType}).');
        Error.throwWithStackTrace(error, stack);
      } finally {
        _isRecording = false;
        await _cleanupOwnedRecording();
      }
    });
  }

  /// Cancel recording without returning data.
  Future<void> cancelRecording() async {
    final activeTransition = _recordingTransition;
    if (activeTransition != null) await activeTransition;
    await _runRecordingTransition<void>(() async {
      try {
        if (_isRecording) {
          await _recorder.cancel();
        }
      } catch (error) {
        debugPrint(
          '[OSIA Audio] cancelRecording failed (${error.runtimeType}).',
        );
      } finally {
        _isRecording = false;
        await _cleanupOwnedRecording();
      }
    });
  }

  // ── Playback ───────────────────────────────────────────────────────────

  /// Play MP3 audio from a base64-encoded string.
  ///
  /// Successive calls are queued and play in exact arrival order.
  Future<void> playMp3(String base64Mp3) => _playback.playMp3(base64Mp3);

  /// Stop any ongoing playback.
  Future<void> stopPlayback() => _playback.stopPlayback();

  /// Whether audio is currently playing.
  bool get isPlaying => _playback.isPlaying;

  /// Stream of playback state changes.
  Stream<PlayerState> get playerStateStream => _playback.playerStateStream;

  // ── Lifecycle ─────────────────────────────────────────────────────────

  /// Release all native resources.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final transition = _recordingTransition;
    if (transition != null) await transition;
    await cancelRecording();
    await _playback.dispose();
    await _recorder.dispose();
  }
}
