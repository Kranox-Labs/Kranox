import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/bridge/controller.dart';
import 'package:kranox_wallet/bridge/store.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/ui/copy.dart';
import 'package:kranox_wallet/ui/screens/settings_page.dart';
import 'package:kranox_wallet/ui/theme/kranox_theme.dart';
import 'package:kranox_wallet/ui/theme/palette.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/failure.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/settings.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

/// A wallet engine that refuses every proxy, as wallet2 refuses one that it cannot read.
final class _Wallet implements WalletBackend {
  @override
  Future<T> call<T>(WalletRequest request) async {
    if (request is ConnectNode && request.proxy != null) {
      throw const WalletException(WalletFailure.proxyRefused, 'Failed to parse proxy address');
    }
    final Object? answer = switch (request) {
      ReadStatus() => WalletStatus.unknown,
      ReadHistory() => const <WalletTransfer>[],
      ReadReceiveAddress() => const ReceiveAddress(address: 'subaddress-1', index: 1),
      ReadFileKeys() => FileKeys(key: Uint8List(32)),
      _ => null,
    };
    return answer as T;
  }

  @override
  void stop() {}
}

/// A relay that answers nothing but its health.
final class _Relay implements BridgeClient {
  @override
  Future<bool> isOnline() async => true;

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError('The settings ask for nothing else.');
}

void main() {
  testWidgets('a proxy that wallet2 refused at the unlock shows its error in Settings from the start', (tester) async {
    late Directory root;
    late WalletController wallet;
    late BridgeController bridge;
    await tester.runAsync(() async {
      root = Directory.systemTemp.createTempSync('kranox-settings-proxy');
      final storage = AppStorage(root.path);
      await storage.prepareWalletFolder(MoneroNetwork.mainnet);
      File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
      await storage.writeSettings(const AppSettings().withProxy('127.0.0.1:9050'));
      wallet = WalletController(worker: _Wallet(), storage: storage);
      await wallet.start();
      await wallet.unlock('password');
      bridge = BridgeController(client: _Relay(), store: BridgeStore(storage.bridgePath), wallet: wallet);
      await bridge.start();
    });
    addTearDown(() async {
      bridge.dispose();
      await wallet.lock();
      wallet.dispose();
      root.deleteSync(recursive: true);
    });
    expect(wallet.phase, WalletPhase.open, reason: 'the wallet opens, so that the user can reach Settings');
    expect(wallet.proxyRefused, isTrue);

    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: KranoxTheme.build(Palette.of(activeLook)),
        home: Scaffold(
          body: SettingsPage(controller: wallet, bridge: bridge, onLock: () {}),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(Copy.proxyRefused), findsOneWidget);
  });
}
