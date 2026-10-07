import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/bridge/controller.dart';
import 'package:kranox_wallet/bridge/store.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/ui/copy.dart';
import 'package:kranox_wallet/ui/screens/privacy_page.dart';
import 'package:kranox_wallet/ui/theme/kranox_theme.dart';
import 'package:kranox_wallet/ui/theme/palette.dart';
import 'package:kranox_wallet/ui/widgets/sidebar.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

/// A synced wallet of 10 XMR whose history the test sets: the subaddress of each payment that came in.
final class _Wallet implements WalletBackend {
  _Wallet(this.indexes);

  final List<int> indexes;
  final List<WalletRequest> handled = [];
  int _subaddress = 1;

  @override
  Future<T> call<T>(WalletRequest request) async {
    handled.add(request);
    final Object? answer = switch (request) {
      ReadStatus() => WalletStatus(
        balance: XmrAmount.parse('10'),
        unlocked: XmrAmount.parse('10'),
        walletHeight: 100,
        nodeHeight: 100,
        synchronized: true,
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
      _ => null,
    };
    return answer as T;
  }

  @override
  void stop() {}
}

/// The page reads only the swaps that the store holds, so the exchanger never answers.
final class _NoRelay implements BridgeClient {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError('The privacy page calls no exchanger.');
}

void main() {
  late Directory root;
  late _Wallet engine;
  late WalletController wallet;
  late BridgeController bridge;
  final opened = <WalletPage>[];

  Future<void> start(List<int> indexes) async {
    root = Directory.systemTemp.createTempSync('kranox-privacy-page');
    final storage = AppStorage(root.path);
    await storage.prepareWalletFolder(MoneroNetwork.mainnet);
    File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
    engine = _Wallet(indexes);
    wallet = WalletController(worker: engine, storage: storage);
    await wallet.start();
    await wallet.unlock('password');
    bridge = BridgeController(client: _NoRelay(), store: BridgeStore(storage.bridgePath), wallet: wallet);
    opened.clear();
  }

  tearDown(() async {
    bridge.dispose();
    await wallet.lock();
    wallet.dispose();
    root.deleteSync(recursive: true);
  });

  Future<void> show(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: KranoxTheme.build(Palette.of(activeLook)),
        home: Scaffold(
          body: PrivacyPage(controller: wallet, bridge: bridge, onNavigate: opened.add),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a public node and a subaddress of many payments are two things to improve, each with its way', (
    tester,
  ) async {
    await tester.runAsync(() => start([1, 1, 1, 2]));
    await show(tester);
    expect(find.text(Copy.privacyToImprove(2)), findsOneWidget);
    expect(find.text(Copy.privacySubaddressOne(1, 3)), findsOneWidget);

    await tester.tap(find.text(Copy.privacyChangeNode));
    expect(opened, [WalletPage.settings]);

    // The first unlock of a wallet makes the subaddress of the receive page too, so the test counts from here.
    int made() => engine.handled.whereType<ReadReceiveAddress>().where((request) => request.createNew).length;
    final before = made();
    await tester.tap(find.text(Copy.privacyNewSubaddress));
    // The wallet writes the new index to its settings file: the file takes real time, and each step after it a frame.
    for (var round = 0; round < 40 && opened.length < 2; round++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    }
    expect(made(), before + 1);
    expect(opened, [WalletPage.settings, WalletPage.receive]);
  });

  testWidgets('a node of its own network and one payment for each subaddress leave the wallet all clear', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await start([1, 2, 3]);
      await wallet.changeNode('192.168.1.5:18089');
    });
    await show(tester);
    expect(find.text(Copy.privacyClear), findsOneWidget);
    expect(find.text(Copy.privacyChangeNode), findsNothing);
    expect(find.text(Copy.privacyNewSubaddress), findsNothing);
    expect(find.text(Copy.privacyNodeOwn('192.168.1.5:18089')), findsOneWidget);
  });
}
