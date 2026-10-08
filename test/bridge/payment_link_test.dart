import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/models.dart';
import 'package:kranox_wallet/bridge/payment_link.dart';

const _deposit = '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984';

void main() {
  test('names Robinhood Chain and the amount of ETH in wei', () {
    expect(
      depositLink(asset: BridgeAsset.eth, address: _deposit, amount: '0.0055'),
      'ethereum:$_deposit@4663?value=5500000000000000',
    );
  });

  test('names the contract of USDG, the deposit address, and the amount in units of six decimals', () {
    expect(
      depositLink(asset: BridgeAsset.usdg, address: _deposit, amount: '25.5'),
      'ethereum:0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168@4663/transfer?address=$_deposit&uint256=25500000',
    );
  });

  test('leaves out an amount that the coin cannot carry, so that the wallet asks for it', () {
    expect(baseUnits('25.12345678', 6), isNull);
    expect(
      depositLink(asset: BridgeAsset.usdg, address: _deposit, amount: '25.12345678'),
      'ethereum:0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168@4663/transfer?address=$_deposit',
    );
    expect(depositLink(asset: BridgeAsset.eth, address: _deposit, amount: '1e-3'), 'ethereum:$_deposit@4663');
  });

  test('turns decimal text into whole units without a float', () {
    expect(baseUnits('0', 18), '0');
    expect(baseUnits('1', 6), '1000000');
    expect(baseUnits('0.000000000000000001', 18), '1');
    expect(baseUnits('123456789.123456789123456789', 18), '123456789123456789123456789');
    expect(baseUnits('0.0000000000000000001', 18), isNull, reason: 'nineteen decimals');
  });
}
