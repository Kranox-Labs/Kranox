import 'dart:typed_data';

import 'package:pointycastle/digests/keccak.dart';

import '../config/network.dart';
import 'base58.dart';

/// The kinds of Monero address that a payment can go to.
enum AddressKind { standard, integrated, subaddress }

/// What is wrong with an address.
enum AddressProblem { empty, wrongLength, notBase58, badChecksum, otherNetwork, unknownPrefix }

final class AddressException implements Exception {
  const AddressException(this.problem, {this.network});

  final AddressProblem problem;

  /// The network of the address, when the address belongs to another network than the wallet.
  final MoneroNetwork? network;

  @override
  String toString() => 'AddressException: ${problem.name}';
}

/// Checks a Monero address for a network and gives its kind. Throws an [AddressException] that says what is
/// wrong.
///
/// The app checks addresses itself: `Wallet_addressValid` of monero_c checks every network other than mainnet
/// against testnet, so it rejects every stagenet address. CHECKED 4 Oct 2026 with v0.18.4.6-RC2.
AddressKind checkAddress(String text, MoneroNetwork network) {
  final address = text.trim();
  if (address.isEmpty) {
    throw const AddressException(AddressProblem.empty);
  }
  if (address.length != _AddressLayout.plainChars && address.length != _AddressLayout.integratedChars) {
    throw const AddressException(AddressProblem.wrongLength);
  }
  final Uint8List bytes;
  try {
    bytes = MoneroBase58.decode(address);
  } on FormatException {
    throw const AddressException(AddressProblem.notBase58);
  }
  final body = Uint8List.sublistView(bytes, 0, bytes.length - _AddressLayout.checksumBytes);
  final checksum = Uint8List.sublistView(bytes, bytes.length - _AddressLayout.checksumBytes);
  final hash = KeccakDigest(256).process(body);
  for (var index = 0; index < _AddressLayout.checksumBytes; index++) {
    if (hash[index] != checksum[index]) {
      throw const AddressException(AddressProblem.badChecksum);
    }
  }
  final prefix = _readVarint(body);
  final kind = _kindOf(prefix.value, network);
  if (kind == null) {
    final other = MoneroNetwork.values.where((candidate) => _kindOf(prefix.value, candidate) != null);
    throw AddressException(
      other.isEmpty ? AddressProblem.unknownPrefix : AddressProblem.otherNetwork,
      network: other.isEmpty ? null : other.first,
    );
  }
  final expectedBytes =
      prefix.length + _AddressLayout.keyBytes + (kind == AddressKind.integrated ? _AddressLayout.paymentIdBytes : 0);
  if (body.length != expectedBytes) {
    throw const AddressException(AddressProblem.wrongLength);
  }
  return kind;
}

/// The parts of an address: two public keys of 32 bytes, a payment id of 8 bytes in an integrated address, and a
/// checksum of 4 bytes, the first bytes of the Keccak-256 hash of everything before it.
abstract final class _AddressLayout {
  static const int plainChars = 95;
  static const int integratedChars = 106;
  static const int keyBytes = 64;
  static const int paymentIdBytes = 8;
  static const int checksumBytes = 4;
}

AddressKind? _kindOf(int prefix, MoneroNetwork network) {
  if (prefix == network.standardPrefix) return AddressKind.standard;
  if (prefix == network.integratedPrefix) return AddressKind.integrated;
  if (prefix == network.subaddressPrefix) return AddressKind.subaddress;
  return null;
}

/// Reads the network prefix at the start of an address: a variable-length number of 7 bits for each byte.
({int value, int length}) _readVarint(Uint8List bytes) {
  var value = 0;
  for (var index = 0; index < bytes.length; index++) {
    final byte = bytes[index];
    value |= (byte & 0x7F) << (7 * index);
    if (byte & 0x80 == 0) {
      return (value: value, length: index + 1);
    }
  }
  throw const AddressException(AddressProblem.wrongLength);
}
