import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/network.dart';
import '../wallet/controller.dart';
import 'client.dart';
import 'live_quote.dart';
import 'models.dart';
import 'pay_controller.dart';
import 'store.dart';

/// The state of the bridge for its pages: the receive form with its live quote, pay in [pay], and the swaps of both
/// ways that the app follows. The exchanger works on the Monero mainnet only.
final class BridgeController extends ChangeNotifier {
  BridgeController({required this._client, required this._store, required this._wallet});

  final BridgeClient _client;
  final BridgeStore _store;
  final WalletController _wallet;

  BridgeAsset _asset = BridgeAsset.eth;
  String _amount = '';
  late final LiveQuote<(BridgeAsset, String), BridgeQuote> _quote = LiveQuote(
    fetch: (key) => _client.quote(key.$1, key.$2),
    onChanged: notifyListeners,
  );
  List<BridgeSwap> _swaps = const [];
  bool? _relayOnline;
  bool _checkingRelay = false;
  Timer? _poll;
  Future<void>? _pollInFlight;

  /// Pay, XMR out to an address on Robinhood Chain, for the send page. A payment that leaves joins the swaps here.
  late final PayController pay = PayController(client: _client, wallet: _wallet, record: _addSwap);

  BridgeAsset get asset => _asset;
  String get amount => _amount;
  BridgeQuote? get quote => _quote.value;
  BridgeException? get quoteError => _quote.error;
  bool get quoting => _quote.pending;

  /// Whether the relay answered at the last check; null before the first check.
  bool? get relayOnline => _relayOnline;
  bool get checkingRelay => _checkingRelay;

  /// Every swap, the newest first.
  List<BridgeSwap> get swaps => _swaps;

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

  /// The swap of one way that its page shows with its steps: the newest one that runs, or that ended and that the user
  /// has not closed yet, so that a result, above all a failure or a refund, stays in view until the user has read it.
  BridgeSwap? shownSwapOf(SwapDirection direction) {
    for (final swap in swapsOf(direction)) {
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
    final quote = _quote.value;
    return available &&
        quote != null &&
        quote.asset == _asset &&
        quote.amount == _amount &&
        quote.estimatedXmr != null &&
        !_quote.pending;
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

  void _scheduleQuote() => _quote.follow(available && isBridgeAmount(_amount) ? (_asset, _amount) : null);

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
      xmrAmount: created.estimatedXmr,
      depositAddress: created.depositAddress,
      payoutAddress: created.payoutAddress,
      subaddressIndex: address.index,
      createdAt: DateTime.now(),
      stage: SwapStage.waiting,
      refundAddress: refundAddress,
    );
    _amount = '';
    _quote.follow(null);
    await _addSwap(swap);
    return swap;
  }

  /// Keeps a new swap, the newest first, and follows it.
  Future<void> _addSwap(BridgeSwap swap) async {
    _swaps = [swap, ..._swaps];
    await _store.write(_swaps);
    _followSwaps();
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
    _quote.dispose();
    pay.dispose();
    _poll?.cancel();
    super.dispose();
  }
}
