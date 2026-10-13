import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/core/connection_probe.dart';
import 'package:kranox_wallet/ui/copy.dart';
import 'package:kranox_wallet/ui/screens/home_page.dart';
import 'package:kranox_wallet/ui/theme/kranox_theme.dart';
import 'package:kranox_wallet/ui/theme/palette.dart';
import 'package:kranox_wallet/ui/widgets/sidebar.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/settings.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

/// The state of a wallet whose node does not answer, and of one whose node answers, as the engine reads them.
const _silent = WalletStatus(
  balance: XmrAmount.zero,
  unlocked: XmrAmount.zero,
  walletHeight: 10,
  nodeHeight: 0,
  synchronized: false,
  connection: NodeConnection.disconnected,
);
const _answering = WalletStatus(
  balance: XmrAmount.zero,
  unlocked: XmrAmount.zero,
  walletHeight: 10,
  nodeHeight: 20,
  synchronized: false,
  connection: NodeConnection.connected,
);

/// A wallet engine that reports [status] and takes any proxy.
final class _Wallet implements WalletBackend {
  WalletStatus status = _silent;

  @override
  Future<T> call<T>(WalletRequest request) async {
    final Object? answer = switch (request) {
      ReadStatus() => status,
      ReadHistory() => const <WalletTransfer>[],
      ReadReceiveAddress() || ReadSubaddress() => const ReceiveAddress(address: 'subaddress-1', index: 1),
      _ => null,
    };
    return answer as T;
  }

  @override
  void stop() {}
}

/// A look of the test: it answers [trouble] and counts the looks.
final class _Probe extends ConnectionProbe {
  ConnectionTrouble? trouble = ConnectionTrouble.proxyDown;
  int looks = 0;

  @override
  Future<ConnectionTrouble?> run({required String host, required int port, required String? proxy}) async {
    looks++;
    return trouble;
  }
}

void main() {
  testWidgets('the home says why the node does not answer, tries again on a click, and leads to Settings', (
    tester,
  ) async {
    late Directory root;
    late WalletController wallet;
    final backend = _Wallet();
    final probe = _Probe();
    await tester.runAsync(() async {
      root = Directory.systemTemp.createTempSync('kranox-node-notice');
      final storage = AppStorage(root.path);
      await storage.prepareWalletFolder(MoneroNetwork.mainnet);
      File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
      await storage.writeSettings(const AppSettings().withProxy('127.0.0.1:9050'));
      wallet = WalletController(worker: backend, storage: storage, probe: probe);
      await wallet.start();
      await wallet.unlock('password');
      // The node has stayed silent, and the user asked the app to try again, so the app looked at once.
      await wallet.reconnect();
    });
    addTearDown(() async {
      await wallet.lock();
      wallet.dispose();
      root.deleteSync(recursive: true);
    });
    expect(wallet.nodeReport?.trouble, ConnectionTrouble.proxyDown);
    expect(probe.looks, 1);

    WalletPage? navigated;
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: KranoxTheme.build(Palette.of(activeLook)),
        home: Scaffold(
          // The shell of the app rebuilds the page on every change of the wallet; the test does the same.
          body: ListenableBuilder(
            listenable: wallet,
            builder: (context, _) => HomePage(controller: wallet, onNavigate: (page) => navigated = page),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(Copy.nodeTroubleProxyDown('127.0.0.1:9050')), findsOneWidget);
    expect(find.text(Copy.nodeOffline.toUpperCase()), findsOneWidget, reason: 'the chip');
    expect(find.text(Copy.nodeOffline), findsOneWidget, reason: 'the title of the notice');

    // Settings leads to the settings page.
    await tester.tap(find.text(Copy.nodeSettings));
    expect(navigated, WalletPage.settings);

    // Try again connects the wallet again and looks again; once the node answers, the notice goes.
    backend.status = _answering;
    await tester.runAsync(() async {
      await tester.tap(find.text(Copy.nodeTryAgain));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.text(Copy.nodeTroubleProxyDown('127.0.0.1:9050')), findsNothing);
    expect(find.text(Copy.nodeOnline.toUpperCase()), findsOneWidget);
    expect(find.text(Copy.nodeOffline), findsNothing);
    expect(wallet.nodeReport, isNull);
    expect(probe.looks, 1, reason: 'a node that answers needs no look');
  });
}
