import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/chain_scan.dart';
import 'package:kranox_wallet/bridge/models.dart';
import 'package:kranox_wallet/privacy/chain_privacy.dart';

// The scanned address, from the examples of EIP-55, and the addresses around it.
const _me = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
const _exchange = '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359';
const _mine = '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB';
const _shop = '0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb';
// Looks like the shop: the same first and last four hex digits.
const _fakeShop = '0xD1229999999999999999999999999999999e9aDb';
const _deposit = '0x52908400098527886E0F7030069857D2E4169EE7';
const _usdg = '0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984';

final DateTime _t0 = DateTime.utc(2026, 10, 1, 9);

ChainParty _party(String address, {String? label}) => ChainParty(address: address, label: label, isContract: false);

ChainTransfer _transfer(
  String hash,
  String from,
  String to, {
  Duration after = Duration.zero,
  String? fromLabel,
  bool token = false,
  int value = 1000,
}) => ChainTransfer(
  hash: hash,
  from: _party(from, label: fromLabel),
  to: _party(to),
  value: BigInt.from(value),
  token: token ? const ChainToken(symbol: 'USDG', address: _usdg, decimals: 6) : null,
  time: _t0.add(after),
);

ChainScan _scan({
  ChainTransfer? first,
  ChainTransfer? firstToken,
  List<ChainTransfer> transactions = const [],
  List<ChainTransfer> tokenTransfers = const [],
  List<ChainHolding> holdings = const [],
  int transactionCount = 0,
  int tokenTransferCount = 0,
}) => ChainScan(
  address: _me,
  isContract: false,
  balanceWei: BigInt.zero,
  transactionCount: transactionCount,
  tokenTransferCount: tokenTransferCount,
  firstTransaction: first,
  firstTokenTransfer: firstToken,
  transactions: transactions,
  tokenTransfers: tokenTransfers,
  holdings: holdings,
  fundingSure: true,
);

BridgeSwap _swap(
  String id,
  SwapDirection direction, {
  String deposit = _deposit,
  String payout = 'subaddress-3',
  String? refund,
  String? payoutHash,
}) => BridgeSwap(
  direction: direction,
  id: id,
  asset: BridgeAsset.usdg,
  amount: 100,
  xmrAmount: 0.2,
  depositAddress: deposit,
  payoutAddress: payout,
  subaddressIndex: 3,
  createdAt: _t0.add(const Duration(days: 2)),
  stage: SwapStage.finished,
  refundAddress: refund,
  payoutHash: payoutHash,
);

void main() {
  group('the first funding', () {
    test('links an address funded by a sender with a public name, the oldest transfer in first', () {
      final report = analyzeChain(
        _scan(
          first: _transfer('eth', _exchange, _me, after: const Duration(hours: 5), fromLabel: 'Big Exchange'),
          firstToken: _transfer('usdg', _shop, _me, token: true),
        ),
        swaps: const [],
        ownAddresses: const [],
      );
      expect(report.funding!.transfer.hash, 'usdg', reason: 'the token came in before the ETH');
      expect(report.funding!.links, isFalse);
      final named = analyzeChain(
        _scan(first: _transfer('eth', _exchange, _me, fromLabel: 'Big Exchange')),
        swaps: const [],
        ownAddresses: const [],
      );
      expect(named.funding!.label, 'Big Exchange');
      expect(named.toImprove, 1);
    });

    test('links an address funded by another address of the user, a refund address of a receive included', () {
      final scanned = analyzeChain(
        _scan(first: _transfer('eth', _mine, _me)),
        swaps: const [],
        ownAddresses: [_mine.toLowerCase()],
      );
      expect(scanned.funding!.fromOwn, isTrue);
      final refund = analyzeChain(
        _scan(first: _transfer('eth', _mine, _me)),
        swaps: [_swap('receive', SwapDirection.receive, refund: _mine)],
        ownAddresses: const [],
      );
      expect(refund.funding!.fromOwn, isTrue);
    });

    test(
      'reads the payout of a payment of the user from XMR as a clean start, whatever name the explorer gives it',
      () {
        final report = analyzeChain(
          _scan(first: _transfer('0xPayout', _exchange, _me, fromLabel: 'ChangeNOW')),
          swaps: [_swap('paid', SwapDirection.pay, payout: _me, payoutHash: '0xpayout')],
          ownAddresses: const [],
        );
        expect(report.funding!.fromPay!.id, 'paid');
        expect(report.funding!.links, isFalse);
        expect(report.toImprove, 0, reason: 'one swap alone ties nothing else to it');
      },
    );

    test('finds no funding when the oldest transfer went out', () {
      final report = analyzeChain(
        _scan(first: _transfer('out', _me, _shop)),
        swaps: const [],
        ownAddresses: const [],
      );
      expect(report.funding, isNull);
      expect(report.toImprove, 0);
    });
  });

  test('finds direct transfers with other addresses of the user, but not with the address itself', () {
    final report = analyzeChain(
      _scan(
        transactions: [
          _transfer('a', _me, _mine, after: const Duration(days: 1)),
          _transfer('b', _mine, _me, after: const Duration(days: 3)),
          _transfer('c', _me, _shop),
        ],
      ),
      swaps: const [],
      ownAddresses: [_mine, _me],
    );
    expect(report.own, hasLength(1));
    expect(report.own.single.other, _mine);
    expect(report.own.single.at, _t0.add(const Duration(days: 3)));
  });

  test('finds a sender that looks like an address that this address paid', () {
    final report = analyzeChain(
      _scan(
        transactions: [_transfer('paid', _me, _shop)],
        tokenTransfers: [
          _transfer('dust', _fakeShop, _me, after: const Duration(minutes: 2), token: true, value: 0),
          _transfer('refund', _shop, _me, after: const Duration(days: 1), token: true),
        ],
      ),
      swaps: const [],
      ownAddresses: const [],
    );
    expect(report.lookAlikes, hasLength(1));
    expect(report.lookAlikes.single.sender, _fakeShop);
    expect(report.lookAlikes.single.resembles, _shop);
    expect(report.toImprove, 1);
  });

  test('counts an address that ties swaps together as something to improve, on one side or on both', () {
    final report = analyzeChain(
      _scan(tokenTransfers: [_transfer('in', _me, _deposit, token: true)]),
      swaps: [
        _swap('funded', SwapDirection.receive),
        _swap('refund', SwapDirection.receive, deposit: _exchange, refund: _me.toLowerCase()),
        _swap('paid', SwapDirection.pay, payout: _me.toLowerCase()),
        _swap('other', SwapDirection.pay, payout: _shop),
      ],
      ownAddresses: const [],
    );
    expect(
      {for (final link in report.kranox) link.swap.id: link.runtimeType},
      {'funded': FundedReceive, 'refund': RefundOf, 'paid': GotPay},
    );
    expect(report.tiesSwaps, isTrue);
    expect(onBothSides(report.kranox), isTrue);
    expect(report.toImprove, 1);

    // Two receives tie each other too, on one side.
    final receives = analyzeChain(
      _scan(),
      swaps: [
        _swap('first', SwapDirection.receive, refund: _me),
        _swap('second', SwapDirection.receive, refund: _me),
      ],
      ownAddresses: const [],
    );
    expect(receives.tiesSwaps, isTrue);
    expect(onBothSides(receives.kranox), isFalse);

    // One swap is how a swap goes.
    final one = analyzeChain(
      _scan(),
      swaps: [_swap('paid', SwapDirection.pay, payout: _me)],
      ownAddresses: const [],
    );
    expect(one.kranox, hasLength(1));
    expect(one.tiesSwaps, isFalse);
    expect(one.toImprove, 0);
  });

  test('says what everyone sees: the counts, the tokens it holds, its first day, and its hours', () {
    final evening = [
      for (var day = 0; day < 10; day++) _transfer('e$day', _me, _shop, after: Duration(days: day, hours: 9)),
    ];
    final report = analyzeChain(
      _scan(
        first: _transfer('first', _exchange, _me),
        transactions: [
          ...evening,
          _transfer('noon', _me, _shop, after: const Duration(hours: 3)),
        ],
        holdings: [
          ChainHolding(
            token: const ChainToken(symbol: 'USDG', address: _usdg, decimals: 6),
            value: BigInt.from(5),
          ),
          ChainHolding(
            token: const ChainToken(symbol: 'OLD', address: _shop, decimals: 18),
            value: BigInt.zero,
          ),
        ],
        transactionCount: 11,
        tokenTransferCount: 4,
      ),
      swaps: const [],
      ownAddresses: const [],
    );
    final exposure = report.exposure;
    expect(exposure.transactions, 11);
    expect(exposure.tokenTransfers, 4);
    expect(exposure.tokens, ['USDG'], reason: 'a token with nothing left is not held');
    expect(exposure.firstSeen, _t0);
    // Ten of the twelve transfers fall at 18:00 UTC, so a window of six hours holds them.
    final (from, to) = exposure.activeHours!;
    expect((18 - from) % 24, lessThan(6));
    expect(to, (from + 6) % 24);
  });

  test('reads no hours from a short history', () {
    final report = analyzeChain(
      _scan(transactions: [_transfer('one', _me, _shop)]),
      swaps: const [],
      ownAddresses: const [],
    );
    expect(report.exposure.activeHours, isNull);
  });

  test('reads the scan that the relay answers', () {
    final scan = ChainScan.fromJson({
      'address': _me,
      'isContract': false,
      'balanceWei': '18446744073709551616',
      'transactionCount': 2,
      'tokenTransferCount': 1,
      'firstTransaction': {
        'hash': '0xtx1',
        'from': {'address': _exchange, 'label': 'Big Exchange', 'isContract': false},
        'to': {'address': _me, 'label': null, 'isContract': false},
        'value': '5000000000000000',
        'token': null,
        'time': '2026-10-01T08:00:00.000000Z',
      },
      'firstTokenTransfer': null,
      'transactions': [
        {
          'hash': '0xcreate',
          'from': {'address': _me, 'label': null, 'isContract': false},
          'to': null,
          'value': '0',
          'token': null,
          'time': '2026-10-02T08:00:00.000Z',
        },
      ],
      'tokenTransfers': [
        {
          'hash': '0xtoken',
          'from': {'address': _me, 'label': null, 'isContract': false},
          'to': {'address': _shop, 'label': 'Coffee Shop', 'isContract': true},
          'value': '25000000',
          'token': {'symbol': 'USDG', 'address': _usdg, 'decimals': 6},
          'time': '2026-10-03T08:00:00.000Z',
        },
      ],
      'holdings': [
        {
          'token': {'symbol': 'USDG', 'address': _usdg, 'decimals': 6},
          'value': '75000000',
        },
      ],
    });
    expect(scan.balanceWei, BigInt.parse('18446744073709551616'), reason: 'a balance in wei passes the int of Dart');
    expect(scan.firstTransaction!.from.label, 'Big Exchange');
    expect(scan.firstTransaction!.time, DateTime.utc(2026, 10, 1, 8));
    expect(scan.transactions.single.to, isNull);
    expect(scan.tokenTransfers.single.token!.decimals, 6);
    expect(scan.holdings.single.value, BigInt.from(75000000));
    expect(scan.fundingRead, isFalse, reason: 'a relay before 10 Oct 2026 reads no first funding of its own');
    expect(scan.fundingSure, isFalse);
    expect(() => ChainScan.fromJson({'address': _me, 'transactions': 'many'}), throwsA(isA<FormatException>()));
  });

  test('reads the first funding that the relay read, and whether it is sure', () {
    Map<String, Object?> answer({Object? funding, Object? sure}) => {
      'address': _me,
      'isContract': false,
      'balanceWei': '0',
      'transactionCount': 0,
      'tokenTransferCount': 0,
      'firstTransaction': null,
      'firstTokenTransfer': null,
      'transactions': const <Object?>[],
      'tokenTransfers': const <Object?>[],
      'holdings': const <Object?>[],
      'firstFunding': funding,
      'fundingSure': sure,
    };
    final funded = ChainScan.fromJson(
      answer(
        funding: {
          'hash': '0xinternal',
          'from': {'address': _exchange, 'label': 'Disperse', 'labelSource': 'contract', 'isContract': true},
          'to': {'address': _me, 'label': null, 'isContract': false},
          'value': '1000000000000000',
          'token': null,
          'time': '2026-08-29T09:39:00.000Z',
        },
        sure: true,
      ),
    );
    expect(funded.fundingRead, isTrue);
    expect(funded.fundingSure, isTrue);
    expect(funded.firstFunding!.from.isContract, isTrue);
    expect(funded.firstFunding!.from.labelSource, LabelSource.contract);
    ChainParty party(Object? source) =>
        ChainParty.fromJson({'address': _exchange, 'label': 'x', 'labelSource': source, 'isContract': false});
    expect(party('domain').labelSource, LabelSource.domain);
    expect(party('tag').labelSource, LabelSource.tag);
    expect(party(null).labelSource, LabelSource.tag, reason: 'a relay before 10 Oct 2026 names no source');
    expect(party('a source of a newer relay').labelSource, LabelSource.tag);
    final none = ChainScan.fromJson(answer(sure: false));
    expect(none.fundingRead, isTrue);
    expect(none.firstFunding, isNull);
    expect(none.fundingSure, isFalse);
  });

  group('the first funding that the relay read', () {
    ChainScan read(ChainTransfer? funding, {bool sure = true, ChainTransfer? first}) => ChainScan(
      address: _me,
      isContract: false,
      balanceWei: BigInt.zero,
      transactionCount: 1,
      tokenTransferCount: 0,
      firstTransaction: first,
      firstTokenTransfer: null,
      transactions: const [],
      tokenTransfers: const [],
      holdings: const [],
      firstFunding: funding,
      fundingRead: true,
      fundingSure: sure,
    );

    test('stands over the oldest transactions, which may miss the ETH that a contract sent', () {
      final report = analyzeChain(
        read(
          _transfer('internal', _exchange, _me, fromLabel: 'Disperse'),
          first: _transfer('later', _shop, _me, after: const Duration(days: 3)),
        ),
        swaps: const [],
        ownAddresses: const [],
      );
      expect(report.funding!.transfer.hash, 'internal');
      expect(report.funding!.links, isTrue);
      expect(report.toImprove, 1);
    });

    test('a funding that the relay could not read for sure stays unsure, and one that links still warns', () {
      final plain = analyzeChain(
        read(_transfer('eth', _shop, _me), sure: false),
        swaps: const [],
        ownAddresses: const [],
      );
      expect(plain.funding!.sure, isFalse);
      expect(plain.funding!.links, isFalse);
      expect(plain.toImprove, 0);
      final named = analyzeChain(
        read(_transfer('eth', _exchange, _me, fromLabel: 'Big Exchange'), sure: false),
        swaps: const [],
        ownAddresses: const [],
      );
      expect(named.funding!.links, isTrue);
      expect(named.toImprove, 1);
    });

    test('none found is no funding, even with an older transaction in that the relay left out', () {
      final report = analyzeChain(
        read(null, first: _transfer('eth', _shop, _me)),
        swaps: const [],
        ownAddresses: const [],
      );
      expect(report.funding, isNull);
    });
  });
}
