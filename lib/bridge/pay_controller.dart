import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/network.dart';
import '../core/address.dart';
import '../core/amount.dart';
import '../core/evm_address.dart';
import '../wallet/controller.dart';
import '../wallet/failure.dart';
import '../wallet/models.dart';
import 'attempt.dart';
import 'client.dart';
import 'live_quote.dart';
import 'models.dart';

/// A payment that the exchanger made and that the wallet built, before it leaves: what the review shows.
final class PayReview {
  const PayReview({
    required this.created,
    required this.asset,
    required this.rate,
    required this.prepared,
    required this.refund,
    required this.validUntil,
  });

  final CreatedPay created;
  final BridgeAsset asset;
  final PayRate rate;

  /// The XMR payment to the deposit address of the exchanger, with its fee.
  final PreparedSend prepared;

  /// The subaddress of this wallet that takes the XMR back if the swap fails.
  final ReceiveAddress refund;

  /// The time until which the fixed rate waits for the deposit, as the exchanger gives it.
  final DateTime? validUntil;
}

/// The state of pay for the send page: the form, where the user types the XMR to pay, chooses the rate, and sees the
/// coin that it buys, the review of a payment, and the payment itself, which [record] keeps among the swaps that the
/// app follows before its XMR leaves, [update] completes once it left, and [forget] drops when nothing left. The
/// exchanger works on the Monero mainnet only.
final class PayController extends ChangeNotifier {
  PayController({
    required this._client,
    required this._wallet,
    required this._record,
    required this._update,
    required this._forget,
  }) {
    _wallet.addListener(_followWallet);
  }

  final BridgeClient _client;
  final WalletController _wallet;
  final Future<void> Function(BridgeSwap swap) _record;
  final Future<void> Function(BridgeSwap swap) _update;
  final Future<void> Function(String id) _forget;

  // A review on its way: the exchanger makes the payment and the wallet builds it. The send page keeps its choice of
  // the way until it ends, so that no plain payment is built meanwhile.
  bool _preparing = false;

  // The mock of 3 Oct 2026 shows a payment in USDG first, the coin with a fixed value.
  BridgeAsset _asset = BridgeAsset.usdg;

  // A fixed rate first: the recipient gets exactly the amount that the form shows.
  PayRate _rate = PayRate.fixed;
  String _recipient = '';
  String _xmrText = '';
  late final LiveQuote<(BridgeAsset, PayRate, String), PayQuote> _quote = LiveQuote(
    fetch: _fetchQuote,
    onChanged: notifyListeners,
  );
  PayReview? _review;

  // The range of one payment for each coin and rate, so that the form shows the least amount before the user types.
  final Map<(BridgeAsset, PayRate), PayRange> _ranges = {};
  BridgeException? _rangeError;

  // A range on its way when the page goes away must not reach a controller that is gone.
  bool _disposed = false;

  // The creation of a payment whose answer has not come back, for a second try of the same form.
  CreationAttempt? _payAttempt;
  final Random _random = Random.secure();

  BridgeAsset get asset => _asset;
  PayRate get rate => _rate;
  String get recipientText => _recipient;

  /// The XMR to pay, as the field holds it.
  String get xmrText => _xmrText;
  PayQuote? get quote => _quote.value;
  BridgeException? get quoteError => _quote.error;
  bool get quoting => _quote.pending;

  /// The payment under review, or null while the form shows.
  PayReview? get review => _review;

  /// Whether a review is on its way.
  bool get preparing => _preparing;

  /// A lock or a change of network closes the wallet and drops the payment that it built, so the review goes too.
  void _followWallet() {
    if (_review != null && _wallet.phase != WalletPhase.open) {
      _review = null;
      notifyListeners();
    }
  }

  /// The range of one payment into the coin of the form at the rate of the form, once the exchanger gave it.
  PayRange? get range => rangeOf(_rate);

  /// The range of one payment into the coin of the form at [rate], for the choice of the rate.
  PayRange? rangeOf(PayRate rate) => _ranges[(_asset, rate)];

  /// Why a range of the coin of the form did not come, or null.
  BridgeException? get rangeError => _rangeError;

  /// Asks the exchanger for the range of one payment into the coin of the form at each rate, unless the app knows it
  /// already.
  Future<void> loadRange() async {
    final asset = _asset;
    if (!available) return;
    for (final rate in PayRate.values) {
      if (_ranges.containsKey((asset, rate))) continue;
      try {
        final range = await _client.payRange(asset, rate);
        if (_disposed) return;
        _ranges[(asset, rate)] = range;
        _rangeError = null;
      } on BridgeException catch (failure) {
        _rangeError = failure;
      } on FormatException catch (failure) {
        _rangeError = BridgeException(BridgeFailure.failed, failure.message);
      }
    }
    if (!_disposed) notifyListeners();
  }

  /// Where the XMR to pay stands against [range]: below it, above it, or null within it or while it is unknown.
  PayLimit? _limitIn(PayRange? range) {
    final xmr = this.xmr;
    if (xmr == null || range == null) return null;
    final value = xmr.units / XmrAmount.unitsPerXmr;
    if (value < range.minXmr) return PayLimit.below;
    final max = range.maxXmr;
    if (max != null && value > max) return PayLimit.above;
    return null;
  }

  /// Where the XMR to pay stands against the range of the rate of the form.
  PayLimit? get limit => _limitIn(range);

  /// Whether the XMR to pay is below the minimum of a fixed rate but within the range of a floating one, so that the
  /// form offers the floating rate.
  bool get suggestsFloating =>
      _rate == PayRate.fixed &&
      limit == PayLimit.below &&
      rangeOf(PayRate.floating) != null &&
      _limitIn(rangeOf(PayRate.floating)) == null;

  /// Whether the open wallet can pay: the exchanger works on mainnet only.
  bool get available => _wallet.network == MoneroNetwork.mainnet;

  /// The recipient when the field holds a valid address of Robinhood Chain, or null.
  String? get recipient {
    try {
      return checkEvmAddress(_recipient);
    } on EvmAddressException {
      return null;
    }
  }

  void setRecipient(String text) {
    if (text == _recipient) return;
    _recipient = text;
    notifyListeners();
  }

  void selectAsset(BridgeAsset asset) {
    if (asset == _asset) return;
    _asset = asset;
    _followQuote();
    unawaited(loadRange());
  }

  void selectRate(PayRate rate) {
    if (rate == _rate) return;
    _rate = rate;
    _followQuote();
  }

  void setXmr(String text) {
    final xmr = text.trim();
    if (xmr == _xmrText) return;
    _xmrText = xmr;
    _followQuote();
  }

  void _followQuote() => _quote.follow(available && isBridgeAmount(_xmrText) ? (_asset, _rate, _xmrText) : null);

  /// Asks for a quote, and keeps the range that comes with an amount outside it, which is the newest one.
  Future<PayQuote> _fetchQuote((BridgeAsset, PayRate, String) key) async {
    final quote = await _client.payQuote(key.$1, key.$2, key.$3);
    final min = quote.minXmr;
    if (quote.limit != null && min != null) {
      _ranges[(quote.asset, quote.rate)] = PayRange(
        asset: quote.asset,
        rate: quote.rate,
        minXmr: min,
        maxXmr: quote.maxXmr,
      );
    }
    return quote;
  }

  /// The XMR to pay, when the field holds an amount that the form takes and that the wallet can hold.
  XmrAmount? get xmr {
    if (!isBridgeAmount(_xmrText)) return null;
    try {
      return XmrAmount.parse(_xmrText);
    } on AmountFormatException {
      return null;
    }
  }

  /// The quote when it covers the form as it stands.
  PayQuote? get _currentQuote {
    final quote = _quote.value;
    if (quote == null || quote.asset != _asset || quote.rate != _rate || quote.xmrAmount != _xmrText) return null;
    return quote;
  }

  /// The amount of the coin that the recipient gets, when the quote covers the form as it stands: exact at a fixed
  /// rate, an estimate at a floating rate.
  double? get quotedAmount => _currentQuote?.amount;

  /// Whether the XMR to pay leaves room for the network fee in the unlocked balance, once the wallet knows it.
  bool get coversFee {
    final xmr = this.xmr;
    final status = _wallet.status;
    return xmr == null || status.isLoading || status.unlocked > xmr;
  }

  /// Whether the form holds a recipient and an amount of XMR that the exchanger quoted and the wallet can pay.
  bool get canReview =>
      available &&
      recipient != null &&
      quotedAmount != null &&
      (_rate == PayRate.floating || _currentQuote?.rateId != null) &&
      !_quote.pending &&
      coversFee &&
      _review == null &&
      !_preparing;

  /// Makes the payment at the exchanger at the quoted rate, then builds the XMR payment to its deposit address, so
  /// that the review shows the real fee. Nothing leaves the wallet yet: a payment that the user does not send runs out
  /// at the exchanger. Throws a [BridgeException] or a wallet failure.
  Future<PayReview> startReview() async {
    final quote = _currentQuote;
    final recipient = this.recipient;
    if (!canReview || quote == null || recipient == null) {
      throw StateError('The pay form holds no recipient and quoted amount.');
    }
    _preparing = true;
    notifyListeners();
    try {
      return await _prepareReview(quote, recipient);
    } finally {
      _preparing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<PayReview> _prepareReview(PayQuote quote, String recipient) async {
    final rateId = quote.rate == PayRate.fixed ? quote.rateId : null;
    // A new subaddress takes a refund, so that the exchanger sees an address that no payer has seen. A second try of
    // the same form reuses the subaddress and the key of the first, whose answer may have been lost.
    final attempt = await attemptFor(
      [quote.asset.code, quote.rate.name, quote.xmrAmount, recipient, rateId ?? ''].join('|'),
      _payAttempt,
      _wallet.newBridgeAddress,
      _random,
    );
    _payAttempt = attempt;
    final refund = attempt.address;
    final CreatedPay created;
    try {
      created = await _client.createPay(
        asset: quote.asset,
        rate: quote.rate,
        xmrAmount: quote.xmrAmount,
        address: recipient,
        refundAddress: refund.address,
        rateId: rateId,
        creationKey: attempt.key,
      );
    } on FormatException catch (failure) {
      throw BridgeException(BridgeFailure.failed, failure.message);
    }
    // The app knows the payment now, so the next review makes a new one: a second payment to the same recipient must
    // never reuse the deposit address of the first.
    _payAttempt = null;
    final xmr = XmrAmount.parse(quote.xmrAmount);
    _checkCreated(created, recipient: recipient, xmr: xmr, refundAddress: refund.address);
    // The state of the new payment gives the time until which a fixed rate waits for the deposit.
    final SwapState state;
    try {
      state = await _client.readSwap(created.id, token: created.readToken);
    } on FormatException catch (failure) {
      throw BridgeException(BridgeFailure.failed, failure.message);
    }
    // Without its time, a fixed rate would let the XMR leave after the rate ran out.
    if (quote.rate == PayRate.fixed && state.validUntil == null) {
      throw const BridgeException(BridgeFailure.failed, 'The exchanger gave no time for its fixed rate.');
    }
    final prepared = await _wallet.prepareSend(address: created.depositAddress, amount: xmr);
    final review = PayReview(
      created: created,
      asset: quote.asset,
      rate: quote.rate,
      prepared: prepared,
      refund: refund,
      validUntil: state.validUntil,
    );
    _review = review;
    notifyListeners();
    return review;
  }

  /// Sends the XMR of the payment under review with the [password] of the wallet, and keeps the swap among the swaps
  /// that the app follows. Throws a [BridgeException] of [BridgeFailure.rateExpired] when the fixed rate runs out too
  /// soon, so that the user reviews the payment again.
  Future<BridgeSwap> confirm({required String password}) async {
    final review = _review;
    if (review == null) throw StateError('No payment is under review.');
    final validUntil = review.validUntil;
    final deadline = validUntil?.subtract(AppConfig.payRateMargin);
    if (deadline != null && !DateTime.now().isBefore(deadline)) {
      await cancelReview();
      throw const BridgeException(BridgeFailure.rateExpired, 'The fixed rate ran out before the payment left.');
    }
    final created = review.created;
    // The swap and its exchange id go to the file before any XMR leaves, so that no lock, quit, or crash after the
    // payment can lose them.
    final waiting = BridgeSwap(
      direction: SwapDirection.pay,
      id: created.id,
      asset: review.asset,
      amount: created.amount,
      xmrAmount: created.xmrAmount,
      depositAddress: created.depositAddress,
      payoutAddress: created.payoutAddress,
      subaddressIndex: review.refund.index,
      refundAddress: review.refund.address,
      createdAt: DateTime.now(),
      stage: SwapStage.waiting,
      validUntil: validUntil,
      fixedRate: review.rate == PayRate.fixed,
      readToken: created.readToken,
    );
    await _record(waiting);
    final SentPayment sent;
    try {
      // The engine checks the deadline again right before the send, so that time spent in the queue counts too.
      sent = await _wallet.confirmSend(review.prepared, password: password, deadline: deadline);
    } on WalletException catch (failure) {
      // wallet2 sent nothing, so the swap goes again; the exchanger lets its payment run out.
      await _forget(waiting.id);
      if (failure.failure == WalletFailure.deadlinePassed) {
        _review = null;
        notifyListeners();
        throw const BridgeException(BridgeFailure.rateExpired, 'The fixed rate ran out before the payment left.');
      }
      if (failure.failure == WalletFailure.paymentChanged || failure.failure == WalletFailure.walletClosed) {
        _review = null;
        notifyListeners();
      }
      rethrow;
    }
    _review = null;
    _recipient = '';
    _xmrText = '';
    _quote.follow(null);
    final swap = waiting.withDeposit(sent.transactionId);
    await _update(swap);
    return swap;
  }

  /// Drops the payment under review. The XMR payment never leaves, and the payment at the exchanger runs out.
  Future<void> cancelReview() async {
    final review = _review;
    if (review == null) return;
    await _wallet.cancelSend(review.prepared);
    _review = null;
    notifyListeners();
  }

  /// The app checks what the exchanger made before it builds a payment to it: the recipient, the XMR, a deposit
  /// address of the Monero mainnet, and the refund to the subaddress that the app sent.
  static void _checkCreated(
    CreatedPay created, {
    required String recipient,
    required XmrAmount xmr,
    required String refundAddress,
  }) {
    if (created.payoutAddress.toLowerCase() != recipient.toLowerCase()) {
      throw const BridgeException(BridgeFailure.failed, 'The exchanger made the payment for another recipient.');
    }
    if (created.refundAddress != refundAddress) {
      throw const BridgeException(BridgeFailure.failed, 'The exchanger made the payment with another refund address.');
    }
    if ((created.xmrAmount - xmr.units / XmrAmount.unitsPerXmr).abs() > AppConfig.payAmountTolerance) {
      throw const BridgeException(BridgeFailure.failed, 'The exchanger made the payment for another amount of XMR.');
    }
    try {
      checkAddress(created.depositAddress, MoneroNetwork.mainnet);
    } on AddressException {
      throw const BridgeException(BridgeFailure.failed, 'The exchanger gave a deposit address outside Monero mainnet.');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _wallet.removeListener(_followWallet);
    _quote.dispose();
    super.dispose();
  }
}
