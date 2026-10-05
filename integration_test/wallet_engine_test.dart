// Runs the wallet without a window, with the real Monero library and a stagenet node: it makes a wallet, waits
// until the wallet has caught up with the node, makes a subaddress, tries a payment that the balance does not cover,
// reads the seed, locks the wallet and opens it again, and restores a second wallet from the same seed.
//
// Run in apps/wallet, after sh tool/fetch_monero_c.sh: fvm flutter test integration_test/wallet_engine_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/core/address.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/failure.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

const String _password = 'kranox-test-password';

/// A new stagenet wallet first fetches the hashes of the blocks since the last checkpoint of wallet2, about 550,000,
/// up to the height of the node, about 2,222,000. CHECKED 4 Oct 2026: one to six minutes, by node.
const Duration _syncPatience = Duration(minutes: 8);
const Duration _step = Duration(milliseconds: 500);

// A stagenet address of a throwaway wallet, as in test/core/address_test.dart.
const String _stagenetAddress =
    '54gC41sfYPoXMRg6ytR2hRTtwK2TES1cbZ1KPxxXKAv2drLzkQbakX4ifsEGq2SZo5WeXHRM7hLRA1YC3F6Eyu6aLwnPUng';

/// The library that tool/fetch_monero_c.sh puts beside the macOS project. The test runs outside the app bundle.
String get _libraryPath => '${Directory.current.path}/macos/Libraries/libmonero_wallet2_api_c.dylib';

Matcher _failsWith(WalletFailure failure) =>
    throwsA(isA<WalletException>().having((error) => error.failure, 'failure', failure));

Future<WalletController> _controllerIn(Directory root) async {
  final worker = await WalletWorker.start(libraryPath: _libraryPath);
  final controller = WalletController(worker: worker, storage: AppStorage(root.path));
  await controller.start();
  await controller.switchNetwork(MoneroNetwork.stagenet);
  return controller;
}

Future<void> _waitUntil(bool Function() condition, String what, Duration patience) async {
  final deadline = DateTime.now().add(patience);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('The wallet did not reach: $what.');
    await Future<void>.delayed(_step);
  }
}

void main() {
  test('makes, syncs, locks, opens, and restores a stagenet wallet', () async {
    final root = Directory.systemTemp.createTempSync('kranox-engine');
    final controller = await _controllerIn(root);
    expect(controller.phase, WalletPhase.noWallet);

    final seed = await controller.create(_password);
    expect(seed, hasLength(25));
    await controller.enterWallet();
    expect(controller.phase, WalletPhase.open);

    // The seed shows with the password also while the wallet scans the chain.
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(controller.status.synchronized, isFalse);
    await expectLater(controller.readSeed('wrong-password'), _failsWith(WalletFailure.wrongPassword));
    expect(await controller.readSeed(_password), seed);
    await _waitUntil(() => controller.status.synchronized, 'a scanned chain', _syncPatience);
    expect(controller.status.walletHeight, greaterThanOrEqualTo(controller.status.nodeHeight - 1));
    expect(controller.status.balance, XmrAmount.zero);

    // The app hands out subaddresses, and each new one has the next index.
    final first = controller.receiveAddress!;
    expect(first.index, 1);
    expect(checkAddress(first.address, MoneroNetwork.stagenet), AddressKind.subaddress);
    await controller.newReceiveAddress();
    expect(controller.receiveAddress!.index, first.index + 1);

    // wallet2 refuses a payment that the balance does not cover.
    await expectLater(
      controller.prepareSend(address: _stagenetAddress, amount: XmrAmount.parse('1')),
      _failsWith(WalletFailure.notEnoughUnlocked),
    );

    // The seed shows only with the password, and it is the seed of the creation.
    await expectLater(controller.readSeed('wrong-password'), _failsWith(WalletFailure.wrongPassword));
    expect(await controller.readSeed(_password), seed);

    await controller.lock();
    expect(controller.phase, WalletPhase.locked);
    await expectLater(controller.unlock('wrong-password'), _failsWith(WalletFailure.wrongPassword));
    expect(controller.phase, WalletPhase.locked);
    await controller.unlock(_password);
    expect(controller.phase, WalletPhase.open);
    final nodeHeight = controller.status.nodeHeight;
    await controller.shutdown();

    // A wallet restored from the seed derives the same subaddresses.
    final restoredRoot = Directory.systemTemp.createTempSync('kranox-restored');
    final restored = await _controllerIn(restoredRoot);
    await restored.restore(seed: seed, restoreHeight: nodeHeight, password: _password);
    expect(restored.phase, WalletPhase.open);
    expect(restored.receiveAddress!.address, first.address);
    await restored.shutdown();

    root.deleteSync(recursive: true);
    restoredRoot.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
