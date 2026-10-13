import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/core/tor_engine.dart';
import 'package:kranox_wallet/ui/copy.dart';
import 'package:kranox_wallet/ui/screens/home_page.dart';
import 'package:kranox_wallet/ui/theme/kranox_theme.dart';
import 'package:kranox_wallet/ui/theme/palette.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/tor_service.dart';
import 'package:kranox_wallet/wallet/worker.dart';

/// The state of a wallet whose node answers, as the engine reads it.
const _answering = WalletStatus(
  balance: XmrAmount.zero,
  unlocked: XmrAmount.zero,
  walletHeight: 10,
  nodeHeight: 10,
  synchronized: true,
  connection: NodeConnection.connected,
);

/// A wallet engine that reports a node that answers once it has been asked to connect, and nothing before.
final class _Wallet implements WalletBackend {
  bool connected = false;
  final List<ConnectNode> connects = [];

  @override
  Future<T> call<T>(WalletRequest request) async {
    if (request is ConnectNode) {
      connects.add(request);
      connected = true;
    }
    final Object? answer = switch (request) {
      ReadStatus() => connected ? _answering : WalletStatus.unknown,
      ReadHistory() => const <WalletTransfer>[],
      ReadReceiveAddress() || ReadSubaddress() => const ReceiveAddress(address: 'subaddress-1', index: 1),
      _ => null,
    };
    return answer as T;
  }

  @override
  void stop() {}
}

/// An engine of Tor of the test, which the test brings on.
final class _Engine implements TorEngine {
  final Completer<int> starting = Completer<int>();

  @override
  Future<int> start() => starting.future;

  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets('the home says that the wallet waits for Tor built into the app, and connects once it is on', (
    tester,
  ) async {
    late Directory root;
    late WalletController wallet;
    final backend = _Wallet();
    final engine = _Engine();
    await tester.runAsync(() async {
      root = Directory.systemTemp.createTempSync('kranox-tor-notice');
      final storage = AppStorage(root.path);
      await storage.prepareWalletFolder(MoneroNetwork.mainnet);
      File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
      wallet = WalletController(
        worker: backend,
        storage: storage,
        tor: TorService(engine: engine, probe: (_) async {}),
        resolve: ({required proxy, required host, required timeout}) async => InternetAddress('203.0.113.5'),
      );
      await wallet.start();
      await wallet.unlock('password');
    });
    addTearDown(() async {
      await wallet.lock();
      wallet.dispose();
      root.deleteSync(recursive: true);
    });
    expect(wallet.waitsForTor, isTrue);
    expect(backend.connects, isEmpty);

    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: KranoxTheme.build(Palette.of(activeLook)),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: wallet,
            builder: (context, _) => HomePage(controller: wallet, onNavigate: (_) {}),
          ),
        ),
      ),
    );
    expect(find.text(Copy.torTitle), findsOneWidget);
    expect(find.text(Copy.torStarting), findsOneWidget);
    expect(find.text(Copy.nodeOffline), findsNothing);

    // Tor comes on: the wallet connects through it, and the notice goes away.
    await tester.runAsync(() async {
      engine.starting.complete(9150);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(wallet.waitsForTor, isFalse);
    expect(backend.connects.single.proxy, '127.0.0.1:9150');
    expect(find.text(Copy.torStarting), findsNothing);
  });
}
