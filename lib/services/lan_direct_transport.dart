import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'relay_crypto_service.dart';
import 'relay_service.dart';
import 'transport_coordinator.dart';

const bool kLanDirectV1 = bool.fromEnvironment(
  'lan_direct_v1',
  defaultValue: true,
);
const String _environmentLanHost = String.fromEnvironment('lan_direct_host');
const String _environmentLanCertificateSha256 = String.fromEnvironment(
  'lan_direct_certificate_sha256',
);

const int lanDirectPort = 8766;
const int lanDirectProtocolVersion = 1;
const Duration _handshakeTimeout = Duration(seconds: 5);
const Duration _nativePingInterval = Duration(seconds: 25);

const Set<String> _controlFields = <String>{
  'v',
  'type',
  'role',
  'pair_id',
  'payload',
};
const Set<String> _helloFields = <String>{
  'e2e_version',
  'alg',
  'public_key',
  'nonce_base',
  'e2e_chunk_version',
};
const Set<String> _readyFields = <String>{'e2e_version', 'alg', 'kid', 'tag'};
const Set<String> _pcReadyFields = <String>{
  'e2e',
  'transport',
  'protocol_version',
};
const Set<String> _e2eFrameFields = <String>{
  'v',
  'type',
  'role',
  'pair_id',
  'seq',
  'e2e_version',
  'alg',
  'kid',
  'priority',
  'final',
  'nonce',
  'ciphertext',
};

class LanDirectConfig {
  LanDirectConfig({
    required String host,
    required String certificateSha256,
    this.port = lanDirectPort,
  }) : host = _validatePrivateIpv4(host),
       certificateSha256 = normalizeCertificateSha256(certificateSha256) {
    if (port != lanDirectPort) {
      throw const FormatException('LAN-direct v1 must use port 8766');
    }
  }

  final String host;
  final int port;
  final String certificateSha256;

  Uri get endpoint => Uri(scheme: 'wss', host: host, port: port, path: '/lan');

  static LanDirectConfig? fromEnvironment() {
    if (_environmentLanHost.trim().isEmpty ||
        _environmentLanCertificateSha256.trim().isEmpty) {
      return null;
    }
    return LanDirectConfig(
      host: _environmentLanHost,
      certificateSha256: _environmentLanCertificateSha256,
    );
  }
}

String normalizeCertificateSha256(String raw) {
  final normalized = raw.replaceAll(':', '').trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw const FormatException(
      'LAN certificate pin must be a 64-character SHA-256 hex digest',
    );
  }
  return normalized;
}

bool certificateSha256Matches(List<int> der, String expected) {
  final normalized = normalizeCertificateSha256(expected);
  final actual = sha256.convert(der).bytes;
  var difference = 0;
  for (var index = 0; index < actual.length; index++) {
    final expectedByte = int.parse(
      normalized.substring(index * 2, index * 2 + 2),
      radix: 16,
    );
    difference |= actual[index] ^ expectedByte;
  }
  return difference == 0;
}

String _validatePrivateIpv4(String raw) {
  final value = raw.trim();
  final address = InternetAddress.tryParse(value);
  if (address == null || address.type != InternetAddressType.IPv4) {
    throw const FormatException(
      'LAN host must be a numeric private IPv4 address',
    );
  }
  final bytes = address.rawAddress;
  final private =
      bytes[0] == 10 ||
      (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
      (bytes[0] == 192 && bytes[1] == 168);
  if (!private) {
    throw const FormatException('LAN host must be a private IPv4 address');
  }
  return address.address;
}

bool _hasExactKeys(Map<Object?, Object?> value, Set<String> fields) =>
    value.length == fields.length && value.keys.every(fields.contains);

enum LanDirectState {
  idle,
  connecting,
  authenticating,
  ready,
  activeTurn,
  closing,
  disconnected,
}

class LanCloseInfo {
  const LanCloseInfo({required this.code, required this.category});

  final int? code;
  final String category;
}

class LanDirectTransport {
  LanDirectTransport({
    required this.config,
    required this.token,
    required this.onFrame,
    required this.onClosed,
    required this.onError,
    this.onCloseInfo,
  });

  final LanDirectConfig config;
  final String token;
  final void Function(Map<String, dynamic> frame) onFrame;
  final VoidCallback onClosed;
  final void Function(Object error) onError;
  final void Function(LanCloseInfo info)? onCloseInfo;

  WebSocket? _socket;
  HttpClient? _client;
  StreamSubscription<dynamic>? _subscription;
  Completer<bool>? _readyCompleter;
  Future<void> _receiveChain = Future<void>.value();
  Future<void> _sendChain = Future<void>.value();
  Future<void>? _closeFuture;
  final SequenceReplayGuard _replayGuard = SequenceReplayGuard();
  final OutboundSequence _outboundSequence = OutboundSequence();

  RelaySessionContext? _context;
  RelaySessionKeys? _keys;
  late final RelayPairCredentials _credentials;
  late final List<int> _privateKey;
  late final List<int> _publicKey;
  late final List<int> _nonceBase;
  bool _pcE2eReady = false;
  bool _pcBridgeReady = false;
  bool _closedNotified = false;
  String _activeRequestId = '';
  String _activeTurnId = '';
  LanDirectState _state = LanDirectState.idle;

  LanDirectState get state => _state;
  bool get active =>
      _state == LanDirectState.ready || _state == LanDirectState.activeTurn;

  void _setState(LanDirectState next) {
    if (_state == next) return;
    final allowed = <LanDirectState, Set<LanDirectState>>{
      LanDirectState.idle: {LanDirectState.connecting, LanDirectState.closing},
      LanDirectState.connecting: {
        LanDirectState.authenticating,
        LanDirectState.closing,
      },
      LanDirectState.authenticating: {
        LanDirectState.ready,
        LanDirectState.closing,
      },
      LanDirectState.ready: {LanDirectState.activeTurn, LanDirectState.closing},
      LanDirectState.activeTurn: {LanDirectState.ready, LanDirectState.closing},
      LanDirectState.closing: {LanDirectState.disconnected},
      LanDirectState.disconnected: <LanDirectState>{},
    };
    if (!(allowed[_state]?.contains(next) ?? false)) {
      throw StateError('invalid LAN lifecycle transition $_state -> $next');
    }
    _state = next;
  }

  Future<bool> connect() async {
    if (_state != LanDirectState.idle) return active;
    _setState(LanDirectState.connecting);
    _credentials = RelayService.derivePairCredentials(token);
    _privateKey = generateX25519PrivateKey();
    _publicKey = await x25519PublicKey(_privateKey);
    _nonceBase = generateNonceBase();
    _readyCompleter = Completer<bool>();

    var certificateChecked = false;
    final client = HttpClient(
      context: SecurityContext(withTrustedRoots: false),
    );
    client.connectionTimeout = const Duration(seconds: 10);
    client.badCertificateCallback = (certificate, host, port) {
      certificateChecked = true;
      return host == config.host &&
          port == config.port &&
          certificateSha256Matches(certificate.der, config.certificateSha256);
    };
    _client = client;

    try {
      final socket = await WebSocket.connect(
        config.endpoint.toString(),
        customClient: client,
      ).timeout(const Duration(seconds: 10));
      if (!certificateChecked) {
        await socket.close(WebSocketStatus.policyViolation);
        await close();
        return false;
      }
      _socket = socket;
      _setState(LanDirectState.authenticating);
      socket.pingInterval = _nativePingInterval;
      _subscription = socket.listen(
        _queueIncoming,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
        cancelOnError: false,
      );
      _sendControl('E2E_HELLO', <String, Object?>{
        'e2e_version': relayE2eVersion,
        'alg': relayCryptoAlgChacha20Poly1305,
        'public_key': b64UrlEncodeNoPadding(_publicKey),
        'nonce_base': b64UrlEncodeNoPadding(_nonceBase),
        'e2e_chunk_version': relayE2eChunkVersion,
      });
      final ready = await _readyCompleter!.future.timeout(
        _handshakeTimeout,
        onTimeout: () => false,
      );
      if (!ready || socket.readyState != WebSocket.open) {
        await close();
        return false;
      }
      _setState(LanDirectState.ready);
      return true;
    } catch (error) {
      debugPrint('[OSIA LAN] connection failed: ${error.runtimeType}');
      await close();
      return false;
    }
  }

  bool send(Map<String, dynamic> frame) {
    final socket = _socket;
    final keys = _keys;
    final type = frame['type']?.toString() ?? '';
    final requestId =
        frame['request_id']?.toString() ??
        frame['client_request_id']?.toString() ??
        '';
    final turnId = frame['turn_id']?.toString() ?? '';
    final startsTurn = isApplicationTurnStartingFrame(frame);
    if (!active ||
        socket == null ||
        socket.readyState != WebSocket.open ||
        keys == null ||
        !_pcE2eReady ||
        !_pcBridgeReady ||
        type == 'auth' ||
        (startsTurn && requestId.isEmpty)) {
      return false;
    }
    if (startsTurn) {
      if (_state == LanDirectState.ready) {
        _activeRequestId = requestId;
        _activeTurnId = turnId;
        _setState(LanDirectState.activeTurn);
      } else if (_state != LanDirectState.activeTurn ||
          requestId != _activeRequestId ||
          (turnId.isNotEmpty && turnId != _activeTurnId)) {
        return false;
      }
    }
    final stableFrame = Map<String, dynamic>.from(frame);
    _sendChain = _sendChain
        .then((_) async {
          if (!active || !identical(socket, _socket)) return;
          final encrypted = await encryptFrame(
            stableFrame.cast<String, Object?>(),
            keys: keys,
            direction: RelayCryptoDirection.mobileToPc,
            pairId: _credentials.pairId,
            role: 'mobile',
            priority: relayFramePriority(stableFrame.cast<String, Object?>()),
            finalFrame: relayFrameIsFinal(stableFrame.cast<String, Object?>()),
            outboundSequence: _outboundSequence,
          );
          socket.add(
            jsonEncode(<String, Object?>{
              'v': lanDirectProtocolVersion,
              'type': 'E2E_FRAME',
              'role': 'mobile',
              'pair_id': _credentials.pairId,
              ...encrypted,
            }),
          );
        })
        .catchError((Object error, StackTrace stack) {
          _failActive(error);
        });
    return true;
  }

  /// Wait until all frames accepted by [send] have reached the socket writer.
  /// Attachment uploads use this to keep their queued bytes bounded.
  Future<void> drain() => _sendChain;

  Future<void> close() => _beginClose(notify: false);

  Future<void> _beginClose({
    required bool notify,
    bool subscriptionAlreadyDone = false,
  }) {
    final existing = _closeFuture;
    if (existing != null) return existing;
    final future = _finishClose(
      notify: notify,
      subscriptionAlreadyDone: subscriptionAlreadyDone,
    );
    _closeFuture = future;
    return future;
  }

  Future<void> _finishClose({
    required bool notify,
    required bool subscriptionAlreadyDone,
  }) async {
    if (_state != LanDirectState.disconnected &&
        _state != LanDirectState.closing) {
      _setState(LanDirectState.closing);
    }
    _completeReady(false);
    final socket = _socket;
    final closeCode = socket?.closeCode;
    final subscription = _subscription;
    _subscription = null;
    if (!subscriptionAlreadyDone) {
      try {
        await subscription?.cancel();
      } catch (_) {
        // The stream is already terminating.
      }
    }
    try {
      await _receiveChain;
    } catch (_) {
      // Receive failures are converted into the sanitized close callback.
    }
    _socket = null;
    if (socket != null && socket.readyState != WebSocket.closed) {
      try {
        await socket.close();
      } catch (_) {
        // Best-effort close.
      }
    }
    _client?.close(force: true);
    _client = null;
    try {
      await _sendChain;
    } catch (_) {
      // Send failures are already reported by the chain.
    }
    if (_state == LanDirectState.closing) {
      _setState(LanDirectState.disconnected);
    }
    if (notify && !_closedNotified) {
      _closedNotified = true;
      final info = LanCloseInfo(
        code: closeCode,
        category: _closeCategory(closeCode),
      );
      onCloseInfo?.call(info);
      onClosed();
    }
  }

  static String _closeCategory(int? code) => switch (code) {
    WebSocketStatus.normalClosure => 'normal',
    WebSocketStatus.policyViolation => 'policy',
    1013 => 'busy',
    WebSocketStatus.internalServerError => 'bridge',
    null => 'network',
    _ => 'protocol',
  };

  void _queueIncoming(dynamic raw) {
    _receiveChain = _receiveChain.then((_) => _handleIncoming(raw)).catchError((
      Object error,
      StackTrace stack,
    ) async {
      debugPrint('[OSIA LAN] rejected frame: ${error.runtimeType}');
      _completeReady(false);
      final socket = _socket;
      if (socket != null) {
        unawaited(
          socket.close(
            WebSocketStatus.policyViolation,
            'LAN authentication failed',
          ),
        );
      }
    });
  }

  Future<void> _handleIncoming(dynamic raw) async {
    if (raw is! String) throw const FormatException('LAN frames must be text');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('LAN frame must be an object');
    }
    final message = decoded.cast<String, dynamic>();
    final type = message['type']?.toString() ?? '';

    if (type == 'E2E_FRAME') {
      if (!_pcE2eReady || !_pcBridgeReady || _keys == null) {
        throw const FormatException('encrypted frame arrived before LAN ready');
      }
      if (!_hasExactKeys(message, _e2eFrameFields) ||
          message['v'] != lanDirectProtocolVersion ||
          message['role'] != 'pc' ||
          message['pair_id'] != _credentials.pairId) {
        throw const FormatException('invalid encrypted LAN envelope');
      }
      final frame = await decryptFrame(
        message.cast<String, Object?>(),
        keys: _keys!,
        direction: RelayCryptoDirection.pcToMobile,
        replayGuard: _replayGuard,
        replayKey: 'pc',
      );
      final appFrame = frame.cast<String, dynamic>();
      _observeApplicationFrame(appFrame);
      onFrame(appFrame);
      return;
    }

    if (!_hasExactKeys(message, _controlFields) ||
        message['v'] != lanDirectProtocolVersion ||
        message['role'] != 'pc' ||
        message['pair_id'] != _credentials.pairId ||
        message['payload'] is! Map) {
      throw const FormatException('invalid LAN control envelope');
    }
    final payload = (message['payload'] as Map).cast<String, dynamic>();
    switch (type) {
      case 'E2E_HELLO':
        await _handlePcHello(payload);
      case 'E2E_READY':
        _handlePcReady(payload);
      case 'PC_READY':
        if (!_hasExactKeys(payload, _pcReadyFields) ||
            payload['e2e'] != true ||
            payload['transport'] != 'lan' ||
            payload['protocol_version'] != lanDirectProtocolVersion) {
          throw const FormatException('invalid LAN bridge-ready frame');
        }
        _pcBridgeReady = true;
        _maybeCompleteReady();
      default:
        throw const FormatException('unexpected LAN control frame');
    }
  }

  Future<void> _handlePcHello(Map<String, dynamic> payload) async {
    if (_context != null ||
        !_hasExactKeys(payload, _helloFields) ||
        payload['e2e_version'] != relayE2eVersion ||
        payload['alg'] != relayCryptoAlgChacha20Poly1305 ||
        payload['e2e_chunk_version'] != relayE2eChunkVersion) {
      throw const FormatException('invalid LAN E2E hello');
    }
    final pcPublicKey = b64UrlDecodeNoPadding(
      payload['public_key']?.toString() ?? '',
    );
    final pcNonceBase = b64UrlDecodeNoPadding(
      payload['nonce_base']?.toString() ?? '',
    );
    final context = RelaySessionContext(
      pairId: _credentials.pairId,
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
    _sendControl('E2E_READY', <String, Object?>{
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

  void _handlePcReady(Map<String, dynamic> payload) {
    final context = _context;
    final keys = _keys;
    if (context == null ||
        keys == null ||
        !_hasExactKeys(payload, _readyFields) ||
        payload['e2e_version'] != relayE2eVersion ||
        payload['alg'] != relayCryptoAlgChacha20Poly1305 ||
        payload['kid'] != keys.kid ||
        !verifyHandshakeConfirmation(
          token: token,
          context: context,
          senderRole: 'pc',
          tag: payload['tag']?.toString() ?? '',
        )) {
      throw const FormatException('LAN E2E identity confirmation failed');
    }
    _pcE2eReady = true;
    _maybeCompleteReady();
  }

  void _sendControl(String type, Map<String, Object?> payload) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      throw const SocketException('LAN socket is closed');
    }
    socket.add(
      jsonEncode(<String, Object?>{
        'v': lanDirectProtocolVersion,
        'type': type,
        'role': 'mobile',
        'pair_id': _credentials.pairId,
        'payload': payload,
      }),
    );
  }

  void _maybeCompleteReady() {
    if (_pcE2eReady && _pcBridgeReady && _keys != null) {
      _completeReady(true);
    }
  }

  void _completeReady(bool ready) {
    final completer = _readyCompleter;
    if (completer != null && !completer.isCompleted) completer.complete(ready);
  }

  void _handleSocketError(Object error) {
    debugPrint('[OSIA LAN] socket error: ${error.runtimeType}');
    _completeReady(false);
    if (active) onError(error);
  }

  void _handleSocketDone() {
    _completeReady(false);
    unawaited(_beginClose(notify: true, subscriptionAlreadyDone: true));
  }

  void _failActive(Object error) {
    if (!active) return;
    onError(error);
    final socket = _socket;
    if (socket != null) {
      unawaited(socket.close(WebSocketStatus.internalServerError));
    }
  }

  void _observeApplicationFrame(Map<String, dynamic> frame) {
    if (_state != LanDirectState.activeTurn) return;
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
      _setState(LanDirectState.ready);
    }
  }
}
