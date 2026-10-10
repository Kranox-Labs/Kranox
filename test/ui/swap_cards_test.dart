import 'dart:io';
import 'dart:typed_data';

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
import 'package:kranox_wallet/ui/screens/receive_page.dart';
import 'package:kranox_wallet/ui/theme/kranox_theme.dart';
import 'package:kranox_wallet/ui/theme/palette.dart';
import 'package:kranox_wallet/ui/widgets/qr_card.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

/// Deposit addresses on Robinhood Chain from the examples of EIP-55: one for each swap that the test starts with, and
/// one for the swap that it makes.
const _depositNew = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
const _depositRunning = '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359';
const _depositOlder = '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB';
const _depositExpired = '0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb';

/// A synced wallet without history.
final class _Wallet implements WalletBackend {
  int _subaddress = 1;

  @override
  Future<T> call<T>(WalletRequest request) async {
    final Object? answer = switch (request) {
      ReadStatus() => WalletStatus(
        balance: XmrAmount.zero,
        unlocked: XmrAmount.zero,
        walletHeight: 100,
        nodeHeight: 100,
        synchronized: true,
        connection: NodeConnection.connected,
      ),
      ReadHistory() => const <WalletTransfer>[],
      ReadReceiveAddress(:final createNew) => ReceiveAddress(
        address: 'subaddress-${createNew ? ++_subaddress : _subaddress}',
        index: _subaddress,
      ),
      ReadSubaddress(:final index) => ReceiveAddress(address: 'subaddress-$index', index: index),
      ReadFileKey() => Uint8List(32),
      _ => null,
    };
    return answer as T;
  }

  @override
  void stop() {}
}

/// The relay: a quote for any amount, one new swap, and the state that [states] gives each swap.
final class _Relay implements BridgeClient {
  final Map<String, SwapStage> states = {};

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
  }) async => CreatedSwap(
    id: 'new',
    amount: double.parse(amount),
    estimatedXmr: 0.0358,
    depositAddress: _depositNew,
    payoutAddress: address,
    refundAddress: refundAddress,
    readToken: 'token',
  );

  @override
  Future<SwapState> readSwap(String id, {String? token}) async => SwapState(stage: states[id] ?? SwapStage.waiting);

  @override
  Future<bool> isOnline() async => true;

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError('The cards ask for nothing else.');
}

BridgeSwap _swap(String id, String deposit, double amount, Duration age, SwapStage stage) => BridgeSwap(
  id: id,
  asset: BridgeAsset.usdg,
  amount: amount,
  xmrAmount: 0.1,
  depositAddress: deposit,
  payoutAddress: 'subaddress-$amount',
  subaddressIndex: 2,
  createdAt: DateTime.now().subtract(age),
  stage: stage,
);

void main() {
  late Directory root;
  late WalletController wallet;
  late BridgeController bridge;
  late _Relay relay;

  /// A wallet whose bridge holds [swaps], the newest first.
  Future<void> start(List<BridgeSwap> swaps) async {
    root = Directory.systemTemp.createTempSync('kranox-swap-cards');
    final storage = AppStorage(root.path);
    await storage.prepareWalletFolder(MoneroNetwork.mainnet);
    File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
    final store = BridgeStore(storage.bridgePath);
    await store.read(Uint8List(32));
    await store.write(swaps);
    wallet = WalletController(worker: _Wallet(), storage: storage);
    await wallet.start();
    await wallet.unlock('password');
    relay = _Relay();
    for (final swap in swaps) {
      relay.states[swap.id] = swap.stage;
    }
    bridge = BridgeController(client: relay, store: store, wallet: wallet);
    await bridge.start();
  }

  tearDown(() async {
    bridge.dispose();
    await wallet.lock();
    wallet.dispose();
    root.deleteSync(recursive: true);
  });

  /// The receive page, which opens on the receive from Robinhood Chain while a swap runs. A click on Receive in the
  /// sidebar adds one to [reselect].
  Future<void> show(WidgetTester tester, ValueNotifier<int> reselect) async {
    await tester.binding.setSurfaceSize(const Size(1200, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: KranoxTheme.build(Palette.of(activeLook)),
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: reselect,
            builder: (context, clicks, _) => ReceivePage(controller: wallet, bridge: bridge, reselect: clicks),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Taps [finder] and waits for what it changes on the disk, such as the file of the swaps.
  Future<void> tapAndSave(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();
  }

  /// The deposit address that the page of a swap shows, once its code shows the address alone.
  Future<String> deposit(WidgetTester tester) async {
    await tester.tap(find.text(Copy.bridgeAddressOnly));
    await tester.pump();
    return tester.widget<QrCard>(find.byType(QrCard)).data!;
  }

  testWidgets('each open swap has a simple card under the form, and a click opens its page', (tester) async {
    await tester.runAsync(
      () => start([
        _swap('running', _depositRunning, 25, const Duration(minutes: 5), SwapStage.waiting),
        _swap('older', _depositOlder, 30, const Duration(hours: 2), SwapStage.waiting),
        _swap('expired', _depositExpired, 40, const Duration(days: 2), SwapStage.expired),
      ]),
    );
    final reselect = ValueNotifier(0);
    await show(tester, reselect);

    // The form stays on top, and the cards under it show no steps and no deposit.
    expect(find.text(Copy.bridgeReview), findsOneWidget);
    expect(find.text(Copy.bridgeOpenSwaps(3).toUpperCase()), findsOneWidget);
    expect(find.byType(QrCard), findsNothing);
    expect(find.textContaining('${Copy.bridgeStepWaiting} · Started'), findsNWidgets(2));
    expect(find.textContaining('${Copy.bridgeStepExpired} · Started'), findsOneWidget);

    // A card opens the page of its swap, with its deposit, and the way back leads to the form.
    await tester.tap(find.text(Copy.bridgeSwapTitle('30', BridgeAsset.usdg)).first);
    await tester.pump();
    expect(find.text(Copy.bridgeReview), findsNothing);
    expect(find.text(Copy.bridgeSwapTitle('30', BridgeAsset.usdg)), findsOneWidget);
    expect(await deposit(tester), _depositOlder);
    await tester.tap(find.text(Copy.navReceive));
    await tester.pump();
    expect(find.text(Copy.bridgeReview), findsOneWidget);

    // A click on Receive in the sidebar leaves the page of a swap too.
    await tester.tap(find.text(Copy.bridgeSwapTitle('25', BridgeAsset.usdg)).first);
    await tester.pump();
    expect(await deposit(tester), _depositRunning);
    reselect.value++;
    await tester.pump();
    expect(find.text(Copy.bridgeReview), findsOneWidget);

    // An expired swap shows no deposit, says not to send, and its card closes, which leads back to the form.
    await tester.tap(find.text(Copy.bridgeSwapTitle('40', BridgeAsset.usdg)).first);
    await tester.pump();
    expect(find.text(Copy.bridgeExpired(BridgeAsset.usdg)), findsOneWidget);
    expect(find.byType(QrCard), findsNothing);
    expect(find.text(Copy.bridgeRefresh), findsNothing, reason: 'an ended swap has nothing left to check');
    await tapAndSave(tester, find.text(Copy.bridgeClose));
    expect(find.text(Copy.bridgeOpenSwaps(2).toUpperCase()), findsOneWidget);

    // Its line in the list still opens its page, without a card to close.
    await tester.tap(find.text(Copy.bridgeSwapLine('40', BridgeAsset.usdg)));
    await tester.pump();
    expect(find.text(Copy.bridgeExpired(BridgeAsset.usdg)), findsOneWidget);
    expect(find.text(Copy.bridgeClose), findsNothing);
  });

  testWidgets('a new swap opens its page at once, and the form starts empty for the next one', (tester) async {
    await tester.runAsync(
      () => start([_swap('running', _depositRunning, 25, const Duration(minutes: 5), SwapStage.waiting)]),
    );
    await show(tester, ValueNotifier(0));

    await tester.enterText(find.byType(TextField).first, '0.01');
    await tester.enterText(find.byType(TextField).at(1), _depositOlder);
    await tester.pump(AppConfig.bridgeQuoteDelay * 2);
    await tester.pump();
    await tester.tap(find.text(Copy.bridgeReview));
    await tester.pump();
    await tester.runAsync(() => tester.tap(find.text(Copy.bridgeCreate)));
    for (var round = 0; round < 40 && find.byType(QrCard).evaluate().isEmpty; round++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    }

    expect(await deposit(tester), _depositNew);
    await tester.tap(find.text(Copy.navReceive));
    await tester.pump();
    expect(find.text(Copy.bridgeOpenSwaps(2).toUpperCase()), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].controller!.text, isEmpty);
    expect(fields[1].controller!.text, isEmpty, reason: 'a refund address must not tie two swaps by mistake');
    // The emptied form asks for no quote, after the wait of the quote.
    await tester.pump(AppConfig.bridgeQuoteDelay * 2);
  });
}
