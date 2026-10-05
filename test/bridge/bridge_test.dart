import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/bridge/controller.dart';
import 'package:kranox_wallet/bridge/models.dart';
import 'package:kranox_wallet/bridge/store.dart';
import 'package:kranox_wallet/config/app_config.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

/// A wallet engine that opens every wallet and hands out subaddresses with rising indexes.
final class _SampleWallet implements WalletBackend {
  int _index = 1;
  final List<WalletRequest> requests = [];

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
      _ => null,
    };
    return answer as T;
  }

  @override
  void stop() {}
}

/// An exchanger with a minimum of 0.004 and a rate of 5 XMR for one coin, whose swaps report [stage].
final class _SampleBridge implements BridgeClient {
  SwapStage stage = SwapStage.waiting;
  final List<String> created = [];

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
  Future<SwapState> readSwap(String id) async => SwapState(stage: stage, amountOut: 0.0274);

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
      estimatedXmr: 0.027,
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
      estimatedXmr: 0.0205,
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
    expect(exchanging.estimatedXmr, 0.0204);
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
      expect(bridge.shownSwap?.stage, SwapStage.failed);
      expect(bridge.activeSwap?.id, swap.id, reason: 'a failed swap may still be refunded');
      await bridge.closeSwap(swap.id);
      expect(bridge.shownSwap, isNull);
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
