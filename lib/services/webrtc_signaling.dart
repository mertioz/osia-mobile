import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'relay_crypto_service.dart';

const int webRtcProtocolVersion = 1;
const String webRtcDataChannelLabel = 'osia-app-v1';
const String webRtcDataChannelProtocol = 'osia.e2e.v1';
const int webRtcMaxCandidates = 64;
const int webRtcMaxCandidatesPerEvent = 16;
const int webRtcMaxSdpBytes = 64 * 1024;
const int webRtcMaxCandidateBytes = 2048;
const Duration webRtcSignalTtl = Duration(seconds: 30);

const Set<String> webRtcSignalEventTypes = <String>{
  'webrtc_prepare',
  'webrtc_offer',
  'webrtc_answer',
  'webrtc_ice_candidates',
  'webrtc_end_of_candidates',
  'webrtc_cancel',
  'webrtc_failed',
  'webrtc_direct_ready',
  'webrtc_direct_commit',
  'webrtc_direct_commit_ack',
};

const Set<String> _signalFields = <String>{
  'protocol_version',
  'transport',
  'attempt_id',
  'generation',
  'source_role',
  'destination_role',
  'event_id',
  'event_type',
  'sequence',
  'created_at',
  'terminal',
  'payload',
};
const Set<String> _failureCategories = <String>{
  'busy',
  'cancelled',
  'expired',
  'ice_failed',
  'signaling_failed',
  'authentication_failed',
  'bridge_unavailable',
  'protocol_error',
  'timeout',
  'unavailable',
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

class WebRtcCapability {
  WebRtcCapability._({
    required this.enabled,
    required this.configurationId,
    required this.iceServers,
  });

  final bool enabled;
  final String configurationId;
  final List<Map<String, Object?>> iceServers;

  factory WebRtcCapability.fromFrame(Map<String, Object?> frame) {
    if (!_hasExactKeys(frame, const <String>{
          'type',
          'protocol_version',
          'enabled',
          'configuration_id',
          'ice_servers',
        }) ||
        frame['type'] != 'webrtc_capabilities' ||
        frame['protocol_version'] != webRtcProtocolVersion ||
        frame['enabled'] is! bool ||
        frame['configuration_id'] is! String) {
      throw const FormatException('invalid WebRTC capability');
    }
    final servers = validateWebRtcIceServers(frame['ice_servers']);
    final enabled = frame['enabled'] as bool;
    final id = frame['configuration_id'] as String;
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(id) ||
        id != webRtcConfigurationId(enabled, servers)) {
      throw const FormatException('invalid WebRTC configuration identity');
    }
    return WebRtcCapability._(
      enabled: enabled,
      configurationId: id,
      iceServers: servers,
    );
  }
}

List<Map<String, Object?>> validateWebRtcIceServers(Object? raw) {
  if (raw is! List || raw.length > 4) {
    throw const FormatException('invalid ICE server list');
  }
  final result = <Map<String, Object?>>[];
  var totalUrls = 0;
  final urlPattern = RegExp(
    r'^(stun|turn|turns):(\[[0-9a-fA-F:]+\]|[A-Za-z0-9.-]+)(?::([0-9]{1,5}))?(?:\?transport=(udp|tcp))?$',
  );
  for (final item in raw) {
    if (item is! Map ||
        !item.keys.every(
          const <String>{'urls', 'username', 'credential'}.contains,
        ) ||
        !item.containsKey('urls')) {
      throw const FormatException('invalid ICE server record');
    }
    final rawUrls = item['urls'];
    final values = rawUrls is String
        ? <Object?>[rawUrls]
        : rawUrls is List
        ? rawUrls
        : const <Object?>[];
    if (values.isEmpty) throw const FormatException('empty ICE URL list');
    final urls = <String>[];
    var hasTurn = false;
    for (final itemUrl in values) {
      if (itemUrl is! String || itemUrl.length > 512) {
        throw const FormatException('invalid ICE URL');
      }
      final url = itemUrl.trim();
      final match = urlPattern.firstMatch(url);
      if (match == null) throw const FormatException('invalid ICE URL');
      final scheme = match.group(1)!;
      final portText = match.group(3);
      final transport = match.group(4);
      if (portText != null) {
        final port = int.parse(portText);
        if (port < 1 || port > 65535) {
          throw const FormatException('invalid ICE URL port');
        }
      }
      if (scheme == 'stun' && transport != null) {
        throw const FormatException('invalid STUN transport query');
      }
      hasTurn = hasTurn || scheme != 'stun';
      urls.add(url);
    }
    totalUrls += urls.length;
    if (totalUrls > 8) throw const FormatException('too many ICE URLs');
    final username = item['username'];
    final credential = item['credential'];
    if (hasTurn) {
      if (username is! String ||
          username.isEmpty ||
          username.length > 256 ||
          credential is! String ||
          credential.isEmpty ||
          credential.length > 512) {
        throw const FormatException('TURN credentials are required');
      }
    } else if (username != null || credential != null) {
      throw const FormatException('STUN credentials are forbidden');
    }
    result.add(<String, Object?>{
      'urls': urls,
      if (hasTurn) 'username': username,
      if (hasTurn) 'credential': credential,
    });
  }
  return result;
}

String webRtcConfigurationId(
  bool enabled,
  List<Map<String, Object?>> iceServers,
) => sha256
    .convert(
      utf8.encode(
        canonicalJson(<String, Object?>{
          'enabled': enabled,
          'ice_servers': iceServers,
        }),
      ),
    )
    .toString()
    .substring(0, 32);

Map<String, Object?> makeWebRtcSignal(
  String eventType, {
  required String attemptId,
  required int generation,
  required int sequence,
  Map<String, Object?> payload = const <String, Object?>{},
  bool terminal = false,
  DateTime? now,
}) {
  final timestamp =
      (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
  final frame = <String, Object?>{
    'protocol_version': webRtcProtocolVersion,
    'transport': 'webrtc',
    'attempt_id': attemptId,
    'generation': generation,
    'source_role': 'mobile',
    'destination_role': 'pc',
    'event_id': _randomHex(16),
    'event_type': eventType,
    'sequence': sequence,
    'created_at': timestamp,
    'terminal': terminal,
    'payload': Map<String, Object?>.from(payload),
  };
  return validateWebRtcSignal(frame, destinationRole: 'pc', now: now);
}

Map<String, Object?> validateWebRtcSignal(
  Map<String, Object?> frame, {
  required String destinationRole,
  DateTime? now,
}) {
  if (!_hasExactKeys(frame, _signalFields)) {
    throw const FormatException('invalid WebRTC signaling envelope');
  }
  final sourceRole = frame['source_role'];
  final eventType = frame['event_type'];
  if (frame['protocol_version'] != webRtcProtocolVersion ||
      frame['transport'] != 'webrtc' ||
      !webRtcSignalEventTypes.contains(eventType) ||
      !const <String>{'pc', 'mobile'}.contains(destinationRole) ||
      frame['destination_role'] != destinationRole ||
      !const <String>{'pc', 'mobile'}.contains(sourceRole) ||
      sourceRole == destinationRole ||
      !RegExp(
        r'^[0-9a-f]{32}$',
      ).hasMatch(frame['attempt_id']?.toString() ?? '') ||
      !RegExp(
        r'^[0-9a-f]{32}$',
      ).hasMatch(frame['event_id']?.toString() ?? '')) {
    throw const FormatException('invalid WebRTC signaling metadata');
  }
  final generation = frame['generation'];
  final sequence = frame['sequence'];
  final createdAt = frame['created_at'];
  final terminal = frame['terminal'];
  if (generation is! int ||
      generation < 1 ||
      generation >= 0x80000000 ||
      sequence is! int ||
      sequence < 1 ||
      sequence >= 0x80000000 ||
      createdAt is! int ||
      terminal is! bool ||
      frame['payload'] is! Map) {
    throw const FormatException('invalid WebRTC signaling sequence');
  }
  final current =
      (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
  if (createdAt > current + 5 ||
      current - createdAt > webRtcSignalTtl.inSeconds) {
    throw const FormatException('expired WebRTC signaling event');
  }
  _validateSignalPayload(
    eventType as String,
    (frame['payload'] as Map).cast<String, Object?>(),
    terminal,
  );
  return Map<String, Object?>.from(frame);
}

void _validateSignalPayload(
  String eventType,
  Map<String, Object?> payload,
  bool terminal,
) {
  if (eventType == 'webrtc_prepare') {
    if (!_hasExactKeys(payload, const <String>{'configuration_id'}) ||
        !RegExp(
          r'^[0-9a-f]{32}$',
        ).hasMatch(payload['configuration_id']?.toString() ?? '') ||
        terminal) {
      throw const FormatException('invalid WebRTC prepare');
    }
    return;
  }
  if (eventType == 'webrtc_offer' || eventType == 'webrtc_answer') {
    final type = eventType == 'webrtc_offer' ? 'offer' : 'answer';
    if (!_hasExactKeys(payload, const <String>{'type', 'sdp'}) ||
        payload['type'] != type ||
        terminal) {
      throw const FormatException('invalid WebRTC SDP payload');
    }
    validateWebRtcDataOnlySdp(payload['sdp']);
    return;
  }
  if (eventType == 'webrtc_ice_candidates') {
    final candidates = payload['candidates'];
    if (!_hasExactKeys(payload, const <String>{'candidates'}) ||
        candidates is! List ||
        candidates.isEmpty ||
        candidates.length > webRtcMaxCandidatesPerEvent ||
        terminal) {
      throw const FormatException('invalid WebRTC candidate batch');
    }
    for (final candidate in candidates) {
      validateWebRtcCandidate(candidate);
    }
    return;
  }
  if (const <String>{
    'webrtc_end_of_candidates',
    'webrtc_direct_ready',
    'webrtc_direct_commit',
    'webrtc_direct_commit_ack',
  }.contains(eventType)) {
    if (payload.isNotEmpty || terminal) {
      throw const FormatException('invalid WebRTC control payload');
    }
    return;
  }
  if (eventType == 'webrtc_cancel') {
    if (!_hasExactKeys(payload, const <String>{'category'}) ||
        !const <String>{
          'cancelled',
          'superseded',
        }.contains(payload['category']) ||
        !terminal) {
      throw const FormatException('invalid WebRTC cancellation');
    }
    return;
  }
  if (eventType == 'webrtc_failed') {
    if (!_hasExactKeys(payload, const <String>{'category'}) ||
        !_failureCategories.contains(payload['category']) ||
        !terminal) {
      throw const FormatException('invalid WebRTC failure');
    }
    return;
  }
  throw const FormatException('unsupported WebRTC event');
}

String validateWebRtcDataOnlySdp(Object? raw) {
  if (raw is! String ||
      raw.isEmpty ||
      utf8.encode(raw).length > webRtcMaxSdpBytes) {
    throw const FormatException('invalid WebRTC SDP');
  }
  final normalized = raw.replaceAll('\r\n', '\n');
  if (!normalized.startsWith('v=0\n') ||
      !normalized.contains('\nm=application ') ||
      normalized.contains('\nm=audio ') ||
      normalized.contains('\nm=video ')) {
    throw const FormatException('WebRTC SDP must be data-only');
  }
  return raw;
}

Map<String, Object?> validateWebRtcCandidate(Object? raw) {
  if (raw is! Map ||
      !_hasExactKeys(raw, const <String>{
        'candidate',
        'sdp_mid',
        'sdp_mline_index',
      })) {
    throw const FormatException('invalid WebRTC candidate fields');
  }
  final candidate = raw['candidate'];
  final mid = raw['sdp_mid'];
  final mline = raw['sdp_mline_index'];
  if (candidate is! String ||
      !candidate.startsWith('candidate:') ||
      utf8.encode(candidate).length > webRtcMaxCandidateBytes ||
      mid is! String ||
      !RegExp(r'^[A-Za-z0-9_-]{1,16}$').hasMatch(mid) ||
      mline is! int ||
      mline < 0 ||
      mline > 8) {
    throw const FormatException('invalid WebRTC candidate');
  }
  final fields = candidate.split(RegExp(r'\s+'));
  if (fields.length < 8 ||
      fields[1] != '1' ||
      !const <String>{'udp', 'tcp'}.contains(fields[2].toLowerCase()) ||
      fields[6] != 'typ' ||
      !const <String>{'host', 'srflx', 'prflx', 'relay'}.contains(fields[7])) {
    throw const FormatException('unsupported WebRTC candidate');
  }
  final port = int.tryParse(fields[5]);
  if (port == null || port < 1 || port > 65535) {
    throw const FormatException('invalid WebRTC candidate port');
  }
  return <String, Object?>{
    'candidate': candidate,
    'sdp_mid': mid,
    'sdp_mline_index': mline,
  };
}

String webRtcCandidateDedupKey(Map<String, Object?> candidate) =>
    sha256.convert(utf8.encode(canonicalJson(candidate))).toString();

({String sdp, List<Map<String, Object?>> candidates}) stripWebRtcSdpCandidates(
  String sdp,
) {
  validateWebRtcDataOnlySdp(sdp);
  final output = <String>[];
  final candidates = <Map<String, Object?>>[];
  var mlineIndex = -1;
  var currentMid = '';
  for (final line in sdp.replaceAll('\r\n', '\n').split('\n')) {
    if (line.startsWith('m=')) mlineIndex++;
    if (line.startsWith('a=mid:')) currentMid = line.substring(6);
    if (line.startsWith('a=candidate:')) {
      candidates.add(
        validateWebRtcCandidate(<String, Object?>{
          'candidate': line.substring(2),
          'sdp_mid': currentMid,
          'sdp_mline_index': mlineIndex,
        }),
      );
      if (candidates.length > webRtcMaxCandidates) {
        throw const FormatException('too many WebRTC candidates');
      }
      continue;
    }
    if (line == 'a=end-of-candidates') continue;
    output.add(line);
  }
  var stripped = output.join('\r\n');
  if (!stripped.endsWith('\r\n')) stripped += '\r\n';
  validateWebRtcDataOnlySdp(stripped);
  return (sdp: stripped, candidates: candidates);
}
