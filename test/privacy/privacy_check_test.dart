import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/models.dart';
import 'package:kranox_wallet/config/app_config.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/bridge/chain_scan.dart';
import 'package:kranox_wallet/privacy/chain_privacy.dart';
import 'package:kranox_wallet/privacy/privacy_check.dart';
import 'package:kranox_wallet/wallet/models.dart';

final DateTime _now = DateTime.utc(2026, 10, 7, 12);
final XmrAmount _fee = XmrAmount.parse('0.00003');

/// A recipient on Robinhood Chain, from the examples of EIP-55.
const _recipient = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';

WalletTransfer _incoming(String hash, String xmr, Duration age, {bool failed = false}) => WalletTransfer(
  hash: hash,
  direction: TransferDirection.incoming,
  amount: XmrAmount.parse(xmr),
  fee: XmrAmount.zero,
  time: _now.subtract(age),
  blockHeight: 100,
  confirmations: 20,
  isPending: false,
  isFailed: failed,
  subaddressIndex: 1,
);

WalletTransfer _outgoing(String hash, String xmr, Duration age) => WalletTransfer(
  hash: hash,
  direction: TransferDirection.outgoing,
  amount: XmrAmount.parse(xmr),
  fee: XmrAmount.zero,
  time: _now.subtract(age),
  blockHeight: 100,
  confirmations: 20,
  isPending: false,
  isFailed: false,
  subaddressIndex: 0,
);

/// A receive from Robinhood Chain: [sent] of [asset] in, and the XMR out as the transfer [payoutHash].
BridgeSwap _receive({
  required double sent,
  required Duration age,
  BridgeAsset asset = BridgeAsset.usdg,
  String? depositHash = '0xdeposit',
  String? payoutHash,
  String? refundAddress,
}) => BridgeSwap(
  id: 'receive-${age.inMinutes}',
  asset: asset,
  amount: sent,
  xmrAmount: null,
  depositAddress: '0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984',
  payoutAddress: 'subaddress-7',
  subaddressIndex: 7,
  createdAt: _now.subtract(age),
  stage: SwapStage.finished,
  depositHash: depositHash,
  payoutHash: payoutHash,
  refundAddress: refundAddress,
);

/// An earlier payment from XMR to [recipient].
BridgeSwap _paid(String recipient, Duration age) => BridgeSwap(
  direction: SwapDirection.pay,
  id: 'pay-${age.inMinutes}',
  asset: BridgeAsset.usdg,
  amount: 20,
  xmrAmount: 0.05,
  depositAddress: 'xmr-deposit',
  payoutAddress: recipient,
  subaddressIndex: 8,
  createdAt: _now.subtract(age),
  stage: SwapStage.finished,
);

PrivacyReport _check(
  String amount, {
  List<WalletTransfer> transfers = const [],
  List<BridgeSwap> swaps = const [],
  String balance = '10',
  String? spendable,
  ChainPayment? chain,
  Iterable<String> ownAddresses = const [],
  int seed = 7,
}) => checkPrivacy(
  amount: XmrAmount.parse(amount),
  fee: _fee,
  transfers: transfers,
  swaps: swaps,
  balance: XmrAmount.parse(balance),
  spendable: XmrAmount.parse(spendable ?? balance),
  now: _now,
  chain: chain,
  ownAddresses: ownAddresses,
  random: Random(seed),
);

ChainPayment _pay(double paid, {double? minXmr, double? maxXmr, String recipient = _recipient}) =>
    ChainPayment(asset: BridgeAsset.usdg, amount: paid, recipient: recipient, minXmr: minXmr, maxXmr: maxXmr);

/// Whether two amounts of XMR stay apart by more than the tolerance of the rule.
bool _apart(XmrAmount a, XmrAmount b) =>
    (a.units - b.units).abs() > AppConfig.privacyXmrTolerance * max(a.units, b.units);

void main() {
  group('the rule of the amount', () {
    test('passes an amount that matches nothing that came in', () {
      final report = _check('0.5', transfers: [_incoming('in1', '1.2', const Duration(hours: 30))]);
      expect(report.amountMatch, isNull);
      expect(report.suggestion, isNull);
    });

    test('warns about XMR close to what came in lately, and suggests an amount that matches nothing', () {
      final came = _incoming('in1', '0.5', const Duration(hours: 30));
      final report = _check('0.4996', transfers: [came]);
      final match = report.amountMatch! as XmrMatch;
      expect(match.amount, came.amount);
      expect(match.at, came.time);
      final suggestion = report.suggestion!;
      expect(_apart(suggestion, came.amount), isTrue);
      expect(suggestion.units % 100000000, 0, reason: 'a suggestion has four decimals');
      expect(suggestion.units, lessThan(XmrAmount.parse('0.4996').units), reason: 'a smaller amount fits first');
    });

    test('names the newest of two matches', () {
      final report = _check(
        '0.5',
        transfers: [
          _incoming('older', '0.5', const Duration(days: 2)),
          _incoming('newer', '0.501', const Duration(hours: 30)),
        ],
      );
      expect(report.amountMatch!.at, _now.subtract(const Duration(hours: 30)));
    });

    test('forgets what came in before its window, what failed, and what went out', () {
      final report = _check(
        '0.5',
        transfers: [
          _incoming('old', '0.5', AppConfig.privacyAmountWindow + const Duration(hours: 1)),
          _incoming('failed', '0.5', const Duration(hours: 30), failed: true),
          _outgoing('out', '0.5', const Duration(hours: 30)),
        ],
      );
      expect(report.amountMatch, isNull);
    });

    test('warns about pay when the recipient gets about what the user sent in from Robinhood Chain', () {
      final report = _check(
        '0.2',
        swaps: [_receive(sent: 100, age: const Duration(hours: 40))],
        chain: _pay(97),
      );
      final match = report.amountMatch! as ChainMatch;
      expect(match.sent, 100);
      expect(match.paid, 97);
      // The coin that the suggestion buys stays outside the tolerance on the chain too.
      final paid = 97 * report.suggestion!.units / XmrAmount.parse('0.2').units;
      expect((paid - 100).abs(), greaterThan(AppConfig.privacyChainTolerance * 100));
    });

    test('ignores a receive that the user never paid into, and a receive of another coin', () {
      final report = _check(
        '0.2',
        swaps: [
          _receive(sent: 100, age: const Duration(hours: 40), depositHash: null),
          _receive(sent: 100, age: const Duration(hours: 40), asset: BridgeAsset.eth),
        ],
        chain: _pay(98),
      );
      expect(report.amountMatch, isNull);
    });

    test('keeps a suggestion for pay inside the limits of the exchanger', () {
      final came = _incoming('in1', '0.1', const Duration(hours: 30));
      // A smaller amount would fall below the minimum, so the suggestion goes up.
      final report = _check('0.1', transfers: [came], chain: _pay(50, minXmr: 0.0999, maxXmr: 2));
      final suggestion = report.suggestion!;
      expect(suggestion.units, greaterThan(XmrAmount.parse('0.1').units));
      expect(_apart(suggestion, came.amount), isTrue);
    });

    test('gives no suggestion when no amount fits', () {
      final report = _check(
        '0.1',
        transfers: [_incoming('in1', '0.1', const Duration(hours: 30))],
        balance: '0.1001',
        chain: _pay(50, minXmr: 0.0999, maxXmr: 2),
      );
      expect(report.amountMatch, isNotNull);
      expect(report.suggestion, isNull);
    });

    test('suggests amounts that follow no fixed step', () {
      final came = _incoming('in1', '0.5', const Duration(hours: 30));
      final suggestions = {
        for (var seed = 0; seed < 6; seed++) _check('0.5', transfers: [came], seed: seed).suggestion,
      };
      expect(suggestions.length, greaterThan(1));
    });
  });

  group('the rule of the timing', () {
    test('passes when the coins from before the window cover the payment', () {
      final report = _check('2', transfers: [_incoming('new', '1', const Duration(hours: 2))], balance: '10');
      expect(report.fresh, isNull);
    });

    test('warns when the payment needs coins that came in lately, and says when it no longer does', () {
      final first = _incoming('first', '1', const Duration(hours: 6));
      final second = _incoming('second', '1', const Duration(hours: 2));
      // 1.5 XMR from before the window: the payment of 2.2 needs the first new coins, not the second.
      final report = _check('2.2', transfers: [second, first], balance: '3.5');
      final fresh = report.fresh!;
      expect(fresh.since, first.time);
      expect(fresh.clearsAt, first.time.add(AppConfig.privacyFreshWindow));
      expect(fresh.fromChain, isFalse);
    });

    test('says when the new coins came from Robinhood Chain', () {
      final came = _incoming('payout', '1', const Duration(hours: 3));
      final report = _check(
        '0.9',
        transfers: [came],
        swaps: [_receive(sent: 500, age: const Duration(hours: 4), payoutHash: 'payout')],
        balance: '1',
      );
      expect(report.fresh!.fromChain, isTrue);
    });
  });

  group('the rule of the address', () {
    test('only pay has it', () {
      final report = _check('0.5');
      expect(report.checksAddress, isFalse);
      expect(report.ownAddress, isNull);
    });

    test('warns when the recipient is the refund address of a receive, in any case of its letters', () {
      final report = _check(
        '0.5',
        swaps: [
          _receive(sent: 10, age: const Duration(days: 9), refundAddress: _recipient.toLowerCase()),
          _receive(sent: 20, age: const Duration(days: 2), refundAddress: _recipient),
        ],
        chain: _pay(250),
      );
      expect(report.checksAddress, isTrue);
      expect(report.ownAddress!.usedAt, _now.subtract(const Duration(days: 2)));
      expect(report.ownAddress!.link, isA<RefundOf>());
      expect(report.warnings, 1);
    });

    test('warns when the scan of the recipient finds a receive whose coin it sent in', () {
      final receive = _receive(sent: 10, age: const Duration(days: 3));
      final scan = ChainScan(
        address: _recipient,
        isContract: false,
        balanceWei: BigInt.zero,
        transactionCount: 1,
        tokenTransferCount: 0,
        firstTransaction: null,
        firstTokenTransfer: null,
        transactions: [
          ChainTransfer(
            hash: '0xin',
            from: const ChainParty(address: _recipient, label: null, isContract: false),
            to: ChainParty(address: receive.depositAddress, label: null, isContract: false),
            value: BigInt.one,
            token: null,
            time: receive.createdAt,
          ),
        ],
        tokenTransfers: const [],
        holdings: const [],
        fundingSure: true,
      );
      final report = _check('0.5', swaps: [receive], chain: _pay(250));
      expect(report.ownAddress, isNull, reason: 'the records alone do not know who sent the coin in');
      final scanned = analyzeChain(scan, swaps: [receive], ownAddresses: const []);
      final own = ownAddressOf(_recipient, [receive], links: scanned.kranox);
      expect(own!.link, isA<FundedReceive>());
      expect(report.withOwnAddress(own).warnings, 1);
    });

    test('warns about an earlier payment only when the user scanned the recipient as theirs', () {
      final swaps = [_paid(_recipient, const Duration(days: 3))];
      expect(
        _check('0.5', swaps: swaps, chain: _pay(250)).ownAddress,
        isNull,
        reason: 'paying someone again is fine',
      );
      final yours = _check('0.5', swaps: swaps, chain: _pay(250), ownAddresses: [_recipient.toLowerCase()]);
      expect(yours.ownAddress!.link, isA<GotPay>());
      expect(yours.ownAddress!.usedAt, _now.subtract(const Duration(days: 3)));
    });

    test('passes another recipient', () {
      final report = _check(
        '0.5',
        swaps: [
          _receive(sent: 10, age: const Duration(days: 2), refundAddress: '0x0000000000000000000000000000000000000001'),
        ],
        chain: _pay(250),
      );
      expect(report.ownAddress, isNull);
      expect(report.warnings, 0);
    });
  });
}
