import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bridge/chain_scan.dart';
import '../../bridge/client.dart';
import '../../config/app_config.dart';
import '../../bridge/controller.dart';
import '../../bridge/models.dart';
import '../../bridge/payment_link.dart';
import '../../core/evm_address.dart';
import '../../privacy/chain_privacy.dart';
import '../../privacy/chain_scans.dart';
import '../../privacy/receive_check.dart';
import '../../wallet/failure.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import '../widgets/address_check.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/field.dart';
import '../widgets/privacy_check.dart';
import '../widgets/qr_card.dart';
import '../widgets/review_line.dart';
import '../widgets/surfaces.dart';
import '../widgets/swap_box.dart';
import '../widgets/swap_steps.dart';

/// Receive from Robinhood Chain: the user sends ETH or USDG there, and ChangeNOW turns it into XMR for a new
/// subaddress of this wallet. The part of the receive page under the choice "From Robinhood Chain", in the form of a
/// swap as pay on the send page: the coin that the user sends above, the XMR that it buys below. From 10 Oct 2026 a
/// review with the privacy check of the receive comes before the exchanger makes the deposit address.
class ReceiveFromChain extends StatefulWidget {
  const ReceiveFromChain({super.key, required this.bridge, this.scans});

  final BridgeController bridge;

  /// The addresses that the user scanned in the menu Privacy, which the check of the refund address counts as the
  /// user's.
  final ChainScans? scans;

  @override
  State<ReceiveFromChain> createState() => _ReceiveFromChainState();
}

class _ReceiveFromChainState extends State<ReceiveFromChain> {
  late final _amount = TextEditingController(text: widget.bridge.amount);
  final _refund = TextEditingController();
  String? _refundError;
  String? _error;
  bool _creating = false;

  // While a swap is on its way, the page shows that swap alone, until the user asks for the form of another one.
  bool _another = false;

  // The review before the exchanger makes the deposit address, with the refund address of the form.
  bool _reviewing = false;
  String? _reviewRefund;

  // The check of the refund address, for the address that it belongs to: what the scan found, or why it failed.
  String? _checkedRefund;
  ChainPrivacyReport? _refundReport;
  String? _refundCheckError;
  bool _checkingRefund = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => widget.bridge.setAmount(_amount.text));
    widget.bridge.refresh();
  }

  @override
  void dispose() {
    _amount.dispose();
    _refund.dispose();
    super.dispose();
  }

  /// Opens the review of the form, where the privacy check of the receive shows before the exchanger makes anything.
  void _startReview() {
    final text = _refund.text.trim();
    // The refund address gets the checksum of EIP-55 too, as the recipient of pay does: a typo in an address of
    // mixed case would send a refund nowhere.
    String? refund;
    if (text.isNotEmpty) {
      try {
        refund = checkEvmAddress(text);
      } on EvmAddressException {
        setState(() => _refundError = Copy.bridgeRefundInvalid);
        return;
      }
    }
    setState(() {
      _refundError = null;
      _error = null;
      _reviewing = true;
      _reviewRefund = refund;
    });
  }

  Future<void> _create() async {
    setState(() {
      _error = null;
      _creating = true;
    });
    try {
      await widget.bridge.createSwap(refundAddress: _reviewRefund);
      _amount.clear();
      _another = false;
      _reviewing = false;
    } on BridgeException catch (error) {
      setState(() => _error = bridgeFailureText(error));
    } on WalletException catch (error) {
      setState(() => _error = failureText(error));
    } on Object {
      setState(() => _error = Copy.unexpectedFailure);
      rethrow;
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  /// Scans the refund address [address] through the relay. The scan stays out of the scans of the menu Privacy, as the
  /// check of the recipient of pay does.
  Future<void> _checkRefund(String address, ChainScanClient scanner) async {
    setState(() {
      _checkedRefund = address;
      _refundReport = null;
      _refundCheckError = null;
      _checkingRefund = true;
    });
    try {
      final scan = await readScan(scanner, address);
      final report = analyzeChain(scan, swaps: widget.bridge.swaps, ownAddresses: widget.scans?.scanned ?? const []);
      if (mounted && _checkedRefund == address) setState(() => _refundReport = report);
    } on BridgeException catch (error) {
      if (mounted && _checkedRefund == address) setState(() => _refundCheckError = bridgeFailureText(error));
    } finally {
      if (mounted) setState(() => _checkingRefund = false);
    }
  }

  /// The check of the refund address [refund] on the review, when the relay of the app offers the scan.
  Widget? _refundCheck(String refund) {
    final scanner = widget.bridge.scanner;
    if (scanner == null) return null;
    final mine = _checkedRefund == refund;
    return AddressCheck(
      report: mine ? _refundReport : null,
      checking: mine && _checkingRefund,
      error: mine ? _refundCheckError : null,
      onCheck: _creating || _checkingRefund ? null : () => _checkRefund(refund, scanner),
      now: DateTime.now(),
      lead: Copy.receiveCheckRefundLead,
      freshNote: Copy.receiveRefundFreshNote,
      apartNote: Copy.receiveRefundApart,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.bridge,
    builder: (context, _) {
      final bridge = widget.bridge;
      final shown = bridge.shownSwapOf(SwapDirection.receive);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!bridge.available)
            Surface(
              child: Text(
                Copy.bridgeMainnetOnly,
                textAlign: TextAlign.center,
                style: KranoxType.bodyRegular.copyWith(color: context.palette.inkSoft),
              ),
            )
          else ...[
            if (shown != null) ...[
              _SwapCard(
                swap: shown,
                checkedAt: bridge.checkedAt,
                onRefresh: bridge.refresh,
                onAnother: shown.stage.isFinal || _another ? null : () => setState(() => _another = true),
                onClose: shown.stage.isFinal ? () => bridge.closeSwap(shown.id) : null,
              ),
              if (_another && !shown.stage.isFinal) ...[
                const SizedBox(height: Metrics.gap),
                _formOrReview(context, bridge),
              ],
            ] else
              _formOrReview(context, bridge),
          ],
          if (bridge.swapsOf(SwapDirection.receive) case final swaps when swaps.isNotEmpty) ...[
            const SizedBox(height: Metrics.gap),
            SwapHistory(
              title: Copy.bridgeSwapsTitle,
              swaps: swaps,
              line: (swap) => Copy.bridgeSwapLine(formatDecimal(swap.amount, decimals: 8), swap.asset),
              // A failed or refunded swap brought no XMR, so it shows no amount of XMR.
              trailing: (swap) => switch (swap.amountOut ?? swap.xmrAmount) {
                final xmr? when swap.stage != SwapStage.failed && swap.stage != SwapStage.refunded => Copy.bridgeOut(
                  formatDecimal(xmr),
                ),
                _ => null,
              },
            ),
          ],
        ],
      );
    },
  );

  Widget _formOrReview(BuildContext context, BridgeController bridge) =>
      _reviewing ? _review(context, bridge) : _form(context, bridge);

  Widget _form(BuildContext context, BridgeController bridge) {
    final palette = context.palette;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwapPair(
            top: SwapAmountBox(
              label: Copy.bridgeYouSend,
              amount: TextField(
                controller: _amount,
                onSubmitted: (_) => bridge.canSwap ? _startReview() : null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(AppConfig.amountFieldMaxLength),
                  AmountInputFormatter(decimals: AppConfig.bridgeAmountDecimals),
                ],
                style: KranoxType.swapFigure.copyWith(color: palette.ink),
                cursorColor: palette.accent,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: Copy.amountHint,
                  hintStyle: KranoxType.swapFigure.copyWith(color: palette.inkFaint),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              coin: CoinMenu(asset: bridge.asset, enabled: !_creating, onSelect: bridge.selectAsset),
              footer: _MinimumLine(bridge: bridge),
            ),
            bottom: SwapAmountBox(
              label: Copy.bridgeYouGet,
              amount: _EstimateFigure(bridge: bridge),
              coin: const SwapCoin(label: Copy.currency, network: Copy.payOnMonero),
              footer: _SpeedLine(bridge: bridge),
            ),
          ),
          _QuoteNote(bridge: bridge),
          const SizedBox(height: Metrics.gap),
          LabeledField(
            label: Copy.bridgeRefundField,
            controller: _refund,
            hint: Copy.bridgeRefundHint,
            note: Copy.bridgeRefundNote,
            error: _refundError,
            mono: true,
          ),
          ErrorLine(_error),
          const SizedBox(height: Metrics.gap + 4),
          PillButton(label: Copy.bridgeReview, expand: true, onPressed: bridge.canSwap ? _startReview : null),
          const SizedBox(height: Metrics.gapSmall),
          Text(
            Copy.bridgeSeenBy,
            textAlign: TextAlign.center,
            style: KranoxType.small.copyWith(color: palette.inkFaint),
          ),
        ],
      ),
    );
  }

  /// The review of the form: the XMR that it buys, the refund address in full with its check, what goes where, the
  /// privacy check of the receive, and the button that asks the exchanger for the deposit address.
  Widget _review(BuildContext context, BridgeController bridge) {
    final palette = context.palette;
    final refund = _reviewRefund;
    final estimate = bridge.quote?.estimatedXmr;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Copy.receiveReviewTitle,
            textAlign: TextAlign.center,
            style: KranoxType.cardTitle.copyWith(color: palette.ink),
          ),
          const SizedBox(height: 4),
          Text(
            Copy.receiveReviewLead,
            textAlign: TextAlign.center,
            style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Metrics.gap + 4),
          Text(
            Copy.bridgeYouGet.toUpperCase(),
            textAlign: TextAlign.center,
            style: KranoxType.label.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Metrics.gapTiny),
          Center(
            child: bridge.quoting
                ? LoadingFigure(style: KranoxType.sendFigure)
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AmountFigure(
                      value: estimate == null ? Copy.amountHint : Copy.about(formatDecimal(estimate)),
                      style: KranoxType.sendFigure,
                      unitStyle: KranoxType.smallStrong,
                    ),
                  ),
          ),
          const SizedBox(height: Metrics.gap),
          if (refund != null) ...[
            ReviewAddress(label: Copy.receiveRefundTo, address: refund, check: _refundCheck(refund)),
            const SizedBox(height: Metrics.gapSmall),
          ],
          ReviewLine(label: Copy.bridgeYouSend, value: '${bridge.amount} ${bridge.asset.label}'),
          ReviewLine(label: Copy.to, value: Copy.receiveReviewNewSubaddress),
          if (refund == null) ReviewLine(label: Copy.privacyRefundRuleLabel, value: Copy.receiveRefundNone),
          const SizedBox(height: Metrics.gapSmall),
          PrivacyRulesCard(note: Copy.privacyGoOnNote, rules: _receiveRules(refund, bridge.swaps, DateTime.now())),
          const SizedBox(height: Metrics.gap),
          PillButton(
            label: Copy.bridgeCreate,
            busy: _creating,
            busyLabel: Copy.bridgeCreating,
            expand: true,
            onPressed: bridge.canSwap ? _create : null,
          ),
          ErrorLine(_error),
          const SizedBox(height: Metrics.gapSmall),
          PillButton(
            label: Copy.back,
            tone: PillTone.quiet,
            expand: true,
            onPressed: _creating ? null : () => setState(() => _reviewing = false),
          ),
          const SizedBox(height: Metrics.gapSmall),
          Text(
            Copy.bridgeSeenBy,
            textAlign: TextAlign.center,
            style: KranoxType.small.copyWith(color: palette.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// The rules of the privacy check of a receive from Robinhood Chain: whether the user paid the refund address
/// [refund] from XMR, and what to do once the XMR comes in.
List<PrivacyRule> _receiveRules(String? refund, List<BridgeSwap> swaps, DateTime now) {
  final paidAt = refund == null ? null : lastPaidFromXmr(refund, swaps);
  return [
    PrivacyRule(
      label: Copy.privacyRefundRuleLabel,
      state: paidAt == null ? RuleState.passed : RuleState.warning,
      text: switch ((refund, paidAt)) {
        (null, _) => Copy.privacyRefundNone,
        (_, null) => Copy.privacyRefundNeverPaid,
        (_, final paid?) => Copy.privacyRefundPaid(formatAgo(now.difference(paid))),
      },
    ),
    PrivacyRule(
      label: Copy.privacyAfterThis,
      state: RuleState.tip,
      text: Copy.privacyAfterReceive(AppConfig.privacyFreshWindow.inHours),
    ),
  ];
}

/// The least amount of the coin of the form, once a quote has given it, in the color of a failure while the amount
/// stands below it.
class _MinimumLine extends StatelessWidget {
  const _MinimumLine({required this.bridge});

  final BridgeController bridge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final minimum = bridge.minimum;
    if (minimum == null) return const SizedBox.shrink();
    final text = formatLimit(minimum, up: true);
    final below = bridge.belowMinimum;
    return Text(
      below ? Copy.bridgeBelowMinimum(text, bridge.asset) : Copy.bridgeMinimum(text, bridge.asset),
      style: KranoxType.smallStrong.copyWith(color: below ? palette.danger : palette.inkSoft),
    );
  }
}

/// The XMR that the amount buys: a spinner while the quote is on its way, then the estimate, which can still move.
class _EstimateFigure extends StatelessWidget {
  const _EstimateFigure({required this.bridge});

  final BridgeController bridge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = KranoxType.swapFigure;
    if (bridge.quoting) return LoadingFigure(style: style);
    final estimate = bridge.quote?.estimatedXmr;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        estimate == null ? Copy.amountHint : Copy.about(formatDecimal(estimate)),
        style: style.copyWith(color: estimate == null ? palette.inkFaint : palette.ink),
      ),
    );
  }
}

/// How long a swap of the quoted amount usually takes.
class _SpeedLine extends StatelessWidget {
  const _SpeedLine({required this.bridge});

  final BridgeController bridge;

  @override
  Widget build(BuildContext context) {
    final quote = bridge.quote;
    final speed = quote?.speedMinutes;
    if (quote?.estimatedXmr == null || speed == null) return const SizedBox.shrink();
    return Text(Copy.bridgeSpeed(speed), style: KranoxType.small.copyWith(color: context.palette.inkSoft));
  }
}

/// Why there is no quote, or a warning of the exchanger beside a good one.
class _QuoteNote extends StatelessWidget {
  const _QuoteNote({required this.bridge});

  final BridgeController bridge;

  @override
  Widget build(BuildContext context) => switch ((bridge.quoteError, bridge.quote)) {
    _ when bridge.quoting => const SwapNote(null),
    (final error?, _) => SwapNote(bridgeFailureText(error), failure: true),
    (null, BridgeQuote(:final warning?)) => SwapNote(warning),
    _ => const SwapNote(null),
  };
}

/// The swap that the page follows: its steps from the deposit to the XMR in this wallet, each with what ChangeNOW
/// reports about it. A failure, a check, or a refund says what happened and what to do, and the card stays until the
/// user closes it.
class _SwapCard extends StatelessWidget {
  const _SwapCard({
    required this.swap,
    required this.checkedAt,
    required this.onRefresh,
    required this.onAnother,
    required this.onClose,
  });

  final BridgeSwap swap;
  final DateTime? checkedAt;
  final Future<void> Function() onRefresh;

  /// Shows the form for another swap; null when the form shows or the swap has ended.
  final VoidCallback? onAnother;

  /// Closes the card of an ended swap; null while the swap runs.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final steps = _steps(context);
    return Surface(
      padding: const EdgeInsets.all(Metrics.heroPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwapCardHeader(
            title: Copy.bridgeSwapTitle(formatDecimal(swap.amount, decimals: 8), swap.asset),
            swap: swap,
            checkedAt: checkedAt,
            onRefresh: onRefresh,
            notes: const [Copy.bridgeCanClose],
          ),
          const SizedBox(height: Metrics.gap),
          for (var index = 0; index < steps.length; index++)
            SwapStepRow(
              step: steps[index],
              last: index == steps.length - 1,
              nextMark: index + 1 < steps.length ? steps[index + 1].mark : null,
            ),
          const SizedBox(height: Metrics.gapSmall),
          Row(
            children: [
              Expanded(
                child: SwapCopyLine(label: Copy.bridgeSwapId, value: swap.id, shorten: false),
              ),
              if (onAnother != null) PillButton(label: Copy.bridgeAnother, tone: PillTone.quiet, onPressed: onAnother),
              if (onClose != null) PillButton(label: Copy.bridgeClose, tone: PillTone.solid, onPressed: onClose),
            ],
          ),
        ],
      ),
    );
  }

  /// The steps as the swap stands: the steps of a good swap up to the furthest one it reached, then either the rest
  /// of the way, or the check, the failure, or the refund in place of the step where it stopped.
  List<SwapStep> _steps(BuildContext context) {
    final asset = swap.asset;
    final amount = formatDecimal(swap.amount, decimals: 8);
    final estimate = swap.xmrAmount;
    final xmr = swap.amountOut ?? estimate;
    final xmrText = xmr == null ? '…' : formatDecimal(xmr);
    final depositHash = swap.depositHash;
    final payoutHash = swap.payoutHash;

    // Each step of the way, with its facts once done and while it runs.
    SwapStep step(SwapStage of, SwapMark mark) => switch (of) {
      SwapStage.waiting => SwapStep(mark, mark == SwapMark.done ? Copy.bridgeStepDeposited : Copy.bridgeStepWaiting, [
        if (mark == SwapMark.active) _Deposit(swap: swap),
        if (mark == SwapMark.done) SwapFact(Copy.bridgeStepReceived(amount, asset)),
        if (mark == SwapMark.done && depositHash != null)
          SwapCopyLine(label: Copy.bridgeDepositHash, value: depositHash),
      ]),
      SwapStage.confirming => SwapStep(mark, Copy.bridgeStepConfirming, [
        if (mark == SwapMark.active) const SwapFact(Copy.bridgeStepConfirmingNote),
      ]),
      SwapStage.exchanging => SwapStep(mark, Copy.bridgeStepExchanging(asset), [
        if (mark == SwapMark.active && estimate != null) SwapFact(Copy.bridgeStepRate(formatDecimal(estimate))),
        if (mark == SwapMark.done) SwapFact(Copy.bridgeStepExchanged(xmrText)),
      ]),
      SwapStage.sending => SwapStep(mark, Copy.bridgeStepSending(swap.subaddressIndex), [
        if (mark == SwapMark.active) SwapFact(Copy.bridgeStepSendingNote(xmrText)),
        if (mark != SwapMark.pending && payoutHash != null)
          SwapCopyLine(label: Copy.bridgePayoutHash, value: payoutHash),
      ]),
      _ => SwapStep(mark, Copy.bridgeStepDone, [if (mark == SwapMark.done) SwapFact(Copy.bridgeStepDoneNote(xmrText))]),
    };

    final refundAddress = swap.refundAddress;
    final refundHash = swap.refundHash;
    return swapSteps(
      swap,
      step: step,
      refunded: SwapStep(SwapMark.refunded, Copy.bridgeStepRefunded, [
        SwapFact(
          refundAddress == null
              ? Copy.bridgeRefundedNoAddress(formatDecimal(swap.refundAmount ?? swap.amount, decimals: 8), asset)
              : Copy.bridgeRefundedTo(
                  formatDecimal(swap.refundAmount ?? swap.amount, decimals: 8),
                  asset,
                  shortText(refundAddress),
                ),
        ),
        if (refundHash != null) SwapCopyLine(label: Copy.bridgeRefundHash, value: refundHash),
      ]),
      failed: SwapStep(SwapMark.failed, Copy.bridgeStepFailed, [
        SwapFact(
          depositHash == null && swap.reached == SwapStage.waiting
              ? Copy.bridgeFailedNoDeposit(asset)
              : refundAddress == null
              ? Copy.bridgeFailedNoRefundAddress(amount, asset)
              : Copy.bridgeFailedRefunding(amount, asset, shortText(refundAddress)),
        ),
        // The step of the deposit shows its hash once it is done; before that, the failure shows it.
        if (depositHash != null && swap.reached == SwapStage.waiting)
          SwapCopyLine(label: Copy.bridgeDepositHash, value: depositHash),
      ]),
    );
  }
}

/// The deposit while the swap waits for it: the address on Robinhood Chain as a code to scan and as text. The code
/// holds a payment link that names the chain, the coin, and the amount, or the address alone for a wallet that cannot
/// read such a link.
class _Deposit extends StatefulWidget {
  const _Deposit({required this.swap});

  final BridgeSwap swap;

  @override
  State<_Deposit> createState() => _DepositState();
}

class _DepositState extends State<_Deposit> {
  bool _addressOnly = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final swap = widget.swap;
    final amount = formatDecimal(swap.amount, decimals: 8);
    final code = _addressOnly
        ? swap.depositAddress
        : depositLink(asset: swap.asset, address: swap.depositAddress, amount: amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Copy.bridgeDepositLead(amount, swap.asset),
          style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft),
        ),
        const SizedBox(height: Metrics.gapSmall),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                QrCard(data: code, size: Metrics.bridgeQrSize, padding: Metrics.bridgeQrPadding),
                const SizedBox(height: Metrics.gapTiny),
                SmallPillButton(
                  label: _addressOnly ? Copy.bridgePaymentLink : Copy.bridgeAddressOnly,
                  onPressed: () => setState(() => _addressOnly = !_addressOnly),
                ),
              ],
            ),
            const SizedBox(width: Metrics.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(swap.depositAddress, style: KranoxType.mono.copyWith(color: palette.ink)),
                  const SizedBox(height: Metrics.gapSmall),
                  PillButton(
                    label: Copy.copyAddress,
                    icon: Icons.copy_rounded,
                    onPressed: () => copyToClipboard(context, swap.depositAddress),
                  ),
                  const SizedBox(height: Metrics.gapSmall),
                  if (!_addressOnly) ...[
                    Text(Copy.bridgeLinkNote(swap.asset), style: KranoxType.small.copyWith(color: palette.inkSoft)),
                    const SizedBox(height: Metrics.gapTiny),
                  ],
                  Text(Copy.bridgeOnlyAsset(swap.asset), style: KranoxType.small.copyWith(color: palette.danger)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
