import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/chain_scan.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/bridge/controller.dart';
import 'package:kranox_wallet/bridge/store.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/privacy/chain_scans.dart';
import 'package:kranox_wallet/ui/copy.dart';
import 'package:kranox_wallet/ui/format.dart';
import 'package:kranox_wallet/ui/screens/privacy_page.dart';
import 'package:kranox_wallet/ui/theme/kranox_theme.dart';
import 'package:kranox_wallet/ui/theme/palette.dart';
import 'package:kranox_wallet/ui/widgets/sidebar.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

/// A synced wallet of 10 XMR whose history the test sets: the subaddress of each payment that came in.
final class _Wallet implements WalletBackend {
  _Wallet(this.indexes);

  final List<int> indexes;
  final List<WalletRequest> handled = [];
  int _subaddress = 1;

  @override
  Future<T> call<T>(WalletRequest request) async {
    handled.add(request);
    final Object? answer = switch (request) {
      ReadStatus() => WalletStatus(
        balance: XmrAmount.parse('10'),
        unlocked: XmrAmount.parse('10'),
        walletHeight: 100,
        nodeHeight: 100,
        synchronized: true,
        connection: NodeConnection.connected,
      ),
      ReadHistory() => [
        for (final (number, index) in indexes.indexed)
          WalletTransfer(
            hash: 'in$number',
            direction: TransferDirection.incoming,
            amount: XmrAmount.parse('1'),
            fee: XmrAmount.zero,
            time: DateTime.now().subtract(Duration(days: 5 + number)),
            blockHeight: 90,
            confirmations: 100,
            isPending: false,
            isFailed: false,
            subaddressIndex: index,
          ),
      ],
      ReadReceiveAddress(:final createNew) => ReceiveAddress(
        address: 'subaddress-${createNew ? ++_subaddress : _subaddress}',
        index: _subaddress,
      ),
      ReadSubaddress(:final index) => ReceiveAddress(address: 'subaddress-$index', index: index),
      _ => null,
    };
    return answer as T;
  }

  @override
  void stop() {}
}

/// An address on Robinhood Chain from the examples of EIP-55, its first funder, the shop that it paid, and a look-alike
/// of the shop.
const _address = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
const _exchange = '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359';
const _shop = '0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb';
const _fakeShop = '0xD1229999999999999999999999999999999e9aDb';

/// The relay with the scan of one address: funded by an exchange with a public name, and a look-alike of the shop that
/// it paid.
final class _Scanner implements ChainScanClient {
  final List<String> asked = [];

  @override
  Future<ChainScan> scanAddress(String address) async {
    asked.add(address);
    ChainParty party(String value, {String? label}) => ChainParty(address: value, label: label, isContract: false);
    final start = DateTime.now().subtract(const Duration(days: 20));
    return ChainScan(
      address: address,
      isContract: false,
      balanceWei: BigInt.zero,
      transactionCount: 3,
      tokenTransferCount: 1,
      firstTransaction: ChainTransfer(
        hash: '0xfirst',
        from: party(_exchange, label: 'Big Exchange'),
        to: party(address),
        value: BigInt.from(5),
        token: null,
        time: start,
      ),
      firstTokenTransfer: null,
      transactions: [
        ChainTransfer(
          hash: '0xpaid',
          from: party(address),
          to: party(_shop),
          value: BigInt.from(1),
          token: null,
          time: start.add(const Duration(days: 1)),
        ),
      ],
      tokenTransfers: [
        ChainTransfer(
          hash: '0xdust',
          from: party(_fakeShop),
          to: party(address),
          value: BigInt.zero,
          token: null,
          time: start.add(const Duration(days: 2)),
        ),
      ],
      holdings: const [],
    );
  }
}

/// The page reads only the swaps that the store holds, so the exchanger never answers.
final class _NoRelay implements BridgeClient {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError('The privacy page calls no exchanger.');
}

void main() {
  late Directory root;
  late _Wallet engine;
  late WalletController wallet;
  late BridgeController bridge;
  final opened = <WalletPage>[];
  var paid = 0;

  Future<void> start(List<int> indexes) async {
    root = Directory.systemTemp.createTempSync('kranox-privacy-page');
    final storage = AppStorage(root.path);
    await storage.prepareWalletFolder(MoneroNetwork.mainnet);
    File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
    engine = _Wallet(indexes);
    wallet = WalletController(worker: engine, storage: storage);
    await wallet.start();
    await wallet.unlock('password');
    bridge = BridgeController(client: _NoRelay(), store: BridgeStore(storage.bridgePath), wallet: wallet);
    opened.clear();
    paid = 0;
  }

  tearDown(() async {
    bridge.dispose();
    await wallet.lock();
    wallet.dispose();
    root.deleteSync(recursive: true);
  });

  Future<void> show(WidgetTester tester, {ChainScans? scans}) async {
    // Tall enough for the part of Robinhood Chain under the cards of the wallet.
    await tester.binding.setSurfaceSize(const Size(1400, 6000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: KranoxTheme.build(Palette.of(activeLook)),
        home: Scaffold(
          body: PrivacyPage(
            controller: wallet,
            bridge: bridge,
            onNavigate: opened.add,
            onPayNewAddress: () => paid++,
            scans: scans,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a public node and a subaddress of many payments are two things to improve, each with its way', (
    tester,
  ) async {
    await tester.runAsync(() => start([1, 1, 1, 2]));
    await show(tester);
    expect(find.text(Copy.privacyToImprove(2)), findsOneWidget);
    expect(find.text(Copy.privacyRingCount(4, 6)), findsOneWidget);
    expect(find.text(Copy.privacySubaddressLine(1, 3)), findsOneWidget);

    // The longer text of a check shows when the user opens its tile, and goes when the user closes it.
    expect(find.text(Copy.privacySubaddressOne(1, 3)), findsNothing);
    await tester.tap(find.text(Copy.privacySubaddressTitle));
    await tester.pump();
    expect(find.text(Copy.privacySubaddressOne(1, 3)), findsOneWidget);
    await tester.tap(find.text(Copy.privacySubaddressTitle));
    await tester.pump();
    expect(find.text(Copy.privacySubaddressOne(1, 3)), findsNothing);

    await tester.tap(find.text(Copy.privacyChangeNode));
    expect(opened, [WalletPage.settings]);

    // The first unlock of a wallet makes the subaddress of the receive page too, so the test counts from here.
    int made() => engine.handled.whereType<ReadReceiveAddress>().where((request) => request.createNew).length;
    final before = made();
    await tester.tap(find.text(Copy.privacyNewSubaddress));
    // The wallet writes the new index to its settings file: the file takes real time, and each step after it a frame.
    for (var round = 0; round < 40 && opened.length < 2; round++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    }
    expect(made(), before + 1);
    expect(opened, [WalletPage.settings, WalletPage.receive]);
  });

  testWidgets('a node of its own network and one payment for each subaddress leave the wallet all clear', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await start([1, 2, 3]);
      await wallet.changeNode('192.168.1.5:18089');
    });
    await show(tester);
    expect(find.text(Copy.privacyClear), findsOneWidget);
    expect(find.text(Copy.privacyRingCount(6, 6)), findsOneWidget);
    expect(find.text(Copy.privacyChangeNode), findsNothing);
    expect(find.text(Copy.privacyNewSubaddress), findsNothing);
    expect(find.text(Copy.privacyNodeOwnLine), findsOneWidget);
    await tester.tap(find.text(Copy.privacyNodeTitle));
    await tester.pump();
    expect(find.text(Copy.privacyNodeOwn('192.168.1.5:18089')), findsOneWidget);
  });

  testWidgets('scans an address of the user on Robinhood Chain and says what it gives away', (tester) async {
    await tester.runAsync(() => start([1, 2]));
    final scanner = _Scanner();
    final scans = ChainScans(scanner);
    addTearDown(scans.dispose);
    await show(tester, scans: scans);
    expect(find.text(Copy.privacyFundingPending), findsNothing);

    // The scan has a tab of its own, whose tiles say what each check reads before the first scan.
    await tester.tap(find.text(Copy.privacyChainTab.toUpperCase()));
    await tester.pump();
    expect(find.text(Copy.privacyFundingPending), findsOneWidget);
    expect(find.text(Copy.privacyExposurePending), findsOneWidget);

    // An address of the wrong form never reaches the relay.
    await tester.enterText(find.byType(TextField), '0x123');
    await tester.tap(find.text(Copy.privacyChainScan));
    await tester.pump();
    expect(scanner.asked, isEmpty);
    expect(find.text(Copy.privacyChainResult(shortText(_address))), findsNothing);

    await tester.enterText(find.byType(TextField), _address);
    await tester.tap(find.text(Copy.privacyChainScan));
    for (var round = 0; round < 4; round++) {
      await tester.pump();
    }
    expect(scanner.asked, [_address]);
    expect(find.text(Copy.privacyChainResult(shortText(_address))), findsOneWidget);
    expect(find.text(Copy.privacyToImprove(2)), findsOneWidget);
    expect(find.text(Copy.privacyRingCount(3, 5)), findsOneWidget);
    expect(find.text(Copy.privacyFundingNamedLine('Big Exchange')), findsOneWidget);
    expect(find.text(Copy.privacyLookAlikeLine(1)), findsOneWidget);
    expect(find.text(Copy.privacyStatCount(3)), findsOneWidget);
    expect(find.text(Copy.privacyFundingPending), findsNothing);

    await tester.tap(find.text(Copy.privacyFundingTitle));
    await tester.tap(find.text(Copy.privacyLookAlikeTitle));
    await tester.pump();
    expect(find.textContaining('Big Exchange funded it first'), findsOneWidget);
    expect(find.textContaining('$_fakeShop looks like $_shop'), findsOneWidget);

    // Things to improve come with the way to a clean start: pay to a new address of the user.
    await tester.tap(find.text(Copy.privacyPayNewAddress));
    expect(paid, 1);
  });

  testWidgets('a wallet on another network than mainnet shows no scan of Robinhood Chain', (tester) async {
    await tester.runAsync(() async {
      await start([1, 2]);
      await wallet.switchNetwork(MoneroNetwork.stagenet);
    });
    final scans = ChainScans(_Scanner());
    addTearDown(scans.dispose);
    await show(tester, scans: scans);
    expect(find.text(Copy.privacyChainTab.toUpperCase()), findsNothing);
    expect(find.text(Copy.privacyChainTitle), findsNothing);
  });
}
