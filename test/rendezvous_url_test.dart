import 'package:flutter_test/flutter_test.dart';

import 'package:osia_mobile/services/rendezvous_service.dart';

// WOR-64 regression: the rendezvous Worker hands back a `{"url": ...}` whose
// host the phone must turn into exactly `wss://<host>/ws`. A live test caught a
// malformed `https://<host>:0/0/ws#` instead — the symptom of a NON-bare value
// (scheme/port/path) reaching the WebSocket URL builder. `RendezvousService
// .bareHost` is the guard: its output must be a clean bare host so the builder
// in `WebSocketService._doConnect` (the protected file) forms the URL safely.
//
// `_doConnect` builds the URL as:
//   final host = _sanitizeHost(bareHost(...));            // _sanitizeHost is a
//   final isDomain = RegExp(r'[a-zA-Z]').hasMatch(host);  //   no-op on a bare
//   final url = isDomain ? 'wss://$host/ws'               //   host
//                        : 'ws://$host:8765/ws';
// `_sanitizeHost` lives in the protected `websocket_service.dart` and is
// private, so we reproduce it verbatim here to assert the END-TO-END URL. The
// bareHost invariant tests below prove the reproduction is faithful: on a bare
// host, `_sanitizeHost` cannot change anything.
String _sanitizeHost(String raw) {
  var s = raw.trim();
  s = s.replaceFirst(RegExp(r'^(wss?|https?)://', caseSensitive: false), '');
  final slash = s.indexOf('/');
  if (slash != -1) s = s.substring(0, slash);
  final colon = s.indexOf(':');
  if (colon != -1) s = s.substring(0, colon);
  return s;
}

/// The full host → connect-URL path, exactly as `_doConnect` performs it for a
/// resolver-provided host.
String connectUrlFor(String workerUrl) {
  final host = _sanitizeHost(RendezvousService.bareHost(workerUrl));
  final isDomain = RegExp(r'[a-zA-Z]').hasMatch(host);
  return isDomain ? 'wss://$host/ws' : 'ws://$host:8765/ws';
}

void main() {
  const sampleWorkerUrl =
      'https://elect-inquiries-col-translate.trycloudflare.com';
  const expectedHost = 'elect-inquiries-col-translate.trycloudflare.com';
  const expectedUrl =
      'wss://elect-inquiries-col-translate.trycloudflare.com/ws';

  group('RendezvousService.bareHost', () {
    test('strips the scheme from the documented Worker response', () {
      expect(RendezvousService.bareHost(sampleWorkerUrl), expectedHost);
    });

    test('normalises scheme/port/path/whitespace variants to the same host',
        () {
      for (final raw in <String>[
        sampleWorkerUrl,
        '$sampleWorkerUrl/', // trailing slash
        '$sampleWorkerUrl/ws', // path
        '$sampleWorkerUrl:443', // explicit port
        '$sampleWorkerUrl:443/ws', // port + path
        'HTTPS://$expectedHost', // upper-case scheme
        'wss://$expectedHost', // already a ws scheme
        expectedHost, // no scheme at all
        '  $sampleWorkerUrl  ', // surrounding whitespace
        '$sampleWorkerUrl#', // bare trailing fragment
        '$sampleWorkerUrl?x=1', // bare query, no path slash
        '$sampleWorkerUrl#/0/ws', // the exact leak from the live report
      ]) {
        expect(RendezvousService.bareHost(raw), expectedHost,
            reason: 'bareHost("$raw") should be the clean host');
      }
    });

    test('output carries nothing that could leak into the URL', () {
      final host = RendezvousService.bareHost(sampleWorkerUrl);
      expect(host, isNot(contains('://')), reason: 'no scheme');
      expect(host, isNot(contains(':')), reason: 'no port');
      expect(host, isNot(contains('/')), reason: 'no path');
      expect(host, isNot(contains('#')), reason: 'no fragment');
      expect(host, host.trim(), reason: 'no surrounding whitespace');
    });
  });

  group('host → connect URL', () {
    test('the documented Worker response yields exactly wss://<host>/ws', () {
      expect(connectUrlFor(sampleWorkerUrl), expectedUrl);
    });

    test('never reproduces the live malformed shapes (:0, /0/, scheme, #)', () {
      final url = connectUrlFor(sampleWorkerUrl);
      expect(url, startsWith('wss://'));
      expect(url, isNot(contains(':0')));
      expect(url, isNot(contains('/0/')));
      expect(url, isNot(contains('#')));
      // No second scheme smuggled into the authority.
      expect('://'.allMatches(url).length, 1);
    });

    test('all Worker-response variants resolve to the one correct URL', () {
      for (final raw in <String>[
        sampleWorkerUrl,
        '$sampleWorkerUrl/',
        '$sampleWorkerUrl/ws',
        '$sampleWorkerUrl:443',
        'HTTPS://$expectedHost',
      ]) {
        expect(connectUrlFor(raw), expectedUrl,
            reason: 'connectUrlFor("$raw")');
      }
    });
  });
}
