import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/network.dart';
import '../core/amount.dart';
import '../core/connection_probe.dart';
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

/// What the app found when it looked for the way to its node, after wallet2 had reported no connection for a while:
/// the trouble, or null when a plain connection opened, so that the trouble lies above the connection.
final class NodeReport {
  const NodeReport({required this.trouble, required this.node, required this.proxy, required this.at});

  final ConnectionTrouble? trouble;

  /// The node and the proxy that the look tried, so that the words name them and not a setting that came after.
  final String node;
  final String? proxy;

  /// When the look ended, on the clock of the controller, which only moves forward.
  final Duration at;
}

/// The state of the wallet for the screens. Every call to wallet2 goes through the backend: the worker in the app.
final class WalletController extends ChangeNotifier {
  WalletController({
    required this._worker,
    required this._storage,
    this.probe = const ConnectionProbe(),
    Duration Function()? elapsed,
  }) : _elapsed = elapsed ?? _monotonic();

  final WalletBackend _worker;
  final AppStorage _storage;

  /// The look for the trouble with the node; a test gives another one.
  final ConnectionProbe probe;

  /// The clock of the look, which only moves forward: a change of the clock of the Mac moves no look. A test gives
  /// its own.
  final Duration Function() _elapsed;

  static Duration Function() _monotonic() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  // The look for the trouble while the node does not answer: since when it has been silent, the last report, whether
  // a look runs, and a count that lets a look that ends after a connect, a lock, or a dispose change nothing.
  Duration? _nodeSilentSince;
  NodeReport? _nodeReport;
  bool _lookingForNode = false;
  int _lookGeneration = 0;
  bool _disposed = false;

  // One reconnect at a time, for the button of the notice: a click during one joins it. A failure of wallet2 in it
  // stays for the notice until the next reconnect.
  Future<void>? _reconnectInFlight;
  bool _reconnecting = false;
  WalletException? _reconnectFailure;

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

  /// What keeps the wallet from its node, as the app found by its own attempt to connect, while wallet2 reports no
  /// connection; null while the node answers, and before the first look.
  NodeReport? get nodeReport => _status.connection == NodeConnection.disconnected ? _nodeReport : null;

  /// Whether a look for the trouble with the node runs.
  bool get lookingForNode => _lookingForNode;

  /// Whether a reconnect runs, and what wallet2 answered to the last one when it refused.
  bool get reconnecting => _reconnecting;
  WalletException? get reconnectFailure => _reconnectFailure;
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

  /// Where the start moved a settings file that it could not read, or null, so that the screens can say so.
  String? get settingsRecoveredFrom => _storage.settingsRecoveredFrom;

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
    _checkNewPassword(password);
    await _storage.prepareWalletFolder(network);
    return _worker.call<List<String>>(
      CreateWallet(path: _storage.walletPath(network), password: password, networkType: network.walletType),
    );
  }

  Future<void> restore({required List<String> seed, required int restoreHeight, required String password}) async {
    _checkNewPassword(password);
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

  /// The rule of a new password holds here as well as on the screens, so that no way into the controller makes a
  /// wallet under a short password (the sharp-edges scan of 10 Oct 2026). A wallet made before keeps its password, so
  /// an unlock checks nothing. The error never holds the password.
  static void _checkNewPassword(String password) {
    if (!isLongEnoughPassword(password)) {
      throw ArgumentError('A new password must have at least ${AppConfig.minPasswordLength} characters.');
    }
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
    await _reconnectInFlight;
    await _worker.call<void>(const CloseWallet());
    _status = WalletStatus.unknown;
    _transfers = const [];
    _receiveAddress = null;
    _resetLook();
    _reconnectFailure = null;
  }

  /// Forgets the look: a look in flight changes nothing when it ends, and the report goes.
  void _resetLook() {
    _lookGeneration++;
    _lookingForNode = false;
    _nodeReport = null;
    _nodeSilentSince = null;
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

  Future<PreparedSend> prepareSend({required String address, required XmrAmount amount}) async {
    final prepared = await _worker.call<PreparedSend>(PrepareSend(address: address.trim(), amountUnits: amount.units));
    // A fee above the most that the app pays drops the payment before any review shows it.
    if (prepared.fee > AppConfig.maxNetworkFee) {
      await cancelSend(prepared);
      throw WalletException(WalletFailure.feeTooHigh, prepared.fee.toExact());
    }
    return prepared;
  }

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

  /// The keys of the files of the app that belong to the open wallet, such as the swaps of the bridge (wallet O-007
  /// of the second security review).
  Future<FileKeys> readFileKeys() => _worker.call<FileKeys>(const ReadFileKeys());

  /// Records in the wallet that its files are sealed with the key of [readFileKeys], so that the app takes no file of
  /// an earlier form after it (the sharp-edges scan of 10 Oct 2026).
  Future<void> markFilesSealed() => _worker.call<void>(const MarkFilesSealed());

  /// The SOCKS proxy to the node of every network and to the relay, or null when the wallet reaches both straight.
  String? get proxy => _settings.proxy;

  /// Whether wallet2 refused the proxy at the last connection, so that the wallet stays away from its node until the
  /// user sets one that works. The wallet still opens, so that the user can reach the settings.
  bool get proxyRefused => _proxyRefused;
  bool _proxyRefused = false;

  /// Saves the proxy, such as Tor at 127.0.0.1:9050, or no proxy for empty text, and connects the wallet through it.
  /// Throws a [NodeAddressException] for an address that is no IP address and port, and a [WalletException] of
  /// [WalletFailure.proxyRefused] when wallet2 refuses the proxy.
  Future<void> changeProxy(String text) async {
    final proxy = text.trim().isEmpty ? null : parseProxyAddress(text);
    if (proxy == _settings.proxy && !_proxyRefused) return;
    _settings = _settings.withProxy(proxy);
    await _storage.writeSettings(_settings);
    if (_phase == WalletPhase.open) {
      await _connect();
      await _readState(withHistory: false);
    }
    notifyListeners();
    if (_proxyRefused) {
      throw const WalletException(WalletFailure.proxyRefused, 'wallet2 refused the proxy.');
    }
  }

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

  /// Connects the wallet to its node. A node that does not answer leaves the wallet open and offline; so does a proxy
  /// that wallet2 refused, after which the engine asks the node nothing.
  Future<void> _connect() async {
    // A connect tries the settings as they stand, so a report of an earlier node or proxy says nothing about it.
    _resetLook();
    try {
      await _worker.call<void>(ConnectNode(address: node, proxy: proxy));
      _proxyRefused = false;
    } on WalletException catch (error) {
      switch (error.failure) {
        case WalletFailure.proxyRefused:
          _proxyRefused = true;
        case WalletFailure.nodeUnreachable:
          _proxyRefused = false;
        default:
          rethrow;
      }
    }
  }

  /// Connects the wallet to its node again, for the user who set things right outside the app, such as a Tor that
  /// started, and looks for the trouble at once when the node still does not answer. One runs at a time: a second
  /// call joins the first. A refusal of wallet2 stays in [reconnectFailure], so that the notice can say it.
  Future<void> reconnect() => _reconnectInFlight ??= _reconnect().whenComplete(() {
    _reconnectInFlight = null;
    _reconnecting = false;
    if (!_disposed) notifyListeners();
  });

  Future<void> _reconnect() async {
    if (_phase != WalletPhase.open) return;
    _reconnecting = true;
    _reconnectFailure = null;
    notifyListeners();
    try {
      await _connect();
      await _readState(withHistory: false);
    } on WalletException catch (failure) {
      if (_phase == WalletPhase.open) _reconnectFailure = failure;
      return;
    }
    if (_status.connection == NodeConnection.disconnected) await _lookForNode(now: true);
  }

  /// Looks for what keeps the wallet from its node, once the node has been silent for a while, and again at an
  /// interval; [now] looks at once. A proxy that wallet2 refused needs no look: the settings say so.
  Future<void> _lookForNode({bool now = false}) async {
    if (_phase != WalletPhase.open || _lookingForNode || _proxyRefused || _disposed) return;
    final moment = _elapsed();
    if (!now) {
      // The silence counts from the first read that found the node silent, which [_readState] notes.
      final since = _nodeSilentSince;
      if (since == null || moment - since < AppConfig.nodeLookDelay) return;
      if (_nodeReport case final report? when moment - report.at < AppConfig.lookInterval) return;
    }
    _lookingForNode = true;
    final generation = ++_lookGeneration;
    final node = this.node;
    final proxy = this.proxy;
    notifyListeners();
    ConnectionTrouble? trouble;
    try {
      final (:host, :port) = splitNodeAddress(node);
      trouble = await probe.run(host: host, port: port, proxy: proxy);
    } on Object catch (error, stack) {
      // A look that fails says so, and the failure reaches the zone of the app (the sharp-edges scan of 13 Oct 2026).
      trouble = ConnectionTrouble.lookFailed;
      Zone.current.handleUncaughtError(error, stack);
    }
    if (generation != _lookGeneration || _disposed) return;
    _lookingForNode = false;
    _nodeReport = NodeReport(trouble: trouble, node: node, proxy: proxy, at: _elapsed());
    notifyListeners();
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
    // The state "unknown" is no read of the node, so it starts no look.
    if (status.connection == NodeConnection.disconnected && !identical(status, WalletStatus.unknown)) {
      _nodeSilentSince ??= _elapsed();
      unawaited(_lookForNode());
    } else if (_nodeSilentSince != null || _lookingForNode) {
      _resetLook();
    }
    notifyListeners();
  }

  void _setPhase(WalletPhase phase) {
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _lookGeneration++;
    _poll?.cancel();
    super.dispose();
  }
}

/// Whether [password] is long enough for a new wallet: at least [AppConfig.minPasswordLength] characters, counted as
/// code points of Unicode, so that a character beyond the basic plane, such as an emoji, counts once rather than twice
/// (the sharp-edges scan of 10 Oct 2026).
bool isLongEnoughPassword(String password) => password.runes.length >= AppConfig.minPasswordLength;
