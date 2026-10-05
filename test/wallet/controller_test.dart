import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/config/app_config.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

/// A wallet engine that opens every wallet and keeps the requests it gets, so that a test can check them.
final class _RecordingBackend implements WalletBackend {
  final List<WalletRequest> requests = [];

  @override
  Future<T> call<T>(WalletRequest request) async {
    requests.add(request);
    final Object? answer = switch (request) {
      ReadReceiveAddress() => const ReceiveAddress(address: 'sample', index: 1),
      ReadHistory() => const <WalletTransfer>[],
      ReadStatus() => WalletStatus.unknown,
      _ => null,
    };
    return answer as T;
  }

  @override
  void stop() {}
}

void main() {
  late Directory root;
  late AppStorage storage;
  late _RecordingBackend backend;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kranox-controller');
    storage = AppStorage(root.path);
    backend = _RecordingBackend();
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<WalletController> started() async {
    final controller = WalletController(worker: backend, storage: storage);
    await controller.start();
    addTearDown(controller.dispose);
    return controller;
  }

  void makeWallet(MoneroNetwork network) {
    Directory(storage.walletFolder(network)).createSync(recursive: true);
    File('${storage.walletPath(network)}.keys').createSync();
  }

  test('starts on mainnet and offers a new wallet there', () async {
    makeWallet(MoneroNetwork.stagenet);
    final controller = await started();
    expect(controller.network, MoneroNetwork.mainnet);
    expect(controller.phase, WalletPhase.noWallet);
    expect(controller.node, AppConfig.defaultNode(MoneroNetwork.mainnet));
  });

  test('moves to the wallet of another network and remembers the network', () async {
    makeWallet(MoneroNetwork.stagenet);
    final controller = await started();
    await controller.switchNetwork(MoneroNetwork.stagenet);
    expect(controller.phase, WalletPhase.locked);
    expect(controller.node, AppConfig.defaultNode(MoneroNetwork.stagenet));
    expect(controller.walletFolder, storage.walletFolder(MoneroNetwork.stagenet));

    final again = await started();
    expect(again.network, MoneroNetwork.stagenet);
    expect(again.phase, WalletPhase.locked);
  });

  test('closes the open wallet before it moves, and opens the wallet of the new network', () async {
    makeWallet(MoneroNetwork.mainnet);
    makeWallet(MoneroNetwork.testnet);
    final controller = await started();
    await controller.unlock('password');
    expect(controller.phase, WalletPhase.open);

    await controller.switchNetwork(MoneroNetwork.testnet);
    expect(controller.phase, WalletPhase.locked);
    expect(backend.requests.whereType<CloseWallet>(), hasLength(1));

    await controller.unlock('password');
    final opened = backend.requests.whereType<OpenWallet>().last;
    expect(opened.path, storage.walletPath(MoneroNetwork.testnet));
    expect(opened.networkType, MoneroNetwork.testnet.walletType);
    final connected = backend.requests.whereType<ConnectNode>().last;
    expect(connected.address, AppConfig.defaultNode(MoneroNetwork.testnet));
    await controller.lock();
  });

  test('keeps a chosen node with its network', () async {
    final controller = await started();
    await controller.changeNode('my.node:18081');
    expect(controller.node, 'my.node:18081');
    await controller.switchNetwork(MoneroNetwork.stagenet);
    expect(controller.node, AppConfig.defaultNode(MoneroNetwork.stagenet));
    await controller.switchNetwork(MoneroNetwork.mainnet);
    expect(controller.node, 'my.node:18081');
  });
}
