import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/keccak.dart';

/// What is wrong with an address on Robinhood Chain, an EVM chain.
enum EvmAddressProblem { empty, wrongForm, badChecksum }

final class EvmAddressException implements Exception {
  const EvmAddressException(this.problem);

  final EvmAddressProblem problem;

  @override
  String toString() => 'EvmAddressException: ${problem.name}';
}

/// An address on an EVM chain: 0x and 40 hex digits.
final RegExp _evmAddress = RegExp(r'^0x[0-9a-fA-F]{40}$');

/// The size of the Keccak hash that EIP-55 reads, in bits.
const int _keccakBits = 256;

/// The value from which a nibble of the hash makes its letter a capital, in EIP-55.
const int _capitalNibble = 8;

/// Checks an address on Robinhood Chain and gives it back without the spaces around it. Throws an
/// [EvmAddressException] that says what is wrong.
///
/// An address in mixed case carries the checksum of EIP-55, so a typo in it shows. An address all in lowercase or all
/// in uppercase carries no checksum, so only its form can be checked.
String checkEvmAddress(String text) {
  final address = text.trim();
  if (address.isEmpty) throw const EvmAddressException(EvmAddressProblem.empty);
  if (!_evmAddress.hasMatch(address)) throw const EvmAddressException(EvmAddressProblem.wrongForm);
  final hex = address.substring(2);
  final mixedCase = hex != hex.toLowerCase() && hex != hex.toUpperCase();
  if (mixedCase && checksumEvmAddress(address) != address) {
    throw const EvmAddressException(EvmAddressProblem.badChecksum);
  }
  return address;
}

/// The address in the mixed case of EIP-55: a letter is a capital when the nibble at its place in the Keccak-256
/// hash of the lowercase hex is 8 or more.
String checksumEvmAddress(String address) {
  final hex = address.substring(2).toLowerCase();
  final hash = KeccakDigest(_keccakBits).process(Uint8List.fromList(ascii.encode(hex)));
  final out = StringBuffer('0x');
  for (var index = 0; index < hex.length; index++) {
    final byte = hash[index ~/ 2];
    final nibble = index.isEven ? byte >> 4 : byte & 0x0f;
    out.write(nibble >= _capitalNibble ? hex[index].toUpperCase() : hex[index]);
  }
  return out.toString();
}
