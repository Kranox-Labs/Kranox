import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/bridge/controller.dart';
import 'package:kranox_wallet/bridge/models.dart';
import 'package:kranox_wallet/bridge/store.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/ui/copy.dart';
import 'package:kranox_wallet/ui/screens/receive_from_chain.dart';
import 'package:kranox_wallet/ui/theme/kranox_theme.dart';
import 'package:kranox_wallet/ui/theme/palette.dart';
import 'package:kranox_wallet/ui/widgets/qr_card.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

const _deposit = '0x7A3Fc0E1b9D24a6C58E0F3B1d9A7C4e2F6B8D015';

/// A synced wallet without history.
final class _Wallet implements WalletBackend {
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
      ReadReceiveAddress() => const ReceiveAddress(address: 'subaddress-1', index: 1),
      ReadSubaddress(:final index) => ReceiveAddress(address: 'subaddress-$index', index: index),
      _ => null,
    };
    return answer as T;
  }

  @override
  void stop() {}
}

/// The relay of a swap that waits for its deposit.
final class _Relay implements BridgeClient {
  @override
  Future<SwapState> readSwap(String id, {String? token}) async => const SwapState(stage: SwapStage.waiting);

  @override
  Future<bool> isOnline() async => true;

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError('The deposit card asks for nothing else.');
}

void main() {
  late Directory root;
  late WalletController wallet;
  late BridgeController bridge;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('kranox-receive-deposit');
    final storage = AppStorage(root.path);
    await storage.prepareWalletFolder(MoneroNetwork.mainnet);
    File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
    final store = BridgeStore(storage.bridgePath);
    await store.write([
      BridgeSwap(
        id: 'swap1',
        asset: BridgeAsset.usdg,
        amount: 25.5,
        xmrAmount: 0.12,
        depositAddress: _deposit,
        payoutAddress: 'subaddress-2',
        subaddressIndex: 2,
        createdAt: DateTime.now(),
        stage: SwapStage.waiting,
      ),
    ]);
    wallet = WalletController(worker: _Wallet(), storage: storage);
    await wallet.start();
    await wallet.unlock('password');
    bridge = BridgeController(client: _Relay(), store: store, wallet: wallet);
    await bridge.start();
  });

  tearDown(() async {
    bridge.dispose();
    await wallet.lock();
    wallet.dispose();
    root.deleteSync(recursive: true);
  });

  testWidgets('the code of a deposit names the chain, the coin, and the amount, or the address alone (K-22)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: KranoxTheme.build(Palette.of(activeLook)),
        home: Scaffold(
          body: SingleChildScrollView(child: ReceiveFromChain(bridge: bridge)),
        ),
      ),
    );
    await tester.pump();
    String code() => tester.widget<QrCard>(find.byType(QrCard)).data!;
    expect(
      code(),
      'ethereum:0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168@4663/transfer?address=$_deposit&uint256=25500000',
    );
    expect(find.text(Copy.bridgeLinkNote(BridgeAsset.usdg)), findsOneWidget);

    await tester.tap(find.text(Copy.bridgeAddressOnly));
    await tester.pump();
    expect(code(), _deposit);
    expect(find.text(Copy.bridgeLinkNote(BridgeAsset.usdg)), findsNothing);
    await tester.tap(find.text(Copy.bridgePaymentLink));
    await tester.pump();
    expect(code(), startsWith('ethereum:'));
  });
}
