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

/// One bounded FIFO that serializes TTS clips and invalidates stale playback.
class AudioPlaybackQueue {
  AudioPlaybackQueue(this._play, this._stop, {this.maxPending = 64});

  final Future<void> Function(String data) _play;
  final Future<void> Function() _stop;
  final int maxPending;
  final ListQueue<_QueuedPlayback> _pending = ListQueue<_QueuedPlayback>();
  Future<void>? _worker;
  int _generation = 0;
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
    if (_worker != null || _pending.isEmpty || _disposed) return;
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
    _generation += 1;
    while (_pending.isNotEmpty) {
      final item = _pending.removeFirst();
      if (!item.completer.isCompleted) item.completer.complete();
    }
    await _stop();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancel();
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
  final AudioPlayer _player;
  late final AudioPlaybackQueue _playbackQueue;

  String? _recordingPath;
  bool _isRecording = false;

  /// Whether microphone permission has been permanently denied.
  bool _permissionDenied = false;

  AudioService({AudioRecorder? recorder, AudioPlayer? player})
    : _recorder = recorder ?? AudioRecorder(),
      _player = player ?? AudioPlayer() {
    _playbackQueue = AudioPlaybackQueue(_playMp3Now, _player.stop);
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
    if (_isRecording) return;

    // Double-check permission
    final allowed = await ensureMicrophonePermission();
    if (!allowed) {
      throw Exception('Microphone permission not granted.');
    }

    try {
      final tempDir = await getTemporaryDirectory();
      _recordingPath =
          '${tempDir.path}/osia_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        numChannels: 1,
        sampleRate: 16000,
        bitRate: 256000,
      );

      await _recorder.start(config, path: _recordingPath!);
      _isRecording = true;
      debugPrint('[OSIA Audio] Recording started → $_recordingPath');
    } catch (e) {
      debugPrint('[OSIA Audio] startRecording error: $e');
      _isRecording = false;
      rethrow;
    }
  }

  /// Stop recording and return the audio as a base64-encoded WAV string.
  ///
  /// Returns `null` if no recording was in progress or the file is missing.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;

      final effectivePath = path ?? _recordingPath;
      if (effectivePath == null) {
        debugPrint('[OSIA Audio] No recording path after stop.');
        return null;
      }

      final file = File(effectivePath);
      if (!file.existsSync()) {
        debugPrint('[OSIA Audio] Recording file not found: $effectivePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final base64 = base64Encode(bytes);
      debugPrint(
        '[OSIA Audio] Recording stopped → ${bytes.length} bytes, base64 len=${base64.length}',
      );

      // Clean up the temp file
      try {
        await file.delete();
      } catch (_) {}

      return base64;
    } catch (e) {
      _isRecording = false;
      debugPrint('[OSIA Audio] stopRecording error: $e');
      rethrow;
    }
  }

  /// Cancel recording without returning data.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try {
      await _recorder.cancel();
      _isRecording = false;
      // Clean up
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (file.existsSync()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('[OSIA Audio] cancelRecording error: $e');
      _isRecording = false;
    }
  }

  // ── Playback ───────────────────────────────────────────────────────────

  /// Play MP3 audio from a base64-encoded string.
  ///
  /// Successive calls are queued and play in exact arrival order.
  Future<void> playMp3(String base64Mp3) => _playbackQueue.add(base64Mp3);

  Future<void> _playMp3Now(String base64Mp3) async {
    File? tempFile;
    try {
      // Decode base64 and write to a temp file
      final bytes = base64Decode(base64Mp3);
      final tempDir = await getTemporaryDirectory();
      tempFile = File(
        '${tempDir.path}/osia_tts_${DateTime.now().microsecondsSinceEpoch}.mp3',
      );
      await tempFile.writeAsBytes(bytes);

      debugPrint(
        '[OSIA Audio] Playing MP3 → ${bytes.length} bytes from ${tempFile.path}',
      );

      // Load and play
      await _player.setFilePath(tempFile.path);
      await _player.play();
    } catch (e) {
      debugPrint('[OSIA Audio] playMp3 error: $e');
      rethrow;
    } finally {
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Stop any ongoing playback.
  Future<void> stopPlayback() async {
    try {
      await _playbackQueue.cancel();
    } catch (e) {
      debugPrint('[OSIA Audio] stopPlayback error: $e');
    }
  }

  /// Whether audio is currently playing.
  bool get isPlaying => _player.playing;

  /// Stream of playback state changes.
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  // ── Lifecycle ─────────────────────────────────────────────────────────

  /// Release all native resources.
  Future<void> dispose() async {
    if (_isRecording) {
      await cancelRecording();
    }
    await _playbackQueue.dispose();
    await _recorder.dispose();
    await _player.dispose();
  }
}
