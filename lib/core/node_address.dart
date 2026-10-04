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
