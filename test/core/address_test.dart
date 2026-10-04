import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/core/address.dart';

// Addresses of throwaway wallets that monero_c v0.18.4.6-RC2 made on 4 Oct 2026. The files of those wallets
// were deleted at once; nothing was ever sent to them.
const _stagenetStandard =
    '54gC41sfYPoXMRg6ytR2hRTtwK2TES1cbZ1KPxxXKAv2drLzkQbakX4ifsEGq2SZo5WeXHRM7hLRA1YC3F6Eyu6aLwnPUng';
const _stagenetSubaddress =
    '7BNzVRGC5iaT1cRSPv2JgjR2UcC258tLdDQJYPeQxfoJTWSJiPdnGneegDAJN3Mynv7AB26mNLwfDbXru3zLXUDY5Q3VH5h';
const _stagenetIntegrated =
    '5JVjAkVd5imCmXpFpW2x22XkddwXdXDgd4iZ9GuuSEsJHgAmeMLgaCrQwXfXJYrJ4dganWivnqabzQaTNW1cRvfRHjAmSJc3BJkTyZhL2z';
const _mainnetStandard =
    '48PFnHrr8bVGx463yo8SMXGZUp7PyYPgwZJR4MnpgjKCDXpw3XvK6UTbarKkpwaPbPSYSdJ4rozjZjGxr2t3qVP4B4DzzVs';
const _mainnetSubaddress =
    '883z7Wmbd5nhoH6xQxLzgniNhN6jqdvxFiza4rMdErWA1XW1TCL1tqrCwWFwhG1QkuL17RRHP45J33y6u4sH8Rfa7kryRza';

Matcher _throwsProblem(AddressProblem problem) =>
    throwsA(isA<AddressException>().having((error) => error.problem, 'problem', problem));

void main() {
  test('accepts each kind of stagenet address', () {
    expect(checkAddress(_stagenetStandard, MoneroNetwork.stagenet), AddressKind.standard);
    expect(checkAddress(_stagenetSubaddress, MoneroNetwork.stagenet), AddressKind.subaddress);
    expect(checkAddress(_stagenetIntegrated, MoneroNetwork.stagenet), AddressKind.integrated);
    expect(checkAddress('  $_stagenetStandard\n', MoneroNetwork.stagenet), AddressKind.standard);
  });

  test('accepts mainnet addresses on mainnet', () {
    expect(checkAddress(_mainnetStandard, MoneroNetwork.mainnet), AddressKind.standard);
    expect(checkAddress(_mainnetSubaddress, MoneroNetwork.mainnet), AddressKind.subaddress);
  });

  test('names the network of an address of another network', () {
    expect(
      () => checkAddress(_mainnetStandard, MoneroNetwork.stagenet),
      throwsA(
        isA<AddressException>()
            .having((error) => error.problem, 'problem', AddressProblem.otherNetwork)
            .having((error) => error.network, 'network', MoneroNetwork.mainnet),
      ),
    );
    expect(
      () => checkAddress(_stagenetSubaddress, MoneroNetwork.mainnet),
      throwsA(isA<AddressException>().having((error) => error.network, 'network', MoneroNetwork.stagenet)),
    );
  });

  test('rejects a changed character through the checksum', () {
    final changed = _stagenetStandard.replaceRange(40, 41, _stagenetStandard[40] == 'a' ? 'b' : 'a');
    expect(() => checkAddress(changed, MoneroNetwork.stagenet), _throwsProblem(AddressProblem.badChecksum));
  });

  test('rejects text of the wrong length or outside base58', () {
    expect(() => checkAddress('', MoneroNetwork.stagenet), _throwsProblem(AddressProblem.empty));
    expect(
      () => checkAddress(_stagenetStandard.substring(1), MoneroNetwork.stagenet),
      _throwsProblem(AddressProblem.wrongLength),
    );
    final withZero = _stagenetStandard.replaceRange(10, 11, '0');
    expect(() => checkAddress(withZero, MoneroNetwork.stagenet), _throwsProblem(AddressProblem.notBase58));
  });
}
