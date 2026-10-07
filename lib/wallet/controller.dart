import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/network.dart';
import '../core/amount.dart';
import '../core/node_address.dart';
import '../core/unlock.dart';
import 'failure.dart';
import 'models.dart';
import 'requests.dart';
import 'settings.dart';
import 'storage.dart';
import 'worker.dart';

/// The stages of the app: it looks for a wallet, it offers to make one, it waits for the password, or it shows
/// the open wallet.
enum WalletPhase { starting, noWallet, locked, open }

/// The state of the wallet for the screens. Every call to wallet2 goes through the backend: the worker in the app.
final class WalletController extends ChangeNotifier {
  WalletController({required this._worker, required this._storage});

  final WalletBackend _worker;
  final AppStorage _storage;

  WalletPhase _phase = WalletPhase.starting;
  WalletStatus _status = WalletStatus.unknown;
  List<WalletTransfer> _transfers = const [];
  ReceiveAddress? _receiveAddress;
  AppSettings _settings = const AppSettings();
  Timer? _poll;
  Future<void>? _pollInFlight;

  // A payment on its way: a lock, a change of network, and the end of the app wait for it, so that the wallet never
  // closes between a payment that left and the reads after it.
  Future<void>? _sendInFlight;

  WalletPhase get phase => _phase;
  WalletStatus get status => _status;
  List<WalletTransfer> get transfers => _transfers;
  ReceiveAddress? get receiveAddress => _receiveAddress;

  /// The wait of the locked part of the balance: the progress of the transfer that unlocks last. Null when nothing is
  /// locked, or when no transfer in the history explains the locked part, as before the first read of the history.
  UnlockProgress? get unlockWait => _status.locked.units > 0
      ? UnlockProgress.slowest(_transfers.where((transfer) => !transfer.isFailed).map((transfer) => transfer.unlock))
      : null;
  MoneroNetwork get network => _settings.network;
  String get node => _settings.nodeOf(network);
  String get walletFolder => _storage.walletFolder(network);

  Future<void> start() async {
    _settings = await _storage.readSettings();
    await _showWalletOfNetwork();
  }

  /// Moves the app to another network. Each network keeps its own wallet: an open wallet closes, and the app asks
  /// for the password of the wallet of the other network, or offers to make one.
  Future<void> switchNetwork(MoneroNetwork network) async {
    if (network == this.network) return;
    await _closeWallet();
    _settings = _settings.withNetwork(network);
    await _storage.writeSettings(_settings);
    await _showWalletOfNetwork();
  }

  Future<void> _showWalletOfNetwork() async =>
      _setPhase(await _storage.walletExists(network) ? WalletPhase.locked : WalletPhase.noWallet);

  /// Makes a new wallet and gives its seed. The wallet opens when the user has written the seed down.
  Future<List<String>> create(String password) async {
    await _storage.prepareWalletFolder(network);
    return _worker.call<List<String>>(
      CreateWallet(path: _storage.walletPath(network), password: password, networkType: network.walletType),
    );
  }

  Future<void> restore({required List<String> seed, required int restoreHeight, required String password}) async {
    await _storage.prepareWalletFolder(network);
    await _worker.call<void>(
      RestoreWallet(
        path: _storage.walletPath(network),
        password: password,
        seed: seed.join(' '),
        restoreHeight: restoreHeight,
        networkType: network.walletType,
      ),
    );
    await enterWallet();
  }

  Future<void> unlock(String password) async {
    await _worker.call<void>(
      OpenWallet(path: _storage.walletPath(network), password: password, networkType: network.walletType),
    );
    await enterWallet();
  }

  /// Reads the wallet from its file, connects it to its node, and shows it. A node that does not answer leaves the
  /// wallet open: the home screen shows the connection, and the user can choose another node.
  Future<void> enterWallet() async {
    // The history comes first: once the wallet scans the chain, a read of the history stops the scan.
    _receiveAddress = await _readReceiveAddress();
    _transfers = await _worker.call<List<WalletTransfer>>(const ReadHistory());
    await _connect();
    await _readState(withHistory: false);
    _poll = Timer.periodic(AppConfig.statusInterval, (_) => _pollOnce());
    _setPhase(WalletPhase.open);
  }

  Future<void> lock() async {
    await _closeWallet();
    _setPhase(WalletPhase.locked);
  }

  /// Stops the reads of the state and closes the wallet in the engine, if one is open there. A payment on its way
  /// ends first.
  Future<void> _closeWallet() async {
    _poll?.cancel();
    _poll = null;
    await _pollInFlight;
    await _sendInFlight;
    await _worker.call<void>(const CloseWallet());
    _status = WalletStatus.unknown;
    _transfers = const [];
    _receiveAddress = null;
  }

  /// Closes the wallet before the app quits, so that wallet2 writes its file.
  Future<void> shutdown() async {
    if (_phase == WalletPhase.open) {
      await lock();
    }
    _worker.stop();
  }

  /// The subaddress that the receive page shows: the one that the settings keep for this network. Without one, or
  /// when the wallet does not have it, as after a restore, the wallet makes a new subaddress, so that the page never
  /// shows one that the bridge handed to the exchanger.
  Future<ReceiveAddress> _readReceiveAddress() async {
    final saved = _settings.receiveIndexOf(network);
    if (saved != null) {
      try {
        return await _worker.call<ReceiveAddress>(ReadSubaddress(index: saved));
      } on WalletException catch (error) {
        if (error.failure != WalletFailure.native) rethrow;
      }
    }
    final address = await _worker.call<ReceiveAddress>(const ReadReceiveAddress(createNew: true));
    await _keepReceiveIndex(address.index);
    return address;
  }

  Future<void> _keepReceiveIndex(int index) async {
    _settings = _settings.withReceiveIndex(network, index);
    await _storage.writeSettings(_settings);
  }

  /// Makes a new subaddress for the receive page.
  Future<void> newReceiveAddress() async {
    final address = await _worker.call<ReceiveAddress>(const ReadReceiveAddress(createNew: true));
    await _keepReceiveIndex(address.index);
    _receiveAddress = address;
    notifyListeners();
  }

  /// Makes a subaddress for the exchanger: the payout of a swap or the refund of a payment. The receive page keeps its
  /// own subaddress, so that the user never hands out an address that the exchanger knows. The wallet writes its file
  /// at once, so that no crash can give the same index again.
  Future<ReceiveAddress> newBridgeAddress() async {
    final address = await _worker.call<ReceiveAddress>(const ReadReceiveAddress(createNew: true));
    await _worker.call<void>(const StoreWallet());
    return address;
  }

  Future<PreparedSend> prepareSend({required String address, required XmrAmount amount}) =>
      _worker.call<PreparedSend>(PrepareSend(address: address.trim(), amountUnits: amount.units));

  /// Sends [prepared], the payment of the review on screen, and no other, with the [password] of the wallet. With
  /// [deadline], the payment leaves only before that time. Throws a [WalletException] when nothing left the wallet.
  Future<SentPayment> confirmSend(PreparedSend prepared, {required String password, DateTime? deadline}) async {
    final done = Completer<void>();
    _sendInFlight = done.future;
    try {
      final payment = await _worker.call<SentPayment>(
        ConfirmSend(
          id: prepared.id,
          address: prepared.address,
          amountUnits: prepared.amount.units,
          password: password,
          deadline: deadline?.millisecondsSinceEpoch,
        ),
      );
      await _refreshAfterSend();
      return payment;
    } finally {
      _sendInFlight = null;
      done.complete();
    }
  }

  /// Reads the state after a payment left. The payment is out either way, so a read that fails, such as one that a
  /// node interrupts, leaves the screens as they were until the next read of the poll.
  Future<void> _refreshAfterSend() async {
    try {
      await _readState(withHistory: true);
    } on WalletException {
      // The payment stays sent: the next read shows it in the history.
    }
  }

  /// Drops [prepared] when it is still the payment that the wallet holds.
  Future<void> cancelSend(PreparedSend prepared) => _worker.call<void>(CancelSend(id: prepared.id));

  Future<List<String>> readSeed(String password) => _worker.call<List<String>>(ReadSeed(password: password));

  /// Saves another node for the network of the app and connects the wallet to it. Throws a [NodeAddressException]
  /// for an address of the wrong form.
  Future<void> changeNode(String text) async {
    final node = parseNodeAddress(text);
    _settings = _settings.withNode(network, node);
    await _storage.writeSettings(_settings);
    if (_phase == WalletPhase.open) {
      await _connect();
      await _readState(withHistory: false);
    }
    notifyListeners();
  }

  Future<void> _connect() async {
    try {
      await _worker.call<void>(ConnectNode(address: node));
    } on WalletException catch (error) {
      if (error.failure != WalletFailure.nodeUnreachable) rethrow;
    }
  }

  void _pollOnce() {
    if (_pollInFlight != null) return;
    _pollInFlight = _readState(withHistory: false).whenComplete(() => _pollInFlight = null);
  }

  /// Reads the state of the wallet. The history comes along when the wallet has caught up with the node and has
  /// scanned new blocks or seen its balance change.
  ///
  /// A read of the history stops the scan of wallet2 while it runs: CHECKED 4 Oct 2026, a new stagenet wallet
  /// advanced no block in 25 seconds while the app read the history every 2 seconds. So the app leaves the history
  /// alone until the wallet has caught up.
  Future<void> _readState({required bool withHistory}) async {
    final previous = _status;
    final status = await _worker.call<WalletStatus>(const ReadStatus());
    final changed =
        status.walletHeight != previous.walletHeight ||
        status.balance != previous.balance ||
        status.unlocked != previous.unlocked ||
        status.synchronized != previous.synchronized;
    if (withHistory || (status.synchronized && changed)) {
      _transfers = await _worker.call<List<WalletTransfer>>(const ReadHistory());
    }
    if (status.synchronized && !previous.synchronized) {
      await _worker.call<void>(const StoreWallet());
    }
    _status = status;
    notifyListeners();
  }

  void _setPhase(WalletPhase phase) {
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
