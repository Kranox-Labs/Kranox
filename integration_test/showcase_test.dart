// Draws the screens of the app with sample data for the pictures of the site, in the frame of the macOS window:
// the open wallet with a large balance and recent activity, receive, the review of a payment, settings, activity,
// the lock, the welcome, and the restore. It also draws the QR code of the sample subaddress alone, as the receive
// page draws it, for the receive widget of the site. The screens are the screens of the app; only the answers of
// the wallet engine are samples, so the run needs no node and no Monero library. Run in apps/wallet:
//   fvm flutter test integration_test/showcase_test.dart -d flutter-tester
// The test writes the pictures to build/showcase/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kranox_wallet/app.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/bridge/controller.dart';
import 'package:kranox_wallet/bridge/models.dart';
import 'package:kranox_wallet/bridge/store.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/ui/copy.dart';
import 'package:kranox_wallet/ui/format.dart';
import 'package:kranox_wallet/ui/theme/metrics.dart';
import 'package:kranox_wallet/ui/theme/palette.dart';
import 'package:kranox_wallet/ui/theme/typography.dart';
import 'package:kranox_wallet/ui/widgets/field.dart';
import 'package:kranox_wallet/ui/widgets/sidebar.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/settings.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The window of the app when it opens, as in macos/Runner/MainFlutterWindow.swift, on a sharp screen.
const Size _windowSize = Size(1200, 800);
const double _pixelRatio = 2;

/// The window of macOS 26 with a toolbar rounds its corners by about this much and draws a thin light edge.
const double _windowRadius = 26;
const Color _windowEdge = Color(0x29FFFFFF);

/// The window buttons as macOS draws them: 14 points wide and 6 apart, the first one 19 points from the top and
/// the left edge, as measured on 4 Oct 2026 for the unified toolbar.
const double _buttonSize = 14;
const double _buttonGap = 6;
const double _buttonInset = 19;
const List<Color> _buttonColors = [Color(0xFFFF5F57), Color(0xFFFEBC2E), Color(0xFF28C840)];

const Duration _frame = Duration(milliseconds: 100);
const Duration _patience = Duration(seconds: 30);

/// The QR code of the receive widget, in points, and the white margin around it that a scanner needs.
const double _qrSize = 240;
const double _qrQuietZone = 16;

/// A mainnet address of a throwaway wallet, as in test/core/address_test.dart: the recipient of the sample payment.
const String _recipientAddress =
    '48PFnHrr8bVGx463yo8SMXGZUp7PyYPgwZJR4MnpgjKCDXpw3XvK6UTbarKkpwaPbPSYSdJ4rozjZjGxr2t3qVP4B4DzzVs';

/// A mainnet subaddress of a throwaway wallet, as in test/core/address_test.dart: the receive address of the sample.
const String _sampleAddress =
    '883z7Wmbd5nhoH6xQxLzgniNhN6jqdvxFiza4rMdErWA1XW1TCL1tqrCwWFwhG1QkuL17RRHP45J33y6u4sH8Rfa7kryRza';

/// A stagenet subaddress of a throwaway wallet for the QR code of the receive widget of the site. A code on the site
/// that anyone can scan must never take real XMR, so it holds a stagenet address.
const String _qrAddress =
    '7BNzVRGC5eFgRd1oQzSiTN3bpUQyH8MELWpBLU8TDHZaCswUbfDnZKnUaKVC6F4SWcNCbLtC8s9FctBAqKwg2ygJCL4H5h';

XmrAmount _xmr(String text) => XmrAmount.parse(text);

/// The pictures show the app on mainnet, as the release 0.1.0 starts, so the sample addresses belong to mainnet.
const MoneroNetwork _network = MoneroNetwork.mainnet;
const AppSettings _settings = AppSettings(network: _network);

/// The answers of a wallet that holds a large balance and has paid and been paid a few times.
final class _SampleBackend implements WalletBackend {
  _SampleBackend(this._now);

  final DateTime _now;
  PreparedSend? _prepared;

  // The height of mainnet: CHECKED 5 Oct 2026, source get_info of xmr-node.cakewallet.com:18081.
  static const int _height = 3777437;

  // The confirmations of the sample payment to Robinhood Chain in the pictures of its card.
  static const int _sentConfirmations = 3;

  // Four transfers: the home page shows them all without cutting the last one at the foot of the window.
  late final List<WalletTransfer> _history = [
    _transfer('9c41', TransferDirection.incoming, '11.5', const Duration(minutes: 25), confirmations: 4, subaddress: 3),
    _transfer('5be2', TransferDirection.outgoing, '2.75', const Duration(hours: 5, minutes: 40), confirmations: 170),
    _transfer(
      'e07d',
      TransferDirection.incoming,
      '120',
      const Duration(days: 1, hours: 2),
      confirmations: 780,
      subaddress: 2,
    ),
    _transfer('31aa', TransferDirection.outgoing, '0.84', const Duration(days: 2, hours: 4), confirmations: 1560),
  ];

  WalletTransfer _transfer(
    String seed,
    TransferDirection direction,
    String amount,
    Duration age, {
    required int confirmations,
    int? subaddress,
  }) => WalletTransfer(
    hash: seed * 16,
    direction: direction,
    amount: _xmr(amount),
    fee: direction == TransferDirection.outgoing ? _xmr('0.0000312') : XmrAmount.zero,
    time: _now.subtract(age),
    blockHeight: _height - confirmations + 1,
    confirmations: confirmations,
    isPending: false,
    isFailed: false,
    subaddressIndex: subaddress,
  );

  /// Sends the prepared payment, which the history then holds with a few confirmations.
  SentPayment _send() {
    final prepared = _prepared!;
    _history.insert(
      0,
      WalletTransfer(
        hash: _samplePayinHash,
        direction: TransferDirection.outgoing,
        amount: prepared.amount,
        fee: prepared.fee,
        time: _now,
        blockHeight: _height - _sentConfirmations + 1,
        confirmations: _sentConfirmations,
        isPending: false,
        isFailed: false,
        subaddressIndex: null,
      ),
    );
    return SentPayment(transactionId: _samplePayinHash, amount: prepared.amount, fee: prepared.fee);
  }

  @override
  Future<T> call<T>(WalletRequest request) async {
    final Object? answer = switch (request) {
      OpenWallet() || ConnectNode() || StoreWallet() || CloseWallet() => null,
      ReadReceiveAddress() || ReadSubaddress() => const ReceiveAddress(address: _sampleAddress, index: 4),
      PrepareSend(:final address, :final amountUnits) => _prepared = PreparedSend(
        id: 1,
        address: address,
        amount: XmrAmount(amountUnits),
        fee: _xmr('0.0000312'),
      ),
      ConfirmSend() => _send(),
      CancelSend() => null,
      ReadFileKeys() => FileKeys(key: Uint8List(32)),
      ReadHistory() => _history,
      ReadStatus() => WalletStatus(
        balance: _xmr('1286.4219'),
        unlocked: _xmr('1274.9219'),
        walletHeight: _height,
        nodeHeight: _height,
        synchronized: true,
        connection: NodeConnection.connected,
      ),
      _ => throw UnsupportedError('The sample wallet does not answer ${request.runtimeType}.'),
    };
    return answer as T;
  }

  @override
  void stop() {}
}

/// XMR for one ETH, from the prices of 5 Oct 2026 (CoinGecko: ETH 2,727.50 USD, XMR 547.88 USD), for the sample quote.
const double _xmrPerEth = 4.978;

/// The least ETH that the sample exchanger takes for XMR.
const double _minEth = 0.0041715;

/// A sample deposit address on Robinhood Chain for the picture of an open swap. It belongs to no known wallet.
const String _sampleDeposit = '0x7A3Fc0E1b9D24a6C58E0F3B1d9A7C4e2F6B8D015';

/// Sample transaction hashes for the pictures of the steps of a swap. They belong to no known transaction.
const String _sampleDepositHash = '0x946f9c2d7be41a0c58f3e1b9d24a6c58e0f3b1d9a7c4e2f6b8d015a3c78bdce6';
const String _samplePayoutHash = 'c4f27a91e05b3d6f8a2c71e94d0b5f3a6e8c2d17b94f0a3e5c6d81b2a7f94e03';
const String _sampleRefundHash = '0x2b7e91c4d05f3a6e8c2d17b94f0a3e5c6d81b2a7f94e03c4f27a91e05b3d6f8a';
const String _sampleRefundAddress = '0x57f31ad4b64095347F87eDB1675566DAfF5EC886';

/// The recipient of the sample payment to Robinhood Chain: the first example of EIP-55, in its mixed case.
const String _payRecipient = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';

/// Sample hashes of the payment to Robinhood Chain: the XMR that the wallet sends, and the coin at the recipient. They
/// belong to no known transaction.
const String _samplePayinHash = '7d0e94b1c3a52f68e0d9b4a17c3e5f2a9b8c6d4e1f0a3b5c7d9e2f4a6b8c0d1e3';
const String _sampleChainHash = '0x5c8e2a7b9d14f03e6a2c8b5d7e9f1a3c5e7b9d0f2a4c6e8b1d3f5a7c9e0b2d4f';

/// The XMR for one coin of a payment at a fixed rate. CHECKED 5 Oct 2026, the fixed-rate estimates of ChangeNOW: 80
/// USDG for 0.15366631 XMR, and 0.03 ETH for 0.15475806 XMR.

/// The XMR of the sample payment to Robinhood Chain.
const String _payXmr = '0.15';
const Map<BridgeAsset, double> _payXmrPerCoin = {BridgeAsset.usdg: 0.15366631 / 80, BridgeAsset.eth: 0.15475806 / 0.03};

/// The answers of the exchanger for the pictures: a quote at the prices of 5 Oct 2026, and swaps whose state the test
/// sets step by step.
final class _SampleBridge implements BridgeClient {
  SwapState state = const SwapState(stage: SwapStage.waiting);
  int _swaps = 0;

  // Below the minimum the relay gives the minimum alone, without an estimate.
  @override
  Future<BridgeQuote> quote(BridgeAsset asset, String amount) async => BridgeQuote(
    asset: asset,
    amount: amount,
    minAmount: _minEth,
    estimatedXmr: double.parse(amount) < _minEth ? null : double.parse(amount) * _xmrPerEth,
    speedMinutes: '10-60',
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
    id: '9f4e2c71b03ad${++_swaps}',
    amount: double.parse(amount),
    estimatedXmr: double.parse(amount) * _xmrPerEth,
    depositAddress: _sampleDeposit,
    payoutAddress: address,
    refundAddress: refundAddress,
  );

  // The range of one payment at a fixed rate. CHECKED 6 Oct 2026, the range of ChangeNOW for XMR into ETH: 0.02267982 to
  // 1.451521737121 XMR.
  // CHECKED the same day, the floating rate: from 0.0118679 XMR, without a top.
  @override
  Future<PayRange> payRange(BridgeAsset asset, PayRate rate) async => switch (rate) {
    PayRate.fixed => PayRange(asset: asset, rate: rate, minXmr: 0.02267982, maxXmr: 1.451521737121),
    PayRate.floating => PayRange(asset: asset, rate: rate, minXmr: 0.0118679, maxXmr: null),
  };

  @override
  Future<PayQuote> payQuote(BridgeAsset asset, PayRate rate, String xmrAmount) async {
    final xmr = double.parse(xmrAmount);
    final range = await payRange(asset, rate);
    if (xmr < range.minXmr) {
      return PayQuote(
        asset: asset,
        rate: rate,
        xmrAmount: xmrAmount,
        amount: null,
        rateId: null,
        validUntil: null,
        warning: null,
        limit: PayLimit.below,
        minXmr: range.minXmr,
        maxXmr: range.maxXmr,
      );
    }
    return _quoteAt(asset, rate, xmrAmount);
  }

  // The fees of ChangeNOW: CHECKED 6 Oct 2026, 0.006 XMR for the deposit and 0.7370513 USDG for the payout.
  PayQuote _quoteAt(BridgeAsset asset, PayRate rate, String xmrAmount) => PayQuote(
    asset: asset,
    rate: rate,
    depositFee: 0.006,
    withdrawalFee: 0.7370513,
    xmrAmount: xmrAmount,
    amount: double.parse(xmrAmount) / _payXmrPerCoin[asset]!,
    rateId: rate == PayRate.fixed ? 'sample-rate' : null,
    validUntil: null,
    warning: null,
    limit: null,
    minXmr: null,
    maxXmr: null,
  );

  // The sample deposit address of the exchanger is the mainnet address of the throwaway wallet.
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
    id: '7b2d91e04c5fa${++_swaps}',
    amount: double.parse(xmrAmount) / _payXmrPerCoin[asset]!,
    xmrAmount: double.parse(xmrAmount),
    depositAddress: _recipientAddress,
    payoutAddress: address,
    refundAddress: refundAddress,
  );

  @override
  Future<SwapState> readSwap(String id, {String? token}) async => state;

  @override
  Future<bool> isOnline() async => true;
}

/// The three window buttons at the top left of the window.
class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context) => Row(
    textDirection: TextDirection.ltr,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (index, color) in _buttonColors.indexed) ...[
        if (index > 0) const SizedBox(width: _buttonGap),
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: _buttonSize),
        ),
      ],
    ],
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('draws the screens of the app with sample data', (tester) async {
    tester.view.physicalSize = _windowSize * _pixelRatio;
    tester.view.devicePixelRatio = _pixelRatio;
    addTearDown(tester.view.reset);
    final font = FontLoader(KranoxType.family)..addFont(rootBundle.load('assets/fonts/archivo/Archivo-Variable.ttf'));
    await font.load();
    final out = Directory('${Directory.current.path}/build/showcase')..createSync(recursive: true);
    final frame = GlobalKey();

    Future<void> show(WalletController controller, BridgeController bridge) => tester.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_windowRadius),
          child: Stack(
            textDirection: TextDirection.ltr,
            children: [
              KranoxApp(controller: controller, bridge: bridge),
              const Positioned(left: _buttonInset, top: _buttonInset, child: _WindowButtons()),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_windowRadius),
                      border: Border.all(color: _windowEdge),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Future<void> waitFor(Finder finder) async {
      final deadline = DateTime.now().add(_patience);
      while (finder.evaluate().isEmpty) {
        if (DateTime.now().isAfter(deadline)) fail('The screen did not show $finder.');
        await tester.pump(_frame);
      }
    }

    // A moving part, such as a toast, is drawn without the pause, before it goes.
    Future<void> shoot(String name, {bool settle = true}) async {
      // The pictures of the ground and the logo decode off the frame; give them a moment.
      if (settle) await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await tester.pump(_frame);
      final boundary = frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: _pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/wallet-$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    // A button below the window scrolls into view first, as the user scrolls to it.
    Future<void> tapInView(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump(_frame);
      await tester.tap(finder);
    }

    Future<void> openPage(String label) async {
      await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text(label)));
      await tester.pump(_frame);
    }

    // The open wallet. A keys file makes the app find a wallet, so it asks for the password and opens the sample.
    final root = Directory.systemTemp.createTempSync('kranox-showcase');
    final storage = AppStorage(root.path);
    await storage.writeSettings(_settings);
    await storage.prepareWalletFolder(_network);
    File('${storage.walletPath(_network)}.keys').createSync();
    final controller = WalletController(worker: _SampleBackend(DateTime.now()), storage: storage);
    await controller.start();
    await controller.unlock('sample');
    expect(controller.phase, WalletPhase.open);
    final bridge = BridgeController(
      client: _SampleBridge(),
      store: BridgeStore(storage.bridgePath),
      wallet: controller,
    );
    await bridge.start();
    await show(controller, bridge);
    await waitFor(find.text(Copy.balance.toUpperCase()));
    await shoot('home');

    await openPage(Copy.navReceive);
    await waitFor(find.text(Copy.newAddress));
    await shoot('receive');
    // The toast of a copy at the foot of the page. The clipboard of the test takes the text without a platform.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    await tester.tap(find.text(Copy.copyAddress));
    await tester.pump(Metrics.toastFade + _frame);
    await shoot('receive-copied', settle: false);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);

    await openPage(Copy.navSend);
    await tester.enterText(find.byType(TextField).at(0), _recipientAddress);
    await tester.enterText(find.byType(TextField).at(1), '25');
    await tester.pump(_frame);
    await tester.tap(find.text(Copy.review));
    await waitFor(find.text(Copy.reviewTitle));
    await shoot('send-review');

    await openPage(Copy.navActivity);
    await tester.pump(_frame);
    await shoot('activity');

    await openPage(Copy.navSettings);
    await waitFor(find.text(Copy.settingsLead));
    await shoot('settings');

    await openPage(Copy.navLock);
    await waitFor(find.text(Copy.unlockTitle));
    await shoot('unlock');
    await controller.shutdown();

    // A device without a wallet: the welcome and the restore.
    final emptyRoot = Directory.systemTemp.createTempSync('kranox-showcase-empty');
    final emptyStorage = AppStorage(emptyRoot.path);
    await emptyStorage.writeSettings(_settings);
    final newcomer = WalletController(worker: _SampleBackend(DateTime.now()), storage: emptyStorage);
    await newcomer.start();
    final newcomerBridge = BridgeController(
      client: _SampleBridge(),
      store: BridgeStore(emptyStorage.bridgePath),
      wallet: newcomer,
    );
    await show(newcomer, newcomerBridge);
    await waitFor(find.text(Copy.createWallet));
    await shoot('welcome');
    await tester.tap(find.text(Copy.restoreWallet));
    await tester.pump(_frame);
    await shoot('restore');

    // Receive from Robinhood Chain on mainnet, where the exchanger works: a quote for 0.0055 ETH, then the open swap.
    final mainnetRoot = Directory.systemTemp.createTempSync('kranox-showcase-mainnet');
    final mainnetStorage = AppStorage(mainnetRoot.path);
    await mainnetStorage.prepareWalletFolder(MoneroNetwork.mainnet);
    File('${mainnetStorage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
    final mainnet = WalletController(worker: _SampleBackend(DateTime.now()), storage: mainnetStorage);
    await mainnet.start();
    await mainnet.unlock('sample');
    final sampleBridge = _SampleBridge();
    final mainnetBridge = BridgeController(
      client: sampleBridge,
      store: BridgeStore(mainnetStorage.bridgePath),
      wallet: mainnet,
    );
    await mainnetBridge.start();
    await show(mainnet, mainnetBridge);
    await waitFor(find.text(Copy.balance.toUpperCase()));
    await openPage(Copy.navReceive);
    await tester.tap(find.text(Copy.receiveChainTab.toUpperCase()));
    await waitFor(find.text(Copy.bridgeYouSend.toUpperCase()));
    // The XMR that the sample amount of 0.006 ETH buys.
    final estimate = find.text(Copy.about(formatDecimal(0.006 * _xmrPerEth)));
    Future<void> swapAt(SwapState state, String name) async {
      sampleBridge.state = state;
      await mainnetBridge.refresh();
      await tester.pump(_frame);
      await shoot(name);
    }

    await tester.enterText(find.byType(TextField).first, '0.001');
    await waitFor(find.textContaining('Below the minimum'));
    await shoot('receive-chain-minimum');
    await tester.enterText(find.byType(TextField).first, '0.006');
    await waitFor(estimate);
    await shoot('receive-chain-quote');
    // The review with the privacy check of the receive comes before the exchanger makes the deposit address.
    await tester.tap(find.text(Copy.bridgeReview));
    await waitFor(find.text(Copy.receiveReviewTitle));
    await shoot('receive-chain-review');
    // The review is taller than the window, so its button scrolls into view first.
    await tester.ensureVisible(find.text(Copy.bridgeCreate));
    await tester.tap(find.text(Copy.bridgeCreate));
    await waitFor(find.text(Copy.bridgeStepWaiting));
    await tester.pump(_frame);
    expect(find.text(Copy.bridgeCreate), findsNothing);
    await shoot('receive-chain-waiting');
    await swapAt(
      const SwapState(stage: SwapStage.confirming, expectedOut: 0.0205789, depositHash: _sampleDepositHash),
      'receive-chain-confirming',
    );
    await swapAt(
      const SwapState(
        stage: SwapStage.finished,
        amountOut: 0.0205214,
        depositHash: _sampleDepositHash,
        payoutHash: _samplePayoutHash,
      ),
      'receive-chain-done',
    );

    // A swap that fails after the deposit, and its refund.
    await tester.tap(find.text(Copy.bridgeClose));
    await waitFor(find.text(Copy.bridgeYouSend.toUpperCase()));
    sampleBridge.state = const SwapState(stage: SwapStage.waiting);
    await tester.enterText(find.byType(TextField).first, '0.006');
    await waitFor(estimate);
    await tester.tap(find.text(Copy.bridgeReview));
    await waitFor(find.text(Copy.receiveReviewTitle));
    // The review is taller than the window, so its button scrolls into view first.
    await tester.ensureVisible(find.text(Copy.bridgeCreate));
    await tester.tap(find.text(Copy.bridgeCreate));
    await waitFor(find.text(Copy.bridgeStepWaiting));
    await swapAt(const SwapState(stage: SwapStage.confirming, depositHash: _sampleDepositHash), 'receive-chain-step');
    await swapAt(const SwapState(stage: SwapStage.failed, depositHash: _sampleDepositHash), 'receive-chain-failed');
    await swapAt(
      const SwapState(
        stage: SwapStage.refunded,
        refundAddress: _sampleRefundAddress,
        refundHash: _sampleRefundHash,
        refundAmount: 0.0058,
      ),
      'receive-chain-refunded',
    );
    // Pay to Robinhood Chain: the USDG that 0.15 XMR buys at a fixed rate, the review, and the payment on its way and
    // at its end.
    await openPage(Copy.navSend);
    // The steps of the feature video of pay, in the order of a user: the send page as it opens, the empty form of pay,
    // the amount with its quote at each rate, and the form scrolled to the recipient, before and after a paste.
    final quotedUsdg = find.text(formatDecimal(double.parse(_payXmr) / _payXmrPerCoin[BridgeAsset.usdg]!, decimals: 8));
    await waitFor(find.text(Copy.sendMoneroTab.toUpperCase()));
    await shoot('send');
    await tester.tap(find.text(Copy.sendChainTab.toUpperCase()));
    await waitFor(find.text(Copy.payTheyReceive.toUpperCase()));
    await waitFor(find.textContaining('Minimum payment'));
    await shoot('send-chain-empty');
    await tester.enterText(find.byType(TextField).at(0), _payXmr);
    await waitFor(quotedUsdg);
    await shoot('send-chain-amount');
    await tester.tap(find.text(Copy.payRateFloating));
    await waitFor(find.text(Copy.payTheyReceiveAbout.toUpperCase()));
    await shoot('send-chain-amount-floating');
    await tester.tap(find.text(Copy.payRateFixed));
    await waitFor(quotedUsdg);
    await tester.ensureVisible(find.text(Copy.payEnterRecipient));
    await tester.pump(_frame);
    await shoot('send-chain-scrolled');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData' ? <String, Object?>{'text': _payRecipient} : null,
    );
    await tester.tap(find.text(Copy.paste));
    await waitFor(find.text(Copy.payRecipientValid));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await shoot('send-chain-ready');
    // The pictures that follow show the form from its top.
    final payPage = find.ancestor(of: find.text(Copy.payRateTitle.toUpperCase()), matching: find.byType(Scrollable));
    tester.state<ScrollableState>(payPage.first).position.jumpTo(0);
    await tester.pump(_frame);
    await tester.enterText(find.byType(TextField).at(1), _payRecipient);
    await tester.enterText(find.byType(TextField).at(0), '0.01');
    await waitFor(find.textContaining('Below the minimum payment'));
    await shoot('send-chain-minimum');
    await tester.enterText(find.byType(TextField).at(0), '0.015');
    await waitFor(find.textContaining('Switch to a floating rate'));
    await tester.tap(find.textContaining('Switch to a floating rate'));
    await waitFor(find.text(Copy.payTheyReceiveAbout.toUpperCase()));
    await waitFor(find.textContaining('ChangeNOW fees'));
    await shoot('send-chain-floating');
    await tester.tap(find.text(Copy.payRateFixed));
    await tester.enterText(find.byType(TextField).at(0), _payXmr);
    await waitFor(quotedUsdg);
    await shoot('send-chain-quote');
    // The menu of the coin, open below the coin; choosing the same coin closes it.
    await tester.tap(find.text(BridgeAsset.usdg.label).first);
    await tester.pumpAndSettle();
    await shoot('send-chain-coins');
    await tester.tap(find.text(BridgeAsset.usdg.label).last);
    await tester.pumpAndSettle();
    sampleBridge.state = SwapState(
      stage: SwapStage.waiting,
      validUntil: DateTime.now().add(const Duration(minutes: 10)),
    );
    await tapInView(find.text(Copy.review));
    await waitFor(find.text(Copy.payNow));
    // The button waits for the password of the wallet; the sample engine takes any.
    await tester.enterText(
      find.descendant(of: find.widgetWithText(LabeledField, Copy.sendPassword), matching: find.byType(TextField)),
      'sample',
    );
    await tester.pump(_frame);
    await shoot('send-chain-review');
    await tapInView(find.text(Copy.payNow));
    await waitFor(find.text(Copy.payStepWaiting));
    await tester.pump(_frame);
    await shoot('send-chain-waiting');
    await swapAt(const SwapState(stage: SwapStage.confirming, depositHash: _samplePayinHash), 'send-chain-confirming');
    await swapAt(const SwapState(stage: SwapStage.exchanging, depositHash: _samplePayinHash), 'send-chain-exchanging');
    await swapAt(
      const SwapState(stage: SwapStage.finished, depositHash: _samplePayinHash, payoutHash: _sampleChainHash),
      'send-chain-done',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    mainnetBridge.dispose();
    await mainnet.shutdown();
    mainnetRoot.deleteSync(recursive: true);

    // The QR code of the sample subaddress, on white, as the receive page draws it. Its label for assistive
    // technology needs a reading direction.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: frame,
            child: ColoredBox(
              color: BrandColors.white,
              child: Padding(
                padding: const EdgeInsets.all(_qrQuietZone),
                child: QrImageView(
                  data: _qrAddress,
                  size: _qrSize,
                  padding: EdgeInsets.zero,
                  backgroundColor: BrandColors.white,
                  eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: BrandColors.coal),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: BrandColors.coal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await shoot('qr');

    debugPrint('Pictures of the screens (${_network.label}): ${out.path}');
    newcomer.dispose();
    bridge.dispose();
    newcomerBridge.dispose();
    root.deleteSync(recursive: true);
    emptyRoot.deleteSync(recursive: true);
  });
}
