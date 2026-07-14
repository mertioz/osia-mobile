import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:osia_mobile/services/relay_crypto_service.dart';
import 'package:osia_mobile/services/transport_coordinator.dart';
import 'package:osia_mobile/services/webrtc_direct_transport.dart';
import 'package:osia_mobile/services/webrtc_signaling.dart';

const answerSdp =
    'v=0\r\n'
    'o=- 2 2 IN IP4 127.0.0.1\r\n'
    's=-\r\n'
    't=0 0\r\n'
    'm=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n'
    'c=IN IP4 0.0.0.0\r\n'
    'a=mid:0\r\n'
    'a=sctp-port:5000\r\n';

Map<String, Object?> pcSignal(
  String type, {
  required String attemptId,
  required int generation,
  required int sequence,
  Map<String, Object?> payload = const <String, Object?>{},
}) {
  final signal = makeWebRtcSignal(
    type,
    attemptId: attemptId,
    generation: generation,
    sequence: sequence,
    payload: payload,
  );
  signal['source_role'] = 'pc';
  signal['destination_role'] = 'mobile';
  return signal;
}

Future<void> pumpAsync([int count = 8]) async {
  for (var index = 0; index < count; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class FakeDataChannel implements WebRtcDataChannelAdapter {
  FakeDataChannel({this.label = webRtcDataChannelLabel});

  @override
  final String label;
  @override
  String state = 'open';
  int _bufferedAmount = 0;
  final List<int> bufferedAmountReads = <int>[];
  @override
  int get bufferedAmount => bufferedAmountReads.isNotEmpty
      ? bufferedAmountReads.removeAt(0)
      : _bufferedAmount;
  set bufferedAmount(int value) => _bufferedAmount = value;
  int threshold = 0;
  VoidCallback? lowCallback;
  void Function(String? text)? messageCallback;
  void Function(String state)? stateCallback;
  final List<String> sent = <String>[];
  int closeCount = 0;

  @override
  set bufferedAmountLowThreshold(int value) => threshold = value;
  @override
  set onBufferedAmountLow(VoidCallback? callback) => lowCallback = callback;
  @override
  set onMessage(void Function(String? text)? callback) =>
      messageCallback = callback;
  @override
  set onState(void Function(String state)? callback) =>
      stateCallback = callback;
  @override
  Future<void> send(String message) async => sent.add(message);
  @override
  Future<void> close() async {
    closeCount++;
    state = 'closed';
  }

  void inject(String message) => messageCallback?.call(message);
  void emitState(String value) {
    state = value;
    stateCallback?.call(value);
  }

  void releaseBackpressure() {
    bufferedAmount = 0;
    lowCallback?.call();
  }
}

class FakePeer implements WebRtcPeerConnectionAdapter {
  void Function(WebRtcDataChannelAdapter channel)? dataChannelCallback;
  void Function(Map<String, Object?>? candidate)? candidateCallback;
  void Function(String state)? connectionCallback;
  final List<Map<String, Object?>?> candidates = <Map<String, Object?>?>[];
  int remoteOfferCount = 0;
  int answerCount = 0;
  int closeCount = 0;
  String currentState = 'new';

  @override
  set onDataChannel(
    void Function(WebRtcDataChannelAdapter channel)? callback,
  ) => dataChannelCallback = callback;
  @override
  set onIceCandidate(
    void Function(Map<String, Object?>? candidate)? callback,
  ) => candidateCallback = callback;
  @override
  set onConnectionState(void Function(String state)? callback) =>
      connectionCallback = callback;
  @override
  Future<void> setRemoteOffer(String sdp) async => remoteOfferCount++;
  @override
  Future<void> addRemoteCandidate(Map<String, Object?>? candidate) async =>
      candidates.add(candidate);
  @override
  Future<String> createAndSetLocalAnswer() async {
    answerCount++;
    return answerSdp;
  }

  @override
  Future<Map<String, String>> selectedCandidateSummary() async =>
      <String, String>{
        'local_type': 'host',
        'remote_type': 'srflx',
        'protocol': 'udp',
      };
  @override
  Future<String> connectionState() async => currentState;
  @override
  Future<void> close() async => closeCount++;

  void emitDataChannel(FakeDataChannel channel) =>
      dataChannelCallback?.call(channel);
}

class DirectHarness {
  DirectHarness({
    String channelLabel = webRtcDataChannelLabel,
    Duration connectTimeout = const Duration(seconds: 2),
  }) : channel = FakeDataChannel(label: channelLabel) {
    final ice = validateWebRtcIceServers(<Object?>[]);
    capability = WebRtcCapability.fromFrame(<String, Object?>{
      'type': 'webrtc_capabilities',
      'protocol_version': webRtcProtocolVersion,
      'enabled': true,
      'configuration_id': webRtcConfigurationId(true, ice),
      'ice_servers': ice,
    });
    transport = WebRtcDirectTransport(
      capability: capability,
      token: token,
      pairId: pairId,
      sendSignal: (frame) {
        signals.add(Map<String, Object?>.from(frame));
        return true;
      },
      authorizeCommit: () {
        authorizeCount++;
        lease = coordinator.tryAcquire(ApplicationTransportKind.webrtc, this);
        return lease != null;
      },
      onFrame: frames.add,
      onClosed: (info) {
        closes.add(info);
        lease?.release();
      },
      peerConnectionFactory: (_) async => peer,
      connectTimeout: connectTimeout,
    );
  }

  final token = 'mobile-webrtc-test-token';
  final pairId = '1' * 64;
  final peer = FakePeer();
  final FakeDataChannel channel;
  final coordinator = ApplicationTransportCoordinator();
  final signals = <Map<String, Object?>>[];
  final frames = <Map<String, dynamic>>[];
  final closes = <WebRtcCloseInfo>[];
  late final WebRtcCapability capability;
  late final WebRtcDirectTransport transport;
  ApplicationTransportLease? lease;
  int authorizeCount = 0;

  Future<({RelaySessionKeys keys, OutboundSequence sequence})>
  activate() async {
    final connecting = transport.connect(attemptGeneration: 1);
    await pumpAsync();
    final prepare = signals.single;
    final attemptId = prepare['attempt_id'] as String;
    await transport.handleSignal(
      pcSignal(
        'webrtc_offer',
        attemptId: attemptId,
        generation: 1,
        sequence: 1,
        payload: <String, Object?>{'type': 'offer', 'sdp': answerSdp},
      ),
    );
    expect(peer.remoteOfferCount, 1);
    expect(peer.answerCount, 1);
    final candidate = <String, Object?>{
      'candidate': 'candidate:1 1 udp 1 127.0.0.1 50000 typ host',
      'sdp_mid': '0',
      'sdp_mline_index': 0,
    };
    await transport.handleSignal(
      pcSignal(
        'webrtc_ice_candidates',
        attemptId: attemptId,
        generation: 1,
        sequence: 2,
        payload: <String, Object?>{
          'candidates': <Map<String, Object?>>[candidate, candidate],
        },
      ),
    );
    expect(peer.candidates, hasLength(1));
    peer.emitDataChannel(channel);
    await pumpAsync();
    final mobileHello = jsonDecode(channel.sent.last) as Map<String, dynamic>;
    final pcPrivate = generateX25519PrivateKey();
    final pcPublic = await x25519PublicKey(pcPrivate);
    final pcNonce = generateNonceBase();
    final context = RelaySessionContext(
      pairId: webRtcDirectPairId(pairId, attemptId, 1),
      pcPublicKey: pcPublic,
      mobilePublicKey: b64UrlDecodeNoPadding(
        mobileHello['public_key'] as String,
      ),
      pcNonceBase: pcNonce,
      mobileNonceBase: b64UrlDecodeNoPadding(
        mobileHello['nonce_base'] as String,
      ),
    );
    final keys = await deriveSessionKeys(
      token: token,
      localPrivateKey: pcPrivate,
      peerPublicKey: context.mobilePublicKey,
      context: context,
    );
    channel.inject(
      jsonEncode(<String, Object?>{
        'type': 'webrtc_e2e_hello',
        'protocol_version': webRtcProtocolVersion,
        'transport': 'webrtc',
        'attempt_id': attemptId,
        'generation': 1,
        'source_role': 'pc',
        'destination_role': 'mobile',
        'data_channel_label': webRtcDataChannelLabel,
        'data_channel_protocol': webRtcDataChannelProtocol,
        'e2e_version': relayE2eVersion,
        'alg': relayCryptoAlgChacha20Poly1305,
        'public_key': b64UrlEncodeNoPadding(pcPublic),
        'nonce_base': b64UrlEncodeNoPadding(pcNonce),
      }),
    );
    await pumpAsync();
    expect(transport.state, WebRtcDirectState.authenticating);
    channel.inject(
      jsonEncode(<String, Object?>{
        'type': 'webrtc_e2e_ready',
        'protocol_version': webRtcProtocolVersion,
        'transport': 'webrtc',
        'attempt_id': attemptId,
        'generation': 1,
        'source_role': 'pc',
        'destination_role': 'mobile',
        'e2e_version': relayE2eVersion,
        'alg': relayCryptoAlgChacha20Poly1305,
        'kid': keys.kid,
        'tag': handshakeConfirmationTag(
          token: token,
          context: context,
          senderRole: 'pc',
        ),
      }),
    );
    await pumpAsync();
    expect(transport.state, WebRtcDirectState.authenticating);
    final outbound = OutboundSequence();
    Future<void> injectEncrypted(Map<String, Object?> frame) async {
      final encrypted = await encryptFrame(
        frame,
        keys: keys,
        direction: RelayCryptoDirection.pcToMobile,
        pairId: context.pairId,
        role: 'pc',
        priority: relayPriorityCritical,
        finalFrame: false,
        outboundSequence: outbound,
      );
      channel.inject(
        jsonEncode(<String, Object?>{'type': 'E2E_FRAME', ...encrypted}),
      );
      await pumpAsync();
    }

    await injectEncrypted(
      pcSignal(
        'webrtc_direct_ready',
        attemptId: attemptId,
        generation: 1,
        sequence: 10,
      ),
    );
    expect(authorizeCount, 1);
    await injectEncrypted(
      pcSignal(
        'webrtc_direct_commit_ack',
        attemptId: attemptId,
        generation: 1,
        sequence: 11,
      ),
    );
    expect(await connecting, isTrue);
    return (keys: keys, sequence: outbound);
  }
}

void main() {
  test('fixed answerer authenticates before one authority commit', () async {
    final harness = DirectHarness();
    final session = await harness.activate();
    expect(harness.transport.state, WebRtcDirectState.ready);
    expect(harness.coordinator.activeKind, ApplicationTransportKind.webrtc);
    expect(harness.authorizeCount, 1);
    expect(harness.peer.answerCount, 1);
    expect(
      harness.signals.where((frame) => frame['event_type'] == 'webrtc_answer'),
      hasLength(1),
    );

    harness.channel.sent.clear();
    harness.channel.bufferedAmountReads.addAll(<int>[600000, 0, 0]);
    expect(
      harness.transport.send(<String, dynamic>{'type': 'get_config'}),
      isTrue,
    );
    await harness.transport.drain();
    expect(harness.channel.sent, isNotEmpty);

    final accepted = harness.transport.send(<String, dynamic>{
      'type': 'text',
      'content': 'hello',
      'conversation_id': 'conv',
      'client_request_id': 'req',
      'turn_id': 'turn',
    });
    expect(accepted, isTrue);
    await harness.transport.drain();
    final envelope =
        jsonDecode(harness.channel.sent.last) as Map<String, dynamic>;
    final decrypted = await decryptFrame(
      envelope.cast<String, Object?>(),
      keys: session.keys,
      direction: RelayCryptoDirection.mobileToPc,
      replayGuard: SequenceReplayGuard(),
      replayKey: 'mobile',
    );
    expect(decrypted['content'], 'hello');
    expect(harness.transport.state, WebRtcDirectState.activeTurn);
    expect(harness.peer.closeCount, 0);

    await harness.transport.close();
    await harness.transport.close();
    harness.lease?.release();
    expect(harness.peer.closeCount, 1);
    expect(harness.channel.closeCount, 1);
  });

  test(
    'wrong DataChannel label fails before E2E and releases selection',
    () async {
      final harness = DirectHarness(channelLabel: 'wrong-label');
      final connecting = harness.transport.connect(attemptGeneration: 1);
      await pumpAsync();
      final attemptId = harness.signals.single['attempt_id'] as String;
      await harness.transport.handleSignal(
        pcSignal(
          'webrtc_offer',
          attemptId: attemptId,
          generation: 1,
          sequence: 1,
          payload: <String, Object?>{'type': 'offer', 'sdp': answerSdp},
        ),
      );
      harness.peer.emitDataChannel(harness.channel);
      expect(await connecting, isFalse);
      expect(harness.authorizeCount, 0);
      expect(harness.coordinator.activeKind, isNull);
    },
  );

  test('missing E2E times out and stale attempt cannot activate', () async {
    final harness = DirectHarness(
      connectTimeout: const Duration(milliseconds: 50),
    );
    final connecting = harness.transport.connect(attemptGeneration: 7);
    await pumpAsync();
    await harness.transport.handleSignal(
      pcSignal(
        'webrtc_offer',
        attemptId: 'f' * 32,
        generation: 7,
        sequence: 1,
        payload: <String, Object?>{'type': 'offer', 'sdp': answerSdp},
      ),
    );
    expect(harness.peer.remoteOfferCount, 0);
    expect(await connecting, isFalse);
    expect(harness.transport.state, WebRtcDirectState.disconnected);
  });

  test('active-turn close is terminal and never authorizes fallback', () async {
    final harness = DirectHarness();
    await harness.activate();
    expect(
      harness.transport.send(<String, dynamic>{
        'type': 'text',
        'content': 'active',
        'conversation_id': 'conv',
        'client_request_id': 'req-active',
        'turn_id': 'turn-active',
      }),
      isTrue,
    );
    harness.channel.emitState('closed');
    await pumpAsync();
    expect(harness.closes, hasLength(1));
    expect(harness.closes.single.hadActiveTurn, isTrue);
    expect(harness.coordinator.activeKind, isNull);
    expect(
      harness.signals.where((frame) => frame['type'] == 'transport_commit'),
      isEmpty,
    );
  });

  test('LAN authority blocks WebRTC commit and then permits relay', () async {
    final harness = DirectHarness();
    final lan = harness.coordinator.tryAcquire(
      ApplicationTransportKind.lan,
      Object(),
    );
    expect(lan, isNotNull);
    expect(
      await harness.activate().then((_) => true, onError: (_) => false),
      isFalse,
    );
    expect(harness.authorizeCount, 1);
    expect(harness.coordinator.activeKind, ApplicationTransportKind.lan);
    lan!.release();
    final relay = harness.coordinator.tryAcquire(
      ApplicationTransportKind.relay,
      Object(),
    );
    expect(relay, isNotNull);
    relay!.release();
  });

  test('chunk reassembly handles reordering, duplicates and conflicts', () {
    final payload = utf8.encode(
      jsonEncode(<String, Object?>{'type': 'response', 'content': 'x' * 12000}),
    );
    final checksum = sha256.convert(payload).toString();
    Map<String, Object?> chunk(int index, List<int> data) => <String, Object?>{
      'type': 'WEBRTC_CHUNK',
      'message_id': 'a' * 32,
      'chunk_index': index,
      'chunk_count': 2,
      'total_bytes': payload.length,
      'checksum': checksum,
      'data': base64Url.encode(data),
    };
    final first = chunk(0, payload.sublist(0, 9000));
    final second = chunk(1, payload.sublist(9000));
    final reassembler = WebRtcDirectChunkReassembler();
    expect(reassembler.accept(second), isNull);
    expect(reassembler.accept(second), isNull);
    expect(reassembler.accept(first), utf8.decode(payload));
    expect(reassembler.inflightCount, 0);

    final progressive = WebRtcDirectChunkReassembler();
    final start = DateTime.utc(2026);
    Map<String, Object?> progressiveChunk(int index, List<int> data) =>
        <String, Object?>{
          'type': 'WEBRTC_CHUNK',
          'message_id': 'b' * 32,
          'chunk_index': index,
          'chunk_count': 3,
          'total_bytes': payload.length,
          'checksum': checksum,
          'data': base64Url.encode(data),
        };
    expect(
      progressive.accept(
        progressiveChunk(0, payload.sublist(0, 5000)),
        now: start,
      ),
      isNull,
    );
    expect(
      progressive.accept(
        progressiveChunk(1, payload.sublist(5000, 10000)),
        now: start.add(const Duration(seconds: 20)),
      ),
      isNull,
    );
    expect(
      progressive.accept(
        progressiveChunk(2, payload.sublist(10000)),
        now: start.add(const Duration(seconds: 40)),
      ),
      utf8.decode(payload),
    );
  });

  test('coordinator prevents LAN, WebRTC and relay double authority', () {
    for (var index = 0; index < 50; index++) {
      final coordinator = ApplicationTransportCoordinator();
      final lan = coordinator.tryAcquire(
        ApplicationTransportKind.lan,
        Object(),
      );
      expect(lan, isNotNull);
      expect(
        coordinator.tryAcquire(ApplicationTransportKind.webrtc, Object()),
        isNull,
      );
      expect(
        coordinator.tryAcquire(ApplicationTransportKind.relay, Object()),
        isNull,
      );
      lan!.release();
      final webRtc = coordinator.tryAcquire(
        ApplicationTransportKind.webrtc,
        Object(),
      );
      expect(webRtc, isNotNull);
      expect(
        coordinator.tryAcquire(ApplicationTransportKind.relay, Object()),
        isNull,
      );
      webRtc!.release();
    }
  });
}
