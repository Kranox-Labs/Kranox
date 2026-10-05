/// The coins on Robinhood Chain that the bridge takes in and turns into XMR. [code] is their name at the relay.
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

/// One swap into XMR: the user sends [amount] of [asset] on Robinhood Chain to [depositAddress], and the exchanger
/// sends XMR to the subaddress [subaddressIndex] of the wallet.
final class BridgeSwap {
  const BridgeSwap({
    required this.id,
    required this.asset,
    required this.amount,
    required this.estimatedXmr,
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
    this.closed = false,
  }) : reached = reached ?? stage;

  final String id;
  final BridgeAsset asset;
  final double amount;

  /// The XMR that the exchanger expects to send, at the rate of the moment.
  final double? estimatedXmr;
  final String depositAddress;
  final String payoutAddress;
  final int subaddressIndex;
  final DateTime createdAt;
  final SwapStage stage;

  /// The furthest step of [SwapStage.path] that the swap has reached. A swap that fails keeps it, so that the app
  /// shows where it stopped.
  final SwapStage reached;

  /// The XMR that the exchanger sent, once it knows the amount.
  final double? amountOut;

  /// The transaction of the deposit on Robinhood Chain.
  final String? depositHash;

  /// The transaction of the XMR to this wallet.
  final String? payoutHash;

  /// The address on Robinhood Chain to which the exchanger returns the deposit of a swap that fails.
  final String? refundAddress;
  final String? refundHash;
  final double? refundAmount;
  final DateTime? updatedAt;

  /// Whether the user closed the card of the ended swap. An ended swap shows until the user closes it.
  final bool closed;

  /// The swap with the state that the exchanger reported.
  BridgeSwap withState(SwapState state) {
    final reachedIndex = SwapStage.path.indexOf(reached);
    final stageIndex = SwapStage.path.indexOf(state.stage);
    return _copy(
      stage: state.stage,
      reached: stageIndex > reachedIndex ? state.stage : reached,
      estimatedXmr: state.expectedOut ?? estimatedXmr,
      amountOut: state.amountOut ?? amountOut,
      depositHash: state.depositHash ?? depositHash,
      payoutHash: state.payoutHash ?? payoutHash,
      refundAddress: state.refundAddress ?? refundAddress,
      refundHash: state.refundHash ?? refundHash,
      refundAmount: state.refundAmount ?? refundAmount,
      updatedAt: state.updatedAt ?? updatedAt,
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
    double? estimatedXmr,
    double? amountOut,
    String? depositHash,
    String? payoutHash,
    String? refundAddress,
    String? refundHash,
    double? refundAmount,
    DateTime? updatedAt,
    bool? closed,
  }) => BridgeSwap(
    id: id,
    asset: asset,
    amount: amount,
    estimatedXmr: estimatedXmr ?? this.estimatedXmr,
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
    closed: closed ?? this.closed,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'asset': asset.code,
    'amount': amount,
    'estimatedXmr': estimatedXmr,
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
    'closed': closed,
  };

  /// Reads a saved swap. A swap saved before a field existed reads without it.
  factory BridgeSwap.fromJson(Map<String, Object?> data) {
    final stage = _stageNamed(_string(data, 'stage'));
    final reached = _stringOrNull(data, 'reached');
    final updated = _stringOrNull(data, 'updatedAt');
    return BridgeSwap(
      id: _string(data, 'id'),
      asset: BridgeAsset.fromCode(_string(data, 'asset')),
      amount: _number(data, 'amount'),
      estimatedXmr: _numberOrNull(data, 'estimatedXmr'),
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

  factory SwapState.fromJson(Map<String, Object?> data) {
    final updated = _stringOrNull(data, 'updatedAt');
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
