import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/models.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/privacy/receive_check.dart';
import 'package:kranox_wallet/wallet/models.dart';

final _now = DateTime.utc(2026, 10, 10, 12);

/// An address on Robinhood Chain from the examples of EIP-55.
const _address = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';

WalletTransfer _transfer(
  String hash, {
  required int? index,
  TransferDirection direction = TransferDirection.incoming,
  bool failed = false,
}) => WalletTransfer(
  hash: hash,
  direction: direction,
  amount: XmrAmount.parse('1'),
  fee: XmrAmount.zero,
  time: _now.subtract(const Duration(days: 2)),
  blockHeight: 90,
  confirmations: 100,
  isPending: false,
  isFailed: failed,
  subaddressIndex: index,
);

BridgeSwap _swap(
  String id, {
  required SwapDirection direction,
  required Duration age,
  String? payout,
  String? refund,
}) => BridgeSwap(
  direction: direction,
  id: id,
  asset: BridgeAsset.eth,
  amount: 0.01,
  xmrAmount: 0.03,
  depositAddress: 'deposit-$id',
  payoutAddress: payout ?? 'subaddress-$id',
  subaddressIndex: 3,
  createdAt: _now.subtract(age),
  stage: SwapStage.finished,
  refundAddress: refund,
);

void main() {
  test('counts the payments that came in to one subaddress, without failed ones and without payments out', () {
    final transfers = [
      _transfer('a1', index: 2),
      _transfer('a2', index: 2),
      _transfer('a3', index: 2, failed: true),
      _transfer('a4', index: 2, direction: TransferDirection.outgoing),
      _transfer('b1', index: 3),
      _transfer('c1', index: null),
    ];
    expect(paymentsTo(2, transfers), 2);
    expect(paymentsTo(3, transfers), 1);
    expect(paymentsTo(4, transfers), 0);
  });

  test('finds the newest payment from XMR to a refund address, in any case of its letters', () {
    final swaps = [
      _swap('older', direction: SwapDirection.pay, age: const Duration(days: 5), payout: _address),
      _swap('newer', direction: SwapDirection.pay, age: const Duration(days: 2), payout: _address.toLowerCase()),
      _swap(
        'other',
        direction: SwapDirection.pay,
        age: const Duration(hours: 1),
        payout: '0x0000000000000000000000000000000000000001',
      ),
    ];
    expect(
      lastPaidFromXmr(_address.toUpperCase().replaceFirst('0X', '0x'), swaps),
      _now.subtract(const Duration(days: 2)),
    );
  });

  test('a receive with the address as its refund address is no payment from XMR', () {
    final swaps = [_swap('in', direction: SwapDirection.receive, age: const Duration(days: 1), refund: _address)];
    expect(lastPaidFromXmr(_address, swaps), isNull);
    expect(lastPaidFromXmr(_address, const []), isNull);
  });
}
