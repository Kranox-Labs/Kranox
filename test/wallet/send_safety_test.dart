import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/config/app_config.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/failure.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

const _sent = SentPayment(transactionId: 'tx1', amount: XmrAmount(160000000000), fee: XmrAmount(30000000));
const _prepared = PreparedSend(
  id: 1,
  address: 'deposit-of-the-exchanger',
  amount: XmrAmount(160000000000),
  fee: XmrAmount(30000000),
);

/// A wallet engine that answers one request at a time, in the order of arrival, as the worker of the app does
/// (lib/wallet/worker.dart). A send can wait in the engine until the test lets it go, as a long commit of wallet2 does;
/// a closed wallet refuses every read, as the engine does (lib/wallet/engine.dart).
final class _QueueWallet implements WalletBackend {
  final List<Type> handled = [];
  final Map<int, String> subaddresses = {1: 'subaddress-1'};
  bool open = false;
  Completer<void>? holdCommit;
  PreparedSend prepared = _prepared;
  WalletException? readFailure;
  Future<void> _tail = Future<void>.value();

  @override
  Future<T> call<T>(WalletRequest request) {
    final answer = _tail.then((_) => _handle(request));
    _tail = answer.then((_) {}, onError: (Object _) {});
    return answer.then((value) => value as T);
  }

  Future<Object?> _handle(WalletRequest request) async {
    handled.add(request.runtimeType);
    switch (request) {
      case OpenWallet():
        open = true;
        return null;
      case CloseWallet():
        open = false;
        return null;
      case ConnectNode():
        return null;
      case PrepareSend():
        _requireOpen();
        return prepared;
      case CancelSend():
        return null;
      case ConfirmSend():
        _requireOpen();
        await holdCommit?.future;
        return _sent;
      case ReadReceiveAddress(:final createNew):
        _requireOpen();
        if (createNew) subaddresses[subaddresses.length + 1] = 'subaddress-${subaddresses.length + 1}';
        final index = subaddresses.length;
        return ReceiveAddress(address: subaddresses[index]!, index: index);
      case ReadSubaddress(:final index):
        _requireOpen();
        final address = subaddresses[index];
        if (address == null) throw WalletException(WalletFailure.native, 'No subaddress #$index.');
        return ReceiveAddress(address: address, index: index);
      case ReadStatus():
        _requireOpen();
        if (readFailure case final failure?) throw failure;
        return WalletStatus.unknown;
      case ReadHistory():
        _requireOpen();
        return const <WalletTransfer>[];
      case StoreWallet():
        _requireOpen();
        return null;
      default:
        throw UnsupportedError('The queue wallet does not answer ${request.runtimeType}.');
    }
  }

  void _requireOpen() {
    if (!open) throw const WalletException(WalletFailure.walletClosed, 'No wallet is open.');
  }

  @override
  void stop() {}
}

void main() {
  late Directory root;
  late AppStorage storage;
  late _QueueWallet engine;
  late WalletController controller;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('kranox-send-safety');
    storage = AppStorage(root.path);
    await storage.prepareWalletFolder(MoneroNetwork.mainnet);
    File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
    engine = _QueueWallet();
    controller = WalletController(worker: engine, storage: storage);
    await controller.start();
    await controller.unlock('password');
  });

  tearDown(() {
    controller.dispose();
    root.deleteSync(recursive: true);
  });

  test('a network fee above the most that the app pays drops the payment, and nothing leaves (K-11)', () async {
    final amount = XmrAmount.parse('1');
    engine.prepared = PreparedSend(
      id: 2,
      address: 'an-address',
      amount: amount,
      fee: XmrAmount(AppConfig.maxNetworkFee.units + 1),
    );
    await expectLater(
      controller.prepareSend(address: 'an-address', amount: amount),
      throwsA(isA<WalletException>().having((error) => error.failure, 'failure', WalletFailure.feeTooHigh)),
    );
    expect(engine.handled, containsAllInOrder([PrepareSend, CancelSend]));
    expect(engine.handled, isNot(contains(ConfirmSend)));

    engine.prepared = PreparedSend(id: 3, address: 'an-address', amount: amount, fee: AppConfig.maxNetworkFee);
    expect(
      (await controller.prepareSend(address: 'an-address', amount: amount)).id,
      3,
      reason: 'the most still goes',
    );
  });

  test('a lock during a send waits for it, and the send reports the payment that left', () async {
    engine.holdCommit = Completer<void>();
    final sending = controller.confirmSend(_prepared, password: 'password');
    await pumpEventQueue();
    final locking = controller.lock();
    await pumpEventQueue();
    expect(engine.handled, isNot(contains(CloseWallet)), reason: 'the wallet stays open while the payment leaves');
    engine.holdCommit!.complete();
    expect((await sending).transactionId, 'tx1');
    await locking;
    final order = engine.handled.skipWhile((type) => type != ConfirmSend).toList();
    expect(order.first, ConfirmSend);
    expect(order.last, CloseWallet);
    expect(order.indexOf(ReadStatus), lessThan(order.indexOf(CloseWallet)), reason: 'the reads come before the close');
    expect(controller.phase, WalletPhase.locked);
  });

  test('the end of the app during a send waits for it too', () async {
    engine.holdCommit = Completer<void>();
    final sending = controller.confirmSend(_prepared, password: 'password');
    await pumpEventQueue();
    final quitting = controller.shutdown();
    await pumpEventQueue();
    expect(engine.handled, isNot(contains(CloseWallet)));
    engine.holdCommit!.complete();
    expect((await sending).transactionId, 'tx1');
    await quitting;
  });

  test('a read that fails after the payment left does not turn the payment into a failure', () async {
    engine.readFailure = const WalletException(WalletFailure.nodeUnreachable, 'failed to connect to daemon');
    expect((await controller.confirmSend(_prepared, password: 'password')).transactionId, 'tx1');
  });

  test('a send that reaches a closed wallet sends nothing and says so', () async {
    await controller.lock();
    await expectLater(
      controller.confirmSend(_prepared, password: 'password'),
      throwsA(isA<WalletException>().having((error) => error.failure, 'failure', WalletFailure.walletClosed)),
    );
  });

  test('the receive page keeps its own subaddress, and the bridge never takes it', () async {
    final shown = controller.receiveAddress!;
    final forBridge = await controller.newBridgeAddress();
    expect(forBridge.index, greaterThan(shown.index));
    expect(controller.receiveAddress!.address, shown.address);
    expect(engine.handled.last, StoreWallet, reason: 'the wallet writes the new index at once');

    // After a restart the receive page shows the same subaddress, not the newest one of the bridge.
    await controller.lock();
    await controller.unlock('password');
    expect(controller.receiveAddress!.address, shown.address);

    await controller.newReceiveAddress();
    final newer = controller.receiveAddress!;
    expect(newer.index, greaterThan(forBridge.index));
    await controller.lock();
    await controller.unlock('password');
    expect(controller.receiveAddress!.address, newer.address);
  });

  test('a damaged settings file lets the app start with the defaults, and stays for support', () async {
    final path = '${root.path}/settings.json';
    File(path).writeAsStringSync('{"network": "mainnet", "nodes": {"mainnet": 4');
    final storage = AppStorage(root.path);
    final settings = await storage.readSettings();
    expect(settings.network, MoneroNetwork.mainnet);
    expect(File(path).existsSync(), isFalse);
    expect(storage.settingsRecoveredFrom, contains('settings.json.unreadable-'), reason: 'the screens can say so');
    expect(
      root.listSync().whereType<File>().where((file) => file.path.contains('settings.json.unreadable-')),
      hasLength(1),
    );
  });

  test('the settings keep the subaddress of the receive page for each network', () async {
    final saved = jsonDecode(File('${root.path}/settings.json').readAsStringSync()) as Map<String, Object?>;
    expect(saved['receiveIndexes'], {'mainnet': controller.receiveAddress!.index});
  });
}
