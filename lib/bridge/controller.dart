import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/network.dart';
import '../wallet/controller.dart';
import 'client.dart';
import 'models.dart';
import 'store.dart';

/// An amount of the bridge form: digits, and a point with at most [AppConfig.bridgeAmountDecimals] decimals.
final RegExp _amountPattern = RegExp('^\\d{1,9}(\\.\\d{1,${AppConfig.bridgeAmountDecimals}})?\$');

/// Whether [text] is an amount above zero that the bridge form takes.
bool isBridgeAmount(String text) => _amountPattern.hasMatch(text) && double.parse(text) > 0;

/// The state of the bridge for its page: the receive form with its live quote, and the swaps that the app follows.
/// The exchanger works on the Monero mainnet only.
final class BridgeController extends ChangeNotifier {
  BridgeController({required this._client, required this._store, required this._wallet});

  final BridgeClient _client;
  final BridgeStore _store;
  final WalletController _wallet;

  BridgeAsset _asset = BridgeAsset.eth;
  String _amount = '';
  BridgeQuote? _quote;
  BridgeException? _quoteError;
  bool _quoting = false;
  List<BridgeSwap> _swaps = const [];
  bool? _relayOnline;
  bool _checkingRelay = false;
  Timer? _quoteTimer;
  Timer? _poll;
  Future<void>? _pollInFlight;

  BridgeAsset get asset => _asset;
  String get amount => _amount;
  BridgeQuote? get quote => _quote;
  BridgeException? get quoteError => _quoteError;
  bool get quoting => _quoting;

  /// Whether the relay answered at the last check; null before the first check.
  bool? get relayOnline => _relayOnline;
  bool get checkingRelay => _checkingRelay;

  /// Every swap, the newest first.
  List<BridgeSwap> get swaps => _swaps;

  /// Whether the open wallet can use the bridge: the exchanger works on mainnet only.
  bool get available => _wallet.network == MoneroNetwork.mainnet;

  /// The newest swap that the app still follows: one that runs, or one that failed and may still be refunded.
  BridgeSwap? get activeSwap {
    for (final swap in _swaps) {
      if (swap.watched) return swap;
    }
    return null;
  }

  /// The swap that the page shows with its steps: the newest one that runs, or that ended and that the user has not
  /// closed yet, so that a result, above all a failure or a refund, stays in view until the user has read it.
  BridgeSwap? get shownSwap {
    for (final swap in _swaps) {
      if (!swap.stage.isFinal || !swap.closed) return swap;
    }
    return null;
  }

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
    final quote = _quote;
    return available &&
        quote != null &&
        quote.asset == _asset &&
        quote.amount == _amount &&
        quote.estimatedXmr != null &&
        !_quoting;
  }

  Future<void> start() async {
    _swaps = await _store.read();
    _followSwaps();
    notifyListeners();
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

  /// Asks for a quote a moment after the last change of the form, so that typing does not send a request per key.
  void _scheduleQuote() {
    _quoteTimer?.cancel();
    _quote = null;
    _quoteError = null;
    if (available && isBridgeAmount(_amount)) {
      _quoting = true;
      _quoteTimer = Timer(AppConfig.bridgeQuoteDelay, _fetchQuote);
    } else {
      _quoting = false;
    }
    notifyListeners();
  }

  Future<void> _fetchQuote() async {
    final asset = _asset;
    final amount = _amount;
    BridgeQuote? quote;
    BridgeException? error;
    try {
      quote = await _client.quote(asset, amount);
    } on BridgeException catch (failure) {
      error = failure;
    } on FormatException catch (failure) {
      error = BridgeException(BridgeFailure.failed, failure.message);
    }
    // The form may have changed while the quote was on its way; a newer request follows then.
    if (asset != _asset || amount != _amount) return;
    _quote = quote;
    _quoteError = error;
    _quoting = false;
    notifyListeners();
  }

  /// Makes a swap of the amount in the form into XMR. The XMR goes to a new subaddress of this wallet, so that the
  /// exchanger sees an address that no payer has seen. Throws a [BridgeException] or a wallet failure.
  Future<BridgeSwap> createSwap({String? refundAddress}) async {
    if (!canSwap) throw StateError('The bridge form holds no quoted amount.');
    final asset = _asset;
    final amount = _amount;
    await _wallet.newReceiveAddress();
    final address = _wallet.receiveAddress;
    if (address == null) throw StateError('The wallet gave no subaddress.');
    final CreatedSwap created;
    try {
      created = await _client.createSwap(
        asset: asset,
        amount: amount,
        address: address.address,
        refundAddress: refundAddress,
      );
    } on FormatException catch (failure) {
      throw BridgeException(BridgeFailure.failed, failure.message);
    }
    final swap = BridgeSwap(
      id: created.id,
      asset: asset,
      amount: created.amount,
      estimatedXmr: created.estimatedXmr,
      depositAddress: created.depositAddress,
      payoutAddress: created.payoutAddress,
      subaddressIndex: address.index,
      createdAt: DateTime.now(),
      stage: SwapStage.waiting,
      refundAddress: refundAddress,
    );
    _swaps = [swap, ..._swaps];
    await _store.write(_swaps);
    _amount = '';
    _quote = null;
    _followSwaps();
    notifyListeners();
    return swap;
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
    for (final swap in _swaps.where((swap) => swap.watched).toList()) {
      try {
        final updated = swap.withState(await _client.readSwap(swap.id));
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
      notifyListeners();
    }
    if (activeSwap == null) {
      _poll?.cancel();
      _poll = null;
    }
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _poll?.cancel();
    super.dispose();
  }
}
