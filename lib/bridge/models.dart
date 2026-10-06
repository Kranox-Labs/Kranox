import '../config/app_config.dart';

/// An amount of a form of the bridge: digits, and a point with at most [AppConfig.bridgeAmountDecimals] decimals.
final RegExp _amountPattern = RegExp('^\\d{1,9}(\\.\\d{1,${AppConfig.bridgeAmountDecimals}})?\$');

/// Whether [text] is an amount above zero that a form of the bridge takes.
bool isBridgeAmount(String text) => _amountPattern.hasMatch(text) && double.parse(text) > 0;

/// The coins on Robinhood Chain that the bridge takes in for XMR and pays out from XMR. [code] is their name at the
/// relay.
enum BridgeAsset {
  eth(code: 'eth', label: 'ETH'),
  usdg(code: 'usdg', label: 'USDG');

  const BridgeAsset({required this.code, required this.label});

  final String code;
  final String label;

  static BridgeAsset fromCode(String code) => BridgeAsset.values.firstWhere(
    (asset) => asset.code == code,
    orElse: () => throw FormatException('The bridge knows no asset named $code.'),
  );
}

/// What the exchanger offers for an amount: the least amount that it takes, and the XMR that the amount buys at the
/// moment. Below the minimum it gives no estimate.
final class BridgeQuote {
  const BridgeQuote({
    required this.asset,
    required this.amount,
    required this.minAmount,
    required this.estimatedXmr,
    required this.speedMinutes,
    required this.warning,
  });

  final BridgeAsset asset;
  final String amount;
  final double minAmount;
  final double? estimatedXmr;

  /// Minutes, such as "10-60", as the exchanger forecasts them.
  final String? speedMinutes;
  final String? warning;

  factory BridgeQuote.fromJson(Map<String, Object?> data) => BridgeQuote(
    asset: BridgeAsset.fromCode(_string(data, 'asset')),
    amount: _string(data, 'amount'),
    minAmount: _number(data, 'minAmount'),
    estimatedXmr: _numberOrNull(data, 'estimatedXmr'),
    speedMinutes: _stringOrNull(data, 'speedMinutes'),
    warning: _stringOrNull(data, 'warning'),
  );
}

/// Where an amount of a payment stands outside the range of its rate.
enum PayLimit { below, above }

/// The rate of a payment, which the user chooses: a fixed rate, at which the recipient gets exactly the quoted amount,
/// or a floating rate, with about half the minimum, at which the amount follows the market until the exchange. The
/// owner asked on 6 Oct 2026 to let the user choose. The names are the names at the relay.
enum PayRate { fixed, floating }

/// The range of the XMR of one payment into [asset] at [rate]. A floating rate has no top.
final class PayRange {
  const PayRange({required this.asset, required this.rate, required this.minXmr, required this.maxXmr});

  final BridgeAsset asset;
  final PayRate rate;
  final double minXmr;
  final double? maxXmr;

  factory PayRange.fromJson(Map<String, Object?> data) => PayRange(
    asset: BridgeAsset.fromCode(_string(data, 'asset')),
    rate: PayRate.values.byName(_string(data, 'rate')),
    minXmr: _number(data, 'minXmr'),
    maxXmr: _numberOrNull(data, 'maxXmr'),
  );
}

/// What the exchanger gives for a payment of [xmrAmount] at [rate]: the [amount] of [asset] that the recipient gets,
/// after the fees of the exchanger, a [depositFee] in XMR and a [withdrawalFee] in [asset]. A fixed rate gives the id
/// of the rate and the time until which the estimate holds. Outside the range of the rate the exchanger gives that
/// range in XMR instead, with [limit] on the side where the amount of XMR stands.
final class PayQuote {
  const PayQuote({
    required this.asset,
    required this.rate,
    required this.xmrAmount,
    required this.amount,
    required this.rateId,
    required this.validUntil,
    required this.warning,
    required this.limit,
    required this.minXmr,
    required this.maxXmr,
    this.depositFee,
    this.withdrawalFee,
    this.speedMinutes,
  });

  final BridgeAsset asset;
  final PayRate rate;

  /// The amount of XMR that the wallet pays, as the form holds it.
  final String xmrAmount;

  /// The amount of [asset] that the recipient gets at the fixed rate.
  final double? amount;
  final String? rateId;
  final DateTime? validUntil;
  final String? warning;
  final PayLimit? limit;
  final double? minXmr;
  final double? maxXmr;
  final double? depositFee;
  final double? withdrawalFee;

  /// Minutes, such as "10-60", as the exchanger forecasts them for a floating rate.
  final String? speedMinutes;

  factory PayQuote.fromJson(Map<String, Object?> data) {
    final valid = _stringOrNull(data, 'validUntil');
    final limit = _stringOrNull(data, 'limit');
    return PayQuote(
      asset: BridgeAsset.fromCode(_string(data, 'asset')),
      rate: PayRate.values.byName(_string(data, 'rate')),
      xmrAmount: _string(data, 'xmrAmount'),
      amount: _numberOrNull(data, 'amount'),
      rateId: _stringOrNull(data, 'rateId'),
      validUntil: valid == null ? null : DateTime.tryParse(valid),
      warning: _stringOrNull(data, 'warning'),
      limit: limit == null ? null : PayLimit.values.byName(limit),
      minXmr: _numberOrNull(data, 'minXmr'),
      maxXmr: _numberOrNull(data, 'maxXmr'),
      depositFee: _numberOrNull(data, 'depositFee'),
      withdrawalFee: _numberOrNull(data, 'withdrawalFee'),
      speedMinutes: _stringOrNull(data, 'speedMinutes'),
    );
  }
}

/// The steps of a swap at the exchanger, from its status names: new, waiting, confirming, exchanging, sending,
/// finished, failed, refunded, and verifying.
enum SwapStage {
  waiting,
  confirming,
  exchanging,
  sending,
  finished,
  failed,
  refunded,
  verifying;

  static SwapStage fromStatus(String status) => switch (status) {
    'new' || 'waiting' => SwapStage.waiting,
    'confirming' => SwapStage.confirming,
    'exchanging' => SwapStage.exchanging,
    'sending' => SwapStage.sending,
    'finished' => SwapStage.finished,
    'failed' => SwapStage.failed,
    'refunded' => SwapStage.refunded,
    'verifying' => SwapStage.verifying,
    _ => throw FormatException('The exchanger reported an unknown status: $status.'),
  };

  /// The steps of a swap that goes well, in their order.
  static const List<SwapStage> path = [waiting, confirming, exchanging, sending, finished];

  /// Whether the swap has ended, so that the app stops asking for its state.
  bool get isFinal => this == finished || this == failed || this == refunded;

  /// Whether the swap went wrong or waits for a check, outside the steps of [path].
  bool get isOffPath => !path.contains(this);
}

/// Which way a swap goes: a coin on Robinhood Chain into XMR for this wallet, or XMR of this wallet out to an address
/// on Robinhood Chain.
enum SwapDirection { receive, pay }

/// One swap of the bridge. For receive, the user sends [amount] of [asset] on Robinhood Chain to [depositAddress],
/// and the exchanger sends XMR to the subaddress [subaddressIndex] of the wallet. For pay, the wallet sends
/// [xmrAmount] to [depositAddress], a Monero address of the exchanger, and the exchanger sends exactly [amount] of
/// [asset] to [payoutAddress] on Robinhood Chain; a refund goes back to the subaddress [subaddressIndex].
final class BridgeSwap {
  const BridgeSwap({
    this.direction = SwapDirection.receive,
    required this.id,
    required this.asset,
    required this.amount,
    required this.xmrAmount,
    required this.depositAddress,
    required this.payoutAddress,
    required this.subaddressIndex,
    required this.createdAt,
    required this.stage,
    SwapStage? reached,
    this.amountOut,
    this.depositHash,
    this.payoutHash,
    this.refundAddress,
    this.refundHash,
    this.refundAmount,
    this.updatedAt,
    this.validUntil,
    this.fixedRate = false,
    this.closed = false,
  }) : reached = reached ?? stage;

  final SwapDirection direction;
  final String id;
  final BridgeAsset asset;

  /// The amount of [asset]: what the user sends in for receive, and what the recipient gets for pay.
  final double amount;

  /// The XMR of the swap: for receive, what the exchanger expects to send at the rate of the moment; for pay, what
  /// this wallet sends at the fixed rate.
  final double? xmrAmount;
  final String depositAddress;
  final String payoutAddress;
  final int subaddressIndex;
  final DateTime createdAt;
  final SwapStage stage;

  /// The furthest step of [SwapStage.path] that the swap has reached. A swap that fails keeps it, so that the app
  /// shows where it stopped.
  final SwapStage reached;

  /// What the exchanger sent, once it knows the amount: XMR for receive, [asset] for pay.
  final double? amountOut;

  /// The transaction of the deposit: on Robinhood Chain for receive, the Monero payment of this wallet for pay.
  final String? depositHash;

  /// The transaction of the payout: the XMR to this wallet for receive, [asset] to the recipient for pay.
  final String? payoutHash;

  /// Where the exchanger returns the deposit of a swap that fails: an optional address on Robinhood Chain for
  /// receive, a subaddress of this wallet for pay.
  final String? refundAddress;
  final String? refundHash;

  /// The refund, in the coin of the deposit.
  final double? refundAmount;
  final DateTime? updatedAt;

  /// For pay, the time until which the fixed rate waits for the deposit.
  final DateTime? validUntil;

  /// Whether the swap runs at a fixed rate, so that [amount] is exact; a swap at a floating rate has an estimate.
  final bool fixedRate;

  /// Whether the user closed the card of the ended swap. An ended swap shows until the user closes it.
  final bool closed;

  /// The swap with the state that the exchanger reported. The XMR of a payment stays as the wallet sent it.
  BridgeSwap withState(SwapState state) {
    final reachedIndex = SwapStage.path.indexOf(reached);
    final stageIndex = SwapStage.path.indexOf(state.stage);
    return _copy(
      stage: state.stage,
      reached: stageIndex > reachedIndex ? state.stage : reached,
      xmrAmount: direction == SwapDirection.receive ? state.expectedOut ?? xmrAmount : xmrAmount,
      amountOut: state.amountOut ?? amountOut,
      depositHash: state.depositHash ?? depositHash,
      payoutHash: state.payoutHash ?? payoutHash,
      refundAddress: state.refundAddress ?? refundAddress,
      refundHash: state.refundHash ?? refundHash,
      refundAmount: state.refundAmount ?? refundAmount,
      updatedAt: state.updatedAt ?? updatedAt,
      validUntil: state.validUntil ?? validUntil,
    );
  }

  BridgeSwap close() => _copy(closed: true);

  /// Whether the app keeps asking for the state of the swap. A failed swap can still turn into a refund, so the app
  /// follows it until the user closes its card.
  bool get watched => switch (stage) {
    SwapStage.finished || SwapStage.refunded => false,
    SwapStage.failed => !closed,
    _ => true,
  };

  BridgeSwap _copy({
    SwapStage? stage,
    SwapStage? reached,
    double? xmrAmount,
    double? amountOut,
    String? depositHash,
    String? payoutHash,
    String? refundAddress,
    String? refundHash,
    double? refundAmount,
    DateTime? updatedAt,
    DateTime? validUntil,
    bool? closed,
  }) => BridgeSwap(
    direction: direction,
    fixedRate: fixedRate,
    id: id,
    asset: asset,
    amount: amount,
    xmrAmount: xmrAmount ?? this.xmrAmount,
    depositAddress: depositAddress,
    payoutAddress: payoutAddress,
    subaddressIndex: subaddressIndex,
    createdAt: createdAt,
    stage: stage ?? this.stage,
    reached: reached ?? this.reached,
    amountOut: amountOut ?? this.amountOut,
    depositHash: depositHash ?? this.depositHash,
    payoutHash: payoutHash ?? this.payoutHash,
    refundAddress: refundAddress ?? this.refundAddress,
    refundHash: refundHash ?? this.refundHash,
    refundAmount: refundAmount ?? this.refundAmount,
    updatedAt: updatedAt ?? this.updatedAt,
    validUntil: validUntil ?? this.validUntil,
    closed: closed ?? this.closed,
  );

  Map<String, Object?> toJson() => {
    'direction': direction.name,
    'id': id,
    'asset': asset.code,
    'amount': amount,
    'xmrAmount': xmrAmount,
    'depositAddress': depositAddress,
    'payoutAddress': payoutAddress,
    'subaddressIndex': subaddressIndex,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'stage': stage.name,
    'reached': reached.name,
    'amountOut': amountOut,
    'depositHash': depositHash,
    'payoutHash': payoutHash,
    'refundAddress': refundAddress,
    'refundHash': refundHash,
    'refundAmount': refundAmount,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
    'validUntil': validUntil?.toUtc().toIso8601String(),
    'fixedRate': fixedRate,
    'closed': closed,
  };

  /// Reads a saved swap. A swap saved before a field existed reads without it: a swap of the release 0.1.0 is a
  /// receive with its XMR under the name "estimatedXmr", and a payment of 5 Oct 2026 ran at a fixed rate.
  factory BridgeSwap.fromJson(Map<String, Object?> data) {
    final stage = _stageNamed(_string(data, 'stage'));
    final reached = _stringOrNull(data, 'reached');
    final updated = _stringOrNull(data, 'updatedAt');
    final valid = _stringOrNull(data, 'validUntil');
    final direction = _stringOrNull(data, 'direction');
    return BridgeSwap(
      direction: direction == null ? SwapDirection.receive : SwapDirection.values.byName(direction),
      id: _string(data, 'id'),
      asset: BridgeAsset.fromCode(_string(data, 'asset')),
      amount: _number(data, 'amount'),
      xmrAmount: _numberOrNull(data, 'xmrAmount') ?? _numberOrNull(data, 'estimatedXmr'),
      depositAddress: _string(data, 'depositAddress'),
      payoutAddress: _string(data, 'payoutAddress'),
      subaddressIndex: _number(data, 'subaddressIndex').toInt(),
      createdAt: DateTime.parse(_string(data, 'createdAt')),
      stage: stage,
      reached: reached == null ? stage : _stageNamed(reached),
      amountOut: _numberOrNull(data, 'amountOut'),
      depositHash: _stringOrNull(data, 'depositHash'),
      payoutHash: _stringOrNull(data, 'payoutHash'),
      refundAddress: _stringOrNull(data, 'refundAddress'),
      refundHash: _stringOrNull(data, 'refundHash'),
      refundAmount: _numberOrNull(data, 'refundAmount'),
      updatedAt: updated == null ? null : DateTime.parse(updated),
      validUntil: valid == null ? null : DateTime.parse(valid),
      fixedRate: switch (data['fixedRate']) {
        final bool fixed => fixed,
        _ => direction == SwapDirection.pay.name,
      },
      closed: data['closed'] == true,
    );
  }

  static SwapStage _stageNamed(String name) => SwapStage.values.firstWhere(
    (stage) => stage.name == name,
    orElse: () => throw FormatException('A saved swap has an unknown stage: $name.'),
  );
}

/// The state of a swap as the exchanger reports it, with the facts of its steps.
final class SwapState {
  const SwapState({
    required this.stage,
    this.expectedOut,
    this.amountOut,
    this.depositHash,
    this.payoutHash,
    this.refundAddress,
    this.refundHash,
    this.refundAmount,
    this.updatedAt,
    this.validUntil,
  });

  final SwapStage stage;
  final double? expectedOut;
  final double? amountOut;
  final String? depositHash;
  final String? payoutHash;
  final String? refundAddress;
  final String? refundHash;
  final double? refundAmount;
  final DateTime? updatedAt;
  final DateTime? validUntil;

  factory SwapState.fromJson(Map<String, Object?> data) {
    final updated = _stringOrNull(data, 'updatedAt');
    final valid = _stringOrNull(data, 'validUntil');
    return SwapState(
      stage: SwapStage.fromStatus(_string(data, 'status')),
      expectedOut: _numberOrNull(data, 'expectedOut'),
      amountOut: _numberOrNull(data, 'amountOut'),
      depositHash: _stringOrNull(data, 'depositHash'),
      payoutHash: _stringOrNull(data, 'payoutHash'),
      refundAddress: _stringOrNull(data, 'refundAddress'),
      refundHash: _stringOrNull(data, 'refundHash'),
      refundAmount: _numberOrNull(data, 'refundAmount'),
      updatedAt: updated == null ? null : DateTime.tryParse(updated),
      validUntil: valid == null ? null : DateTime.tryParse(valid),
    );
  }
}

String _string(Map<String, Object?> data, String field) {
  final value = data[field];
  if (value is! String || value.isEmpty) throw FormatException('The bridge data has no text $field.');
  return value;
}

String? _stringOrNull(Map<String, Object?> data, String field) {
  final value = data[field];
  return value is String && value.isNotEmpty ? value : null;
}

double _number(Map<String, Object?> data, String field) {
  final value = data[field];
  if (value is! num) throw FormatException('The bridge data has no number $field.');
  return value.toDouble();
}

double? _numberOrNull(Map<String, Object?> data, String field) {
  final value = data[field];
  return value is num ? value.toDouble() : null;
}
