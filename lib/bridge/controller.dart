import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/network.dart';
import '../core/connection_probe.dart';
import '../core/socks.dart' show SocksException;
import '../core/evm_address.dart';
import '../wallet/controller.dart';
import '../wallet/failure.dart';
import '../wallet/models.dart' show FileKeys;
import 'attempt.dart';
import 'chain_scan.dart';
import 'client.dart';
import 'live_quote.dart';
import 'models.dart';
import 'pay_controller.dart';
import 'store.dart';

/// The state of the bridge for its pages: the receive form with its live quote, pay in [pay], and the swaps of both
/// ways that the app follows. The exchanger works on the Monero mainnet only.
final class BridgeController extends ChangeNotifier {
  BridgeController({
    required this._client,
    required this._store,
    required this._wallet,
    this._scanner,
    this.probe = const ConnectionProbe(),
  });

  final BridgeClient _client;

  /// The look for the trouble with the relay; a test gives another one.
  final ConnectionProbe probe;

  // The look for the trouble while the relay does not answer: the last report, whether a look runs, and a count that
  // lets a look that ends after the swaps closed change nothing.
  ConnectionTrouble? _relayTrouble;
  DateTime? _relayLookedAt;
  bool _lookingForRelay = false;
  int _relayLookGeneration = 0;

  /// The scan of an address on Robinhood Chain for the menu Privacy, when the relay of the app offers it.
  final ChainScanClient? _scanner;
  final BridgeStore _store;
  final WalletController _wallet;

  BridgeAsset _asset = BridgeAsset.eth;
  String _amount = '';
  late final LiveQuote<(BridgeAsset, String), BridgeQuote> _quote = LiveQuote(
    fetch: (key) => _client.quote(key.$1, key.$2),
    onChanged: _quoteChanged,
  );
  final Map<BridgeAsset, double> _minimums = {};

  // The creation of a swap whose answer has not come back, for a second try of the same form.
  CreationAttempt? _receiveAttempt;
  final Random _random = Random.secure();
  List<BridgeSwap> _swaps = const [];
  bool? _relayOnline;
  bool _checkingRelay = false;
  DateTime? _checkedAt;
  Timer? _poll;
  Future<void>? _pollInFlight;

  // Whether the swaps of the open wallet are read, and the sync with the wallet that runs.
  bool _swapsOpen = false;
  Future<void> _syncing = Future<void>.value();
  bool _disposed = false;

  /// Pay, XMR out to an address on Robinhood Chain, for the send page. A payment that leaves joins the swaps here.
  /// The controller exists from the first use, so that a bridge that never paid listens to nothing.
  PayController get pay => _pay ??= PayController(
    client: _client,
    wallet: _wallet,
    record: _addSwap,
    update: _replaceSwap,
    forget: _removeSwap,
    relayFailed: _noteRelayFailure,
    relayAnswered: _noteRelayAnswer,
  );
  PayController? _pay;

  ChainScanClient? get scanner => _scanner;

  /// Where the start moved a file of swaps that it could not read whole, or null, so that the screens can say so.
  String? get recoveredFrom => _store.recoveredFrom;
  BridgeAsset get asset => _asset;
  String get amount => _amount;
  BridgeQuote? get quote => _quote.value;
  BridgeException? get quoteError => _quote.error;
  bool get quoting => _quote.pending;

  /// The least amount of the coin of the form that the exchanger takes, from the latest quote of that coin; null
  /// before the first one. It stays while the next quote is on its way, so that the form does not flicker.
  double? get minimum => _minimums[_asset];

  /// Whether the quote of the form says that its amount stands below the minimum, so that it buys no XMR.
  bool get belowMinimum {
    final quote = _quote.value;
    return quote != null && quote.estimatedXmr == null && double.parse(quote.amount) < quote.minAmount;
  }

  /// Whether the relay answered at the last check or the last call; null before the first.
  bool? get relayOnline => _relayOnline;
  bool get checkingRelay => _checkingRelay;

  /// What keeps the app from the relay, as the app found by its own attempt to connect, while the relay does not
  /// answer; null while it answers, before the first look, and when a plain connection opened.
  ConnectionTrouble? get relayTrouble => _relayOnline == false ? _relayTrouble : null;

  /// Whether a look for the trouble with the relay runs.
  bool get lookingForRelay => _lookingForRelay;

  /// The proxy through which the app reaches the relay, or null; the words about the trouble name it.
  String? get proxy => _wallet.proxy;

  /// Whether the proxy is Tor built into the app, which the words about the trouble name rather than its address.
  bool get torBuiltIn => _wallet.torBuiltIn;

  /// Every swap, the newest first.
  List<BridgeSwap> get swaps => _swaps;

  /// When the exchanger last answered for the swaps that run, so that their cards show that the app still follows
  /// them; null before the first answer.
  DateTime? get checkedAt => _checkedAt;

  /// The swaps of one way, the newest first.
  List<BridgeSwap> swapsOf(SwapDirection direction) => [
    for (final swap in _swaps)
      if (swap.direction == direction) swap,
  ];

  /// Whether the open wallet can use the bridge: the exchanger works on mainnet only.
  bool get available => _wallet.network == MoneroNetwork.mainnet;

  /// The newest swap that the app still follows: one that runs, or one that failed and may still be refunded.
  BridgeSwap? get activeSwap {
    for (final swap in _swaps) {
      if (swap.watched) return swap;
    }
    return null;
  }

  /// The newest swap of one way that the app still follows.
  BridgeSwap? activeSwapOf(SwapDirection direction) {
    for (final swap in swapsOf(direction)) {
      if (swap.watched) return swap;
    }
    return null;
  }

  /// The swaps of one way that its page shows with their steps, the newest first: every one whose card the user has
  /// not closed yet, whether it runs or ended, so that a result, above all a failure or a refund, stays in view until
  /// the user has read it, and a card that waits goes when the user wants it gone (13 Oct 2026).
  List<BridgeSwap> openSwapsOf(SwapDirection direction) => [
    for (final swap in swapsOf(direction))
      if (!swap.closed) swap,
  ];

  /// Closes the card of a swap. The swap stays in the list, and a swap that runs stays followed: the owner asked on
  /// 13 Oct 2026 that a card never has to stay in view while it waits, so the screens ask the user first for a swap
  /// that has not ended.
  Future<void> closeSwap(String id) async {
    // A close after a lock, or of a swap that is gone, does nothing: the file of the swaps is closed then.
    if (!_swapsOpen || _swapOf(id) == null) return;
    _swaps = [for (final swap in _swaps) swap.id == id ? swap.close() : swap];
    await _store.write(_swaps);
    if (activeSwap == null) {
      _poll?.cancel();
      _poll = null;
    }
    notifyListeners();
  }

  /// Whether the quote covers the amount in the form and allows a swap.
  bool get canSwap {
    final quote = _quote.value;
    return available &&
        quote != null &&
        quote.asset == _asset &&
        quote.amount == _amount &&
        quote.estimatedXmr != null &&
        !_quote.pending;
  }

  /// Follows the wallet: the swaps open with the mainnet wallet and close when it locks, because their file reads only
  /// with the key of the open wallet (wallet O-007 of the second security review).
  Future<void> start() async {
    _wallet.addListener(_walletChanged);
    await _syncWithWallet();
  }

  /// One sync after another, in the order of the changes of the wallet. A failure reaches the zone of the app, and the
  /// syncs after it run all the same.
  void _walletChanged() {
    _syncing = _syncing
        .then((_) => _syncWithWallet())
        .catchError((Object error, StackTrace stack) => Zone.current.handleUncaughtError(error, stack));
  }

  Future<void> _syncWithWallet() async {
    if (_disposed) return;
    final open = _wallet.phase == WalletPhase.open && available;
    if (open == _swapsOpen) return;
    _swapsOpen = open;
    if (open) {
      final FileKeys keys;
      try {
        keys = await _wallet.readFileKeys();
      } on WalletException {
        // The wallet locked while its key was on the way; its change syncs again. A wallet that stays open fails loud.
        _swapsOpen = false;
        if (_wallet.phase == WalletPhase.open) rethrow;
        return;
      }
      _swaps = await _store.read(keys);
      // The file holds the seal of the key now, so a file of an earlier form no longer counts. A wallet that locked
      // in the meantime records it at its next unlock.
      if (keys.earlierKey != null) {
        try {
          await _wallet.markFilesSealed();
        } on WalletException {
          if (_wallet.phase == WalletPhase.open) rethrow;
        }
      }
      _followSwaps();
    } else {
      _poll?.cancel();
      _poll = null;
      await _pollInFlight;
      _store.close();
      _swaps = const [];
      _checkedAt = null;
      // The relay is looked at afresh with the next wallet, and a look in flight changes nothing.
      _relayLookGeneration++;
      _lookingForRelay = false;
      _relayTrouble = null;
      _relayLookedAt = null;
      _relayOnline = null;
    }
    if (!_disposed) notifyListeners();
  }

  /// Asks the relay whether it answers, for the settings page, and looks for the trouble when it does not.
  Future<void> checkRelay() async {
    if (_checkingRelay) return;
    _checkingRelay = true;
    notifyListeners();
    final online = _relayOnline = await _client.isOnline();
    if (_disposed) return;
    _checkingRelay = false;
    notifyListeners();
    if (online) {
      _relayTrouble = null;
    } else {
      await _lookForRelay(now: true);
    }
  }

  /// Notes a call that the relay did not answer, and looks for the trouble; another failure says nothing about the way
  /// to the relay.
  void _noteRelayFailure(BridgeException error) {
    if (error.failure != BridgeFailure.relayDown) return;
    _relayOnline = false;
    unawaited(_lookForRelay());
  }

  /// Notes a call that the relay answered.
  void _noteRelayAnswer() {
    _relayOnline = true;
    _relayTrouble = null;
    // A relay that fails again soon after gets a fresh look.
    _relayLookedAt = null;
  }

  /// Looks for what keeps the app from the relay, at most once an interval; [now] looks at once.
  Future<void> _lookForRelay({bool now = false}) async {
    if (_lookingForRelay || _disposed) return;
    if (!now) {
      if (_relayLookedAt case final at? when DateTime.now().difference(at) < AppConfig.lookInterval) return;
    }
    _lookingForRelay = true;
    final generation = ++_relayLookGeneration;
    notifyListeners();
    ConnectionTrouble? trouble;
    try {
      final relay = Uri.parse(AppConfig.bridgeRelay);
      final port = relay.hasPort ? relay.port : (relay.scheme == 'https' ? 443 : 80);
      // The address of the relay is checked at the start of the app; a host that is empty all the same is no look.
      if (relay.host.isEmpty) throw ArgumentError.value(AppConfig.bridgeRelay, 'bridgeRelay', 'has no host');
      // A look while the wallet waits for Tor built into the app would reach the relay without it, so the trouble is
      // Tor, and no look goes out.
      trouble = _wallet.waitsForTor
          ? ConnectionTrouble.torNotReady
          : await probe.run(host: relay.host, port: port, proxy: _wallet.proxy);
      // A proxy of Tor built into the app that stopped answering: Tor counts as failed (W-04).
      if (_wallet.torBuiltIn &&
          (trouble == ConnectionTrouble.proxyDown || trouble == ConnectionTrouble.proxyNotSocks5)) {
        _wallet.tor?.markDead(const SocksException('The proxy of Tor built into the app stopped answering.'));
      }
    } on Object catch (error, stack) {
      // A look that fails says so, and the failure reaches the zone of the app (the sharp-edges scan of 13 Oct 2026).
      trouble = ConnectionTrouble.lookFailed;
      Zone.current.handleUncaughtError(error, stack);
    }
    if (generation != _relayLookGeneration || _disposed) return;
    _lookingForRelay = false;
    _relayTrouble = trouble;
    _relayLookedAt = DateTime.now();
    notifyListeners();
  }

  void selectAsset(BridgeAsset asset) {
    if (asset == _asset) return;
    _asset = asset;
    _scheduleQuote();
  }

  void setAmount(String text) {
    final amount = text.trim();
    if (amount == _amount) return;
    _amount = amount;
    _scheduleQuote();
  }

  void _scheduleQuote() => _quote.follow(available && isBridgeAmount(_amount) ? (_asset, _amount) : null);

  void _quoteChanged() {
    if (_quote.value case final quote?) {
      _minimums[quote.asset] = quote.minAmount;
      _noteRelayAnswer();
    }
    if (_quote.error case final error?) _noteRelayFailure(error);
    notifyListeners();
  }

  /// Makes a swap of the amount in the form into XMR. The XMR goes to a new subaddress of this wallet, so that the
  /// exchanger sees an address that no payer has seen. Throws a [BridgeException] or a wallet failure.
  Future<BridgeSwap> createSwap({String? refundAddress}) async {
    if (!canSwap) throw StateError('The bridge form holds no quoted amount.');
    final asset = _asset;
    final amount = _amount;
    // A second try of the same form reuses the subaddress and the key of the first, whose answer may have been lost.
    final attempt = await attemptFor(
      [asset.code, amount, refundAddress ?? ''].join('|'),
      _receiveAttempt,
      _wallet.newBridgeAddress,
      _random,
    );
    _receiveAttempt = attempt;
    final address = attempt.address;
    final CreatedSwap created;
    try {
      created = await _client.createSwap(
        asset: asset,
        amount: amount,
        address: address.address,
        refundAddress: refundAddress,
        creationKey: attempt.key,
      );
    } on FormatException catch (failure) {
      throw BridgeException(BridgeFailure.failed, failure.message);
    } on BridgeException catch (failure) {
      _noteRelayFailure(failure);
      rethrow;
    }
    _noteRelayAnswer();
    _receiveAttempt = null;
    _checkCreated(created, address: address.address, amount: amount, refundAddress: refundAddress);
    final swap = BridgeSwap(
      id: created.id,
      asset: asset,
      amount: created.amount,
      xmrAmount: created.estimatedXmr,
      depositAddress: created.depositAddress,
      payoutAddress: created.payoutAddress,
      subaddressIndex: address.index,
      createdAt: DateTime.now(),
      stage: SwapStage.waiting,
      refundAddress: refundAddress,
      readToken: created.readToken,
    );
    _amount = '';
    _quote.follow(null);
    await _addSwap(swap);
    return swap;
  }

  /// The app checks what the exchanger made before it shows the deposit address as a code and the amount as "Send
  /// exactly": the coin goes in at an address of Robinhood Chain, of the amount of the form, for the subaddress that
  /// the app sent, with the refund address that the user gave.
  static void _checkCreated(
    CreatedSwap created, {
    required String address,
    required String amount,
    required String? refundAddress,
  }) {
    if (created.payoutAddress != address) {
      throw const BridgeException(BridgeFailure.failed, 'The exchanger made the swap for another address.');
    }
    // From 10 Oct 2026 the relay answers the refund address that ChangeNOW recorded, which may differ from the address
    // of the form in the case of its hex digits only: an address on Robinhood Chain is the same in any case.
    if (created.refundAddress?.toLowerCase() != refundAddress?.toLowerCase()) {
      throw const BridgeException(BridgeFailure.failed, 'The exchanger made the swap with another refund address.');
    }
    if ((created.amount - double.parse(amount)).abs() > AppConfig.payAmountTolerance) {
      throw const BridgeException(BridgeFailure.failed, 'The exchanger made the swap for another amount.');
    }
    try {
      checkEvmAddress(created.depositAddress);
    } on EvmAddressException {
      throw const BridgeException(
        BridgeFailure.failed,
        'The exchanger gave a deposit address outside Robinhood Chain.',
      );
    }
  }

  /// Keeps a new swap, the newest first, and follows it.
  Future<void> _addSwap(BridgeSwap swap) async {
    _swaps = [swap, ..._swaps];
    await _store.write(_swaps);
    _followSwaps();
    notifyListeners();
  }

  /// Keeps the newer state of a swap that the list holds.
  Future<void> _replaceSwap(BridgeSwap swap) async {
    _swaps = [for (final kept in _swaps) kept.id == swap.id ? swap : kept];
    await _store.write(_swaps);
    notifyListeners();
  }

  /// Drops a swap whose payment never left the wallet.
  Future<void> _removeSwap(String id) async {
    _swaps = [
      for (final kept in _swaps)
        if (kept.id != id) kept,
    ];
    await _store.write(_swaps);
    if (activeSwap == null) {
      _poll?.cancel();
      _poll = null;
    }
    notifyListeners();
  }

  /// Asks the exchanger for the state of every swap that has not ended.
  Future<void> refresh() => _pollInFlight ??= _readStates()
      // A read that fails, such as a write of the file that the disk refused, reaches the zone of the app once and
      // stops nothing that waits for the read, such as a lock.
      .catchError((Object error, StackTrace stack) => Zone.current.handleUncaughtError(error, stack))
      .whenComplete(() => _pollInFlight = null);

  /// Reads the state of the open swaps now and then at an interval, until every swap has ended.
  void _followSwaps() {
    if (_poll != null || activeSwap == null) return;
    _poll = Timer.periodic(AppConfig.bridgeStatusInterval, (_) => refresh());
    unawaited(refresh());
  }

  Future<void> _readStates() async {
    var changed = false;
    var answered = false;
    for (final id in [
      for (final swap in _swaps)
        if (swap.watched) swap.id,
    ]) {
      final swap = _swapOf(id);
      if (swap == null) continue;
      final SwapState state;
      try {
        state = await _client.readSwap(id, token: swap.readToken);
      } on BridgeException catch (failure) {
        // The relay or the exchanger did not answer this time; the next round asks again.
        _noteRelayFailure(failure);
        continue;
      } on FormatException {
        // An answer of an unknown form; the next round asks again.
        continue;
      }
      if (_disposed) return;
      answered = true;
      // The swap as it stands now: a card closed or a swap dropped during the read must not come back (CHECKED 13 Oct
      // 2026 by the test of a card that closes while a read runs).
      final latest = _swapOf(id);
      if (latest == null) continue;
      var updated = latest.withState(state);
      // A card closed while the swap ran comes back when the swap leaves the good way: a failure, a hold, a refund, or
      // a deposit that did not come needs the user, and the app follows a failed swap only while its card is open.
      if (latest.closed && !latest.stage.isFinal && updated.stage.isOffPath) updated = updated.reopen();
      if (jsonEncode(updated.toJson()) == jsonEncode(latest.toJson())) continue;
      _swaps = [for (final kept in _swaps) kept.id == id ? updated : kept];
      changed = true;
    }
    if (changed) await _store.write(_swaps);
    if (_disposed) return;
    if (answered) {
      _checkedAt = DateTime.now();
      _noteRelayAnswer();
    }
    if (changed || answered) notifyListeners();
    if (activeSwap == null) {
      _poll?.cancel();
      _poll = null;
    }
  }

  BridgeSwap? _swapOf(String id) => _swaps.where((swap) => swap.id == id).firstOrNull;

  @override
  void dispose() {
    _disposed = true;
    _wallet.removeListener(_walletChanged);
    _quote.dispose();
    _pay?.dispose();
    _poll?.cancel();
    super.dispose();
  }
}
