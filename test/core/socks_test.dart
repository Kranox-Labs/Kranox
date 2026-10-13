import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/core/socks.dart';

/// A SOCKS5 proxy of the test: it picks [method] in the greeting, takes any user name and password, answers
/// CONNECT with success, and RESOLVE with [resolved], and keeps what it got.
final class _FakeProxy {
  _FakeProxy(this.server, {this.method = 0, this.resolved = const [203, 0, 113, 5]}) {
    server.listen((socket) async {
      final bytes = <int>[];
      var step = 0;
      await for (final chunk in socket) {
        bytes.addAll(chunk);
        if (step == 0 && bytes.length >= 2 + bytes[1]) {
          greetings.add(bytes.sublist(2, 2 + bytes[1]));
          bytes.removeRange(0, 2 + bytes[1]);
          socket.add([5, method]);
          step = method == 2 ? 1 : 2;
          if (method != 0 && method != 2) {
            await socket.flush();
            socket.destroy();
            break;
          }
        }
        if (step == 1 && bytes.length >= 2) {
          final userLength = bytes[1];
          if (bytes.length < 2 + userLength + 1) continue;
          final passwordLength = bytes[2 + userLength];
          if (bytes.length < 3 + userLength + passwordLength) continue;
          users.add(String.fromCharCodes(bytes.sublist(2, 2 + userLength)));
          passwords.add(String.fromCharCodes(bytes.sublist(3 + userLength, 3 + userLength + passwordLength)));
          bytes.removeRange(0, 3 + userLength + passwordLength);
          socket.add(const [1, 0]);
          step = 2;
        }
        if (step == 2 && bytes.length >= 4) {
          final length = switch (bytes[3]) {
            1 => 4,
            4 => 16,
            3 => bytes.length > 4 ? 1 + bytes[4] : -1,
            _ => -1,
          };
          if (length < 0 || bytes.length < 4 + length + 2) continue;
          commands.add(bytes[1]);
          names.add(bytes[3] == 3 ? String.fromCharCodes(bytes.sublist(5, 5 + bytes[4])) : '');
          socket.add([5, 0, 0, 1, ...resolved, 0, 0]);
          await socket.flush();
          socket.destroy();
          break;
        }
      }
    });
  }

  final ServerSocket server;
  final int method;
  final List<int> resolved;
  final List<List<int>> greetings = [];
  final List<String> users = [];
  final List<String> passwords = [];
  final List<int> commands = [];
  final List<String> names = [];
}

void main() {
  late ServerSocket server;
  late String proxy;

  setUp(() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    proxy = '127.0.0.1:${server.port}';
  });

  tearDown(() => server.close());

  test('offers a connection without a user name and one with the secret of the app, and takes either', () async {
    final plain = _FakeProxy(server);
    await checkThroughSocks(proxy: proxy, host: 'relay.example', port: 443, timeout: const Duration(seconds: 2));
    expect(plain.greetings.single, [0, 2], reason: 'no user name, and a user name with a password (RFC 1929)');
    expect(plain.users, isEmpty);
    expect(plain.commands, [1]);
    expect(plain.names, ['relay.example']);
    await server.close();
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    proxy = '127.0.0.1:${server.port}';
    final isolating = _FakeProxy(server, method: 2);
    await checkThroughSocks(proxy: proxy, host: 'relay.example', port: 443, timeout: const Duration(seconds: 2));
    expect(isolating.users.single, hasLength(32), reason: 'the secret of the app, sixteen random bytes as hex');
    expect(isolating.passwords.single, isolating.users.single);
    await checkThroughSocks(proxy: proxy, host: 'relay.example', port: 443, timeout: const Duration(seconds: 2));
    expect(isolating.users[1], isolating.users[0], reason: 'one secret for the life of the process (W-09)');
  });

  test('refuses a proxy that picks another method as no SOCKS5 proxy', () async {
    _FakeProxy(server, method: 0xff);
    await expectLater(
      checkThroughSocks(proxy: proxy, host: 'relay.example', port: 443, timeout: const Duration(seconds: 2)),
      throwsA(isA<SocksException>().having((error) => error.notSocks5, 'notSocks5', isTrue)),
    );
  });

  test('checks a proxy with the greeting alone, and resolves a name with RESOLVE (W-04, W-07)', () async {
    final fake = _FakeProxy(server, resolved: const [198, 51, 100, 7]);
    await probeSocks5(proxy: proxy, timeout: const Duration(seconds: 2));
    expect(fake.commands, isEmpty, reason: 'the greeting opens nothing');
    final address = await resolveThroughSocks(proxy: proxy, host: 'node.example', timeout: const Duration(seconds: 2));
    expect(address.address, '198.51.100.7');
    expect(fake.commands, [0xf0]);
    expect(fake.names, ['node.example']);
  });

  test('says when nothing listens at the proxy', () async {
    await server.close();
    await expectLater(probeSocks5(proxy: proxy, timeout: const Duration(seconds: 2)), throwsA(isA<SocketException>()));
  });
}
