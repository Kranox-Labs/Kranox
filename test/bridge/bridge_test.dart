import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/bridge/controller.dart';
import 'package:kranox_wallet/bridge/models.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/bridge/store.dart';
import 'package:kranox_wallet/config/app_config.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

/// A mainnet address of a throwaway wallet, as in test/core/address_test.dart: the deposit address of the exchanger
/// for the sample payments.
const _xmrDeposit = '48PFnHrr8bVGx463yo8SMXGZUp7PyYPgwZJR4MnpgjKCDXpw3XvK6UTbarKkpwaPbPSYSdJ4rozjZjGxr2t3qVP4B4DzzVs';

/// A recipient on Robinhood Chain in the mixed case of EIP-55, from the examples of EIP-55.
const _recipient = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';

/// A wallet engine that opens every wallet, hands out subaddresses with rising indexes, and builds and sends payments
/// with a fixed fee.
final class _SampleWallet implements WalletBackend {
  int _index = 1;
  final List<WalletRequest> requests = [];
  PreparedSend? _prepared;

  @override
  Future<T> call<T>(WalletRequest request) async {
    requests.add(request);
    final Object? answer = switch (request) {
      ReadReceiveAddress(:final createNew) => ReceiveAddress(
        address: 'subaddress-${createNew ? ++_index : _index}',
        index: _index,
      ),
      ReadHistory() => const <WalletTransfer>[],
      ReadStatus() => WalletStatus.unknown,
      PrepareSend(:final address, :final amountUnits) => _prepared = PreparedSend(
        address: address,
        amount: XmrAmount(amountUnits),
        fee: XmrAmount.parse('0.00003'),
      ),
      ConfirmSend() => SentPayment(transactionId: 'c4f27a91', amount: _prepared!.amount, fee: _prepared!.fee),
      _ => null,
    };
    return answer as T;
  }

  @override
  void stop() {}
}

/// An exchanger with a minimum of 0.004 and a rate of 5 XMR for one coin, whose swaps report [stage]. A payment buys
/// 500 coins for one XMR at a fixed rate, from 0.02 to 2 XMR, and its rate waits [payWindow] for the deposit; at a
/// floating rate it buys about 480 coins for one XMR, from 0.01 XMR without a top.
final class _SampleBridge implements BridgeClient {
  SwapStage stage = SwapStage.waiting;
  final List<String> created = [];
  final List<(String, String)> paid = [];
  final List<(PayRate, String?)> paidRates = [];
  Duration payWindow = const Duration(minutes: 10);

  /// The recipient of a payment that the exchanger makes, when it makes one for another recipient.
  String? payoutOverride;

  /// The XMR of a payment that the exchanger makes, when it makes one for another amount.
  double? xmrOverride;

  @override
  Future<BridgeQuote> quote(BridgeAsset asset, String amount) async {
    final value = double.parse(amount);
    return BridgeQuote(
      asset: asset,
      amount: amount,
      minAmount: 0.004,
      estimatedXmr: value < 0.004 ? null : value * 5,
      speedMinutes: '10-60',
      warning: null,
    );
  }

  @override
  Future<CreatedSwap> createSwap({
    required BridgeAsset asset,
    required String amount,
    required String address,
    String? refundAddress,
  }) async {
    created.add(address);
    return CreatedSwap(
      id: 'swap${created.length}',
      amount: double.parse(amount),
      estimatedXmr: double.parse(amount) * 5,
      depositAddress: '0xdeposit',
      payoutAddress: address,
    );
  }

  @override
  Future<PayRange> payRange(BridgeAsset asset, PayRate rate) async => switch (rate) {
    PayRate.fixed => PayRange(asset: asset, rate: rate, minXmr: 0.02, maxXmr: 2),
    PayRate.floating => PayRange(asset: asset, rate: rate, minXmr: 0.01, maxXmr: null),
  };

  static double _coinsPerXmr(PayRate rate) => rate == PayRate.fixed ? 500 : 480;

  @override
  Future<PayQuote> payQuote(BridgeAsset asset, PayRate rate, String xmrAmount) async {
    final value = double.parse(xmrAmount);
    final range = await payRange(asset, rate);
    final max = range.maxXmr;
    final inRange = value >= range.minXmr && (max == null || value <= max);
    return PayQuote(
      asset: asset,
      rate: rate,
      xmrAmount: xmrAmount,
      amount: inRange ? value * _coinsPerXmr(rate) : null,
      rateId: inRange && rate == PayRate.fixed ? 'rate-$xmrAmount' : null,
      validUntil: null,
      warning: null,
      limit: inRange ? null : (value < range.minXmr ? PayLimit.below : PayLimit.above),
      minXmr: inRange ? null : range.minXmr,
      maxXmr: inRange ? null : max,
      depositFee: 0.006,
      withdrawalFee: 0.737,
    );
  }

  @override
  Future<CreatedPay> createPay({
    required BridgeAsset asset,
    required PayRate rate,
    required String xmrAmount,
    required String address,
    required String refundAddress,
    required String? rateId,
  }) async {
    paid.add((address, refundAddress));
    paidRates.add((rate, rateId));
    return CreatedPay(
      id: 'pay${paid.length}',
      amount: double.parse(xmrAmount) * _coinsPerXmr(rate),
      xmrAmount: xmrOverride ?? double.parse(xmrAmount),
      depositAddress: _xmrDeposit,
      payoutAddress: payoutOverride ?? address.toLowerCase(),
    );
  }

  @override
  Future<SwapState> readSwap(String id) async =>
      SwapState(stage: stage, amountOut: 0.0274, validUntil: DateTime.now().add(payWindow));

  bool online = true;

  @override
  Future<bool> isOnline() async => online;
}

/// The quote follows the form after a short pause; the tests wait a little longer.
Future<void> _quoteSettles() => Future<void>.delayed(AppConfig.bridgeQuoteDelay + const Duration(milliseconds: 150));

void main() {
  test('reads the status names of the exchanger', () {
    expect(SwapStage.fromStatus('new'), SwapStage.waiting);
    expect(SwapStage.fromStatus('waiting'), SwapStage.waiting);
    expect(SwapStage.fromStatus('sending'), SwapStage.sending);
    expect(SwapStage.fromStatus('verifying'), SwapStage.verifying);
    expect(SwapStage.finished.isFinal, isTrue);
    expect(SwapStage.refunded.isFinal, isTrue);
    expect(SwapStage.exchanging.isFinal, isFalse);
    expect(() => SwapStage.fromStatus('lost'), throwsFormatException);
  });

  test('takes amounts above zero with at most the allowed decimals', () {
    expect(isBridgeAmount('0.0055'), isTrue);
    expect(isBridgeAmount('15'), isTrue);
    for (final text in ['', '0', '0.0', '-1', '1e3', '1,5', '0.123456789', '.5']) {
      expect(isBridgeAmount(text), isFalse, reason: text);
    }
  });

  test('keeps a swap in its file and reads it back', () async {
    final root = Directory.systemTemp.createTempSync('kranox-bridge-store');
    addTearDown(() => root.deleteSync(recursive: true));
    final store = BridgeStore('${root.path}/bridge.json');
    expect(await store.read(), isEmpty);
    final swap = BridgeSwap(
      id: 'abc123',
      asset: BridgeAsset.usdg,
      amount: 15,
      xmrAmount: 0.027,
      depositAddress: '0xdeposit',
      payoutAddress: 'subaddress',
      subaddressIndex: 3,
      createdAt: DateTime.utc(2026, 10, 5, 7),
      stage: SwapStage.waiting,
    ).withState(const SwapState(stage: SwapStage.sending, amountOut: 0.0268, depositHash: '0xhash'));
    await store.write([swap]);
    final read = (await store.read()).single;
    expect(read.toJson(), swap.toJson());
    expect(read.stage, SwapStage.sending);
    expect(read.amountOut, 0.0268);
  });

  test('keeps the furthest step when a swap fails, and follows a failed swap until its card closes', () {
    final swap = BridgeSwap(
      id: 'abc123',
      asset: BridgeAsset.eth,
      amount: 0.006,
      xmrAmount: 0.0205,
      depositAddress: '0xdeposit',
      payoutAddress: 'subaddress',
      subaddressIndex: 2,
      createdAt: DateTime.utc(2026, 10, 5, 8),
      stage: SwapStage.waiting,
    );
    final exchanging = swap
        .withState(const SwapState(stage: SwapStage.confirming, depositHash: '0xhash'))
        .withState(const SwapState(stage: SwapStage.exchanging, expectedOut: 0.0204));
    expect(exchanging.reached, SwapStage.exchanging);
    expect(exchanging.xmrAmount, 0.0204);
    expect(exchanging.depositHash, '0xhash');

    final failed = exchanging.withState(const SwapState(stage: SwapStage.failed));
    expect(failed.reached, SwapStage.exchanging);
    expect(failed.depositHash, '0xhash');
    expect(failed.watched, isTrue);
    expect(failed.close().watched, isFalse);

    final refunded = failed.withState(
      const SwapState(stage: SwapStage.refunded, refundAddress: '0xrefund', refundHash: '0xback', refundAmount: 0.0058),
    );
    expect(refunded.watched, isFalse);
    expect(refunded.reached, SwapStage.exchanging);
    expect(refunded.refundAmount, 0.0058);
    expect(BridgeSwap.fromJson(refunded.toJson()).toJson(), refunded.toJson());
  });

  test('reads a swap saved before the steps had their facts', () {
    final swap = BridgeSwap.fromJson({
      'id': '5051428c8e2087',
      'asset': 'eth',
      'amount': 0.006,
      'estimatedXmr': 0.0205789,
      'depositAddress': '0xdeposit',
      'payoutAddress': 'subaddress',
      'subaddressIndex': 2,
      'createdAt': '2026-10-05T08:03:04.808306Z',
      'stage': 'confirming',
      'amountOut': null,
      'depositHash': null,
      'payoutHash': null,
    });
    expect(swap.reached, SwapStage.confirming);
    expect(swap.closed, isFalse);
    expect(swap.refundAddress, isNull);
  });

  test('keeps the XMR of a payment, and reads a swap of pay back with its direction', () {
    final payment = BridgeSwap(
      direction: SwapDirection.pay,
      id: 'pay1',
      asset: BridgeAsset.usdg,
      amount: 80,
      xmrAmount: 0.15366631,
      depositAddress: _xmrDeposit,
      payoutAddress: _recipient,
      subaddressIndex: 7,
      refundAddress: 'subaddress-7',
      depositHash: 'c4f27a91',
      createdAt: DateTime.utc(2026, 10, 5, 15),
      stage: SwapStage.waiting,
      validUntil: DateTime.utc(2026, 10, 5, 15, 10),
    ).withState(const SwapState(stage: SwapStage.exchanging, expectedOut: 80));
    expect(payment.xmrAmount, 0.15366631);
    expect(payment.reached, SwapStage.exchanging);
    final read = BridgeSwap.fromJson(payment.toJson());
    expect(read.direction, SwapDirection.pay);
    final saved = payment.toJson()..remove('fixedRate');
    expect(BridgeSwap.fromJson(saved).fixedRate, isTrue, reason: 'the payments of 5 Oct 2026 ran at a fixed rate');
    expect(read.validUntil, DateTime.utc(2026, 10, 5, 15, 10));
    expect(read.toJson(), payment.toJson());
  });

  test('reads a pay quote of the relay, also one outside the range of the fixed rate', () {
    final quote = PayQuote.fromJson({
      'asset': 'usdg',
      'rate': 'fixed',
      'xmrAmount': '0.1',
      'amount': 51.229932,
      'rateId': 'rate',
      'validUntil': '2026-10-06T03:07:28.793Z',
      'warning': null,
      'depositFee': 0.006,
      'withdrawalFee': 0.7370513,
      'speedMinutes': null,
      'limit': null,
      'minXmr': null,
      'maxXmr': null,
    });
    expect(quote.amount, 51.229932);
    expect(quote.rate, PayRate.fixed);
    expect(quote.depositFee, 0.006);
    expect(quote.validUntil, DateTime.utc(2026, 10, 6, 3, 7, 28, 793));
    final outside = PayQuote.fromJson({
      'asset': 'eth',
      'rate': 'floating',
      'xmrAmount': '0.01',
      'amount': null,
      'rateId': null,
      'validUntil': null,
      'warning': null,
      'limit': 'below',
      'minXmr': 0.0227,
      'maxXmr': 1.4505,
    });
    expect(outside.limit, PayLimit.below);
    expect(outside.minXmr, 0.0227);
  });

  group('the controller', () {
    late Directory root;
    late AppStorage storage;
    late _SampleWallet engine;
    late WalletController wallet;
    late _SampleBridge exchanger;
    late BridgeController bridge;

    setUp(() async {
      root = Directory.systemTemp.createTempSync('kranox-bridge');
      storage = AppStorage(root.path);
      await storage.prepareWalletFolder(MoneroNetwork.mainnet);
      File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
      engine = _SampleWallet();
      wallet = WalletController(worker: engine, storage: storage);
      await wallet.start();
      await wallet.unlock('password');
      exchanger = _SampleBridge();
      bridge = BridgeController(client: exchanger, store: BridgeStore(storage.bridgePath), wallet: wallet);
      await bridge.start();
    });

    tearDown(() async {
      bridge.dispose();
      await wallet.lock();
      wallet.dispose();
      root.deleteSync(recursive: true);
    });

    test('quotes an amount and allows a swap only above the minimum', () async {
      expect(bridge.available, isTrue);
      bridge.setAmount('0.001');
      await _quoteSettles();
      expect(bridge.quote?.estimatedXmr, isNull);
      expect(bridge.canSwap, isFalse);
      bridge.setAmount('0.0055');
      expect(bridge.quoting, isTrue);
      await _quoteSettles();
      expect(bridge.quote?.estimatedXmr, closeTo(0.0275, 1e-9));
      expect(bridge.canSwap, isTrue);
      bridge.selectAsset(BridgeAsset.usdg);
      expect(bridge.canSwap, isFalse);
    });

    test('pays out to a new subaddress and follows the swap to its end', () async {
      bridge.setAmount('0.0055');
      await _quoteSettles();
      final swap = await bridge.createSwap();
      expect(engine.requests.whereType<ReadReceiveAddress>().last.createNew, isTrue);
      expect(exchanger.created.single, wallet.receiveAddress!.address);
      expect(swap.subaddressIndex, wallet.receiveAddress!.index);
      expect(bridge.activeSwap?.id, swap.id);
      expect(bridge.amount, isEmpty);

      // The first read of the new swap is on its way; the next one sees the end.
      await bridge.refresh();
      exchanger.stage = SwapStage.finished;
      await bridge.refresh();
      expect(bridge.activeSwap, isNull);
      expect(bridge.swaps.single.stage, SwapStage.finished);
      expect(bridge.swaps.single.amountOut, 0.0274);
      final saved = await BridgeStore(storage.bridgePath).read();
      expect(saved.single.stage, SwapStage.finished);
    });

    test('shows an ended swap until its card closes', () async {
      bridge.setAmount('0.0055');
      await _quoteSettles();
      final swap = await bridge.createSwap(refundAddress: '0x57f31ad4b64095347F87eDB1675566DAfF5EC886');
      expect(swap.refundAddress, '0x57f31ad4b64095347F87eDB1675566DAfF5EC886');
      await bridge.refresh();
      exchanger.stage = SwapStage.failed;
      await bridge.refresh();
      expect(bridge.shownSwapOf(SwapDirection.receive)?.stage, SwapStage.failed);
      expect(bridge.activeSwap?.id, swap.id, reason: 'a failed swap may still be refunded');
      await bridge.closeSwap(swap.id);
      expect(bridge.shownSwapOf(SwapDirection.receive), isNull);
      expect(bridge.activeSwap, isNull);
      expect((await BridgeStore(storage.bridgePath).read()).single.closed, isTrue);
    });

    test('reports whether the relay answers', () async {
      expect(bridge.relayOnline, isNull);
      await bridge.checkRelay();
      expect(bridge.relayOnline, isTrue);
      exchanger.online = false;
      await bridge.checkRelay();
      expect(bridge.relayOnline, isFalse);
      expect(bridge.checkingRelay, isFalse);
    });

    test('quotes the coin that an amount of XMR buys and allows a review only for a valid recipient', () async {
      final pay = bridge.pay;
      pay.setXmr('0.16');
      expect(pay.quoting, isTrue);
      await _quoteSettles();
      expect(pay.quotedAmount, closeTo(80, 1e-9));
      expect(pay.canReview, isFalse, reason: 'no recipient yet');
      pay.setRecipient('0x5aaeb6053F3E94C9b9A09f33669435E7Ef1BeAed');
      expect(pay.recipient, isNull, reason: 'a typo in the checksum');
      pay.setRecipient(_recipient);
      expect(pay.recipient, _recipient);
      expect(pay.canReview, isTrue);
      pay.selectAsset(BridgeAsset.eth);
      expect(pay.canReview, isFalse, reason: 'the quote follows the new coin');
    });

    test('knows the minimum payment before the user types, and marks an amount outside the range', () async {
      final pay = bridge.pay;
      expect(pay.range, isNull);
      await pay.loadRange();
      expect(pay.range?.minXmr, 0.02);
      expect(pay.rangeOf(PayRate.floating)?.minXmr, 0.01);
      expect(pay.limit, isNull, reason: 'no amount yet');
      pay.setXmr('0.01');
      expect(pay.limit, PayLimit.below);
      pay.setXmr('3');
      expect(pay.limit, PayLimit.above);
      pay.setXmr('0.16');
      expect(pay.limit, isNull);
    });

    test('shows the range of the fixed rate for an amount outside it', () async {
      final pay = bridge.pay;
      pay.setRecipient(_recipient);
      pay.setXmr('0.01');
      await _quoteSettles();
      expect(pay.quote?.limit, PayLimit.below);
      expect(pay.quote?.minXmr, 0.02);
      expect(pay.quotedAmount, isNull);
      expect(pay.range?.minXmr, 0.02, reason: 'the quote outside the range brings the range');
      expect(pay.limit, PayLimit.below);
      expect(pay.canReview, isFalse);
    });

    test('makes a payment, sends its XMR to the exchanger, and follows it as a swap of pay', () async {
      final pay = bridge.pay;
      pay.setRecipient(_recipient);
      pay.setXmr('0.16');
      await _quoteSettles();
      final review = await pay.startReview();
      expect(exchanger.paid.single, (_recipient, wallet.receiveAddress!.address));
      expect(review.refund.index, wallet.receiveAddress!.index);
      expect(review.prepared.address, _xmrDeposit);
      expect(review.prepared.amount, XmrAmount.parse('0.16'));
      expect(review.validUntil, isNotNull);
      expect(pay.canReview, isFalse, reason: 'a payment is under review');

      final swap = await pay.confirm();
      expect(engine.requests.whereType<ConfirmSend>(), hasLength(1));
      expect(swap.direction, SwapDirection.pay);
      expect(swap.fixedRate, isTrue);
      expect(exchanger.paidRates.single, (PayRate.fixed, 'rate-0.16'));
      expect(swap.depositHash, 'c4f27a91');
      expect(swap.xmrAmount, closeTo(0.16, 1e-12));
      expect(swap.amount, closeTo(80, 1e-9));
      expect(swap.refundAddress, review.refund.address);
      expect(pay.review, isNull);
      expect(pay.xmrText, isEmpty);
      expect(bridge.activeSwapOf(SwapDirection.pay)?.id, swap.id);
      expect(bridge.activeSwapOf(SwapDirection.receive), isNull);

      await bridge.refresh();
      exchanger.stage = SwapStage.exchanging;
      await bridge.refresh();
      expect(bridge.swapsOf(SwapDirection.pay).single.xmrAmount, closeTo(0.16, 1e-12), reason: 'the XMR that left');
      exchanger.stage = SwapStage.finished;
      await bridge.refresh();
      expect(bridge.activeSwapOf(SwapDirection.pay), isNull);
      final saved = (await BridgeStore(storage.bridgePath).read()).single;
      expect(saved.direction, SwapDirection.pay);
      expect(saved.stage, SwapStage.finished);
    });

    test('offers a floating rate below the minimum of a fixed one, and pays at it without a rate id', () async {
      final pay = bridge.pay;
      await pay.loadRange();
      pay.setRecipient(_recipient);
      pay.setXmr('0.015');
      expect(pay.limit, PayLimit.below);
      expect(pay.suggestsFloating, isTrue);
      pay.selectRate(PayRate.floating);
      expect(pay.limit, isNull);
      expect(pay.suggestsFloating, isFalse);
      await _quoteSettles();
      expect(pay.quotedAmount, closeTo(7.2, 1e-9));
      expect(pay.quote?.rateId, isNull);
      expect(pay.canReview, isTrue, reason: 'a floating rate needs no rate id');
      final review = await pay.startReview();
      expect(review.rate, PayRate.floating);
      expect(exchanger.paidRates.single, (PayRate.floating, null));
      final swap = await pay.confirm();
      expect(swap.fixedRate, isFalse);
      // The first read of the new payment is on its way; the test ends after it.
      await bridge.refresh();
    });

    test('builds no payment that the exchanger made for another recipient', () async {
      final pay = bridge.pay;
      exchanger.payoutOverride = '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359';
      pay.setRecipient(_recipient);
      pay.setXmr('0.16');
      await _quoteSettles();
      await expectLater(
        pay.startReview(),
        throwsA(isA<BridgeException>().having((error) => error.failure, 'failure', BridgeFailure.failed)),
      );
      expect(engine.requests.whereType<PrepareSend>(), isEmpty);
      expect(pay.review, isNull);
    });

    test('builds no payment that the exchanger made for another amount of XMR', () async {
      final pay = bridge.pay;
      exchanger.xmrOverride = 0.17;
      pay.setRecipient(_recipient);
      pay.setXmr('0.16');
      await _quoteSettles();
      await expectLater(
        pay.startReview(),
        throwsA(isA<BridgeException>().having((error) => error.failure, 'failure', BridgeFailure.failed)),
      );
      expect(engine.requests.whereType<PrepareSend>(), isEmpty);
    });

    test('sends nothing when the fixed rate runs out too soon, and drops the review', () async {
      final pay = bridge.pay;
      exchanger.payWindow = const Duration(seconds: 30);
      pay.setRecipient(_recipient);
      pay.setXmr('0.16');
      await _quoteSettles();
      await pay.startReview();
      await expectLater(
        pay.confirm(),
        throwsA(isA<BridgeException>().having((error) => error.failure, 'failure', BridgeFailure.rateExpired)),
      );
      expect(engine.requests.whereType<ConfirmSend>(), isEmpty);
      expect(engine.requests.whereType<CancelSend>(), hasLength(1));
      expect(pay.review, isNull);
      expect(bridge.swapsOf(SwapDirection.pay), isEmpty);
    });

    test('offers nothing on a test network', () async {
      await wallet.switchNetwork(MoneroNetwork.stagenet);
      expect(bridge.available, isFalse);
      bridge.setAmount('0.0055');
      await _quoteSettles();
      expect(bridge.quote, isNull);
      expect(bridge.canSwap, isFalse);
    });
  });
}
