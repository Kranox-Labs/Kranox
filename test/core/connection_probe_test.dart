import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/core/connection_probe.dart';

/// A SOCKS5 proxy of the test: it takes the greeting without a user name and answers each CONNECT with [reply], 0 for
/// a connection that opened, as RFC 1928 gives the replies. With [greeting], it answers the greeting with these bytes
/// instead, as a proxy that is no SOCKS5 proxy would; with [silent], it answers nothing at all.
final class _FakeProxy {
  _FakeProxy(this.server, this.reply, {this.greeting, this.silent = false}) {
    server.listen((socket) async {
      final bytes = <int>[];
      await for (final chunk in socket) {
        bytes.addAll(chunk);
        if (silent) continue;
        if (bytes.length >= 2 && !greeted) {
          greeted = true;
          socket.add(greeting ?? const [5, 0]);
          if (greeting != null) {
            await socket.flush();
            socket.destroy();
            break;
          }
        }
        // The command CONNECT: version, command, reserved, address type, address, port.
        if (greeted && bytes.length >= 2 + 4 + 1 + 2) {
          connects++;
          socket.add([5, reply, 0, 1, 0, 0, 0, 0, 0, 0]);
          await socket.flush();
          socket.destroy();
          break;
        }
      }
    });
  }

  final ServerSocket server;
  final int reply;
  final List<int>? greeting;
  final bool silent;
  bool greeted = false;
  int connects = 0;

  String get address => '127.0.0.1:${server.port}';
}

/// A port of this Mac that nothing listens at: a server took it and closed.
Future<int> freePort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}

void main() {
  const probe = ConnectionProbe(timeout: Duration(seconds: 3));

  test('names a proxy that takes no connection', () async {
    final port = await freePort();
    expect(await probe.run(host: '127.0.0.1', port: 18081, proxy: '127.0.0.1:$port'), ConnectionTrouble.proxyDown);
  });

  test('names a host that the proxy could not reach', () async {
    final proxy = _FakeProxy(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0), 4);
    addTearDown(proxy.server.close);
    // The name never resolves (RFC 2606), which shows that the probe hands it to the proxy and not to the resolver.
    expect(
      await probe.run(host: 'node.invalid', port: 18081, proxy: proxy.address),
      ConnectionTrouble.hostUnreachableThroughProxy,
    );
    expect(proxy.connects, 1);
  });

  test('finds no trouble when the proxy opens the connection', () async {
    final proxy = _FakeProxy(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0), 0);
    addTearDown(proxy.server.close);
    expect(await probe.run(host: 'node.invalid', port: 18081, proxy: proxy.address), isNull);
  });

  test('names a proxy that is no SOCKS5 proxy, such as an HTTP proxy', () async {
    final proxy = _FakeProxy(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      0,
      greeting: 'HTTP/1.1 400 Bad Request\r\n'.codeUnits,
    );
    addTearDown(proxy.server.close);
    expect(await probe.run(host: 'node.invalid', port: 18081, proxy: proxy.address), ConnectionTrouble.proxyNotSocks5);
  });

  test('gives up on a proxy that takes the connection and answers nothing', () async {
    final proxy = _FakeProxy(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0), 0, silent: true);
    addTearDown(proxy.server.close);
    const quick = ConnectionProbe(timeout: Duration(milliseconds: 500));
    expect(
      await quick.run(host: 'node.invalid', port: 18081, proxy: proxy.address),
      ConnectionTrouble.hostUnreachableThroughProxy,
    );
  });

  test('refuses a timeout of nothing', () async {
    const none = ConnectionProbe(timeout: Duration.zero);
    await expectLater(none.run(host: '127.0.0.1', port: 18081, proxy: null), throwsArgumentError);
  });

  test('names a host that takes no connection, without a proxy', () async {
    final port = await freePort();
    expect(await probe.run(host: '127.0.0.1', port: port, proxy: null), ConnectionTrouble.hostDown);
  });

  test('finds no trouble when the host takes the connection, without a proxy', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((socket) => socket.destroy());
    expect(await probe.run(host: '127.0.0.1', port: server.port, proxy: null), isNull);
  });

  test('names a host whose name has no address', () async {
    // The domain .invalid never resolves, as RFC 2606 reserves it.
    expect(await probe.run(host: 'node.invalid', port: 18081, proxy: null), ConnectionTrouble.hostNameUnknown);
  });
}
