import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/webrtc_signaling.dart';

const dataSdp =
    'v=0\r\n'
    'o=- 1 1 IN IP4 127.0.0.1\r\n'
    's=-\r\n'
    't=0 0\r\n'
    'm=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n'
    'c=IN IP4 0.0.0.0\r\n'
    'a=mid:0\r\n'
    'a=sctp-port:5000\r\n'
    'a=candidate:1 1 udp 2130706431 192.168.1.2 50000 typ host\r\n'
    'a=end-of-candidates\r\n';

void main() {
  test('capability validates bounded ICE and deterministic identity', () {
    final servers = validateWebRtcIceServers(<Object?>[
      <String, Object?>{
        'urls': <String>['stun:stun.example.test:3478'],
      },
    ]);
    final id = webRtcConfigurationId(true, servers);
    final capability = WebRtcCapability.fromFrame(<String, Object?>{
      'type': 'webrtc_capabilities',
      'protocol_version': webRtcProtocolVersion,
      'enabled': true,
      'configuration_id': id,
      'ice_servers': servers,
    });
    expect(capability.configurationId, id);
    expect(capability.iceServers, servers);
    expect(jsonEncode(capability.iceServers), isNot(contains('credential')));

    expect(
      () => validateWebRtcIceServers(<Object?>[
        <String, Object?>{
          'urls': <String>['turn:turn.example.test:3478'],
        },
      ]),
      throwsFormatException,
    );
  });

  test('signaling rejects wrong metadata, expiry and oversized batches', () {
    final now = DateTime.utc(2026, 7, 13, 12);
    final signal = makeWebRtcSignal(
      'webrtc_prepare',
      attemptId: 'a' * 32,
      generation: 3,
      sequence: 1,
      payload: <String, Object?>{'configuration_id': 'b' * 32},
      now: now,
    );
    expect(
      validateWebRtcSignal(signal, destinationRole: 'pc', now: now),
      signal,
    );
    for (final changed in <Map<String, Object?>>[
      <String, Object?>{...signal, 'attempt_id': 'bad'},
      <String, Object?>{...signal, 'generation': 0},
      <String, Object?>{...signal, 'destination_role': 'mobile'},
      <String, Object?>{
        ...signal,
        'created_at': now.millisecondsSinceEpoch ~/ 1000 - 31,
      },
    ]) {
      expect(
        () => validateWebRtcSignal(changed, destinationRole: 'pc', now: now),
        throwsFormatException,
      );
    }
    final candidate = <String, Object?>{
      'candidate': 'candidate:1 1 udp 2130706431 192.168.1.2 50000 typ host',
      'sdp_mid': '0',
      'sdp_mline_index': 0,
    };
    expect(
      () => makeWebRtcSignal(
        'webrtc_ice_candidates',
        attemptId: 'a' * 32,
        generation: 3,
        sequence: 2,
        payload: <String, Object?>{
          'candidates': List<Map<String, Object?>>.filled(
            webRtcMaxCandidatesPerEvent + 1,
            candidate,
          ),
        },
      ),
      throwsFormatException,
    );
  });

  test('SDP remains data-only and candidate extraction is bounded', () {
    final stripped = stripWebRtcSdpCandidates(dataSdp);
    expect(stripped.sdp, isNot(contains('candidate:')));
    expect(stripped.candidates, hasLength(1));
    expect(validateWebRtcDataOnlySdp(stripped.sdp), stripped.sdp);
    expect(
      () => validateWebRtcDataOnlySdp(
        '$dataSdp\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n',
      ),
      throwsFormatException,
    );
    expect(
      () => validateWebRtcCandidate(<String, Object?>{
        ...stripped.candidates.single,
        'candidate': 'candidate:1 1 udp 1 1.2.3.4 0 typ host',
      }),
      throwsFormatException,
    );
  });
}
