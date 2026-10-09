import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/node_address.dart';

/// A failure of a SOCKS proxy: it refused the connection, or it answered in a form that is not SOCKS5.
final class SocksException implements Exception {
  const SocksException(this.message);

  final String message;

  @override
  String toString() => 'SocksException: $message';
}

/// Opens a TLS connection to [host] at [port] through the SOCKS5 proxy at [proxy], such as Tor at 127.0.0.1:9050
/// (O-001 of the second security review). The proxy gets the name of the host and resolves it, so the name never
/// reaches the resolver of this Mac. The proxy must take a connection without a user name. A cancel of the task closes
/// the connection at any step before TLS.
Future<ConnectionTask<SecureSocket>> connectTlsThroughSocks({
  required String proxy,
  required String host,
  required int port,
}) async {
  final target = _targetAddress(host);
  final (host: proxyHost, port: proxyPort) = splitNodeAddress(proxy);
  final connecting = await Socket.startConnect(proxyHost, proxyPort);
  Socket? socket;
  var cancelled = false;

  Future<SecureSocket> open() async {
    final opened = socket = await connecting.socket;
    try {
      final replies = _Replies(opened);
      await _handshake(opened, replies, target: target, port: port);
      replies.handOver();
    } on Object {
      opened.destroy();
      rethrow;
    }
    final secure = await SecureSocket.secure(opened, host: host);
    if (cancelled) {
      secure.destroy();
      throw SocksException('The connection to $host through the proxy was cancelled.');
    }
    return secure;
  }

  return ConnectionTask.fromSocket(open(), () {
    cancelled = true;
    connecting.cancel();
    socket?.destroy();
  });
}

/// Asks the proxy for a connection to [target] at [port]: the greeting without a user name, then the command
/// CONNECT, as RFC 1928 gives them.
Future<void> _handshake(Socket socket, _Replies replies, {required List<int> target, required int port}) async {
  socket.add(const [_version, 1, _noAuthentication]);
  final choice = await replies.take(2);
  if (choice[0] != _version || choice[1] != _noAuthentication) {
    throw const SocksException('The proxy is no SOCKS5 proxy that takes a connection without a user name.');
  }
  socket.add([_version, _connect, 0, ...target, port >> 8, port & 0xff]);
  final head = await replies.take(4);
  if (head[0] != _version) {
    throw const SocksException('The proxy answered in a form that is not SOCKS5.');
  }
  if (head[1] != _succeeded) {
    throw SocksException('The proxy could not open the connection: SOCKS5 reply ${head[1]}.');
  }
  // The rest of the reply holds the address that the proxy bound for the connection, which the app does not need.
  final boundLength = switch (head[3]) {
    _ipv4 => 4,
    _ipv6 => 16,
    _domainName => (await replies.take(1)).single,
    _ => throw const SocksException('The proxy answered an address of an unknown type.'),
  };
  await replies.take(boundLength + 2);
}

/// The address of [host] in the command CONNECT: an IP address as its bytes, a name as text for the proxy to resolve.
List<int> _targetAddress(String host) {
  final ip = InternetAddress.tryParse(host);
  if (ip != null) {
    return [ip.type == InternetAddressType.IPv4 ? _ipv4 : _ipv6, ...ip.rawAddress];
  }
  final name = ascii.encode(host);
  if (name.isEmpty || name.length > _maxNameLength) {
    throw ArgumentError.value(host, 'host', 'is no host name for SOCKS5');
  }
  return [_domainName, name.length, ...name];
}

/// The bytes that the proxy sends during the handshake, read in pieces of a known length.
final class _Replies {
  _Replies(Socket socket) {
    _subscription = socket.listen(
      (bytes) {
        _buffer.addAll(bytes);
        _serve();
      },
      onError: (Object error) {
        _error = error;
        _serve();
      },
      onDone: () {
        _error ??= const SocksException('The proxy closed the connection.');
        _serve();
      },
      cancelOnError: true,
    );
  }

  late final StreamSubscription<Uint8List> _subscription;
  final List<int> _buffer = [];
  Object? _error;
  int _length = 0;
  Completer<List<int>>? _waiting;

  /// The next [length] bytes of the proxy.
  Future<List<int>> take(int length) {
    _length = length;
    final waiting = _waiting = Completer<List<int>>();
    _serve();
    return waiting.future;
  }

  void _serve() {
    final waiting = _waiting;
    if (waiting == null) return;
    if (_buffer.length >= _length) {
      _waiting = null;
      final bytes = _buffer.sublist(0, _length);
      _buffer.removeRange(0, _length);
      waiting.complete(bytes);
    } else if (_error case final error?) {
      _waiting = null;
      waiting.completeError(error);
    }
  }

  /// Stops reading after the handshake, so that TLS reads every later byte of the connection. The proxy sends nothing
  /// after its reply until the app speaks again.
  void handOver() {
    if (_buffer.isNotEmpty) {
      throw const SocksException('The proxy sent more than its reply.');
    }
    _subscription.pause();
  }
}

/// The bytes of SOCKS5 (RFC 1928) that the app uses.
const int _version = 5;
const int _noAuthentication = 0;
const int _connect = 1;
const int _succeeded = 0;
const int _ipv4 = 1;
const int _domainName = 3;
const int _ipv6 = 4;
const int _maxNameLength = 255;
