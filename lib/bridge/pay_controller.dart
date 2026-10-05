import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/network.dart';
import '../core/address.dart';
import '../core/amount.dart';
import '../core/evm_address.dart';
import '../wallet/controller.dart';
import '../wallet/models.dart';
import 'client.dart';
import 'live_quote.dart';
import 'models.dart';

/// A payment that the exchanger made and that the wallet built, before it leaves: what the review shows.
final class PayReview {
  const PayReview({
    required this.created,
    required this.asset,
    required this.prepared,
    required this.refund,
    required this.validUntil,
  });

  final CreatedPay created;
  final BridgeAsset asset;

  /// The XMR payment to the deposit address of the exchanger, with its fee.
  final PreparedSend prepared;

  /// The subaddress of this wallet that takes the XMR back if the swap fails.
  final ReceiveAddress refund;

  /// The time until which the fixed rate waits for the deposit, as the exchanger gives it.
  final DateTime? validUntil;
}

/// The state of pay for the send page: the form with its live quote at a fixed rate, the review of a payment, and the
/// payment itself, which [record] keeps among the swaps that the app follows. The exchanger works on the Monero
/// mainnet only.
final class PayController extends ChangeNotifier {
  PayController({required this._client, required this._wallet, required this._record});

  final BridgeClient _client;
  final WalletController _wallet;
  final Future<void> Function(BridgeSwap swap) _record;

  // The mock of 3 Oct 2026 shows a payment in USDG first, the coin with a fixed value.
  BridgeAsset _asset = BridgeAsset.usdg;
  String _recipient = '';
  String _amount = '';
  late final LiveQuote<(BridgeAsset, String), PayQuote> _quote = LiveQuote(
    fetch: (key) => _client.payQuote(key.$1, key.$2),
    onChanged: notifyListeners,
  );
  PayReview? _review;

  BridgeAsset get asset => _asset;
  String get recipientText => _recipient;
  String get amount => _amount;
  PayQuote? get quote => _quote.value;
  BridgeException? get quoteError => _quote.error;
  bool get quoting => _quote.pending;

  /// The payment under review, or null while the form shows.
  PayReview? get review => _review;

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
  }

  void setAmount(String text) {
    final amount = text.trim();
    if (amount == _amount) return;
    _amount = amount;
    _followQuote();
  }

  void _followQuote() => _quote.follow(available && isBridgeAmount(_amount) ? (_asset, _amount) : null);

  /// The XMR that the quote of the form asks for, when the exchanger takes the amount at a fixed rate.
  XmrAmount? get quotedXmr {
    final quote = _quote.value;
    final xmr = quote?.xmrAmount;
    if (quote == null || xmr == null || quote.asset != _asset || quote.amount != _amount) return null;
    return _xmr(xmr);
  }

  /// Whether the quote asks for more XMR than the wallet can send now. The fee comes out of the unlocked balance too.
  bool get aboveUnlocked {
    final xmr = quotedXmr;
    final status = _wallet.status;
    return xmr != null && !status.isLoading && !(status.unlocked > xmr);
  }

  /// Whether the form holds a recipient and a quoted amount that the wallet can pay.
  bool get canReview =>
      available &&
      recipient != null &&
      quotedXmr != null &&
      _quote.value?.rateId != null &&
      !_quote.pending &&
      !aboveUnlocked &&
      _review == null;

  /// Makes the payment at the exchanger at the quoted rate, then builds the XMR payment to its deposit address, so
  /// that the review shows the real fee. Nothing leaves the wallet yet: a payment that the user does not send runs out
  /// at the exchanger. Throws a [BridgeException] or a wallet failure.
  Future<PayReview> startReview() async {
    final quote = _quote.value;
    final recipient = this.recipient;
    final rateId = quote?.rateId;
    if (!canReview || quote == null || recipient == null || rateId == null) {
      throw StateError('The pay form holds no recipient and quoted amount.');
    }
    // A new subaddress takes a refund, so that the exchanger sees an address that no payer has seen.
    await _wallet.newReceiveAddress();
    final refund = _wallet.receiveAddress;
    if (refund == null) throw StateError('The wallet gave no subaddress.');
    final CreatedPay created;
    try {
      created = await _client.createPay(
        asset: quote.asset,
        amount: quote.amount,
        address: recipient,
        refundAddress: refund.address,
        rateId: rateId,
      );
    } on FormatException catch (failure) {
      throw BridgeException(BridgeFailure.failed, failure.message);
    }
    _checkCreated(created, recipient: recipient, amount: quote.amount);
    // The state of the new payment gives the time until which the fixed rate waits for the deposit.
    final SwapState state;
    try {
      state = await _client.readSwap(created.id);
    } on FormatException catch (failure) {
      throw BridgeException(BridgeFailure.failed, failure.message);
    }
    final prepared = await _wallet.prepareSend(address: created.depositAddress, amount: _xmr(created.xmrAmount));
    final review = PayReview(
      created: created,
      asset: quote.asset,
      prepared: prepared,
      refund: refund,
      validUntil: state.validUntil,
    );
    _review = review;
    notifyListeners();
    return review;
  }

  /// Sends the XMR of the payment under review and keeps the swap among the swaps that the app follows. Throws a
  /// [BridgeException] of [BridgeFailure.rateExpired] when the fixed rate runs out too soon, so that the user reviews
  /// the payment again.
  Future<BridgeSwap> confirm() async {
    final review = _review;
    if (review == null) throw StateError('No payment is under review.');
    final validUntil = review.validUntil;
    if (validUntil != null && DateTime.now().isAfter(validUntil.subtract(AppConfig.payRateMargin))) {
      await cancelReview();
      throw const BridgeException(BridgeFailure.rateExpired, 'The fixed rate ran out before the payment left.');
    }
    final sent = await _wallet.confirmSend();
    final created = review.created;
    final swap = BridgeSwap(
      direction: SwapDirection.pay,
      id: created.id,
      asset: review.asset,
      amount: created.amount,
      xmrAmount: created.xmrAmount,
      depositAddress: created.depositAddress,
      payoutAddress: created.payoutAddress,
      subaddressIndex: review.refund.index,
      refundAddress: review.refund.address,
      depositHash: sent.transactionId,
      createdAt: DateTime.now(),
      stage: SwapStage.waiting,
      validUntil: validUntil,
    );
    _review = null;
    _recipient = '';
    _amount = '';
    _quote.follow(null);
    await _record(swap);
    return swap;
  }

  /// Drops the payment under review. The XMR payment never leaves, and the payment at the exchanger runs out.
  Future<void> cancelReview() async {
    if (_review == null) return;
    await _wallet.cancelSend();
    _review = null;
    notifyListeners();
  }

  /// The app checks what the exchanger made before it builds a payment to it: the recipient, the amount, and a deposit
  /// address of the Monero mainnet.
  static void _checkCreated(CreatedPay created, {required String recipient, required String amount}) {
    if (created.payoutAddress.toLowerCase() != recipient.toLowerCase()) {
      throw const BridgeException(BridgeFailure.failed, 'The exchanger made the payment for another recipient.');
    }
    if ((created.amount - double.parse(amount)).abs() > AppConfig.payAmountTolerance) {
      throw const BridgeException(BridgeFailure.failed, 'The exchanger made the payment for another amount.');
    }
    try {
      checkAddress(created.depositAddress, MoneroNetwork.mainnet);
    } on AddressException {
      throw const BridgeException(BridgeFailure.failed, 'The exchanger gave a deposit address outside Monero mainnet.');
    }
  }

  /// An amount of XMR from the exchanger, which gives it as a number with at most a few decimals.
  static XmrAmount _xmr(double value) => XmrAmount.parse(value.toStringAsFixed(XmrAmount.decimals));

  @override
  void dispose() {
    _quote.dispose();
    super.dispose();
  }
}
