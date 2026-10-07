import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/bridge/controller.dart';
import 'package:kranox_wallet/bridge/models.dart';
import 'package:kranox_wallet/bridge/store.dart';
import 'package:kranox_wallet/config/app_config.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/ui/copy.dart';
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
  }) async => CreatedPay(
    id: 'pay1',
    amount: double.parse(xmrAmount) * 500,
    xmrAmount: double.parse(xmrAmount),
    depositAddress: _deposit,
    payoutAddress: address.toLowerCase(),
  );

  @override
  Future<SwapState> readSwap(String id) async =>
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
  }) => throw UnimplementedError('The test makes no swap of receive.');

  @override
  Future<bool> isOnline() async => true;
}

void main() {
  late Directory root;
  late _Wallet engine;
  late WalletController wallet;
  late BridgeController bridge;

  Future<void> start({List<BridgeSwap> swaps = const []}) async {
    root = Directory.systemTemp.createTempSync('kranox-privacy');
    final storage = AppStorage(root.path);
    await storage.prepareWalletFolder(MoneroNetwork.mainnet);
    File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
    final store = BridgeStore(storage.bridgePath);
    await store.write(swaps);
    engine = _Wallet();
    wallet = WalletController(worker: engine, storage: storage);
    await wallet.start();
    await wallet.unlock('password');
    bridge = BridgeController(client: _Relay(), store: store, wallet: wallet);
    await bridge.start();
  }

  tearDown(() async {
    bridge.dispose();
    await wallet.lock();
    wallet.dispose();
    root.deleteSync(recursive: true);
  });

  Future<void> showSendPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: KranoxTheme.build(Palette.of(activeLook)),
        home: Scaffold(
          body: SendPage(controller: wallet, bridge: bridge),
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
    await tester.runAsync(
      () => start(
        swaps: [
          BridgeSwap(
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
            refundAddress: _chainRecipient,
            closed: true,
          ),
        ],
      ),
    );
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
    expect(find.text(Copy.privacyAddressLabel), findsOneWidget);
    expect(find.textContaining('refund address of a receive'), findsOneWidget);
    expect(find.text(Copy.privacyWarnings(1)), findsOneWidget);
  });
}
