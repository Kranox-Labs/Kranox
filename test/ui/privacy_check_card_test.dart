import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/chain_scan.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/bridge/controller.dart';
import 'package:kranox_wallet/bridge/models.dart';
import 'package:kranox_wallet/bridge/store.dart';
import 'package:kranox_wallet/config/app_config.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/ui/copy.dart';
import 'package:kranox_wallet/ui/format.dart';
import 'package:kranox_wallet/ui/screens/send_page.dart';
import 'package:kranox_wallet/ui/theme/kranox_theme.dart';
import 'package:kranox_wallet/ui/theme/palette.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

/// A mainnet address of a throwaway wallet, as in test/core/address_test.dart: the deposit of the exchanger.
const _deposit = '48PFnHrr8bVGx463yo8SMXGZUp7PyYPgwZJR4MnpgjKCDXpw3XvK6UTbarKkpwaPbPSYSdJ4rozjZjGxr2t3qVP4B4DzzVs';

/// A mainnet subaddress of a throwaway wallet, as in test/core/address_test.dart: the plain recipient.
const _plainRecipient =
    '883z7Wmbd5nhoH6xQxLzgniNhN6jqdvxFiza4rMdErWA1XW1TCL1tqrCwWFwhG1QkuL17RRHP45J33y6u4sH8Rfa7kryRza';

/// A recipient on Robinhood Chain, from the examples of EIP-55.
const _chainRecipient = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';

/// Two more addresses from the examples of EIP-55: an exchange, and an address of the user.
const _exchange = '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359';
const _ownAddress = '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB';

/// The relay with the scan that [answer] makes for each address, and the addresses that it was asked for.
final class _Scanner implements ChainScanClient {
  _Scanner(this.answer);

  final ChainScan Function(String address) answer;
  final List<String> asked = [];

  @override
  Future<ChainScan> scanAddress(String address) async {
    asked.add(address);
    return answer(address);
  }
}

ChainParty _party(String address, {String? label}) => ChainParty(address: address, label: label, isContract: false);

/// An address without any history on Robinhood Chain.
ChainScan _freshScan(String address) => ChainScan(
  address: address,
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

/// An address that an exchange with a public name funded first, and that sent ETH to [_ownAddress] later.
ChainScan _linkedScan(String address) {
  final start = DateTime.now().subtract(const Duration(days: 20));
  return ChainScan(
    address: address,
    isContract: false,
    balanceWei: BigInt.zero,
    transactionCount: 7,
    tokenTransferCount: 0,
    firstTransaction: ChainTransfer(
      hash: '0xfirst',
      from: _party(_exchange, label: 'Big Exchange'),
      to: _party(address),
      value: BigInt.from(5),
      token: null,
      time: start,
    ),
    firstTokenTransfer: null,
    transactions: [
      ChainTransfer(
        hash: '0xmine',
        from: _party(address),
        to: _party(_ownAddress),
        value: BigInt.one,
        token: null,
        time: start.add(const Duration(days: 3)),
      ),
    ],
    tokenTransfers: const [],
    holdings: const [],
  );
}

/// A finished receive from Robinhood Chain whose refund address was [refundAddress].
BridgeSwap _receive(String refundAddress) => BridgeSwap(
  id: 'receive1',
  asset: BridgeAsset.usdg,
  amount: 25,
  xmrAmount: null,
  depositAddress: '0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984',
  payoutAddress: 'subaddress-3',
  subaddressIndex: 3,
  createdAt: DateTime.now().subtract(const Duration(days: 5)),
  stage: SwapStage.finished,
  depositHash: '0xdeposit',
  refundAddress: refundAddress,
  closed: true,
);

/// A synced wallet of 10 XMR that received 0.5 XMR 30 hours ago, so that a payment of 0.5 XMR matches it.
final class _Wallet implements WalletBackend {
  final List<WalletRequest> handled = [];
  int _built = 0;

  static final XmrAmount _balance = XmrAmount.parse('10');

  @override
  Future<T> call<T>(WalletRequest request) async {
    handled.add(request);
    final Object? answer = switch (request) {
      ReadStatus() => WalletStatus(
        balance: _balance,
        unlocked: _balance,
        walletHeight: 100,
        nodeHeight: 100,
        synchronized: true,
        connection: NodeConnection.connected,
      ),
      ReadHistory() => [
        WalletTransfer(
          hash: 'came-in',
          direction: TransferDirection.incoming,
          amount: XmrAmount.parse('0.5'),
          fee: XmrAmount.zero,
          time: DateTime.now().subtract(const Duration(hours: 30)),
          blockHeight: 90,
          confirmations: 10,
          isPending: false,
          isFailed: false,
          subaddressIndex: 1,
        ),
      ],
      ReadReceiveAddress() => const ReceiveAddress(address: 'subaddress-2', index: 2),
      ReadSubaddress(:final index) => ReceiveAddress(address: 'subaddress-$index', index: index),
      PrepareSend(:final address, :final amountUnits) => PreparedSend(
        id: ++_built,
        address: address,
        amount: XmrAmount(amountUnits),
        fee: XmrAmount.parse('0.00003'),
      ),
      ReadFileKey() => Uint8List(32),
      _ => null,
    };
    return answer as T;
  }

  @override
  void stop() {}
}

/// An exchanger that answers at once: a fixed rate of 500 coins for one XMR.
final class _Relay implements BridgeClient {
  @override
  Future<PayRange> payRange(BridgeAsset asset, PayRate rate) async =>
      PayRange(asset: asset, rate: rate, minXmr: 0.02, maxXmr: 2);

  @override
  Future<PayQuote> payQuote(BridgeAsset asset, PayRate rate, String xmrAmount) async => PayQuote(
    asset: asset,
    rate: rate,
    xmrAmount: xmrAmount,
    amount: double.parse(xmrAmount) * 500,
    rateId: 'rate-$xmrAmount',
    validUntil: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    warning: null,
    limit: null,
    minXmr: null,
    maxXmr: null,
  );

  @override
  Future<CreatedPay> createPay({
    required BridgeAsset asset,
    required PayRate rate,
    required String xmrAmount,
    required String address,
    required String refundAddress,
    required String? rateId,
    required String creationKey,
  }) async => CreatedPay(
    id: 'pay1',
    amount: double.parse(xmrAmount) * 500,
    xmrAmount: double.parse(xmrAmount),
    depositAddress: _deposit,
    payoutAddress: address.toLowerCase(),
    refundAddress: refundAddress,
  );

  @override
  Future<SwapState> readSwap(String id, {String? token}) async =>
      SwapState(stage: SwapStage.waiting, validUntil: DateTime.now().toUtc().add(const Duration(minutes: 10)));

  @override
  Future<BridgeQuote> quote(BridgeAsset asset, String amount) async => BridgeQuote(
    asset: asset,
    amount: amount,
    minAmount: 0.004,
    estimatedXmr: null,
    speedMinutes: null,
    warning: null,
  );

  @override
  Future<CreatedSwap> createSwap({
    required BridgeAsset asset,
    required String amount,
    required String address,
    String? refundAddress,
    required String creationKey,
  }) => throw UnimplementedError('The test makes no swap of receive.');

  @override
  Future<bool> isOnline() async => true;
}

void main() {
  late Directory root;
  late _Wallet engine;
  late WalletController wallet;
  late BridgeController bridge;

  Future<void> start({List<BridgeSwap> swaps = const [], ChainScanClient? scanner}) async {
    root = Directory.systemTemp.createTempSync('kranox-privacy');
    final storage = AppStorage(root.path);
    await storage.prepareWalletFolder(MoneroNetwork.mainnet);
    File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
    final store = BridgeStore(storage.bridgePath);
    await store.read(Uint8List(32));
    await store.write(swaps);
    engine = _Wallet();
    wallet = WalletController(worker: engine, storage: storage);
    await wallet.start();
    await wallet.unlock('password');
    bridge = BridgeController(client: _Relay(), store: store, wallet: wallet, scanner: scanner);
    await bridge.start();
  }

  tearDown(() async {
    bridge.dispose();
    await wallet.lock();
    wallet.dispose();
    root.deleteSync(recursive: true);
  });

  Future<void> showSendPage(WidgetTester tester, {bool startOnPay = false}) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: KranoxTheme.build(Palette.of(activeLook)),
        home: Scaffold(
          body: SendPage(controller: wallet, bridge: bridge, startOnPay: startOnPay),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 6; round++) {
      await tester.pump();
    }
  }

  /// Opens pay, asks for 0.16 XMR to [_chainRecipient], and reviews the payment.
  Future<void> reviewPay(WidgetTester tester) async {
    await showSendPage(tester);
    await tester.tap(find.text(Copy.sendChainTab.toUpperCase()));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), '0.16');
    await tester.enterText(find.byType(TextField).at(1), _chainRecipient);
    await tester.pump(AppConfig.bridgeQuoteDelay + const Duration(milliseconds: 200));
    await settle(tester);
    expect(bridge.pay.canReview, isTrue);
    await tester.tap(find.text(Copy.review));
    await settle(tester);
    expect(bridge.pay.review, isNotNull);
  }

  testWidgets('a plain send of an amount that came in lately gets a warning and a suggestion that clears it', (
    tester,
  ) async {
    await tester.runAsync(start);
    await showSendPage(tester);
    await tester.enterText(find.byType(TextField).at(0), _plainRecipient);
    await tester.enterText(find.byType(TextField).at(1), '0.5');
    await tester.pump();
    await tester.tap(find.text(Copy.review));
    await settle(tester);

    expect(find.text(Copy.privacyTitle.toUpperCase()), findsOneWidget);
    expect(find.text(Copy.privacyWarnings(1)), findsOneWidget);
    final suggestion = find.textContaining('Use ');
    expect(suggestion, findsOneWidget);

    await tester.tap(suggestion);
    await settle(tester);

    final builds = engine.handled.whereType<PrepareSend>().toList();
    expect(builds, hasLength(2), reason: 'the suggestion builds the payment again');
    final first = builds.first.amountUnits;
    final second = builds.last.amountUnits;
    expect((first - second).abs(), greaterThan(AppConfig.privacyXmrTolerance * first));
    expect(engine.handled.whereType<CancelSend>(), hasLength(1), reason: 'the old payment goes');
    expect(find.text(Copy.privacyClear), findsOneWidget);
  });

  testWidgets('pay to an address that the user gave as a refund address warns about the link', (tester) async {
    await tester.runAsync(() => start(swaps: [_receive(_chainRecipient)]));
    await reviewPay(tester);

    // Without the scan of the relay, the review offers no check of the recipient.
    expect(find.text(Copy.payCheckRecipient), findsNothing);
    expect(find.text(Copy.privacyAddressLabel), findsOneWidget);
    expect(find.textContaining('refund address of a receive'), findsOneWidget);
    expect(find.text(Copy.privacyWarnings(1)), findsOneWidget);
  });

  testWidgets('pay checks a recipient without a history on Robinhood Chain and calls it a clean start', (tester) async {
    final scanner = _Scanner(_freshScan);
    await tester.runAsync(() => start(scanner: scanner));
    await reviewPay(tester);
    expect(find.text(Copy.payCheckRecipient), findsOneWidget);
    expect(scanner.asked, isEmpty, reason: 'the check waits for the user');

    await tester.tap(find.text(Copy.payCheckRecipient));
    await settle(tester);
    expect(scanner.asked, [_chainRecipient.toLowerCase()]);
    expect(find.text(Copy.payRecipientFresh), findsOneWidget);
    expect(find.text(Copy.payRecipientFreshNote), findsOneWidget);
    expect(find.text(Copy.payCheckRecipient), findsNothing);
  });

  testWidgets('pay checks a recipient that an exchange funded and that dealt with an address of the user', (
    tester,
  ) async {
    await tester.runAsync(() => start(swaps: [_receive(_ownAddress)], scanner: _Scanner(_linkedScan)));
    await reviewPay(tester);
    await tester.tap(find.text(Copy.payCheckRecipient));
    await settle(tester);

    expect(find.textContaining(Copy.payRecipientFundedNamed('Big Exchange', '')), findsOneWidget);
    expect(find.text(Copy.payRecipientOwn(shortText(_ownAddress))), findsOneWidget);
    expect(find.textContaining('At least 7 transactions'), findsOneWidget);
    expect(find.text(Copy.payRecipientApart), findsOneWidget);
  });

  testWidgets('the send page opens on pay when asked, as the way to a clean start does', (tester) async {
    await tester.runAsync(start);
    await showSendPage(tester, startOnPay: true);
    expect(find.text(Copy.payLead), findsOneWidget);
    expect(find.text(Copy.sendLead), findsNothing);
  });
}
