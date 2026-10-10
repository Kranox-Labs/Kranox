import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/network.dart';
import '../core/evm_address.dart';
import '../wallet/controller.dart';
import '../wallet/failure.dart';
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
  BridgeController({required this._client, required this._store, required this._wallet, this._scanner});

  final BridgeClient _client;

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

  /// Whether the relay answered at the last check; null before the first check.
  bool? get relayOnline => _relayOnline;
  bool get checkingRelay => _checkingRelay;

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

  /// The swaps of one way that its page shows with their steps, the newest first: every one that runs, and every one
  /// that ended and that the user has not closed yet, so that a result, above all a failure or a refund, stays in view
  /// until the user has read it.
  List<BridgeSwap> openSwapsOf(SwapDirection direction) => [
    for (final swap in swapsOf(direction))
      if (!swap.stage.isFinal || !swap.closed) swap,
  ];

  /// Closes the card of an ended swap. The swap stays in the list.
  Future<void> closeSwap(String id) async {
    _swaps = [for (final swap in _swaps) swap.id == id && swap.stage.isFinal ? swap.close() : swap];
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
      final Uint8List key;
      try {
        key = await _wallet.readFileKey();
      } on WalletException {
        // The wallet locked while its key was on the way; its change syncs again. A wallet that stays open fails loud.
        _swapsOpen = false;
        if (_wallet.phase == WalletPhase.open) rethrow;
        return;
      }
      _swaps = await _store.read(key);
      _followSwaps();
    } else {
      _poll?.cancel();
      _poll = null;
      await _pollInFlight;
      _store.close();
      _swaps = const [];
      _checkedAt = null;
    }
    if (!_disposed) notifyListeners();
  }

  /// Asks the relay whether it answers, for the settings page.
  Future<void> checkRelay() async {
    if (_checkingRelay) return;
    _checkingRelay = true;
    notifyListeners();
    _relayOnline = await _client.isOnline();
    _checkingRelay = false;
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
    if (_quote.value case final quote?) _minimums[quote.asset] = quote.minAmount;
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
    }
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
    if (created.refundAddress != refundAddress) {
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
  Future<void> refresh() => _pollInFlight ??= _readStates().whenComplete(() => _pollInFlight = null);

  /// Reads the state of the open swaps now and then at an interval, until every swap has ended.
  void _followSwaps() {
    if (_poll != null || activeSwap == null) return;
    _poll = Timer.periodic(AppConfig.bridgeStatusInterval, (_) => refresh());
    unawaited(refresh());
  }

  Future<void> _readStates() async {
    final next = <String, BridgeSwap>{};
    var answered = false;
    for (final swap in _swaps.where((swap) => swap.watched).toList()) {
      try {
        final updated = swap.withState(await _client.readSwap(swap.id, token: swap.readToken));
        answered = true;
        if (jsonEncode(updated.toJson()) != jsonEncode(swap.toJson())) next[swap.id] = updated;
      } on BridgeException {
        // The relay or the exchanger did not answer this time; the next round asks again.
      } on FormatException {
        // An answer of an unknown form; the next round asks again.
      }
    }
    if (next.isNotEmpty) {
      // A swap made while the states were on their way stays in the list.
      _swaps = [for (final swap in _swaps) next[swap.id] ?? swap];
      await _store.write(_swaps);
    }
    if (answered) _checkedAt = DateTime.now();
    if (next.isNotEmpty || answered) notifyListeners();
    if (activeSwap == null) {
      _poll?.cancel();
      _poll = null;
    }
  }

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
