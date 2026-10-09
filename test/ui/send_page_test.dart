import 'dart:async';
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

/// A wallet that has caught up and holds 100 XMR, so that the forms of both ways can build a payment.
final class _Wallet implements WalletBackend {
  final List<WalletRequest> handled = [];
  int _subaddress = 1;
  int _built = 0;

  static const WalletStatus _synced = WalletStatus(
    balance: XmrAmount(100 * XmrAmount.unitsPerXmr),
    unlocked: XmrAmount(100 * XmrAmount.unitsPerXmr),
    walletHeight: 100,
    nodeHeight: 100,
    synchronized: true,
    connection: NodeConnection.connected,
  );

  @override
  Future<T> call<T>(WalletRequest request) async {
    handled.add(request);
    final Object? answer = switch (request) {
      ReadStatus() => _synced,
      ReadHistory() => const <WalletTransfer>[],
      ReadReceiveAddress(:final createNew) => ReceiveAddress(
        address: 'subaddress-${createNew ? ++_subaddress : _subaddress}',
        index: _subaddress,
      ),
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

/// An exchanger that holds a new payment until the test lets the relay answer, as a slow relay does.
final class _SlowRelay implements BridgeClient {
  final Completer<void> answer = Completer<void>();
  bool asked = false;

  @override
  Future<PayRange> payRange(BridgeAsset asset, PayRate rate) async =>
      PayRange(asset: asset, rate: rate, minXmr: 0.02, maxXmr: 2);

  @override
  Future<PayQuote> payQuote(BridgeAsset asset, PayRate rate, String xmrAmount) async => PayQuote(
    asset: asset,
    rate: rate,
    xmrAmount: xmrAmount,
    amount: double.parse(xmrAmount) * 500,
    rateId: rate == PayRate.fixed ? 'rate-$xmrAmount' : null,
    validUntil: null,
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
  }) async {
    asked = true;
    await answer.future;
    return CreatedPay(
      id: 'pay1',
      amount: double.parse(xmrAmount) * 500,
      xmrAmount: double.parse(xmrAmount),
      depositAddress: _deposit,
      payoutAddress: address.toLowerCase(),
      refundAddress: refundAddress,
    );
  }

  @override
  Future<SwapState> readSwap(String id, {String? token}) async =>
      SwapState(stage: SwapStage.waiting, validUntil: DateTime.now().add(const Duration(minutes: 10)));

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
  }) => throw UnimplementedError('The send page makes no swap of receive.');

  @override
  Future<bool> isOnline() async => true;
}

void main() {
  late Directory root;
  late _Wallet engine;
  late WalletController wallet;
  late _SlowRelay relay;
  late BridgeController bridge;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('kranox-send-page');
    final storage = AppStorage(root.path);
    await storage.prepareWalletFolder(MoneroNetwork.mainnet);
    File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
    engine = _Wallet();
    wallet = WalletController(worker: engine, storage: storage);
    await wallet.start();
    await wallet.unlock('password');
    relay = _SlowRelay();
    bridge = BridgeController(client: relay, store: BridgeStore(storage.bridgePath), wallet: wallet);
    await bridge.start();
  });

  tearDown(() async {
    bridge.dispose();
    await wallet.lock();
    wallet.dispose();
    root.deleteSync(recursive: true);
  });

  testWidgets('the way of the send page stays on pay while pay prepares its review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2400));
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

    // A filled plain form, then pay: the case of a user who starts a payment, waits, and turns to a plain send.
    await tester.enterText(find.byType(TextField).at(0), _plainRecipient);
    await tester.enterText(find.byType(TextField).at(1), '0.05');
    await tester.tap(find.text(Copy.sendChainTab.toUpperCase()));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), '0.16');
    await tester.enterText(find.byType(TextField).at(1), _chainRecipient);
    await tester.pump(AppConfig.bridgeQuoteDelay + const Duration(milliseconds: 200));
    await tester.pump();
    expect(bridge.pay.canReview, isTrue);

    await tester.tap(find.text(Copy.review));
    await tester.pump();
    await tester.pump();
    expect(relay.asked, isTrue, reason: 'pay waits for the relay');
    expect(bridge.pay.preparing, isTrue);

    // The plain way stays closed while pay prepares, so no plain payment can take the place of the deposit.
    await tester.tap(find.text(Copy.sendMoneroTab.toUpperCase()));
    await tester.pump();
    expect(find.text(Copy.payPreparing), findsOneWidget, reason: 'the page stays on pay');
    expect(engine.handled.whereType<PrepareSend>(), isEmpty);

    await tester.runAsync(() async {
      relay.answer.complete();
      for (var round = 0; round < 40 && bridge.pay.review == null; round++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pump();
    expect(bridge.pay.review?.prepared.address, _deposit);
    expect(engine.handled.whereType<PrepareSend>().single.address, _deposit);
  });
}
