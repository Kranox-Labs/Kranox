import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/chain_scan.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/privacy/chain_scans.dart';

// Addresses on Robinhood Chain from the examples of EIP-55: the one that the app asks for, and another.
const _asked = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
const _other = '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359';

/// A relay that answers the scan of [answered], whatever address the app asked for.
final class _Relay implements ChainScanClient {
  _Relay(this.answered);

  final String answered;

  @override
  Future<ChainScan> scanAddress(String address) async => ChainScan(
    address: answered,
    isContract: false,
    balanceWei: BigInt.zero,
    transactionCount: 0,
    tokenTransferCount: 0,
    firstTransaction: null,
    firstTokenTransfer: null,
    transactions: const [],
    tokenTransfers: const [],
    holdings: const [],
  );
}

void main() {
  test('takes the scan of the address that the app asked for, in any case of its letters', () async {
    expect((await readScan(_Relay(_asked.toLowerCase()), _asked)).address, _asked.toLowerCase());
  });

  test('a scan is unsure of its first funding unless it says so, as the reader of the JSON reads it', () async {
    expect((await _Relay(_asked).scanAddress(_asked)).fundingSure, isFalse);
  });

  test('refuses the scan of another address, as a failure of the bridge', () async {
    await expectLater(
      readScan(_Relay(_other), _asked),
      throwsA(isA<BridgeException>().having((error) => error.detail, 'detail', contains('another address'))),
    );
  });
}
