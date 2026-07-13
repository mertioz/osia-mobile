import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

const String lanDiscoveryServiceType = '_osia._tcp.local';
const Duration lanDiscoveryTimeout = Duration(seconds: 3);

class LanDiscoveredService {
  const LanDiscoveredService({
    required this.instanceAlias,
    required this.host,
    required this.port,
    required this.productVersion,
  });

  final String instanceAlias;
  final String host;
  final int port;
  final String productVersion;
}

class LanDiscoveryPtrRecord {
  const LanDiscoveryPtrRecord(this.domainName);

  final String domainName;
}

class LanDiscoveryTxtRecord {
  const LanDiscoveryTxtRecord(this.text);

  final String text;
}

class LanDiscoverySrvRecord {
  const LanDiscoverySrvRecord({required this.target, required this.port});

  final String target;
  final int port;
}

class LanDiscoveryAddressRecord {
  const LanDiscoveryAddressRecord(this.address);

  final InternetAddress address;
}

class LanDiscoveryAdapterException implements Exception {
  const LanDiscoveryAdapterException(this.category);

  final String category;

  @override
  String toString() => 'LanDiscoveryAdapterException($category)';
}

abstract interface class LanDiscoveryAdapter {
  Future<void> start();

  Stream<LanDiscoveryPtrRecord> lookupPointers(Duration timeout);

  Future<List<LanDiscoveryTxtRecord>> lookupText(
    String domainName,
    Duration timeout,
  );

  Stream<LanDiscoverySrvRecord> lookupServices(
    String domainName,
    Duration timeout,
  );

  Stream<LanDiscoveryAddressRecord> lookupIpv4(String target, Duration timeout);

  void stop();
}

typedef LanDiscoveryAdapterFactory = LanDiscoveryAdapter Function();

class MulticastDnsLanDiscoveryAdapter implements LanDiscoveryAdapter {
  MulticastDnsLanDiscoveryAdapter({MDnsClient? client})
    : _client = client ?? MDnsClient();

  final MDnsClient _client;
  bool _startSettled = false;
  bool _stopRequested = false;
  bool _clientStopCalled = false;

  @override
  Future<void> start() async {
    try {
      await _client.start();
    } on SocketException {
      throw const LanDiscoveryAdapterException('socket_unavailable');
    } on OSError {
      throw const LanDiscoveryAdapterException('socket_option_unsupported');
    } on StateError {
      throw const LanDiscoveryAdapterException('client_state');
    } finally {
      _startSettled = true;
      if (_stopRequested) _stopClientOnce();
    }
  }

  @override
  Stream<LanDiscoveryPtrRecord> lookupPointers(Duration timeout) async* {
    try {
      await for (final record in _client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(lanDiscoveryServiceType),
        timeout: timeout,
      )) {
        yield LanDiscoveryPtrRecord(record.domainName);
      }
    } on SocketException {
      throw const LanDiscoveryAdapterException('socket_unavailable');
    } on OSError {
      throw const LanDiscoveryAdapterException('socket_option_unsupported');
    } on StateError {
      throw const LanDiscoveryAdapterException('client_state');
    }
  }

  @override
  Future<List<LanDiscoveryTxtRecord>> lookupText(
    String domainName,
    Duration timeout,
  ) async {
    try {
      final records = await _client
          .lookup<TxtResourceRecord>(
            ResourceRecordQuery.text(domainName),
            timeout: timeout,
          )
          .toList();
      return records
          .map((record) => LanDiscoveryTxtRecord(record.text))
          .toList(growable: false);
    } on SocketException {
      throw const LanDiscoveryAdapterException('socket_unavailable');
    } on OSError {
      throw const LanDiscoveryAdapterException('socket_option_unsupported');
    } on StateError {
      throw const LanDiscoveryAdapterException('client_state');
    }
  }

  @override
  Stream<LanDiscoverySrvRecord> lookupServices(
    String domainName,
    Duration timeout,
  ) async* {
    try {
      await for (final record in _client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(domainName),
        timeout: timeout,
      )) {
        yield LanDiscoverySrvRecord(target: record.target, port: record.port);
      }
    } on SocketException {
      throw const LanDiscoveryAdapterException('socket_unavailable');
    } on OSError {
      throw const LanDiscoveryAdapterException('socket_option_unsupported');
    } on StateError {
      throw const LanDiscoveryAdapterException('client_state');
    }
  }

  @override
  Stream<LanDiscoveryAddressRecord> lookupIpv4(
    String target,
    Duration timeout,
  ) async* {
    try {
      await for (final record in _client.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv4(target),
        timeout: timeout,
      )) {
        yield LanDiscoveryAddressRecord(record.address);
      }
    } on SocketException {
      throw const LanDiscoveryAdapterException('socket_unavailable');
    } on OSError {
      throw const LanDiscoveryAdapterException('socket_option_unsupported');
    } on StateError {
      throw const LanDiscoveryAdapterException('client_state');
    }
  }

  @override
  void stop() {
    if (_stopRequested) return;
    _stopRequested = true;
    if (_startSettled) _stopClientOnce();
  }

  void _stopClientOnce() {
    if (_clientStopCalled) return;
    _clientStopCalled = true;
    _client.stop();
  }
}

class _ActiveLanDiscovery {
  _ActiveLanDiscovery(this.adapter);

  final LanDiscoveryAdapter adapter;
  bool _stopped = false;

  void stop() {
    if (_stopped) return;
    _stopped = true;
    adapter.stop();
  }
}

bool isPrivateIpv4Address(InternetAddress address) {
  if (address.type != InternetAddressType.IPv4) return false;
  final bytes = address.rawAddress;
  return bytes[0] == 10 ||
      (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
      (bytes[0] == 192 && bytes[1] == 168);
}

Map<String, String> parseLanTxtRecord(String text) {
  final result = <String, String>{};
  for (final line in text.split('\n')) {
    final separator = line.indexOf('=');
    if (separator <= 0) continue;
    final key = line.substring(0, separator).trim();
    final value = line.substring(separator + 1).trim();
    if (key.isNotEmpty && value.isNotEmpty) result[key] = value;
  }
  return result;
}

class LanDiscoveryService {
  LanDiscoveryService({LanDiscoveryAdapterFactory? adapterFactory})
    : _adapterFactory = adapterFactory ?? MulticastDnsLanDiscoveryAdapter.new;

  final LanDiscoveryAdapterFactory _adapterFactory;
  _ActiveLanDiscovery? _activeSelection;
  int _selectionGeneration = 0;

  void stop() {
    _selectionGeneration++;
    final active = _activeSelection;
    _activeSelection = null;
    active?.stop();
  }

  Future<LanDiscoveredService?> discover(
    String authenticatedAlias, {
    Duration timeout = lanDiscoveryTimeout,
  }) async {
    stop();
    if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(authenticatedAlias)) return null;
    final generation = _selectionGeneration;
    final active = _ActiveLanDiscovery(_adapterFactory());
    final adapter = active.adapter;
    _activeSelection = active;
    final deadline = DateTime.now().add(timeout);
    Duration remaining() {
      final value = deadline.difference(DateTime.now());
      return value.isNegative ? Duration.zero : value;
    }

    try {
      await adapter.start();
      if (generation != _selectionGeneration) return null;
      final seen = <String>{};
      await for (final ptr in adapter.lookupPointers(remaining())) {
        if (generation != _selectionGeneration) return null;
        final match = RegExp(
          r'^OSIA-([0-9a-f]{16})\._osia\._tcp\.local\.?$',
          caseSensitive: false,
        ).firstMatch(ptr.domainName);
        final alias = match?.group(1)?.toLowerCase() ?? '';
        if (alias != authenticatedAlias || remaining() == Duration.zero) {
          continue;
        }
        final txtRecords = await adapter.lookupText(
          ptr.domainName,
          remaining(),
        );
        final txt = txtRecords.isEmpty
            ? const <String, String>{}
            : parseLanTxtRecord(txtRecords.first.text);
        if (txt['instance'] != authenticatedAlias || txt['protocol'] != '1') {
          continue;
        }
        final productVersion = txt['product_version'] ?? '';
        if (productVersion.isEmpty || remaining() == Duration.zero) continue;
        await for (final srv in adapter.lookupServices(
          ptr.domainName,
          remaining(),
        )) {
          if (generation != _selectionGeneration) return null;
          if (srv.port != 8766 || remaining() == Duration.zero) continue;
          await for (final ip in adapter.lookupIpv4(srv.target, remaining())) {
            if (generation != _selectionGeneration) return null;
            if (!isPrivateIpv4Address(ip.address)) continue;
            final key = '${ip.address.address}:${srv.port}:$alias';
            if (!seen.add(key)) continue;
            return LanDiscoveredService(
              instanceAlias: alias,
              host: ip.address.address,
              port: srv.port,
              productVersion: productVersion,
            );
          }
        }
      }
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on LanDiscoveryAdapterException {
      return null;
    } finally {
      if (identical(_activeSelection, active)) _activeSelection = null;
      active.stop();
    }
    return null;
  }
}
