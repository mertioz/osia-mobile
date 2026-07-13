import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/lan_direct_transport.dart';

void main() {
  group('LAN-direct manual configuration', () {
    test('accepts only the fixed port, private IPv4, and a SHA-256 pin', () {
      final pin = List<String>.filled(32, 'ab').join();
      final config = LanDirectConfig(
        host: '192.168.1.20',
        certificateSha256: pin.toUpperCase(),
      );

      expect(config.host, '192.168.1.20');
      expect(config.port, lanDirectPort);
      expect(config.certificateSha256, pin);
      expect(config.endpoint.toString(), 'wss://192.168.1.20:8766/lan');
    });

    test(
      'rejects public, wildcard, loopback, DNS, malformed pin and other port',
      () {
        final pin = List<String>.filled(32, 'ab').join();
        for (final host in <String>[
          '0.0.0.0',
          '127.0.0.1',
          '8.8.8.8',
          'osia.example',
          '::1',
        ]) {
          expect(
            () => LanDirectConfig(host: host, certificateSha256: pin),
            throwsFormatException,
            reason: host,
          );
        }
        expect(
          () => LanDirectConfig(
            host: '192.168.1.20',
            certificateSha256: 'not-a-pin',
          ),
          throwsFormatException,
        );
        expect(
          () => LanDirectConfig(
            host: '192.168.1.20',
            certificateSha256: pin,
            port: 8765,
          ),
          throwsFormatException,
        );
      },
    );
  });

  test('certificate pin matches exact DER only', () {
    final certificate = utf8.encode('test-certificate-der');
    final pin = sha256.convert(certificate).toString();

    expect(certificateSha256Matches(certificate, pin), isTrue);
    expect(
      certificateSha256Matches(utf8.encode('other-certificate'), pin),
      isFalse,
    );
  });

  test('LAN-direct feature flag is disabled in the default test build', () {
    expect(kLanDirectV1, isFalse);
  });
}
