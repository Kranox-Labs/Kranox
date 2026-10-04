import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../core/amount.dart';
import '../core/node_address.dart';
import 'failure.dart';
import 'models.dart';
import 'requests.dart';
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
  String _node = AppConfig.defaultNode;
  Timer? _poll;
  Future<void>? _pollInFlight;

  WalletPhase get phase => _phase;
  WalletStatus get status => _status;
  List<WalletTransfer> get transfers => _transfers;
  ReceiveAddress? get receiveAddress => _receiveAddress;
  String get node => _node;
  String get walletFolder => _storage.walletFolder;

  Future<void> start() async {
    _node = await _storage.readNode();
    _setPhase(await _storage.walletExists() ? WalletPhase.locked : WalletPhase.noWallet);
  }

  /// Makes a new wallet and gives its seed. The wallet opens when the user has written the seed down.
  Future<List<String>> create(String password) async {
    await _storage.prepareWalletFolder();
    return _worker.call<List<String>>(
      CreateWallet(path: _storage.walletPath, password: password, networkType: AppConfig.network.walletType),
    );
  }

  Future<void> restore({required List<String> seed, required int restoreHeight, required String password}) async {
    await _storage.prepareWalletFolder();
    await _worker.call<void>(
      RestoreWallet(
        path: _storage.walletPath,
        password: password,
        seed: seed.join(' '),
        restoreHeight: restoreHeight,
        networkType: AppConfig.network.walletType,
      ),
    );
    await enterWallet();
  }

  Future<void> unlock(String password) async {
    await _worker.call<void>(
      OpenWallet(path: _storage.walletPath, password: password, networkType: AppConfig.network.walletType),
    );
    await enterWallet();
  }

  /// Reads the wallet from its file, connects it to its node, and shows it. A node that does not answer leaves the
  /// wallet open: the home screen shows the connection, and the user can choose another node.
  Future<void> enterWallet() async {
    // The history comes first: once the wallet scans the chain, a read of the history stops the scan.
    _receiveAddress = await _worker.call<ReceiveAddress>(const ReadReceiveAddress(createNew: false));
    _transfers = await _worker.call<List<WalletTransfer>>(const ReadHistory());
    await _connect();
    await _readState(withHistory: false);
    _poll = Timer.periodic(AppConfig.statusInterval, (_) => _pollOnce());
    _setPhase(WalletPhase.open);
  }

  Future<void> lock() async {
    _poll?.cancel();
    _poll = null;
    await _pollInFlight;
    await _worker.call<void>(const CloseWallet());
    _status = WalletStatus.unknown;
    _transfers = const [];
    _receiveAddress = null;
    _setPhase(WalletPhase.locked);
  }

  /// Closes the wallet before the app quits, so that wallet2 writes its file.
  Future<void> shutdown() async {
    if (_phase == WalletPhase.open) {
      await lock();
    }
    _worker.stop();
  }

  Future<void> newReceiveAddress() async {
    _receiveAddress = await _worker.call<ReceiveAddress>(const ReadReceiveAddress(createNew: true));
    notifyListeners();
  }

  Future<PreparedSend> prepareSend({required String address, required XmrAmount amount}) =>
      _worker.call<PreparedSend>(PrepareSend(address: address.trim(), amountUnits: amount.units));

  Future<SentPayment> confirmSend() async {
    final payment = await _worker.call<SentPayment>(const ConfirmSend());
    await _readState(withHistory: true);
    return payment;
  }

  Future<void> cancelSend() => _worker.call<void>(const CancelSend());

  Future<List<String>> readSeed(String password) => _worker.call<List<String>>(ReadSeed(password: password));

  /// Saves another node and connects the wallet to it. Throws a [NodeAddressException] for an address of the
  /// wrong form.
  Future<void> changeNode(String text) async {
    final node = parseNodeAddress(text);
    await _storage.writeNode(node);
    _node = node;
    if (_phase == WalletPhase.open) {
      await _connect();
      await _readState(withHistory: false);
    }
    notifyListeners();
  }

  Future<void> _connect() async {
    try {
      await _worker.call<void>(ConnectNode(address: _node));
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
