import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

// ── WOR-64: token → URL rendezvous ────────────────────────────────────────
//
// The phone no longer hard-codes a server host. It derives a rendezvous key
// from its stored token, asks the rendezvous Worker for the PC's *current*
// quick-tunnel URL, then connects + authenticates exactly as before. Because
// the URL is fetched fresh on every connect (and reconnect), a PC restart that
// rotates its tunnel URL is handled transparently — only the token persists.
//
// Derivation (MUST stay byte-for-byte identical to the PC and the Worker):
//   proof          = HMAC_SHA256(key = token_utf8, msg = "osia-rdv-v1") → 64 hex
//   rendezvous_key = SHA256(proof_HEX_STRING)                           → 64 hex
// The second step hashes the proof's *hex string*, not its raw bytes.

/// Sentinel error surfaced when the rendezvous Worker returns 404 — the PC is
/// not publishing a tunnel URL (it's offline). A failed [RendezvousService
/// .resolveHost] is re-emitted on the WebSocket error stream as a plain string,
/// so UI layers match on this exact value to tell an offline PC apart from a
/// bad token or a generic network failure.
const String kPcOfflineError = 'PC offline';

/// Thrown by [RendezvousService.resolveHost] when the Worker has no current URL
/// for this token's rendezvous key (HTTP 404 → the PC is offline). Its
/// [toString] is exactly [kPcOfflineError] so it survives the trip through the
/// WebSocket error stream as an identifiable sentinel.
class PcOfflineException implements Exception {
  const PcOfflineException();
  @override
  String toString() => kPcOfflineError;
}

/// Thrown when the rendezvous lookup fails for a transport reason (network
/// unreachable, timeout, bad status, malformed body) — distinct from
/// [PcOfflineException] so callers map it to a generic connection failure.
class RendezvousException implements Exception {
  final String message;
  const RendezvousException(this.message);
  @override
  String toString() => 'RendezvousException: $message';
}

/// Derive the rendezvous key for [token]. Byte-for-byte identical to the PC and
/// Worker:
///   proof = HMAC_SHA256(token_utf8, "osia-rdv-v1") → 64-hex string
///   key   = SHA256(proof_hex_string)               → 64-hex string
/// The second SHA-256 hashes the *hex string* of the proof (not its raw bytes).
String deriveRendezvousKey(String token) {
  final proofHex = Hmac(sha256, utf8.encode(token))
      .convert(utf8.encode('osia-rdv-v1'))
      .toString();
  return sha256.convert(utf8.encode(proofHex)).toString();
}

/// Resolves a token to the PC's current server host via the rendezvous Worker.
class RendezvousService {
  /// Base URL of the deployed rendezvous Worker.
  static const String _workerBase =
      'https://osia-rendezvous.aymengherbi06.workers.dev';

  /// Cloudflare blocks default client user-agents (the PC side hit a 403), so
  /// we send an explicit one to be allowed through.
  static const String _userAgent = 'OSIA-Mobile/1.0';

  static const Duration _timeout = Duration(seconds: 10);

  /// Look up the PC's current server host for [token].
  ///
  /// Derives the rendezvous key, GETs `/r/<key>` from the Worker, and returns
  /// the BARE host (scheme/path/port stripped) of the `{"url": …}` it replies
  /// with, so the existing host sanitiser / URL builder can form
  /// `wss://<host>/ws`.
  ///
  /// Throws [PcOfflineException] on 404 (no URL registered → PC offline) and
  /// [RendezvousException] on any transport/parse failure.
  Future<String> resolveHost(String token) async {
    final key = deriveRendezvousKey(token);
    final uri = Uri.parse('$_workerBase/r/$key');

    final client = HttpClient()
      ..connectionTimeout = _timeout
      // Set the UA before issuing the request so Cloudflare sees it and lets us
      // through (default Dart/curl user-agents can be rejected with a 403).
      ..userAgent = _userAgent;
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      final response = await request.close().timeout(_timeout);

      if (response.statusCode == 404) {
        throw const PcOfflineException();
      }
      if (response.statusCode != HttpStatus.ok) {
        throw RendezvousException('HTTP ${response.statusCode}');
      }

      final body =
          await response.transform(utf8.decoder).join().timeout(_timeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['url'] == null) {
        throw const RendezvousException('Malformed rendezvous response');
      }
      final host = bareHost(decoded['url'].toString());
      if (host.isEmpty) {
        throw const RendezvousException('Empty host in rendezvous response');
      }
      debugPrint('[OSIA Rdv] Resolved host: $host');
      return host;
    } on PcOfflineException {
      rethrow;
    } on RendezvousException {
      rethrow;
    } on SocketException catch (e) {
      throw RendezvousException('Network unreachable: ${e.message}');
    } on TimeoutException {
      throw const RendezvousException('Rendezvous lookup timed out');
    } on HttpException catch (e) {
      throw RendezvousException(e.message);
    } on FormatException catch (e) {
      throw RendezvousException('Bad rendezvous response: ${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  /// Strip scheme, path, query and port from a URL, leaving the bare host.
  ///
  /// The WebSocket layer builds its connect URL as `wss://<host>/ws`, so the
  /// value returned here MUST be a bare host — no scheme, port, path, query or
  /// fragment. Anything else leaks into the final URL (the WOR-64 live bug:
  /// `https://host:0/0/ws#` instead of `wss://host/ws`). Exposed for testing.
  @visibleForTesting
  static String bareHost(String raw) {
    var s = raw.trim();
    s = s.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://'), '');
    // Cut at the first path / query / fragment delimiter, then drop an explicit
    // port — leaving a bare host. A cloudflared quick-tunnel URL carries none of
    // these, but honour the contract so a stray '#'/'?'/'/'/':' can never leak
    // into the `wss://<host>/ws` the WebSocket layer builds.
    final cut = s.indexOf(RegExp(r'[/?#]'));
    if (cut != -1) s = s.substring(0, cut);
    final colon = s.indexOf(':');
    if (colon != -1) s = s.substring(0, colon);
    return s.trim();
  }
}
