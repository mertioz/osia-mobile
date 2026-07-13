import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/services/lan_direct_transport.dart';
import 'package:osia_mobile/services/lan_discovery_service.dart';

const String _pairedAlias = '0123456789abcdef';
const String _pairedDomain = 'OSIA-0123456789abcdef._osia._tcp.local.';

class _FakeDiscoveryAdapter implements LanDiscoveryAdapter {
  final List<LanDiscoveryPtrRecord> pointers = <LanDiscoveryPtrRecord>[];
  final Map<String, List<LanDiscoveryTxtRecord>> text =
      <String, List<LanDiscoveryTxtRecord>>{};
  final Map<String, List<LanDiscoverySrvRecord>> services =
      <String, List<LanDiscoverySrvRecord>>{};
  final Map<String, List<LanDiscoveryAddressRecord>> addresses =
      <String, List<LanDiscoveryAddressRecord>>{};
  final List<Duration> observedTimeouts = <Duration>[];
  final Completer<void> pointerLookupStarted = Completer<void>();

  StreamController<LanDiscoveryPtrRecord>? pointerController;
  Object? startError;
  int startCalls = 0;
  int stopCalls = 0;
  int textLookupCalls = 0;
  int serviceLookupCalls = 0;
  int addressLookupCalls = 0;

  void addValidService({
    String alias = _pairedAlias,
    String host = '192.168.10.20',
    int port = 8766,
    String? txt,
  }) {
    final domain = 'OSIA-$alias._osia._tcp.local.';
    pointers.add(LanDiscoveryPtrRecord(domain));
    text[domain] = <LanDiscoveryTxtRecord>[
      LanDiscoveryTxtRecord(
        txt ??
            'protocol=1\n'
                'product_version=1.0.0\n'
                'instance=$alias\n',
      ),
    ];
    services[domain] = <LanDiscoverySrvRecord>[
      LanDiscoverySrvRecord(target: 'osia-$alias.local.', port: port),
    ];
    addresses['osia-$alias.local.'] = <LanDiscoveryAddressRecord>[
      LanDiscoveryAddressRecord(InternetAddress(host)),
    ];
  }

  @override
  Future<void> start() async {
    startCalls++;
    final error = startError;
    if (error != null) throw error;
  }

  @override
  Stream<LanDiscoveryPtrRecord> lookupPointers(Duration timeout) {
    observedTimeouts.add(timeout);
    if (!pointerLookupStarted.isCompleted) pointerLookupStarted.complete();
    return pointerController?.stream ??
        Stream<LanDiscoveryPtrRecord>.fromIterable(pointers);
  }

  @override
  Future<List<LanDiscoveryTxtRecord>> lookupText(
    String domainName,
    Duration timeout,
  ) async {
    textLookupCalls++;
    observedTimeouts.add(timeout);
    return text[domainName] ?? const <LanDiscoveryTxtRecord>[];
  }

  @override
  Stream<LanDiscoverySrvRecord> lookupServices(
    String domainName,
    Duration timeout,
  ) {
    serviceLookupCalls++;
    observedTimeouts.add(timeout);
    return Stream<LanDiscoverySrvRecord>.fromIterable(
      services[domainName] ?? const <LanDiscoverySrvRecord>[],
    );
  }

  @override
  Stream<LanDiscoveryAddressRecord> lookupIpv4(
    String target,
    Duration timeout,
  ) {
    addressLookupCalls++;
    observedTimeouts.add(timeout);
    return Stream<LanDiscoveryAddressRecord>.fromIterable(
      addresses[target] ?? const <LanDiscoveryAddressRecord>[],
    );
  }

  @override
  void stop() {
    stopCalls++;
  }
}

LanDiscoveryService _serviceFor(_FakeDiscoveryAdapter adapter) =>
    LanDiscoveryService(adapterFactory: () => adapter);

void main() {
  test('valid paired alias, RFC1918 host and fixed port succeeds', () async {
    final adapter = _FakeDiscoveryAdapter()..addValidService();
    final result = await _serviceFor(adapter).discover(_pairedAlias);

    expect(result, isNotNull);
    expect(result!.instanceAlias, _pairedAlias);
    expect(result.host, '192.168.10.20');
    expect(result.port, 8766);
    expect(result.productVersion, '1.0.0');
    expect(adapter.startCalls, 1);
    expect(adapter.stopCalls, 1);
    expect(
      adapter.observedTimeouts,
      everyElement(lessThanOrEqualTo(lanDiscoveryTimeout)),
    );
  });

  test('wrong and missing authenticated aliases are rejected', () async {
    var factoryCalls = 0;
    final invalidService = LanDiscoveryService(
      adapterFactory: () {
        factoryCalls++;
        return _FakeDiscoveryAdapter();
      },
    );
    expect(await invalidService.discover(''), isNull);
    expect(await invalidService.discover('invalid-alias'), isNull);
    expect(factoryCalls, 0);

    final adapter = _FakeDiscoveryAdapter()
      ..addValidService(alias: 'fedcba9876543210');
    expect(await _serviceFor(adapter).discover(_pairedAlias), isNull);
    expect(adapter.textLookupCalls, 0);
    expect(adapter.stopCalls, 1);
  });

  test('only the paired alias is selected from multiple devices', () async {
    final adapter = _FakeDiscoveryAdapter()
      ..addValidService(alias: 'fedcba9876543210', host: '10.0.0.8')
      ..addValidService(host: '10.0.0.9');

    final result = await _serviceFor(adapter).discover(_pairedAlias);

    expect(result, isNotNull);
    expect(result!.instanceAlias, _pairedAlias);
    expect(result.host, '10.0.0.9');
    expect(adapter.textLookupCalls, 1);
  });

  test('public, loopback, wildcard and IPv6 records are rejected', () async {
    for (final host in <String>[
      '8.8.8.8',
      '127.0.0.1',
      '0.0.0.0',
      '169.254.1.1',
      '::1',
      '2001:db8::1',
    ]) {
      final adapter = _FakeDiscoveryAdapter()..addValidService(host: host);
      expect(
        await _serviceFor(adapter).discover(_pairedAlias),
        isNull,
        reason: host,
      );
      expect(adapter.stopCalls, 1, reason: host);
    }
  });

  test('wrong port is rejected', () async {
    final adapter = _FakeDiscoveryAdapter()..addValidService(port: 8765);
    expect(await _serviceFor(adapter).discover(_pairedAlias), isNull);
    expect(adapter.addressLookupCalls, 0);
    expect(adapter.stopCalls, 1);
  });

  test(
    'duplicate PTR, SRV and A records cannot create duplicate authority',
    () async {
      final adapter = _FakeDiscoveryAdapter()..addValidService();
      adapter.pointers.add(const LanDiscoveryPtrRecord(_pairedDomain));
      adapter.services[_pairedDomain]!.add(
        const LanDiscoverySrvRecord(
          target: 'osia-0123456789abcdef.local.',
          port: 8766,
        ),
      );
      adapter.addresses['osia-0123456789abcdef.local.']!.add(
        LanDiscoveryAddressRecord(InternetAddress('192.168.10.20')),
      );

      final result = await _serviceFor(adapter).discover(_pairedAlias);

      expect(result, isNotNull);
      expect(adapter.textLookupCalls, 1);
      expect(adapter.serviceLookupCalls, 1);
      expect(adapter.addressLookupCalls, 1);
      expect(adapter.stopCalls, 1);
    },
  );

  test('malformed TXT records fail closed', () async {
    for (final txt in <String>[
      '',
      'not-key-value',
      'protocol=2\nproduct_version=1.0.0\ninstance=$_pairedAlias\n',
      'protocol=1\ninstance=$_pairedAlias\n',
      'protocol=1\nproduct_version=1.0.0\ninstance=wrong\n',
    ]) {
      final adapter = _FakeDiscoveryAdapter()..addValidService(txt: txt);
      expect(
        await _serviceFor(adapter).discover(_pairedAlias),
        isNull,
        reason: txt,
      );
      expect(adapter.stopCalls, 1, reason: txt);
    }
  });

  test('unauthenticated TXT pin is ignored', () async {
    final adapter = _FakeDiscoveryAdapter()
      ..addValidService(
        txt:
            'protocol=1\n'
            'product_version=1.0.0\n'
            'instance=$_pairedAlias\n'
            'pin=unauthenticated-value\n',
      );

    final result = await _serviceFor(adapter).discover(_pairedAlias);

    expect(result, isNotNull);
    final discoverySource = File(
      'lib/services/lan_discovery_service.dart',
    ).readAsStringSync();
    final websocketSource = File(
      'lib/services/websocket_service.dart',
    ).readAsStringSync();
    expect(discoverySource, isNot(contains("txt['pin']")));
    expect(
      websocketSource,
      contains('certificateSha256: identity.certificateSha256'),
    );
  });

  test(
    'no result before the bounded deadline is a discovery failure',
    () async {
      final adapter = _FakeDiscoveryAdapter();
      final result = await _serviceFor(
        adapter,
      ).discover(_pairedAlias, timeout: const Duration(milliseconds: 25));

      expect(result, isNull);
      expect(adapter.observedTimeouts, hasLength(1));
      expect(adapter.observedTimeouts.single, greaterThan(Duration.zero));
      expect(
        adapter.observedTimeouts.single,
        lessThanOrEqualTo(const Duration(milliseconds: 25)),
      );
      expect(adapter.stopCalls, 1);
    },
  );

  test(
    'stop cancels an active selection exactly once and rejects late records',
    () async {
      final adapter = _FakeDiscoveryAdapter()
        ..pointerController = StreamController<LanDiscoveryPtrRecord>();
      final service = _serviceFor(adapter);
      final discovery = service.discover(_pairedAlias);
      await adapter.pointerLookupStarted.future;

      service.stop();
      service.stop();
      adapter.pointerController!.add(
        const LanDiscoveryPtrRecord(_pairedDomain),
      );
      await adapter.pointerController!.close();

      expect(await discovery, isNull);
      expect(adapter.stopCalls, 1);
      expect(adapter.textLookupCalls, 0);
    },
  );

  test(
    'superseding selection cancels the previous lookup and ignores late data',
    () async {
      final first = _FakeDiscoveryAdapter()
        ..pointerController = StreamController<LanDiscoveryPtrRecord>();
      final second = _FakeDiscoveryAdapter()..addValidService();
      final adapters = <_FakeDiscoveryAdapter>[first, second];
      var index = 0;
      final service = LanDiscoveryService(
        adapterFactory: () => adapters[index++],
      );

      final firstDiscovery = service.discover(_pairedAlias);
      await first.pointerLookupStarted.future;
      final secondResult = await service.discover(_pairedAlias);
      first.pointerController!.add(const LanDiscoveryPtrRecord(_pairedDomain));
      await first.pointerController!.close();

      expect(await firstDiscovery, isNull);
      expect(secondResult, isNotNull);
      expect(first.stopCalls, 1);
      expect(first.textLookupCalls, 0);
      expect(second.stopCalls, 1);
    },
  );

  test(
    'adapter errors return sanitized discovery failure and clean up once',
    () async {
      final adapter = _FakeDiscoveryAdapter()
        ..startError = const LanDiscoveryAdapterException('socket_unavailable');

      expect(await _serviceFor(adapter).discover(_pairedAlias), isNull);
      expect(adapter.startCalls, 1);
      expect(adapter.stopCalls, 1);
    },
  );

  test(
    'production construction remains real mDNS and diagnostic fallback is not default',
    () {
      final source = File(
        'lib/services/lan_discovery_service.dart',
      ).readAsStringSync();
      final transportSource = File(
        'lib/services/lan_direct_transport.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('adapterFactory ?? MulticastDnsLanDiscoveryAdapter.new'),
      );
      expect(source, contains('_client = client ?? MDnsClient()'));
      expect(source, contains("ResourceRecordQuery.serverPointer("));
      expect(source, contains("'_osia._tcp.local'"));
      expect(LanDirectConfig.fromEnvironment(), isNull);
      expect(
        transportSource,
        contains('static LanDirectConfig? fromEnvironment()'),
      );
      expect(
        transportSource,
        contains(
          "const bool kLanDirectV1 = bool.fromEnvironment('lan_direct_v1')",
        ),
      );
    },
  );
}
