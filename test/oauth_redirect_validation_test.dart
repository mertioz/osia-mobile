import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/screens/providers_screen.dart';

const _hex64 = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hex64Upper = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _hex63 = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _legacy =
    'https://osia-rendezvous.aymengherbi06.workers.dev/oauth/cb/$_hex64';

String _authorizationUrl({
  String host = 'accounts.google.com',
  String redirect = osiaOAuthRelayRedirectUri,
  String method = 'S256',
}) {
  return Uri.https(host, '/o/oauth2/v2/auth', <String, String>{
    'response_type': 'code',
    'client_id': 'public-client',
    'state': 'local-state',
    'code_challenge': 'public-challenge',
    'code_challenge_method': method,
    'redirect_uri': redirect,
  }).toString();
}

void main() {
  group('WOR-203 exact OAuth redirect validation', () {
    test('accepts the stable callback and exact temporary legacy form', () {
      expect(isTrustedOsiaMobileOAuthRedirect(osiaOAuthRelayRedirectUri), isTrue);
      expect(isTrustedOsiaMobileOAuthRedirect(_legacy), isTrue);
    });

    test('rejects scheme, host, port, path and authority confusion', () {
      const rejected = <String>[
        'http://relay.osia.space/oauth/callback',
        'https://other.example/oauth/callback',
        'https://sub.relay.osia.space/oauth/callback',
        'https://relay.osia.space.evil.example/oauth/callback',
        'https://xn--relay-osia-9za.space/oauth/callback',
        'https://relay.osia.space:443/oauth/callback',
        'https://relay.osia.space/oauth/callback/extra',
        'https://relay.osia.space/oauth/%63allback',
        'https://relay.osia.space/oauth/../callback',
        'https://relay.osia.space/oauth/%2e%2e/callback',
        'https://user@relay.osia.space/oauth/callback',
        'https://relay.osia.space/oauth/callback#fragment',
        'https://relay.osia.space/oauth/callback?extra=1',
        'https://relay.osiа.space/oauth/callback',
      ];
      for (final value in rejected) {
        expect(isTrustedOsiaMobileOAuthRedirect(value), isFalse, reason: value);
      }
    });

    test('does not broaden the temporary legacy callback', () {
      for (final value in <String>[
        'http://osia-rendezvous.aymengherbi06.workers.dev/oauth/cb/$_hex64',
        'https://sub.osia-rendezvous.aymengherbi06.workers.dev/oauth/cb/$_hex64',
        'https://osia-rendezvous.aymengherbi06.workers.dev:443/oauth/cb/$_hex64',
        'https://user@osia-rendezvous.aymengherbi06.workers.dev/oauth/cb/$_hex64',
        'https://osia-rendezvous.aymengherbi06.workers.dev/oauth/cb/$_hex64Upper',
        'https://osia-rendezvous.aymengherbi06.workers.dev/oauth/cb/$_hex63',
        'https://osia-rendezvous.aymengherbi06.workers.dev/oauth/cb/$_hex64/extra',
        'https://osia-rendezvous.aymengherbi06.workers.dev/oauth/cb/$_hex64?x=1',
        'https://osia-rendezvous.aymengherbi06.workers.dev/oauth/cb/$_hex64#x',
      ]) {
        expect(isTrustedOsiaMobileOAuthRedirect(value), isFalse, reason: value);
      }
    });
  });

  group('WOR-203 authorization URL validation', () {
    test('preserves Gmail host, state and S256 checks', () {
      expect(isTrustedGmailAuthorizationUrl(_authorizationUrl()), isTrue);
      expect(
        isTrustedGmailAuthorizationUrl(_authorizationUrl(host: 'login.example')),
        isFalse,
      );
      expect(
        isTrustedGmailAuthorizationUrl(_authorizationUrl(method: 'plain')),
        isFalse,
      );
      final noState = Uri.parse(_authorizationUrl()).replace(
        queryParameters: <String, String>{
          'response_type': 'code',
          'client_id': 'public-client',
          'code_challenge': 'public-challenge',
          'code_challenge_method': 'S256',
          'redirect_uri': osiaOAuthRelayRedirectUri,
        },
      );
      expect(isTrustedGmailAuthorizationUrl(noState.toString()), isFalse);
    });

    test('permits generic MCP provider hosts with only trusted callbacks', () {
      final generic = Uri.https('login.connector.example', '/authorize', {
        'state': 'sdk-state',
        'redirect_uri': osiaOAuthRelayRedirectUri,
      }).toString();
      final untrusted = Uri.https('login.connector.example', '/authorize', {
        'state': 'sdk-state',
        'redirect_uri': 'https://evil.example/cb',
      }).toString();
      expect(isTrustedMcpAuthorizationUrl(generic), isTrue);
      expect(isTrustedMcpAuthorizationUrl(untrusted), isFalse);
    });
  });
}
