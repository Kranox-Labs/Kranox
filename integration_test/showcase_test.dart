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
import 'package:kranox_wallet/ui/theme/palette.dart';
import 'package:kranox_wallet/ui/theme/typography.dart';
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

  // The height of mainnet: CHECKED 5 Oct 2026, source get_info of xmr-node.cakewallet.com:18081.
  static const int _height = 3777437;

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

  @override
  Future<T> call<T>(WalletRequest request) async {
    final Object? answer = switch (request) {
      OpenWallet() || ConnectNode() || StoreWallet() || CloseWallet() => null,
      ReadReceiveAddress() => const ReceiveAddress(address: _sampleAddress, index: 4),
      PrepareSend(:final address, :final amountUnits) => PreparedSend(
        address: address,
        amount: XmrAmount(amountUnits),
        fee: _xmr('0.0000312'),
      ),
      CancelSend() => null,
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

/// A sample deposit address on Robinhood Chain for the picture of an open swap. It belongs to no known wallet.
const String _sampleDeposit = '0x7a3fC0e1b9D24A6c58E0f3B1d9a7C4e2F6b8D015';

/// Sample transaction hashes for the pictures of the steps of a swap. They belong to no known transaction.
const String _sampleDepositHash = '0x946f9c2d7be41a0c58f3e1b9d24a6c58e0f3b1d9a7c4e2f6b8d015a3c78bdce6';
const String _samplePayoutHash = 'c4f27a91e05b3d6f8a2c71e94d0b5f3a6e8c2d17b94f0a3e5c6d81b2a7f94e03';
const String _sampleRefundHash = '0x2b7e91c4d05f3a6e8c2d17b94f0a3e5c6d81b2a7f94e03c4f27a91e05b3d6f8a';
const String _sampleRefundAddress = '0x57f31ad4b64095347F87eDB1675566DAfF5EC886';

/// The answers of the exchanger for the pictures: a quote at the prices of 5 Oct 2026, and swaps whose state the test
/// sets step by step.
final class _SampleBridge implements BridgeClient {
  SwapState state = const SwapState(stage: SwapStage.waiting);
  int _swaps = 0;

  @override
  Future<BridgeQuote> quote(BridgeAsset asset, String amount) async => BridgeQuote(
    asset: asset,
    amount: amount,
    minAmount: 0.0041715,
    estimatedXmr: double.parse(amount) * _xmrPerEth,
    speedMinutes: '10-60',
    warning: null,
  );

  @override
  Future<CreatedSwap> createSwap({
    required BridgeAsset asset,
    required String amount,
    required String address,
    String? refundAddress,
  }) async => CreatedSwap(
    id: '9f4e2c71b03ad${++_swaps}',
    amount: double.parse(amount),
    estimatedXmr: double.parse(amount) * _xmrPerEth,
    depositAddress: _sampleDeposit,
    payoutAddress: address,
  );

  @override
  Future<SwapState> readSwap(String id) async => state;

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

    Future<void> shoot(String name) async {
      // The pictures of the ground and the logo decode off the frame; give them a moment.
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await tester.pump(_frame);
      final boundary = frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: _pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/wallet-$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
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
    await waitFor(find.text(Copy.bridgeFormTitle));
    Future<void> swapAt(SwapState state, String name) async {
      sampleBridge.state = state;
      await mainnetBridge.refresh();
      await tester.pump(_frame);
      await shoot(name);
    }

    await tester.enterText(find.byType(TextField).first, '0.006');
    await waitFor(find.textContaining('You get about'));
    await shoot('receive-chain-quote');
    await tester.tap(find.text(Copy.bridgeCreate));
    await waitFor(find.text(Copy.bridgeStepWaiting));
    await tester.pump(_frame);
    expect(find.text(Copy.bridgeFormTitle), findsNothing);
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
    await waitFor(find.text(Copy.bridgeFormTitle));
    sampleBridge.state = const SwapState(stage: SwapStage.waiting);
    await tester.enterText(find.byType(TextField).first, '0.006');
    await waitFor(find.textContaining('You get about'));
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
