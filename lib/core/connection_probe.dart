import 'dart:async';
import 'dart:io';

import '../config/app_config.dart';
import 'node_address.dart';
import 'socks.dart';

/// What keeps the app from a host that it needs, the node of the wallet or the relay, found by a plain attempt to
/// connect: the proxy, the name of the host, or the host itself. The owner asked on 13 Oct 2026 that the app says why
/// its node is down, such as a proxy that is not running, instead of "Node offline" alone.
enum ConnectionTrouble {
  /// The proxy of the settings takes no connection: Tor is not running, or it listens at another address.
  proxyDown,

  /// The proxy answers, but it is no SOCKS5 proxy: the control port of Tor, an HTTP proxy, or a SOCKS4 proxy.
  proxyNotSocks5,

  /// The proxy runs, but it could not open a connection to the host: Tor may still be building its circuits, or the
  /// host is down.
  hostUnreachableThroughProxy,

  /// The name of the host has no address: the network is down, or the name is wrong.
  hostNameUnknown,

  /// The host takes no connection at its port.
  hostDown,

  /// The look itself failed, such as on an address that the look cannot read: the settings want a check.
  lookFailed,

  /// Tor built into the app is not on yet, starting or failed, so nothing reaches the host; no look went out.
  torNotReady,
}

/// Looks for what keeps the app from a host, with plain connections that carry nothing. A test gives another probe.
class ConnectionProbe {
  const ConnectionProbe({this.timeout = AppConfig.probeTimeout});

  /// How long each step of a look may take; more than nothing, or every look would name the first step.
  final Duration timeout;

  /// Tries to reach [host] at [port], through the SOCKS5 proxy at [proxy] when the app has one, and names the trouble
  /// of the first step that fails; null when a connection opens, so that the trouble lies above the connection.
  Future<ConnectionTrouble?> run({required String host, required int port, required String? proxy}) async {
    if (timeout <= Duration.zero) throw ArgumentError.value(timeout, 'timeout', 'must be more than nothing');
    if (proxy != null) {
      final (host: proxyHost, port: proxyPort) = splitNodeAddress(proxy);
      if (!await _opens(() => Socket.connect(proxyHost, proxyPort, timeout: timeout))) {
        return ConnectionTrouble.proxyDown;
      }
      // The proxy resolves the name, so a name that it does not know counts as a host it cannot reach.
      try {
        await checkThroughSocks(proxy: proxy, host: host, port: port, timeout: timeout);
        return null;
      } on SocksException catch (failure) {
        return failure.notSocks5 ? ConnectionTrouble.proxyNotSocks5 : ConnectionTrouble.hostUnreachableThroughProxy;
      } on SocketException {
        return ConnectionTrouble.hostUnreachableThroughProxy;
      } on TimeoutException {
        return ConnectionTrouble.hostUnreachableThroughProxy;
      }
    }
    if (InternetAddress.tryParse(host) == null) {
      try {
        await InternetAddress.lookup(host).timeout(timeout);
      } on SocketException {
        return ConnectionTrouble.hostNameUnknown;
      } on TimeoutException {
        return ConnectionTrouble.hostNameUnknown;
      }
    }
    return await _opens(() => Socket.connect(host, port, timeout: timeout)) ? null : ConnectionTrouble.hostDown;
  }

  /// Whether [connect] opens a connection, which closes at once.
  static Future<bool> _opens(Future<Socket> Function() connect) async {
    final Socket socket;
    try {
      socket = await connect();
    } on SocketException {
      return false;
    } on SocksException {
      return false;
    } on TimeoutException {
      return false;
    }
    socket.destroy();
    return true;
  }
}
