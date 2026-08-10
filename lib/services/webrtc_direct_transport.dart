import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'relay_crypto_service.dart';
import 'transport_coordinator.dart';
import 'webrtc_signaling.dart';

const int _maxApplicationFrameBytes = 16 * 1024 * 1024;
const int _maxDirectEnvelopeBytes = 24 * 1024 * 1024;
const int _directChunkBytes = 9 * 1024;
const int _maxDirectChunks = 3072;
const int _maxDirectInflight = 4;
const int _dataChannelHighWater = 512 * 1024;
const int _dataChannelLowWater = 256 * 1024;
const int _maxSendQueueItems = _maxDirectChunks;
const int _maxSendQueueBytes = 24 * 1024 * 1024;
const Duration _connectTimeout = Duration(seconds: 20);
const Duration _sendTimeout = Duration(seconds: 15);
const Duration _sendTimeoutPerChunk = Duration(milliseconds: 500);
const Duration _maxSendTimeout = Duration(minutes: 5);
const Duration _reassemblyTimeout = Duration(seconds: 30);

const Set<String> _helloFields = <String>{
  'type',
  'protocol_version',
  'transport',
  'attempt_id',
  'generation',
  'source_role',
  'destination_role',
  'data_channel_label',
  'data_channel_protocol',
  'e2e_version',
  'alg',
  'public_key',
  'nonce_base',
};
const Set<String> _readyFields = <String>{
  'type',
  'protocol_version',
  'transport',
  'attempt_id',
  'generation',
  'source_role',
  'destination_role',
  'e2e_version',
  'alg',
  'kid',
  'tag',
};
const Set<String> _e2eFields = <String>{
  'type',
  'e2e_version',
  'alg',
  'kid',
  'pair_id',
  'role',
  'seq',
  'priority',
  'final',
  'nonce',
  'ciphertext',
};
const Set<String> _chunkFields = <String>{
  'type',
  'message_id',
  'chunk_index',
  'chunk_count',
  'total_bytes',
  'checksum',
  'data',
};

bool _hasExactKeys(Map<Object?, Object?> value, Set<String> fields) =>
    value.length == fields.length && value.keys.every(fields.contains);

String _randomHex(int bytes) {
  final random = Random.secure();
  return List<int>.generate(
    bytes,
    (_) => random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

String webRtcDirectPairId(String pairId, String attemptId, int generation) =>
    sha256
        .convert(
          utf8.encode(
            'osia-webrtc-direct-v$webRtcProtocolVersion:'
            '$pairId:$attemptId:$generation:pc:mobile:'
            '$webRtcDataChannelLabel:$webRtcDataChannelProtocol',
          ),
        )
        .toString();

enum WebRtcDirectState {
  idle,
  preparing,
  answering,
  connecting,
  authenticating,
  ready,
  activeTurn,
  closing,
  disconnected,
}

class WebRtcCloseInfo {
  const WebRtcCloseInfo({required this.category, required this.hadActiveTurn});

  final String category;
  final bool hadActiveTurn;
}

abstract interface class WebRtcDataChannelAdapter {
  String get label;
  String get state;
  int get bufferedAmount;
  set bufferedAmountLowThreshold(int value);
  set onBufferedAmountLow(VoidCallback? callback);
  set onMessage(void Function(String? text)? callback);
  set onState(void Function(String state)? callback);
  Future<void> send(String message);
  Future<void> close();
}

abstract interface class WebRtcPeerConnectionAdapter {
  set onDataChannel(void Function(WebRtcDataChannelAdapter channel)? callback);
  set onIceCandidate(void Function(Map<String, Object?>? candidate)? callback);
  set onConnectionState(void Function(String state)? callback);
  Future<void> setRemoteOffer(String sdp);
  Future<void> addRemoteCandidate(Map<String, Object?>? candidate);
  Future<String> createAndSetLocalAnswer();
  Future<Map<String, String>> selectedCandidateSummary();
  Future<String> connectionState();
  Future<void> close();
}

typedef WebRtcPeerConnectionFactory =
    Future<WebRtcPeerConnectionAdapter> Function(
      List<Map<String, Object?>> iceServers,
    );

class WebRtcDirectTransport {
  WebRtcDirectTransport({
    required this.capability,
    required this.token,
    required this.pairId,
    required this.sendSignal,
    required this.authorizeCommit,
    required this.onFrame,
    required this.onClosed,
    WebRtcPeerConnectionFactory? peerConnectionFactory,
    Duration connectTimeout = _connectTimeout,
  }) : _peerConnectionFactory =
           peerConnectionFactory ?? _createProductionPeerConnection,
       _connectTimeoutValue = connectTimeout;

  final WebRtcCapability capability;
  final String token;
  final String pairId;
  final bool Function(Map<String, Object?> frame) sendSignal;
  final bool Function() authorizeCommit;
  final void Function(Map<String, dynamic> frame) onFrame;
  final void Function(WebRtcCloseInfo info) onClosed;
  final WebRtcPeerConnectionFactory _peerConnectionFactory;
  final Duration _connectTimeoutValue;

  final SequenceReplayGuard _replayGuard = SequenceReplayGuard();
  final OutboundSequence _outboundSequence = OutboundSequence();
  final WebRtcDirectChunkReassembler _reassembler =
      WebRtcDirectChunkReassembler();
  final Set<String> _remoteEventIds = <String>{};
  final Set<String> _remoteCandidateKeys = <String>{};
  final Set<String> _localCandidateKeys = <String>{};
  final List<Map<String, Object?>> _pendingRemoteCandidates =
      <Map<String, Object?>>[];

  String attemptId = '';
  int generation = 0;
  String _directPairId = '';
  late final List<int> _privateKey;
  late final List<int> _publicKey;
  late final List<int> _nonceBase;
  RelaySessionContext? _context;
  RelaySessionKeys? _keys;
  WebRtcPeerConnectionAdapter? _peerConnection;
  WebRtcDataChannelAdapter? _channel;
  Completer<bool>? _readyCompleter;
  Completer<void>? _bufferLowCompleter;
  Future<void> _receiveChain = Future<void>.value();
  Future<void> _sendChain = Future<void>.value();
  Future<void>? _closeFuture;
  Timer? _connectTimer;
  Timer? _disconnectTimer;
  WebRtcDirectState _state = WebRtcDirectState.idle;
  int _signalSequence = 0;
  int _lastRemoteSignalSequence = 0;
  int _queuedItems = 0;
  int _queuedBytes = 0;
  int _bytesSent = 0;
  int _bytesReceived = 0;
  bool _remoteOfferApplied = false;
  bool _remoteEndOfCandidates = false;
  bool _localEndOfCandidatesSent = false;
  bool _helloSent = false;
  bool _peerAuthenticated = false;
  bool _commitSent = false;
  bool _genuineP2p = false;
  bool _terminalSignalSent = false;
  bool _closedNotified = false;
  String _activeRequestId = '';
  String _activeTurnId = '';

  WebRtcDirectState get state => _state;
  bool get active =>
      _state == WebRtcDirectState.ready ||
      _state == WebRtcDirectState.activeTurn;
  bool get genuineP2p => active && _genuineP2p;

  Future<bool> connect({required int attemptGeneration}) async {
    if (_state != WebRtcDirectState.idle || !capability.enabled) return false;
    _state = WebRtcDirectState.preparing;
    attemptId = _randomHex(16);
    generation = attemptGeneration;
    _directPairId = webRtcDirectPairId(pairId, attemptId, generation);
    _privateKey = generateX25519PrivateKey();
    _publicKey = await x25519PublicKey(_privateKey);
    _nonceBase = generateNonceBase();
    _readyCompleter = Completer<bool>();
    _connectTimer = Timer(_connectTimeoutValue, () {
      _sendTerminalSignal('webrtc_failed', 'timeout');
      _completeReady(false);
    });
    final queued = _sendSignal('webrtc_prepare', <String, Object?>{
      'configuration_id': capability.configurationId,
    });
    if (!queued) {
      await close();
      return false;
    }
    final ready = await _readyCompleter!.future;
    if (!ready || !active) {
      await close();
      return false;
    }
    _connectTimer?.cancel();
    return true;
  }

  Future<bool> handleSignal(Map<String, Object?> raw) async {
    final eventType = raw['event_type']?.toString() ?? '';
    if (!webRtcSignalEventTypes.contains(eventType)) return false;
    final frame = validateWebRtcSignal(raw, destinationRole: 'mobile');
    if (frame['source_role'] != 'pc' ||
        frame['attempt_id'] != attemptId ||
        frame['generation'] != generation) {
      return true;
    }
    final eventId = frame['event_id'] as String;
    final sequence = frame['sequence'] as int;
    if (_remoteEventIds.contains(eventId) ||
        sequence <= _lastRemoteSignalSequence) {
      return true;
    }
    _remoteEventIds.add(eventId);
    _lastRemoteSignalSequence = sequence;
    try {
      switch (eventType) {
        case 'webrtc_offer':
          await _handleOffer((frame['payload'] as Map).cast<String, Object?>());
        case 'webrtc_ice_candidates':
          await _handleCandidates(
            (frame['payload'] as Map)['candidates'] as List,
          );
        case 'webrtc_end_of_candidates':
          _remoteEndOfCandidates = true;
          if (_remoteOfferApplied) {
            await _peerConnection?.addRemoteCandidate(null);
          }
        case 'webrtc_cancel' || 'webrtc_failed':
          _terminalSignalSent = true;
          await _beginClose(
            notify: active,
            category:
                ((frame['payload'] as Map)['category'] ?? 'signaling_failed')
                    .toString(),
          );
      }
    } catch (error) {
      debugPrint('[OSIA WebRTC] signaling rejected: ${error.runtimeType}');
      await fail('protocol_error');
    }
    return true;
  }

  Future<void> _handleOffer(Map<String, Object?> payload) async {
    if (_remoteOfferApplied || _state != WebRtcDirectState.preparing) {
      throw const FormatException('duplicate WebRTC offer');
    }
    _state = WebRtcDirectState.answering;
    final peer = await _peerConnectionFactory(capability.iceServers);
    _peerConnection = peer;
    peer.onDataChannel = _attachDataChannel;
    peer.onIceCandidate = _handleLocalCandidate;
    peer.onConnectionState = (state) {
      debugPrint('[OSIA WebRTC] peer state=$state');
      if (state == 'failed' || state == 'closed') {
        unawaited(fail('ice_failed'));
      } else if (state == 'disconnected') {
        _disconnectTimer?.cancel();
        _disconnectTimer = Timer(const Duration(seconds: 5), () async {
          if (await peer.connectionState() == 'disconnected') {
            await fail('ice_failed');
          }
        });
      } else if (state == 'connected') {
        _disconnectTimer?.cancel();
      }
    };
    await peer.setRemoteOffer(payload['sdp'] as String);
    _remoteOfferApplied = true;
    for (final candidate in _pendingRemoteCandidates) {
      await _addRemoteCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
    if (_remoteEndOfCandidates) {
      await peer.addRemoteCandidate(null);
    }
    final localSdp = await peer.createAndSetLocalAnswer();
    final stripped = stripWebRtcSdpCandidates(localSdp);
    if (!_sendSignal('webrtc_answer', <String, Object?>{
      'type': 'answer',
      'sdp': stripped.sdp,
    })) {
      throw StateError('WebRTC answer signaling unavailable');
    }
    for (final candidate in stripped.candidates) {
      _sendLocalCandidate(candidate);
    }
    _state = WebRtcDirectState.connecting;
  }

  Future<void> _handleCandidates(List<dynamic> values) async {
    for (final raw in values) {
      final candidate = validateWebRtcCandidate(raw);
      final key = webRtcCandidateDedupKey(candidate);
      if (!_remoteCandidateKeys.add(key)) continue;
      if (_remoteCandidateKeys.length > webRtcMaxCandidates) {
        throw const FormatException('too many remote WebRTC candidates');
      }
      if (!_remoteOfferApplied) {
        _pendingRemoteCandidates.add(candidate);
      } else {
        await _addRemoteCandidate(candidate);
      }
    }
  }

  Future<void> _addRemoteCandidate(Map<String, Object?> candidate) =>
      _peerConnection!.addRemoteCandidate(candidate);

  void _handleLocalCandidate(Map<String, Object?>? native) {
    if (native == null || (native['candidate']?.toString() ?? '').isEmpty) {
      if (!_localEndOfCandidatesSent) {
        _localEndOfCandidatesSent = _sendSignal(
          'webrtc_end_of_candidates',
          const <String, Object?>{},
        );
      }
      return;
    }
    try {
      _sendLocalCandidate(validateWebRtcCandidate(native));
    } catch (_) {
      unawaited(fail('protocol_error'));
    }
  }

  void _sendLocalCandidate(Map<String, Object?> candidate) {
    final key = webRtcCandidateDedupKey(candidate);
    if (!_localCandidateKeys.add(key)) return;
    if (_localCandidateKeys.length > webRtcMaxCandidates ||
        !_sendSignal('webrtc_ice_candidates', <String, Object?>{
          'candidates': <Map<String, Object?>>[candidate],
        })) {
      throw const FormatException('local candidate signaling failed');
    }
  }

  void _attachDataChannel(WebRtcDataChannelAdapter channel) {
    if (_channel != null || channel.label != webRtcDataChannelLabel) {
      unawaited(channel.close());
      unawaited(fail('protocol_error'));
      return;
    }
    _channel = channel;
    channel.bufferedAmountLowThreshold = _dataChannelLowWater;
    channel.onBufferedAmountLow = () {
      final completer = _bufferLowCompleter;
      _bufferLowCompleter = null;
      if (completer != null && !completer.isCompleted) completer.complete();
    };
    channel.onMessage = (text) {
      if (text == null) {
        unawaited(fail('protocol_error'));
        return;
      }
      _queueIncoming(text);
    };
    channel.onState = (state) {
      if (state == 'open') {
        unawaited(_onChannelOpen());
      } else if (state == 'closed') {
        unawaited(fail('unavailable'));
      }
    };
    if (channel.state == 'open') {
      unawaited(_onChannelOpen());
    }
  }

  Future<void> _onChannelOpen() async {
    if (_helloSent || _state != WebRtcDirectState.connecting) return;
    _helloSent = true;
    _state = WebRtcDirectState.authenticating;
    await _sendPlain(<String, Object?>{
      'type': 'webrtc_e2e_hello',
      'protocol_version': webRtcProtocolVersion,
      'transport': 'webrtc',
      'attempt_id': attemptId,
      'generation': generation,
      'source_role': 'mobile',
      'destination_role': 'pc',
      'data_channel_label': webRtcDataChannelLabel,
      'data_channel_protocol': webRtcDataChannelProtocol,
      'e2e_version': relayE2eVersion,
      'alg': relayCryptoAlgChacha20Poly1305,
      'public_key': b64UrlEncodeNoPadding(_publicKey),
      'nonce_base': b64UrlEncodeNoPadding(_nonceBase),
    });
  }

  void _queueIncoming(String raw) {
    _receiveChain = _receiveChain.then((_) => _handleIncoming(raw)).catchError((
      Object error,
      StackTrace stack,
    ) async {
      debugPrint('[OSIA WebRTC] direct frame rejected: ${error.runtimeType}');
      await fail('protocol_error');
    });
  }

  Future<void> _handleIncoming(String raw) async {
    final bytes = utf8.encode(raw).length;
    if (bytes > _directChunkBytes * 2) {
      throw const FormatException('oversized direct message');
    }
    _bytesReceived += bytes;
    Object? decoded = jsonDecode(raw);
    if (decoded is Map && decoded['type'] == 'WEBRTC_CHUNK') {
      final complete = _reassembler.accept(decoded.cast<String, Object?>());
      if (complete == null) return;
      decoded = jsonDecode(complete);
    }
    if (decoded is! Map) throw const FormatException('invalid direct message');
    final message = decoded.cast<String, Object?>();
    switch (message['type']) {
      case 'webrtc_e2e_hello':
        await _handlePcHello(message);
      case 'webrtc_e2e_ready':
        await _handlePcReady(message);
      case 'E2E_FRAME':
        await _handleEncrypted(message);
      default:
        throw const FormatException('unexpected direct message');
    }
  }

  Future<void> _handlePcHello(Map<String, Object?> message) async {
    if (_context != null ||
        !_hasExactKeys(message, _helloFields) ||
        message['protocol_version'] != webRtcProtocolVersion ||
        message['transport'] != 'webrtc' ||
        message['attempt_id'] != attemptId ||
        message['generation'] != generation ||
        message['source_role'] != 'pc' ||
        message['destination_role'] != 'mobile' ||
        message['data_channel_label'] != webRtcDataChannelLabel ||
        message['data_channel_protocol'] != webRtcDataChannelProtocol ||
        message['e2e_version'] != relayE2eVersion ||
        message['alg'] != relayCryptoAlgChacha20Poly1305) {
      throw const FormatException('invalid PC WebRTC E2E hello');
    }
    final pcPublicKey = b64UrlDecodeNoPadding(
      message['public_key']?.toString() ?? '',
    );
    final pcNonceBase = b64UrlDecodeNoPadding(
      message['nonce_base']?.toString() ?? '',
    );
    final context = RelaySessionContext(
      pairId: _directPairId,
      pcPublicKey: pcPublicKey,
      mobilePublicKey: _publicKey,
      pcNonceBase: pcNonceBase,
      mobileNonceBase: _nonceBase,
    );
    final keys = await deriveSessionKeys(
      token: token,
      localPrivateKey: _privateKey,
      peerPublicKey: pcPublicKey,
      context: context,
    );
    _context = context;
    _keys = keys;
    await _sendPlain(<String, Object?>{
      'type': 'webrtc_e2e_ready',
      'protocol_version': webRtcProtocolVersion,
      'transport': 'webrtc',
      'attempt_id': attemptId,
      'generation': generation,
      'source_role': 'mobile',
      'destination_role': 'pc',
      'e2e_version': relayE2eVersion,
      'alg': relayCryptoAlgChacha20Poly1305,
      'kid': keys.kid,
      'tag': handshakeConfirmationTag(
        token: token,
        context: context,
        senderRole: 'mobile',
      ),
    });
  }

  Future<void> _handlePcReady(Map<String, Object?> message) async {
    final context = _context;
    final keys = _keys;
    if (_peerAuthenticated ||
        context == null ||
        keys == null ||
        !_hasExactKeys(message, _readyFields) ||
        message['protocol_version'] != webRtcProtocolVersion ||
        message['transport'] != 'webrtc' ||
        message['attempt_id'] != attemptId ||
        message['generation'] != generation ||
        message['source_role'] != 'pc' ||
        message['destination_role'] != 'mobile' ||
        message['e2e_version'] != relayE2eVersion ||
        message['alg'] != relayCryptoAlgChacha20Poly1305 ||
        message['kid'] != keys.kid ||
        !verifyHandshakeConfirmation(
          token: token,
          context: context,
          senderRole: 'pc',
          tag: message['tag']?.toString() ?? '',
        )) {
      throw const FormatException('PC WebRTC identity confirmation failed');
    }
    _peerAuthenticated = true;
  }

  Future<void> _handleEncrypted(Map<String, Object?> envelope) async {
    final keys = _keys;
    if (keys == null ||
        !_peerAuthenticated ||
        !_hasExactKeys(envelope, _e2eFields) ||
        envelope['pair_id'] != _directPairId ||
        envelope['role'] != 'pc') {
      throw const FormatException(
        'encrypted frame before WebRTC authentication',
      );
    }
    final frame = await decryptFrame(
      envelope,
      keys: keys,
      direction: RelayCryptoDirection.pcToMobile,
      replayGuard: _replayGuard,
      replayKey: 'pc',
    );
    final eventType = frame['event_type']?.toString() ?? '';
    if (eventType == 'webrtc_direct_ready') {
      final signal = validateWebRtcSignal(frame, destinationRole: 'mobile');
      if (signal['attempt_id'] != attemptId ||
          signal['generation'] != generation ||
          _state != WebRtcDirectState.authenticating) {
        throw const FormatException('WebRTC commit authorization failed');
      }
      if (!await _refreshSelectedPairTruth()) {
        throw const FormatException('WebRTC selected pair is not direct P2P');
      }
      if (!authorizeCommit()) {
        throw const FormatException('WebRTC commit authorization failed');
      }
      _commitSent = true;
      await _sendEncrypted(
        makeWebRtcSignal(
          'webrtc_direct_commit',
          attemptId: attemptId,
          generation: generation,
          sequence: _nextSignalSequence(),
        ),
      );
      return;
    }
    if (eventType == 'webrtc_direct_commit_ack') {
      final signal = validateWebRtcSignal(frame, destinationRole: 'mobile');
      if (!_commitSent ||
          signal['attempt_id'] != attemptId ||
          signal['generation'] != generation ||
          _state != WebRtcDirectState.authenticating) {
        throw const FormatException('invalid WebRTC commit acknowledgement');
      }
      _state = WebRtcDirectState.ready;
      _completeReady(true);
      return;
    }
    if (!active || frame['type'] == 'auth') {
      throw const FormatException('application frame before WebRTC commit');
    }
    final application = frame.cast<String, dynamic>();
    if (utf8.encode(jsonEncode(application)).length >
        _maxApplicationFrameBytes) {
      throw const FormatException('WebRTC application frame too large');
    }
    _observeInboundApplicationFrame(application);
    onFrame(application);
  }

  bool send(Map<String, dynamic> frame) {
    final type = frame['type']?.toString() ?? '';
    final requestId =
        frame['request_id']?.toString() ??
        frame['client_request_id']?.toString() ??
        '';
    final turnId = frame['turn_id']?.toString() ?? '';
    final startsTurn = isApplicationTurnStartingFrame(frame);
    if (!active ||
        type == 'auth' ||
        utf8.encode(jsonEncode(frame)).length > _maxApplicationFrameBytes ||
        (startsTurn && requestId.isEmpty)) {
      return false;
    }
    if (startsTurn) {
      if (_state == WebRtcDirectState.ready) {
        _activeRequestId = requestId;
        _activeTurnId = turnId;
        _state = WebRtcDirectState.activeTurn;
      } else if (_state != WebRtcDirectState.activeTurn ||
          requestId != _activeRequestId ||
          (turnId.isNotEmpty && turnId != _activeTurnId)) {
        return false;
      }
    }
    final stable = Map<String, Object?>.from(frame);
    _sendChain = _sendChain.then((_) => _sendEncrypted(stable)).catchError((
      Object error,
      StackTrace stack,
    ) async {
      await fail('bridge_unavailable');
    });
    return true;
  }

  /// Wait for the ordered DataChannel send chain, including its bufferedAmount
  /// high/low-water backpressure, to drain.
  Future<void> drain() => _sendChain;

  void _observeInboundApplicationFrame(Map<String, dynamic> frame) {
    if (_state != WebRtcDirectState.activeTurn) return;
    final requestId =
        frame['request_id']?.toString() ??
        frame['client_request_id']?.toString() ??
        '';
    final turnId = frame['turn_id']?.toString() ?? '';
    if (requestId == _activeRequestId &&
        _activeTurnId.isEmpty &&
        turnId.isNotEmpty) {
      _activeTurnId = turnId;
    }
    final sameTurn =
        requestId == _activeRequestId &&
        (_activeTurnId.isEmpty || turnId.isEmpty || turnId == _activeTurnId);
    final terminalError =
        frame['terminal'] == true &&
        const <String>{
          'error',
          'cancelled',
          'canceled',
          'rejected',
        }.contains(frame['status']);
    if (sameTurn && (terminalError || frame['media_terminal'] == true)) {
      _activeRequestId = '';
      _activeTurnId = '';
      _state = WebRtcDirectState.ready;
    }
  }

  bool _sendSignal(String type, Map<String, Object?> payload) => sendSignal(
    makeWebRtcSignal(
      type,
      attemptId: attemptId,
      generation: generation,
      sequence: _nextSignalSequence(),
      payload: payload,
    ),
  );

  int _nextSignalSequence() => ++_signalSequence;

  void _sendTerminalSignal(String eventType, String category) {
    if (_terminalSignalSent ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(attemptId) ||
        generation < 1) {
      return;
    }
    _terminalSignalSent = true;
    sendSignal(
      makeWebRtcSignal(
        eventType,
        attemptId: attemptId,
        generation: generation,
        sequence: _nextSignalSequence(),
        payload: <String, Object?>{'category': category},
        terminal: true,
      ),
    );
  }

  Future<void> _sendPlain(Map<String, Object?> message) =>
      _sendSerialized(jsonEncode(message));

  Future<void> _sendEncrypted(Map<String, Object?> frame) async {
    final keys = _keys;
    if (keys == null) throw StateError('WebRTC E2E keys unavailable');
    final encrypted = await encryptFrame(
      frame,
      keys: keys,
      direction: RelayCryptoDirection.mobileToPc,
      pairId: _directPairId,
      role: 'mobile',
      priority: relayFramePriority(frame),
      finalFrame: relayFrameIsFinal(frame),
      outboundSequence: _outboundSequence,
    );
    final envelope = <String, Object?>{'type': 'E2E_FRAME', ...encrypted};
    final encoded = jsonEncode(envelope);
    if (utf8.encode(encoded).length > _maxDirectEnvelopeBytes) {
      throw const FormatException('WebRTC direct envelope too large');
    }
    await _sendSerialized(encoded);
  }

  Future<void> _sendSerialized(String encoded) async {
    final payload = utf8.encode(encoded);
    final messages = <String>[];
    if (payload.length <= _directChunkBytes) {
      messages.add(encoded);
    } else {
      final count =
          (payload.length + _directChunkBytes - 1) ~/ _directChunkBytes;
      if (count > _maxDirectChunks) {
        throw const FormatException('too many WebRTC direct chunks');
      }
      final messageId = _randomHex(16);
      final checksum = sha256.convert(payload).toString();
      for (var index = 0; index < count; index++) {
        final start = index * _directChunkBytes;
        final end = min(start + _directChunkBytes, payload.length);
        messages.add(
          jsonEncode(<String, Object?>{
            'type': 'WEBRTC_CHUNK',
            'message_id': messageId,
            'chunk_index': index,
            'chunk_count': count,
            'total_bytes': payload.length,
            'checksum': checksum,
            'data': base64Url.encode(payload.sublist(start, end)),
          }),
        );
      }
    }
    final queuedBytes = messages.fold<int>(
      0,
      (sum, message) => sum + utf8.encode(message).length,
    );
    if (_queuedItems + messages.length > _maxSendQueueItems ||
        _queuedBytes + queuedBytes > _maxSendQueueBytes) {
      throw StateError('WebRTC direct send queue full');
    }
    _queuedItems += messages.length;
    _queuedBytes += queuedBytes;
    try {
      final scaledTimeout =
          _sendTimeout + _sendTimeoutPerChunk * messages.length;
      final timeout = scaledTimeout > _maxSendTimeout
          ? _maxSendTimeout
          : scaledTimeout;
      await _writeMessages(messages).timeout(timeout);
    } finally {
      _queuedItems -= messages.length;
      _queuedBytes -= queuedBytes;
    }
  }

  Future<void> _writeMessages(List<String> messages) async {
    final channel = _channel;
    if (channel == null || channel.state != 'open') {
      throw StateError('WebRTC DataChannel is closed');
    }
    for (final message in messages) {
      while (channel.bufferedAmount > _dataChannelHighWater) {
        final completer = Completer<void>();
        _bufferLowCompleter = completer;
        if (channel.bufferedAmount <= _dataChannelHighWater &&
            !completer.isCompleted) {
          completer.complete();
        }
        await completer.future;
        if (channel.state != 'open') {
          throw StateError('WebRTC DataChannel closed under backpressure');
        }
      }
      await channel.send(message);
      _bytesSent += utf8.encode(message).length;
    }
  }

  Future<bool> _refreshSelectedPairTruth() async {
    var localType = 'unknown';
    var remoteType = 'unknown';
    var protocol = 'unknown';
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final summary = await _peerConnection?.selectedCandidateSummary();
        localType = _safeCandidateType(summary?['local_type']);
        remoteType = _safeCandidateType(summary?['remote_type']);
        protocol = _safeCandidateProtocol(summary?['protocol']);
      } catch (_) {
        // The authoritative result remains unknown and cannot commit as P2P.
      }
      if (localType != 'unknown' && remoteType != 'unknown') break;
      if (attempt < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    final direct =
        const <String>{'host', 'srflx', 'prflx'}.contains(localType) &&
        const <String>{'host', 'srflx', 'prflx'}.contains(remoteType);
    _genuineP2p = direct;
    debugPrint(
      '[OSIA WebRTC] direct ready attempt=${attemptId.substring(0, 8)} '
      'generation=$generation local_type=$localType remote_type=$remoteType '
      'protocol=$protocol direct=$direct',
    );
    return direct;
  }

  String _safeCandidateType(String? value) =>
      const <String>{'host', 'srflx', 'prflx', 'relay'}.contains(value)
      ? value!
      : 'unknown';

  String _safeCandidateProtocol(String? value) =>
      const <String>{'udp', 'tcp'}.contains(value?.toLowerCase())
      ? value!.toLowerCase()
      : 'unknown';

  Future<void> fail(String category) {
    _sendTerminalSignal('webrtc_failed', category);
    return _beginClose(notify: active, category: category);
  }

  Future<void> close() {
    if (_state != WebRtcDirectState.idle &&
        _state != WebRtcDirectState.disconnected &&
        !active) {
      _sendTerminalSignal('webrtc_cancel', 'cancelled');
    }
    return _beginClose(notify: false, category: 'cancelled');
  }

  Future<void> _beginClose({required bool notify, required String category}) {
    final existing = _closeFuture;
    if (existing != null) return existing;
    final future = _finishClose(notify: notify, category: category);
    _closeFuture = future;
    return future;
  }

  Future<void> _finishClose({
    required bool notify,
    required String category,
  }) async {
    final hadActiveTurn = _state == WebRtcDirectState.activeTurn;
    _state = WebRtcDirectState.closing;
    _genuineP2p = false;
    _connectTimer?.cancel();
    _disconnectTimer?.cancel();
    _completeReady(false);
    final peer = _peerConnection;
    _peerConnection = null;
    if (peer != null) {
      try {
        await peer.close();
      } catch (_) {}
    }
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      // flutter_webrtc may deliver the peer's final data-channel state on the
      // next event turn. Let it arrive before the channel closes its streams.
      await Future<void>.delayed(Duration.zero);
      try {
        await channel.close();
      } catch (_) {}
    }
    _reassembler.clear();
    _state = WebRtcDirectState.disconnected;
    debugPrint(
      '[OSIA WebRTC] cleanup complete attempt='
      '${attemptId.length >= 8 ? attemptId.substring(0, 8) : 'none'} '
      'generation=$generation bytes_sent=$_bytesSent bytes_received=$_bytesReceived',
    );
    if (notify && !_closedNotified) {
      _closedNotified = true;
      onClosed(
        WebRtcCloseInfo(category: category, hadActiveTurn: hadActiveTurn),
      );
    }
  }

  void _completeReady(bool ready) {
    final completer = _readyCompleter;
    if (completer != null && !completer.isCompleted) completer.complete(ready);
  }
}

Future<WebRtcPeerConnectionAdapter> _createProductionPeerConnection(
  List<Map<String, Object?>> iceServers,
) async {
  final configuration = <String, dynamic>{
    'iceServers': iceServers
        .map(
          (server) => <String, dynamic>{
            'urls': server['urls'],
            if (server['username'] != null) 'username': server['username'],
            if (server['credential'] != null)
              'credential': server['credential'],
          },
        )
        .toList(growable: false),
    'iceTransportPolicy': 'all',
    'sdpSemantics': 'unified-plan',
  };
  return _FlutterWebRtcPeerConnection(
    await createPeerConnection(configuration),
  );
}

class _FlutterWebRtcDataChannel implements WebRtcDataChannelAdapter {
  _FlutterWebRtcDataChannel(this._native);

  final RTCDataChannel _native;

  @override
  String get label => _native.label ?? '';

  @override
  String get state => switch (_native.state) {
    RTCDataChannelState.RTCDataChannelConnecting => 'connecting',
    RTCDataChannelState.RTCDataChannelOpen => 'open',
    RTCDataChannelState.RTCDataChannelClosing => 'closing',
    RTCDataChannelState.RTCDataChannelClosed || null => 'closed',
  };

  @override
  int get bufferedAmount => _native.bufferedAmount ?? 0;

  @override
  set bufferedAmountLowThreshold(int value) {
    _native.bufferedAmountLowThreshold = value;
  }

  @override
  set onBufferedAmountLow(VoidCallback? callback) {
    _native.onBufferedAmountLow = callback == null ? null : (_) => callback();
  }

  @override
  set onMessage(void Function(String? text)? callback) {
    _native.onMessage = callback == null
        ? null
        : (message) => callback(message.isBinary ? null : message.text);
  }

  @override
  set onState(void Function(String state)? callback) {
    _native.onDataChannelState = callback == null
        ? null
        : (_) => callback(state);
  }

  @override
  Future<void> send(String message) =>
      _native.send(RTCDataChannelMessage(message));

  @override
  Future<void> close() => _native.close();
}

class _FlutterWebRtcPeerConnection implements WebRtcPeerConnectionAdapter {
  _FlutterWebRtcPeerConnection(this._native);

  final RTCPeerConnection _native;

  @override
  set onDataChannel(void Function(WebRtcDataChannelAdapter channel)? callback) {
    _native.onDataChannel = callback == null
        ? null
        : (channel) => callback(_FlutterWebRtcDataChannel(channel));
  }

  @override
  set onIceCandidate(void Function(Map<String, Object?>? candidate)? callback) {
    _native.onIceCandidate = callback == null
        ? null
        : (candidate) {
            final value = candidate.candidate;
            if (value == null || value.isEmpty) {
              callback(null);
              return;
            }
            callback(<String, Object?>{
              'candidate': value,
              'sdp_mid': candidate.sdpMid,
              'sdp_mline_index': candidate.sdpMLineIndex,
            });
          };
  }

  @override
  set onConnectionState(void Function(String state)? callback) {
    _native.onConnectionState = callback == null
        ? null
        : (state) => callback(switch (state) {
            RTCPeerConnectionState.RTCPeerConnectionStateNew => 'new',
            RTCPeerConnectionState.RTCPeerConnectionStateConnecting =>
              'connecting',
            RTCPeerConnectionState.RTCPeerConnectionStateConnected =>
              'connected',
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected =>
              'disconnected',
            RTCPeerConnectionState.RTCPeerConnectionStateFailed => 'failed',
            RTCPeerConnectionState.RTCPeerConnectionStateClosed => 'closed',
          });
  }

  @override
  Future<void> setRemoteOffer(String sdp) =>
      _native.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));

  @override
  Future<void> addRemoteCandidate(Map<String, Object?>? candidate) {
    if (candidate == null) {
      // flutter_webrtc 1.5.2 forwards RTCIceCandidate(null, null, null) to
      // nativeAddIceCandidate, which aborts libwebrtc on Android. The bounded
      // signaling event is still consumed explicitly; libwebrtc completes ICE
      // from the candidates already supplied and its normal state/timeouts.
      return Future<void>.value();
    }
    return _native.addCandidate(
      RTCIceCandidate(
        candidate['candidate'] as String,
        candidate['sdp_mid'] as String,
        candidate['sdp_mline_index'] as int,
      ),
    );
  }

  @override
  Future<String> createAndSetLocalAnswer() async {
    final answer = await _native.createAnswer(<String, dynamic>{
      'offerToReceiveAudio': false,
      'offerToReceiveVideo': false,
    });
    await _native.setLocalDescription(answer);
    final local = await _native.getLocalDescription();
    final sdp = local?.sdp;
    if (sdp == null) throw const FormatException('missing WebRTC answer');
    return sdp;
  }

  @override
  Future<String> connectionState() async => switch (await _native
      .getConnectionState()) {
    RTCPeerConnectionState.RTCPeerConnectionStateDisconnected => 'disconnected',
    RTCPeerConnectionState.RTCPeerConnectionStateFailed => 'failed',
    RTCPeerConnectionState.RTCPeerConnectionStateClosed => 'closed',
    RTCPeerConnectionState.RTCPeerConnectionStateConnected => 'connected',
    RTCPeerConnectionState.RTCPeerConnectionStateConnecting => 'connecting',
    _ => 'new',
  };

  @override
  Future<Map<String, String>> selectedCandidateSummary() async {
    var localType = 'unknown';
    var remoteType = 'unknown';
    var protocol = 'unknown';
    final reports = await _native.getStats();
    final byId = <String, StatsReport>{
      for (final report in reports) report.id: report,
    };
    for (final report in reports) {
      final values = report.values;
      if (report.type == 'candidate-pair' &&
          (values['selected'] == true || values['nominated'] == true) &&
          values['state'] == 'succeeded') {
        final local = byId[values['localCandidateId']?.toString() ?? ''];
        final remote = byId[values['remoteCandidateId']?.toString() ?? ''];
        localType = local?.values['candidateType']?.toString() ?? 'unknown';
        remoteType = remote?.values['candidateType']?.toString() ?? 'unknown';
        protocol = local?.values['protocol']?.toString() ?? 'unknown';
        break;
      }
    }
    return <String, String>{
      'local_type': localType,
      'remote_type': remoteType,
      'protocol': protocol,
    };
  }

  @override
  Future<void> close() async {
    await _native.close();
    await _native.dispose();
  }
}

class _DirectAssembly {
  _DirectAssembly({
    required this.updatedAt,
    required this.chunkCount,
    required this.totalBytes,
    required this.checksum,
  });

  DateTime updatedAt;
  final int chunkCount;
  final int totalBytes;
  final String checksum;
  final Map<int, List<int>> parts = <int, List<int>>{};
}

@visibleForTesting
class WebRtcDirectChunkReassembler {
  final Map<String, _DirectAssembly> _inflight = <String, _DirectAssembly>{};
  final Map<String, DateTime> _completed = <String, DateTime>{};

  int get inflightCount => _inflight.length;

  String? accept(Map<String, Object?> message, {DateTime? now}) {
    final current = now ?? DateTime.now().toUtc();
    _expire(current);
    if (!_hasExactKeys(message, _chunkFields)) {
      throw const FormatException('invalid WebRTC direct chunk');
    }
    final messageId = message['message_id'];
    final checksum = message['checksum'];
    final chunkIndex = message['chunk_index'];
    final chunkCount = message['chunk_count'];
    final totalBytes = message['total_bytes'];
    final data = message['data'];
    if (messageId is! String ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(messageId) ||
        checksum is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(checksum) ||
        chunkIndex is! int ||
        chunkCount is! int ||
        totalBytes is! int ||
        data is! String ||
        chunkCount < 1 ||
        chunkCount > _maxDirectChunks ||
        chunkIndex < 0 ||
        chunkIndex >= chunkCount ||
        totalBytes < 1 ||
        totalBytes > _maxDirectEnvelopeBytes) {
      throw const FormatException('invalid WebRTC direct chunk metadata');
    }
    if (_completed.containsKey(messageId)) return null;
    late final Uint8List part;
    try {
      part = base64Url.decode(data);
    } catch (_) {
      throw const FormatException('invalid WebRTC direct chunk encoding');
    }
    if (part.isEmpty || part.length > _directChunkBytes) {
      throw const FormatException('invalid WebRTC direct chunk size');
    }
    var assembly = _inflight[messageId];
    if (assembly == null) {
      if (_inflight.length >= _maxDirectInflight) {
        throw const FormatException('WebRTC direct chunk capacity exceeded');
      }
      assembly = _DirectAssembly(
        updatedAt: current,
        chunkCount: chunkCount,
        totalBytes: totalBytes,
        checksum: checksum,
      );
      _inflight[messageId] = assembly;
    } else if (assembly.chunkCount != chunkCount ||
        assembly.totalBytes != totalBytes ||
        assembly.checksum != checksum) {
      throw const FormatException('conflicting WebRTC direct chunk metadata');
    }
    final previous = assembly.parts[chunkIndex];
    if (previous != null) {
      if (!listEquals(previous, part)) {
        throw const FormatException('conflicting WebRTC direct duplicate');
      }
      return null;
    }
    assembly.parts[chunkIndex] = part;
    assembly.updatedAt = current;
    if (assembly.parts.length != chunkCount) return null;
    final builder = BytesBuilder(copy: false);
    for (var index = 0; index < chunkCount; index++) {
      final value = assembly.parts[index];
      if (value == null) throw const FormatException('missing direct chunk');
      builder.add(value);
    }
    final combined = builder.takeBytes();
    _inflight.remove(messageId);
    if (combined.length != totalBytes ||
        sha256.convert(combined).toString() != checksum) {
      throw const FormatException('WebRTC direct chunk integrity failed');
    }
    _completed[messageId] = current;
    return utf8.decode(combined);
  }

  void clear() {
    _inflight.clear();
    _completed.clear();
  }

  void _expire(DateTime now) {
    _inflight.removeWhere(
      (_, value) => now.difference(value.updatedAt) >= _reassemblyTimeout,
    );
    _completed.removeWhere(
      (_, value) => now.difference(value) >= _reassemblyTimeout * 2,
    );
  }
}
