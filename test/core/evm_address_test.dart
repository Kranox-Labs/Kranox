import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/core/evm_address.dart';

// The examples of EIP-55 (eips.ethereum.org/EIPS/eip-55), each in its correct mixed case.
const _checksummed = [
  '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
  '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
  '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB',
  '0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb',
];

Matcher _throwsProblem(EvmAddressProblem problem) =>
    throwsA(isA<EvmAddressException>().having((error) => error.problem, 'problem', problem));

void main() {
  test('writes the mixed case of EIP-55', () {
    for (final address in _checksummed) {
      expect(checksumEvmAddress(address.toLowerCase()), address);
    }
  });

  test('accepts an address in its mixed case, all in lowercase, or all in uppercase', () {
    for (final address in _checksummed) {
      expect(checkEvmAddress(address), address);
      expect(checkEvmAddress(address.toLowerCase()), address.toLowerCase());
      expect(checkEvmAddress('  $address\n'), address);
    }
    expect(checkEvmAddress('0x${_checksummed.first.substring(2).toUpperCase()}'), isNotEmpty);
  });

  test('refuses a mixed case with a letter in the wrong case', () {
    // The first letter of the first example is a capital in its checksum; in lowercase it is a typo.
    const typo = '0x5aaeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
    expect(() => checkEvmAddress(typo), _throwsProblem(EvmAddressProblem.badChecksum));
  });

  test('refuses an empty text and text of another form', () {
    expect(() => checkEvmAddress(' '), _throwsProblem(EvmAddressProblem.empty));
    for (final text in [
      '0x123',
      '5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
      '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAeZ',
    ]) {
      expect(() => checkEvmAddress(text), _throwsProblem(EvmAddressProblem.wrongForm), reason: text);
    }
  });
}
