import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/chain_scan.dart';
import 'package:kranox_wallet/privacy/chain_privacy.dart';
import 'package:kranox_wallet/ui/copy.dart';
import 'package:kranox_wallet/ui/format.dart';
import 'package:kranox_wallet/ui/theme/kranox_theme.dart';
import 'package:kranox_wallet/ui/theme/palette.dart';
import 'package:kranox_wallet/ui/widgets/address_check.dart';

// The checked address, from the examples of EIP-55, the shop that it paid, a look-alike of the shop, and a funder.
const _me = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
const _shop = '0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb';
const _fakeShop = '0xD1229999999999999999999999999999999e9aDb';
const _funder = '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB';

final DateTime _start = DateTime.utc(2026, 9, 1, 8);
final DateTime _now = _start.add(const Duration(days: 10));

ChainTransfer _transfer(String hash, String from, String to, Duration after, {String value = '1000'}) => ChainTransfer(
  hash: hash,
  from: ChainParty(address: from, label: null, isContract: false),
  to: ChainParty(address: to, label: null, isContract: false),
  value: BigInt.parse(value),
  token: null,
  time: _start.add(after),
);

/// A scan of [_me]: it paid the shop, and the look-alike of the shop sent it nothing, as a trap.
ChainScan _scan({required ChainTransfer? funding, required bool sure}) => ChainScan(
  address: _me,
  isContract: false,
  balanceWei: BigInt.zero,
  transactionCount: 2,
  tokenTransferCount: 0,
  firstTransaction: null,
  firstTokenTransfer: null,
  transactions: [
    _transfer('0xtrap', _fakeShop, _me, const Duration(days: 3), value: '0'),
    _transfer('0xpaid', _me, _shop, const Duration(days: 2)),
  ],
  tokenTransfers: const [],
  holdings: const [],
  firstFunding: funding,
  fundingRead: true,
  fundingSure: sure,
);

Future<void> _show(WidgetTester tester, ChainScan scan) async {
  final report = analyzeChain(scan, swaps: const [], ownAddresses: const []);
  await tester.pumpWidget(
    MaterialApp(
      theme: KranoxTheme.build(Palette.of(activeLook)),
      home: Scaffold(
        body: AddressCheck(
          report: report,
          error: null,
          onRetry: null,
          now: _now,
          freshNote: Copy.receiveRefundFreshNote,
          apartNote: Copy.receiveRefundApart,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the check on a review warns about a look-alike sender in the history', (tester) async {
    await _show(tester, _scan(funding: _transfer('0xfund', _funder, _me, Duration.zero), sure: true));
    expect(find.text(Copy.payRecipientLookAlike(1)), findsOneWidget);
    expect(find.text(Copy.payRecipientFundedPlain(formatTime(_start, _now))), findsOneWidget);
  });

  testWidgets('a funder named by a contract or a domain reads as such, never as a public tag', (tester) async {
    ChainTransfer from(String label, LabelSource source) => ChainTransfer(
      hash: '0xfund',
      from: ChainParty(address: _funder, label: label, isContract: source == LabelSource.contract, labelSource: source),
      to: const ChainParty(address: _me, label: null, isContract: false),
      value: BigInt.from(1000),
      token: null,
      time: _start,
    );
    final day = formatTime(_start, _now);
    await _show(tester, _scan(funding: from('Disperse', LabelSource.contract), sure: true));
    expect(find.text(Copy.payRecipientFundedContract('Disperse', day)), findsOneWidget);
    await _show(tester, _scan(funding: from('friend.eth', LabelSource.domain), sure: true));
    expect(find.text(Copy.payRecipientFundedDomain('friend.eth', day)), findsOneWidget);
    await _show(tester, _scan(funding: from('Big Exchange', LabelSource.tag), sure: true));
    expect(find.text(Copy.payRecipientFundedNamed('Big Exchange', day)), findsOneWidget);
  });

  testWidgets('a first funding that the relay could not read for sure is a note, never a clean line', (tester) async {
    await _show(tester, _scan(funding: _transfer('0xfund', _funder, _me, Duration.zero), sure: false));
    expect(find.text(Copy.payRecipientFundedUnsure(formatTime(_start, _now))), findsOneWidget);
    expect(find.text(Copy.payRecipientFundedPlain(formatTime(_start, _now))), findsNothing);

    await _show(tester, _scan(funding: null, sure: false));
    expect(find.text(Copy.payRecipientFundingUnsure), findsOneWidget);
  });
}
