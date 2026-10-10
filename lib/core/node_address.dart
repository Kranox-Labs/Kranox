import 'dart:io';

/// The highest port number of TCP.
const int _maxPort = 65535;

final class NodeAddressException implements Exception {
  const NodeAddressException();

  @override
  String toString() => 'NodeAddressException';
}

/// Checks the address of a node: a host name, an IPv4 address, or an IPv6 address in brackets, then a colon and
/// a port, such as `node.example.org:38089`. Gives the address without spaces around it.
String parseNodeAddress(String text) {
  final value = text.trim();
  final match = RegExp(r'^([A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?|\[[0-9A-Fa-f:]+\]):(\d{1,5})$').firstMatch(value);
  if (match == null) {
    throw const NodeAddressException();
  }
  final port = int.parse(match.group(2)!);
  if (port < 1 || port > _maxPort) {
    throw const NodeAddressException();
  }
  return value;
}

/// Checks the address of a SOCKS proxy, such as Tor at 127.0.0.1:9050: an IPv4 address, or an IPv6 address in
/// brackets, then a colon and a port. wallet2 reads a proxy as an IP address only and refuses a host name, so the app
/// takes none either: a host name that the relay took and the node refused left the node without the proxy, the
/// sharp-edges scan of 10 Oct 2026 found. Gives the address without spaces around it.
String parseProxyAddress(String text) {
  final value = parseNodeAddress(text);
  if (InternetAddress.tryParse(splitNodeAddress(value).host) == null) throw const NodeAddressException();
  return value;
}

/// The host and the port of an address that [parseNodeAddress] accepts, an IPv6 address without its brackets.
({String host, int port}) splitNodeAddress(String text) {
  final value = parseNodeAddress(text);
  final colon = value.lastIndexOf(':');
  final host = value.substring(0, colon);
  return (
    host: host.startsWith('[') ? host.substring(1, host.length - 1) : host,
    port: int.parse(value.substring(colon + 1)),
  );
}
