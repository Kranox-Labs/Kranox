import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'node_address.dart';

/// A failure of a SOCKS proxy: it refused the connection, or, with [notSocks5], it answered in a form that is not
/// SOCKS5, as the control port of Tor or an HTTP proxy would.
final class SocksException implements Exception {
  const SocksException(this.message, {this.notSocks5 = false});

  final String message;
  final bool notSocks5;

  @override
  String toString() => 'SocksException: $message';
}

/// The user name and the password that the app offers a SOCKS5 proxy (RFC 1929): one random secret for the life of
/// the process. Tor and arti read them as a key of isolation, so the streams of the app share no circuit with those
/// of another process on this Mac that uses the same proxy without them (W-09 of the scan of 13 Oct 2026). A proxy
/// that takes a connection without a user name gets none, as before.
final List<int> _isolationSecret = List<int>.generate(16, (_) => Random.secure().nextInt(256));

/// Opens a TLS connection to [host] at [port] through the SOCKS5 proxy at [proxy], such as Tor at 127.0.0.1:9050
/// (O-001 of the second security review). The proxy gets the name of the host and resolves it, so the name never
/// reaches the resolver of this Mac. The proxy must take a connection without a user name or with the user name and
/// the password of the app. A cancel of the task closes the connection at any step before TLS.
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

/// Checks that the SOCKS5 proxy at [proxy] opens a connection to [host] at [port], for a look at the way to a host,
/// and closes the connection at once: it carries nothing. A step that takes longer than [timeout] fails with a
/// [TimeoutException], and a proxy that refuses the way, or that is no SOCKS5 proxy, throws a [SocksException].
Future<void> checkThroughSocks({
  required String proxy,
  required String host,
  required int port,
  required Duration timeout,
}) async {
  final target = _targetAddress(host);
  final (host: proxyHost, port: proxyPort) = splitNodeAddress(proxy);
  final socket = await Socket.connect(proxyHost, proxyPort, timeout: timeout);
  try {
    await _handshake(socket, _Replies(socket), target: target, port: port).timeout(timeout);
  } finally {
    socket.destroy();
  }
}

/// Checks that the SOCKS5 proxy at [proxy] answers the greeting of the app, and closes the connection at once: it
/// opens no connection to anything. A step that takes longer than [timeout] fails with a [TimeoutException], and a
/// proxy that answers in another form throws a [SocksException].
Future<void> probeSocks5({required String proxy, required Duration timeout}) async {
  final (host: proxyHost, port: proxyPort) = splitNodeAddress(proxy);
  final socket = await Socket.connect(proxyHost, proxyPort, timeout: timeout);
  try {
    await _greet(socket, _Replies(socket)).timeout(timeout);
  } finally {
    socket.destroy();
  }
}

/// Resolves the name [host] through the SOCKS5 proxy at [proxy] with RESOLVE, the command of Tor (its extensions of
/// SOCKS, which arti answers too), so that the name never reaches the resolver of this Mac. A proxy without the
/// command, or one that does not know the name, throws a [SocksException].
Future<InternetAddress> resolveThroughSocks({
  required String proxy,
  required String host,
  required Duration timeout,
}) async {
  final target = _targetAddress(host);
  final (host: proxyHost, port: proxyPort) = splitNodeAddress(proxy);
  final socket = await Socket.connect(proxyHost, proxyPort, timeout: timeout);
  try {
    return await _resolve(socket, _Replies(socket), target: target).timeout(timeout);
  } finally {
    socket.destroy();
  }
}

/// Asks the proxy for a connection to [target] at [port]: the greeting, then the command CONNECT, as RFC 1928 gives
/// them.
Future<void> _handshake(Socket socket, _Replies replies, {required List<int> target, required int port}) async {
  await _greet(socket, replies);
  socket.add([_version, _connect, 0, ...target, port >> 8, port & 0xff]);
  final head = await _reply(replies);
  if (head[1] != _succeeded) {
    throw SocksException('The proxy could not open the connection: SOCKS5 reply ${head[1]}.');
  }
  // The rest of the reply holds the address that the proxy bound for the connection, which the app does not need.
  await _boundAddress(replies, head[3]);
}

/// The greeting: the app offers a connection without a user name and one with its user name and password; the proxy
/// picks. A proxy that picks the second gets the secret of the app (RFC 1929), which Tor and arti read as a key of
/// isolation.
Future<void> _greet(Socket socket, _Replies replies) async {
  socket.add(const [_version, 2, _noAuthentication, _usernamePassword]);
  final choice = await replies.take(2);
  if (choice[0] != _version || (choice[1] != _noAuthentication && choice[1] != _usernamePassword)) {
    throw const SocksException(
      'The proxy is no SOCKS5 proxy that takes a connection without a user name.',
      notSocks5: true,
    );
  }
  if (choice[1] == _usernamePassword) {
    final secret = [for (final byte in _isolationSecret) ...byte.toRadixString(16).padLeft(2, '0').codeUnits];
    socket.add([_authVersion, secret.length, ...secret, secret.length, ...secret]);
    final answer = await replies.take(2);
    if (answer[0] != _authVersion || answer[1] != _succeeded) {
      throw const SocksException('The proxy refused the user name and the password of the app.');
    }
  }
}

/// The command RESOLVE for [target], a name: the address that the proxy found for it.
Future<InternetAddress> _resolve(Socket socket, _Replies replies, {required List<int> target}) async {
  await _greet(socket, replies);
  socket.add([_version, _resolveCommand, 0, ...target, 0, 0]);
  final head = await _reply(replies);
  if (head[1] != _succeeded) {
    throw SocksException('The proxy could not resolve the name: SOCKS5 reply ${head[1]}.');
  }
  final bound = await _boundAddress(replies, head[3]);
  if (head[3] != _ipv4 && head[3] != _ipv6) {
    throw const SocksException('The proxy answered the name with something other than an address.');
  }
  return InternetAddress.fromRawAddress(Uint8List.fromList(bound));
}

/// The head of a reply, four bytes: the version, the status, a reserved byte, and the type of the bound address.
Future<List<int>> _reply(_Replies replies) async {
  final head = await replies.take(4);
  if (head[0] != _version) {
    throw const SocksException('The proxy answered in a form that is not SOCKS5.', notSocks5: true);
  }
  return head;
}

/// The bound address of a reply of type [type], without its port: four bytes, sixteen, or a name.
Future<List<int>> _boundAddress(_Replies replies, int type) async {
  final length = switch (type) {
    _ipv4 => 4,
    _ipv6 => 16,
    _domainName => (await replies.take(1)).single,
    _ => throw const SocksException('The proxy answered an address of an unknown type.'),
  };
  final bytes = await replies.take(length + 2);
  return bytes.sublist(0, length);
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

/// The bytes of SOCKS5 (RFC 1928) that the app uses, with the user name and password of RFC 1929 and RESOLVE, the
/// command of the extensions of Tor (socks-extensions.txt of the Tor Project).
const int _version = 5;
const int _noAuthentication = 0;
const int _usernamePassword = 2;
const int _authVersion = 1;
const int _connect = 1;
const int _resolveCommand = 0xf0;
const int _succeeded = 0;
const int _ipv4 = 1;
const int _domainName = 3;
const int _ipv6 = 4;
const int _maxNameLength = 255;
