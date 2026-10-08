import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/models.dart';
import 'package:kranox_wallet/config/app_config.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/privacy/wallet_privacy.dart';
import 'package:kranox_wallet/wallet/models.dart';

final DateTime _now = DateTime.utc(2026, 10, 7, 12);
const _publicNode = 'xmr-node.cakewallet.com:18081';

/// A recipient on Robinhood Chain, from the examples of EIP-55.
const _address = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';

WalletTransfer _transfer(
  String hash, {
  String xmr = '1',
  Duration age = const Duration(days: 5),
  int? index = 1,
  TransferDirection direction = TransferDirection.incoming,
  bool failed = false,
}) => WalletTransfer(
  hash: hash,
  direction: direction,
  amount: XmrAmount.parse(xmr),
  fee: XmrAmount.zero,
  time: _now.subtract(age),
  blockHeight: 100,
  confirmations: 20,
  isPending: false,
  isFailed: failed,
  subaddressIndex: index,
);

BridgeSwap _swap(
  String id, {
  required SwapDirection direction,
  required double amount,
  required Duration age,
  BridgeAsset asset = BridgeAsset.usdg,
  Duration? updatedAfter,
  String? depositHash = 'deposit',
  String payoutAddress = 'subaddress-9',
  String? refundAddress,
}) {
  final createdAt = _now.subtract(age);
  return BridgeSwap(
    direction: direction,
    id: id,
    asset: asset,
    amount: amount,
    xmrAmount: null,
    depositAddress: 'deposit-of-$id',
    payoutAddress: payoutAddress,
    subaddressIndex: 9,
    createdAt: createdAt,
    stage: SwapStage.finished,
    depositHash: depositHash,
    refundAddress: refundAddress,
    updatedAt: updatedAfter == null ? null : createdAt.add(updatedAfter),
  );
}

WalletPrivacyReport _check({
  String node = _publicNode,
  String? proxy,
  List<WalletTransfer> transfers = const [],
  List<BridgeSwap> swaps = const [],
  String balance = '10',
}) => checkWallet(
  node: node,
  proxy: proxy,
  transfers: transfers,
  swaps: swaps,
  // The parser refuses an amount of 0, which a balance can be.
  balance: balance == '0' ? XmrAmount.zero : XmrAmount.parse(balance),
  now: _now,
);

void main() {
  test('knows a node of its own network from a public node', () {
    const own = [
      'localhost:18081',
      '127.0.0.1:18081',
      '10.0.0.2:18089',
      '172.16.4.1:18081',
      '172.31.255.1:18081',
      '192.168.1.5:18089',
      '169.254.10.1:18081',
      '[::1]:18081',
      '[fd00::5]:18081',
      '[fe80::1]:18081',
      'monero.local:18081',
    ];
    const outside = [
      _publicNode,
      '8.8.8.8:18081',
      '172.32.0.1:18081',
      '192.169.1.1:18081',
      '[2001:db8::1]:18081',
      'fdroid.example.org:18081',
    ];
    for (final node in own) {
      expect(isOwnNode(node), isTrue, reason: node);
    }
    for (final node in outside) {
      expect(isOwnNode(node), isFalse, reason: node);
    }
  });

  test('a public node reached through a proxy such as Tor sees no IP address, so it is nothing to improve (K-11)', () {
    final straight = _check();
    final throughTor = _check(proxy: '127.0.0.1:9050');
    expect(straight.nodeSeesYou, isTrue);
    expect(throughTor.nodeSeesYou, isFalse);
    expect(throughTor.toImprove, straight.toImprove - 1);
  });

  test('a public node is something to improve, and a node of its own network is not', () {
    expect(_check().toImprove, 1);
    expect(_check(node: '192.168.1.5:18089').toImprove, 0);
  });

  test('lists the subaddresses that took more than one payment, the most first', () {
    final report = _check(
      node: '127.0.0.1:18081',
      transfers: [
        _transfer('a1', index: 2),
        _transfer('a2', index: 2),
        _transfer('b1', index: 1),
        _transfer('b2', index: 1),
        _transfer('b3', index: 1),
        _transfer('c1', index: 3),
        _transfer('c2', index: 3, failed: true),
        _transfer('c3', index: 3, direction: TransferDirection.outgoing),
        _transfer('d1', index: null),
        _transfer('d2', index: null),
      ],
    );
    expect([for (final reused in report.reused) (reused.index, reused.payments)], [(1, 3), (2, 2)]);
    expect(report.toImprove, 1);
  });

  test('pairs a receive and a later payment that sit close in time or amount', () {
    final receive = _swap(
      'receive',
      direction: SwapDirection.receive,
      amount: 100,
      age: const Duration(hours: 40),
      updatedAfter: const Duration(hours: 1),
    );
    final both = _swap('both', direction: SwapDirection.pay, amount: 97, age: const Duration(hours: 35));
    final timeOnly = _swap('time', direction: SwapDirection.pay, amount: 60, age: const Duration(hours: 30));
    final amountOnly = _swap('amount', direction: SwapDirection.pay, amount: 103, age: const Duration(hours: 2));
    final apart = _swap(
      'apart',
      direction: SwapDirection.pay,
      amount: 0.05,
      asset: BridgeAsset.eth,
      age: const Duration(hours: 1),
    );
    final report = _check(swaps: [receive, both, timeOnly, amountOnly, apart]);
    final pairs = {for (final pair in report.pairs) pair.pay.id: (pair.closeInTime, pair.closeInAmount)};
    expect(pairs, {'both': (true, true), 'time': (true, false), 'amount': (false, true)});
    expect(report.pairs.first.pay.id, 'amount', reason: 'the newest payment first');
  });

  test('leaves out a receive that the user never paid into and a payment whose XMR never left', () {
    final report = _check(
      swaps: [
        _swap(
          'receive',
          direction: SwapDirection.receive,
          amount: 100,
          age: const Duration(hours: 40),
          depositHash: null,
        ),
        _swap('pay', direction: SwapDirection.pay, amount: 100, age: const Duration(hours: 35)),
        _swap('kept', direction: SwapDirection.receive, amount: 100, age: const Duration(hours: 40)),
        _swap('unsent', direction: SwapDirection.pay, amount: 100, age: const Duration(hours: 35), depositHash: null),
      ],
    );
    expect([for (final pair in report.pairs) (pair.receive.id, pair.pay.id)], [('kept', 'pay')]);
  });

  test('links a refund address that the user later paid from XMR, in any case of its letters', () {
    final report = _check(
      swaps: [
        _swap(
          'receive',
          direction: SwapDirection.receive,
          amount: 10,
          age: const Duration(days: 9),
          refundAddress: _address.toLowerCase(),
        ),
        _swap('pay', direction: SwapDirection.pay, amount: 500, age: const Duration(days: 4), payoutAddress: _address),
        _swap(
          'other',
          direction: SwapDirection.pay,
          amount: 500,
          age: const Duration(days: 4),
          payoutAddress: '0x0000000000000000000000000000000000000001',
        ),
      ],
    );
    expect(report.links, hasLength(1));
    expect(report.links.single.address, _address);
    expect(report.links.single.receivedAt, _now.subtract(const Duration(days: 9)));
    expect(report.links.single.paidAt, _now.subtract(const Duration(days: 4)));
  });

  test('notes new XMR in the balance, and when all of it is older', () {
    final newest = _transfer('new', xmr: '1', age: const Duration(hours: 2));
    final transfers = [newest, _transfer('older', xmr: '0.5', age: const Duration(hours: 30), index: 2)];
    final report = _check(transfers: transfers, balance: '3');
    expect(report.newCoins!.amount, XmrAmount.parse('1'));
    expect(report.newCoins!.allOlderAt, newest.time.add(AppConfig.privacyFreshWindow));
    expect(report.toImprove, 1, reason: 'new XMR is a note, and only the public node counts');
    expect(_check(transfers: transfers, balance: '0.4').newCoins!.amount, XmrAmount.parse('0.4'));
    expect(_check(transfers: transfers, balance: '0').newCoins, isNull);
  });
}
