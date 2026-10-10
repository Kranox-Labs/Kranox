import 'dart:async';
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
import 'package:kranox_wallet/ui/screens/receive_from_chain.dart';
import 'package:kranox_wallet/ui/screens/receive_page.dart';
import 'package:kranox_wallet/ui/theme/kranox_theme.dart';
import 'package:kranox_wallet/ui/theme/palette.dart';
import 'package:kranox_wallet/ui/widgets/buttons.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

/// Addresses on Robinhood Chain from the examples of EIP-55: one that the user paid from XMR, one that the user never
/// paid, and the deposit address of the exchanger.
const _paid = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
const _fresh = '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB';
const _deposit = '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359';

/// One more address from the examples of EIP-55, that took part in no swap.
const _other = '0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb';

/// A wallet whose history the test sets: the subaddress of each payment that came in. The first unlock gives the
/// receive page subaddress #2. It has caught up with its node unless the test says otherwise.
final class _Wallet implements WalletBackend {
  _Wallet(this.indexes, {this.synchronized = true});

  final List<int> indexes;
  final bool synchronized;
  int _subaddress = 1;

  @override
  Future<T> call<T>(WalletRequest request) async {
    final Object? answer = switch (request) {
      ReadStatus() => WalletStatus(
        balance: XmrAmount.parse('10'),
        unlocked: XmrAmount.parse('10'),
        walletHeight: 100,
        nodeHeight: 100,
        synchronized: synchronized,
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
      ReadFileKeys() => FileKeys(key: Uint8List(32)),
      _ => null,
    };
    return answer as T;
  }

  @override
  void stop() {}
}

/// The relay: a quote for any amount, and a swap for each creation, whose refund addresses it keeps.
final class _Relay implements BridgeClient {
  final List<String?> refunds = [];

  @override
  Future<BridgeQuote> quote(BridgeAsset asset, String amount) async => BridgeQuote(
    asset: asset,
    amount: amount,
    minAmount: 0.001,
    estimatedXmr: 0.0358,
    speedMinutes: '10-30',
    warning: null,
  );

  @override
  Future<CreatedSwap> createSwap({
    required BridgeAsset asset,
    required String amount,
    required String address,
    String? refundAddress,
    required String creationKey,
  }) async {
    refunds.add(refundAddress);
    return CreatedSwap(
      id: 'swap${refunds.length}',
      amount: double.parse(amount),
      estimatedXmr: 0.0358,
      depositAddress: _deposit,
      payoutAddress: address,
      refundAddress: refundAddress,
      readToken: 'token',
    );
  }

  @override
  Future<SwapState> readSwap(String id, {String? token}) async => const SwapState(stage: SwapStage.waiting);

  @override
  Future<bool> isOnline() async => true;

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError('A receive asks for nothing else.');
}

/// The scan of an address without a public history, or of one that an exchange with a public name funded, for the
/// addresses in [exchangeFunded]. [hold] keeps the answer back until it completes, and [failure] fails the next scan.
final class _Scanner implements ChainScanClient {
  final List<String> asked = [];
  final Set<String> exchangeFunded = {};
  Completer<void>? hold;
  BridgeException? failure;

  @override
  Future<ChainScan> scanAddress(String address) async {
    asked.add(address);
    await hold?.future;
    if (failure case final failed?) {
      failure = null;
      throw failed;
    }
    return ChainScan(
      address: address,
      isContract: false,
      balanceWei: BigInt.zero,
      transactionCount: 0,
      tokenTransferCount: 0,
      firstTransaction: exchangeFunded.contains(address)
          ? ChainTransfer(
              hash: '0xexchange',
              from: const ChainParty(address: _deposit, label: 'Big Exchange', isContract: false),
              to: ChainParty(address: address, label: null, isContract: false),
              value: BigInt.one,
              token: null,
              time: DateTime.now().subtract(const Duration(days: 30)),
            )
          : null,
      firstTokenTransfer: null,
      transactions: const [],
      tokenTransfers: const [],
      holdings: const [],
      fundingSure: true,
    );
  }
}

void main() {
  late Directory root;
  late WalletController wallet;
  late BridgeController bridge;
  late _Relay relay;
  late _Scanner scanner;

  /// A wallet with payments to [indexes], whose bridge holds a payment from XMR to [_paid] two days ago, and [swaps].
  Future<void> start(List<int> indexes, {List<BridgeSwap> swaps = const [], bool synchronized = true}) async {
    root = Directory.systemTemp.createTempSync('kranox-receive-privacy');
    final storage = AppStorage(root.path);
    await storage.prepareWalletFolder(MoneroNetwork.mainnet);
    File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
    final store = BridgeStore(storage.bridgePath);
    await store.read(FileKeys(key: Uint8List(32)));
    await store.write([
      BridgeSwap(
        direction: SwapDirection.pay,
        id: 'pay1',
        asset: BridgeAsset.eth,
        amount: 0.0036,
        xmrAmount: 0.024,
        depositAddress: 'xmr-deposit',
        payoutAddress: _paid,
        subaddressIndex: 9,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        stage: SwapStage.finished,
      ),
      ...swaps,
    ]);
    wallet = WalletController(
      worker: _Wallet(indexes, synchronized: synchronized),
      storage: storage,
    );
    await wallet.start();
    await wallet.unlock('password');
    relay = _Relay();
    scanner = _Scanner();
    bridge = BridgeController(client: relay, store: store, wallet: wallet, scanner: scanner);
    await bridge.start();
  }

  tearDown(() async {
    bridge.dispose();
    await wallet.lock();
    wallet.dispose();
    root.deleteSync(recursive: true);
  });

  Future<void> show(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: KranoxTheme.build(Palette.of(activeLook)),
        home: Scaffold(body: page),
      ),
    );
    await tester.pump();
  }

  /// Types [amount] into the form and waits for its quote.
  Future<void> quote(WidgetTester tester, String amount) async {
    await tester.enterText(find.byType(TextField).first, amount);
    await tester.pump(AppConfig.bridgeQuoteDelay * 2);
    await tester.pump();
  }

  Future<void> review(WidgetTester tester, String refund) async {
    await tester.enterText(find.byType(TextField).at(1), refund);
    await tester.tap(find.text(Copy.bridgeReview));
    await tester.pump();
  }

  testWidgets('a receive from Robinhood Chain shows its privacy check before the exchanger makes anything', (
    tester,
  ) async {
    await tester.runAsync(() => start(const []));
    final opened = <BridgeSwap>[];
    await show(
      tester,
      SingleChildScrollView(
        child: ReceiveFromChain(bridge: bridge, onOpenSwap: opened.add),
      ),
    );
    await quote(tester, '0.01');

    // A refund address that the user paid from XMR ties both sides, and the exchanger hears nothing yet.
    await review(tester, _paid);
    expect(find.text(Copy.receiveReviewTitle), findsOneWidget);
    expect(find.text(_paid), findsOneWidget);
    expect(find.text(Copy.privacyWarnings(1)), findsOneWidget);
    expect(find.textContaining('ChangeNOW saw you pay it from XMR 2 days ago'), findsOneWidget);
    expect(find.text(Copy.privacyAfterReceive(AppConfig.privacyFreshWindow.inHours)), findsOneWidget);
    expect(relay.refunds, isEmpty);

    // The scan of the refund address starts with the review, without a click, and says what the address shows.
    await tester.pump();
    await tester.pump();
    expect(scanner.asked, [_paid]);
    expect(find.text(Copy.payRecipientFresh), findsOneWidget);
    expect(find.text(Copy.receiveRefundFreshNote), findsOneWidget);

    // Back to the form, which keeps the amount and its quote.
    await tester.tap(find.text(Copy.back));
    await tester.pump();
    expect(find.text(Copy.receiveReviewTitle), findsNothing);
    expect(find.text(Copy.bridgeReview), findsOneWidget);

    // A refund address that the user never paid passes, and it is scanned in its turn.
    await review(tester, _fresh);
    await tester.pump();
    expect(scanner.asked, [_paid, _fresh]);
    expect(find.text(Copy.privacyRefundUnused), findsOneWidget);
    expect(find.text(Copy.privacySendFromClean), findsOneWidget);
    expect(find.text(Copy.privacyClear), findsOneWidget);
    await tester.tap(find.text(Copy.back));
    await tester.pump();

    // Without a refund address, the receive names no address of the user, and the deposit address comes next.
    await review(tester, '');
    expect(find.text(Copy.privacyRefundNone), findsOneWidget);
    expect(find.text(Copy.receiveRefundNone), findsOneWidget);
    expect(find.text(Copy.addressChecking), findsNothing);
    expect(scanner.asked, [_paid, _fresh]);
    // The tap runs outside the fake time of the test, so that the swap that it saves starts its poll there.
    await tester.runAsync(() => tester.tap(find.text(Copy.bridgeCreate)));
    // The review gives way to the form once the swap is saved, with the card of the swap under it, and the page of the
    // new swap opens.
    for (var round = 0; round < 40 && find.text(Copy.receiveReviewTitle).evaluate().isNotEmpty; round++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    }
    expect(relay.refunds, [null]);
    expect(opened.single.refundAddress, isNull);
    expect(find.text(Copy.bridgeOpenSwaps(1).toUpperCase()), findsOneWidget);
    expect(find.text(Copy.receiveReviewTitle), findsNothing);
    // The emptied form asks for no quote, after the wait of the quote.
    await tester.pump(AppConfig.bridgeQuoteDelay * 2);
  });

  testWidgets('the deposit address waits for the check of the refund address, which can run again after a failure', (
    tester,
  ) async {
    await tester.runAsync(() => start(const []));
    await show(
      tester,
      SingleChildScrollView(
        child: ReceiveFromChain(bridge: bridge, onOpenSwap: (_) {}),
      ),
    );
    await quote(tester, '0.01');
    Finder create() => find.widgetWithText(PillButton, Copy.addressCheckWait);

    // While the scan runs, the button says so and does nothing.
    scanner.hold = Completer<void>();
    await review(tester, _fresh);
    expect(find.text(Copy.addressChecking), findsOneWidget);
    expect(create(), findsOneWidget);
    expect(tester.widget<PillButton>(create()).busy, isTrue);
    expect(find.text(Copy.bridgeCreate), findsNothing);

    // A failed scan says why, offers to check again, and lets the user go on.
    scanner.failure = const BridgeException(BridgeFailure.relayDown, 'The relay did not answer.');
    scanner.hold!.complete();
    scanner.hold = null;
    await tester.pump();
    await tester.pump();
    expect(find.text(Copy.addressCheckAgain), findsOneWidget);
    expect(find.text(Copy.bridgeCreate), findsOneWidget);
    // Without its scan, the refund address is not checked, so the card says so instead of "All clear".
    expect(find.text(Copy.privacyRefundUnchecked), findsOneWidget);
    expect(find.text(Copy.privacyNotChecked(1)), findsOneWidget);
    await tester.tap(find.text(Copy.addressCheckAgain));
    await tester.pump();
    await tester.pump();
    expect(scanner.asked, [_fresh, _fresh]);
    expect(find.text(Copy.payRecipientFresh), findsOneWidget);
    expect(find.text(Copy.bridgeCreate), findsOneWidget);
    expect(relay.refunds, isEmpty, reason: 'the check asks the exchanger for nothing');
  });

  testWidgets('a refund address of an earlier receive, or one whose history names an exchange, warns too', (
    tester,
  ) async {
    await tester.runAsync(
      () => start(
        const [],
        swaps: [
          BridgeSwap(
            id: 'receive0',
            asset: BridgeAsset.usdg,
            amount: 25,
            xmrAmount: 0.07,
            depositAddress: _deposit,
            payoutAddress: 'subaddress-4',
            subaddressIndex: 4,
            createdAt: DateTime.now().subtract(const Duration(days: 4)),
            stage: SwapStage.finished,
            refundAddress: _fresh,
            closed: true,
          ),
        ],
      ),
    );
    await show(
      tester,
      SingleChildScrollView(
        child: ReceiveFromChain(bridge: bridge, onOpenSwap: (_) {}),
      ),
    );
    await quote(tester, '0.01');

    // Used again, the refund address ties both receives together.
    await review(tester, _fresh);
    await tester.pump();
    expect(find.text(Copy.privacyRefundReused('4 days ago')), findsOneWidget);
    expect(find.text(Copy.privacyWarnings(1)), findsOneWidget);
    await tester.tap(find.text(Copy.back));
    await tester.pump();

    // A new address whose public history names an exchange ties this receive to it.
    scanner.exchangeFunded.add(_other);
    await review(tester, _other);
    await tester.pump();
    await tester.pump();
    expect(find.text(Copy.privacyRefundHistory), findsOneWidget);
    expect(find.text(Copy.privacyWarnings(1)), findsOneWidget);
  });

  testWidgets('the receive page checks its subaddress before the user hands it out', (tester) async {
    await tester.runAsync(() => start(const [2, 2]));
    await show(
      tester,
      ListenableBuilder(
        listenable: wallet,
        builder: (context, _) => ReceivePage(controller: wallet, bridge: bridge),
      ),
    );
    expect(find.text(Copy.privacySubaddressShared(2, 2)), findsOneWidget);
    expect(find.text(Copy.privacyWarnings(1)), findsOneWidget);
    expect(find.text(Copy.privacyAfterXmr(AppConfig.privacyFreshWindow.inHours)), findsOneWidget);

    // A new subaddress took no payment yet.
    await tester.tap(find.text(Copy.newAddress));
    for (var round = 0; round < 40 && find.text(Copy.privacySubaddressUnused(3)).evaluate().isEmpty; round++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    }
    expect(find.text(Copy.privacySubaddressUnused(3)), findsOneWidget);
    expect(find.text(Copy.privacyClear), findsOneWidget);
  });

  testWidgets('before the wallet caught up, a subaddress without a payment is not checked yet', (tester) async {
    await tester.runAsync(() => start(const [], synchronized: false));
    await show(tester, ReceivePage(controller: wallet, bridge: bridge));
    expect(find.text(Copy.privacySubaddressUnchecked(2)), findsOneWidget);
    expect(find.text(Copy.privacyNotChecked(1)), findsOneWidget);
    expect(find.text(Copy.privacyClear), findsNothing);
  });

  testWidgets('one payment to the subaddress is a tip, since the same payer may pay again', (tester) async {
    await tester.runAsync(() => start(const [2]));
    await show(tester, ReceivePage(controller: wallet, bridge: bridge));
    expect(find.text(Copy.privacySubaddressOnce(2)), findsOneWidget);
    expect(find.text(Copy.privacyClear), findsOneWidget);
  });
}
