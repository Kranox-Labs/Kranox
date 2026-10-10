import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/core/block_height.dart';
import 'package:kranox_wallet/core/node_address.dart';

void main() {
  test('accepts a host or an address with a port', () {
    expect(parseNodeAddress('node.monerodevs.org:38089'), 'node.monerodevs.org:38089');
    expect(parseNodeAddress(' 192.168.1.10:18081 '), '192.168.1.10:18081');
    expect(parseNodeAddress('[::1]:38081'), '[::1]:38081');
    expect(parseNodeAddress('localhost:38081'), 'localhost:38081');
  });

  test('rejects an address without a valid port', () {
    for (final text in [
      'node.monerodevs.org',
      'node.monerodevs.org:',
      'node:0',
      'node:70000',
      'http://node:38089',
      '',
    ]) {
      expect(() => parseNodeAddress(text), throwsA(isA<NodeAddressException>()), reason: text);
    }
  });

  test('takes a proxy as an IP address and a port only, as wallet2 does', () {
    expect(parseProxyAddress(' 127.0.0.1:9050 '), '127.0.0.1:9050');
    expect(parseProxyAddress('[::1]:9150'), '[::1]:9150');
    for (final text in ['localhost:9050', 'tor.example.org:9050', '999.1.1.1:9050', '127.0.0.1', '']) {
      expect(() => parseProxyAddress(text), throwsA(isA<NodeAddressException>()), reason: text);
    }
  });

  test('splits an address into its host and its port', () {
    expect(splitNodeAddress(' 127.0.0.1:9050 '), (host: '127.0.0.1', port: 9050));
    expect(splitNodeAddress('[::1]:9150'), (host: '::1', port: 9150));
    expect(splitNodeAddress('localhost:9050'), (host: 'localhost', port: 9050));
    expect(() => splitNodeAddress('tor'), throwsA(isA<NodeAddressException>()));
  });

  test('reads a restore height, and an empty field as the first block', () {
    expect(parseRestoreHeight(''), 0);
    expect(parseRestoreHeight(' 2,221,920 '), 2221920);
    expect(() => parseRestoreHeight('-5'), throwsA(isA<BlockHeightException>()));
    expect(() => parseRestoreHeight('12a'), throwsA(isA<BlockHeightException>()));
  });
}
