import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bridge/client.dart';
import '../../bridge/controller.dart';
import '../../bridge/models.dart';
import '../../bridge/pay_controller.dart';
import '../../core/evm_address.dart';
import '../../wallet/controller.dart';
import '../../wallet/failure.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/choice_pill.dart';
import '../widgets/field.dart';
import '../widgets/page_frame.dart';
import '../widgets/review_line.dart';
import '../widgets/surfaces.dart';
import '../widgets/swap_steps.dart';

/// The length of an address on Robinhood Chain: 0x and 40 hex digits. The live check of the recipient waits for it.
const int _evmAddressLength = 42;

/// Pay to Robinhood Chain: the user enters a recipient there and the amount that the recipient gets, and ChangeNOW
/// turns XMR of this wallet into exactly that amount at a fixed rate. The part of the send page under the choice "To
/// Robinhood Chain".
class SendToChain extends StatefulWidget {
  const SendToChain({super.key, required this.bridge, required this.wallet});

  final BridgeController bridge;
  final WalletController wallet;

  @override
  State<SendToChain> createState() => _SendToChainState();
}

class _SendToChainState extends State<SendToChain> {
  late final _recipient = TextEditingController(text: _pay.recipientText);
  late final _amount = TextEditingController(text: _pay.amount);
  String? _error;
  bool _busy = false;

  // While a payment is on its way, the page shows that payment alone, until the user asks for the form of another one.
  bool _another = false;

  PayController get _pay => widget.bridge.pay;

  @override
  void initState() {
    super.initState();
    _recipient.addListener(() => _pay.setRecipient(_recipient.text));
    _amount.addListener(() => _pay.setAmount(_amount.text));
    widget.bridge.refresh();
  }

  @override
  void dispose() {
    _recipient.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _recipient.text = text;
  }

  Future<void> _startReview() => _run(_pay.startReview);

  Future<void> _confirm() => _run(() async {
    await _pay.confirm();
    _recipient.clear();
    _amount.clear();
    _another = false;
  });

  Future<void> _cancel() => _run(_pay.cancelReview);

  /// Runs a call of pay while the buttons show that it works, and shows a failure under the buttons.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on BridgeException catch (error) {
      setState(() => _error = bridgeFailureText(error));
    } on WalletException catch (error) {
      setState(() => _error = failureText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.bridge, _pay, widget.wallet]),
    builder: (context, _) {
      if (!_pay.available) {
        return Surface(
          child: Text(
            Copy.payMainnetOnly,
            textAlign: TextAlign.center,
            style: KranoxType.bodyRegular.copyWith(color: context.palette.inkSoft),
          ),
        );
      }
      final shown = widget.bridge.shownSwapOf(SwapDirection.pay);
      final review = _pay.review;
      final payments = widget.bridge.swapsOf(SwapDirection.pay);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (review != null)
            _Review(review: review, busy: _busy, error: _error, onConfirm: _confirm, onCancel: _cancel)
          else if (shown != null) ...[
            _PaymentCard(
              swap: shown,
              onRefresh: widget.bridge.refresh,
              onAnother: shown.stage.isFinal || _another ? null : () => setState(() => _another = true),
              onClose: shown.stage.isFinal ? () => widget.bridge.closeSwap(shown.id) : null,
            ),
            if (_another && !shown.stage.isFinal) ...[const SizedBox(height: Metrics.gap), _form(context)],
          ] else
            _form(context),
          if (payments.isNotEmpty) ...[
            const SizedBox(height: Metrics.gap),
            SwapHistory(
              title: Copy.paymentsTitle,
              swaps: payments,
              line: (swap) =>
                  Copy.paySwapTitle(formatDecimal(swap.amount, decimals: 8), swap.asset, shortText(swap.payoutAddress)),
              // A failed or refunded payment brought the XMR back, so it shows no amount that left.
              trailing: (swap) => switch (swap.xmrAmount) {
                final xmr? when swap.stage != SwapStage.failed && swap.stage != SwapStage.refunded => Copy.payOut(
                  formatDecimal(xmr, decimals: 8),
                ),
                _ => null,
              },
            ),
          ],
        ],
      );
    },
  );

  Widget _form(BuildContext context) {
    final palette = context.palette;
    final pay = _pay;
    final text = _recipient.text.trim();
    // The live check of the recipient: nothing while the address is partial, then its kind or what is wrong with it.
    String? recipientError;
    String? recipientNote;
    if (text.length >= _evmAddressLength) {
      try {
        final hex = checkEvmAddress(text).substring(2);
        final checksum = hex != hex.toLowerCase() && hex != hex.toUpperCase();
        recipientNote = checksum ? Copy.payRecipientValid : Copy.payRecipientNoChecksum;
      } on EvmAddressException catch (problem) {
        recipientError = evmAddressProblemText(problem.problem);
      }
    }
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: Copy.payRecipient,
            controller: _recipient,
            hint: Copy.payRecipientHint,
            error: recipientError,
            note: recipientNote,
            good: recipientNote != null,
            mono: true,
            action: TextButton(
              onPressed: _paste,
              style: TextButton.styleFrom(
                foregroundColor: palette.ink,
                backgroundColor: palette.surface,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: KranoxType.smallStrong,
              ),
              child: const Text(Copy.paste),
            ),
          ),
          const SizedBox(height: Metrics.gap + 4),
          Text(
            Copy.payTheyReceive.toUpperCase(),
            textAlign: TextAlign.center,
            style: KranoxType.label.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Metrics.gapSmall),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Metrics.gapTiny,
            children: [
              for (final asset in BridgeAsset.values)
                ChoicePill(
                  label: asset.label,
                  active: asset == pay.asset,
                  onTap: _busy ? null : () => pay.selectAsset(asset),
                ),
            ],
          ),
          const SizedBox(height: Metrics.gapSmall),
          // The amount that the recipient gets stands large in the middle, like the amount of a Monero payment.
          TextField(
            controller: _amount,
            onSubmitted: (_) => pay.canReview ? _startReview() : null,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: KranoxType.sendFigure.copyWith(color: palette.ink),
            cursorColor: palette.accent,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: Copy.amountHint,
              hintStyle: KranoxType.sendFigure.copyWith(color: palette.inkFaint),
              isDense: true,
            ),
          ),
          Text(
            pay.asset.label,
            textAlign: TextAlign.center,
            style: KranoxType.smallStrong.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Metrics.gapSmall),
          _QuoteLines(pay: pay, wallet: widget.wallet),
          ErrorLine(_error),
          const SizedBox(height: Metrics.gap + 4),
          PillButton(
            label: Copy.review,
            busy: _busy,
            busyLabel: Copy.payPreparing,
            expand: true,
            onPressed: pay.canReview ? _startReview : null,
          ),
        ],
      ),
    );
  }
}

/// The quote under the amount: the XMR that the payment takes at a fixed rate with the unlocked balance, or the range
/// of the fixed rate, or why there is no quote.
class _QuoteLines extends StatelessWidget {
  const _QuoteLines({required this.pay, required this.wallet});

  final PayController pay;
  final WalletController wallet;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget centered(String text, Color color) => Text(
      text,
      textAlign: TextAlign.center,
      style: KranoxType.small.copyWith(color: color),
    );
    final status = wallet.status;
    final available = status.isLoading
        ? const Center(child: IntrinsicWidth(child: LoadingLine(Copy.availableUpdating)))
        : centered(Copy.available(status.unlocked.toExact()), palette.inkSoft);
    if (pay.quoting) return const Center(child: IntrinsicWidth(child: LoadingLine(Copy.payQuoting)));
    if (pay.quoteError case final error?) return centered(bridgeFailureText(error), palette.danger);
    final quote = pay.quote;
    if (quote != null && quote.limit != null) {
      final min = quote.minXmr;
      final max = quote.maxXmr;
      final range = switch ((min, max)) {
        (final min?, final max?) => Copy.payRange(formatDecimal(min, decimals: 4), formatDecimal(max, decimals: 4)),
        (final min?, null) => Copy.payBelowRange(formatDecimal(min, decimals: 4)),
        (null, final max?) => Copy.payAboveRange(formatDecimal(max, decimals: 4)),
        (null, null) => Copy.payRange('…', '…'),
      };
      return centered(range, palette.danger);
    }
    final xmr = pay.quotedXmr;
    if (xmr == null) return available;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          Copy.payYouPay(xmr.toExact()),
          textAlign: TextAlign.center,
          style: KranoxType.cardTitle.copyWith(color: palette.ink),
        ),
        const SizedBox(height: 2),
        if (pay.aboveUnlocked) centered(Copy.amountAboveUnlocked, palette.danger) else available,
        if (quote?.warning case final warning?) centered(warning, palette.inkSoft),
      ],
    );
  }
}

/// The review of a payment: what the recipient gets and where, the XMR that leaves with its fee, until when the rate
/// holds, and where a refund goes.
class _Review extends StatelessWidget {
  const _Review({
    required this.review,
    required this.busy,
    required this.error,
    required this.onConfirm,
    required this.onCancel,
  });

  final PayReview review;
  final bool busy;
  final String? error;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final created = review.created;
    final prepared = review.prepared;
    final validUntil = review.validUntil;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Copy.reviewTitle,
            textAlign: TextAlign.center,
            style: KranoxType.cardTitle.copyWith(color: palette.ink),
          ),
          const SizedBox(height: 4),
          Text(
            Copy.reviewLead,
            textAlign: TextAlign.center,
            style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Metrics.gap + 4),
          Text(
            Copy.payTheyReceive.toUpperCase(),
            textAlign: TextAlign.center,
            style: KranoxType.label.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Metrics.gapTiny),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AmountFigure(
                value: formatDecimal(created.amount, decimals: 8),
                unit: review.asset.label,
                style: KranoxType.sendFigure,
                unitStyle: KranoxType.smallStrong,
              ),
            ),
          ),
          const SizedBox(height: Metrics.gap),
          // The whole recipient, so that the user can check it character by character before the payment leaves.
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.field,
              borderRadius: BorderRadius.circular(Metrics.radiusField),
              border: Border.all(color: palette.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Copy.payTo.toUpperCase(), style: KranoxType.label.copyWith(color: palette.inkSoft)),
                  const SizedBox(height: Metrics.gapTiny),
                  SelectableText(created.payoutAddress, style: KranoxType.mono.copyWith(color: palette.ink)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Metrics.gapSmall),
          ReviewLine(label: Copy.payYouSend, value: '${prepared.amount.toExact()} ${Copy.currency}'),
          ReviewLine(label: Copy.fee, value: '${prepared.fee.toExact()} ${Copy.currency}'),
          Divider(height: 1, color: palette.line),
          ReviewLine(label: Copy.total, value: '${prepared.total.toExact()} ${Copy.currency}', strong: true),
          if (validUntil != null) ReviewLine(label: Copy.payRateHolds, value: formatTime(validUntil, DateTime.now())),
          ReviewLine(label: Copy.payRefundLabel, value: Copy.payRefund(review.refund.index)),
          ErrorLine(error),
          const SizedBox(height: Metrics.gap),
          PillButton(label: Copy.payNow, busy: busy, busyLabel: Copy.paying, expand: true, onPressed: onConfirm),
          const SizedBox(height: Metrics.gapSmall),
          PillButton(label: Copy.cancel, tone: PillTone.quiet, expand: true, onPressed: busy ? null : onCancel),
          const SizedBox(height: Metrics.gapSmall),
          Text(
            Copy.paySeenBy,
            textAlign: TextAlign.center,
            style: KranoxType.small.copyWith(color: palette.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// The payment that the page follows: its steps from the XMR that left this wallet to the coin at the recipient, each
/// with what ChangeNOW reports about it. A failure, a check, or a refund says what happened and what to do, and the
/// card stays until the user closes it.
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.swap, required this.onRefresh, required this.onAnother, required this.onClose});

  final BridgeSwap swap;
  final Future<void> Function() onRefresh;

  /// Shows the form for another payment; null when the form shows or the payment has ended.
  final VoidCallback? onAnother;

  /// Closes the card of an ended payment; null while the payment runs.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    final updated = swap.updatedAt;
    final steps = _steps();
    return Surface(
      padding: const EdgeInsets.all(Metrics.heroPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            Copy.paySwapTitle(formatDecimal(swap.amount, decimals: 8), swap.asset, shortText(swap.payoutAddress)),
            trailing: swap.stage.isFinal
                ? null
                : PillButton(label: Copy.bridgeRefresh, tone: PillTone.quiet, onPressed: onRefresh),
          ),
          const SizedBox(height: 4),
          Text(
            Copy.bridgeSwapTimes(formatTime(swap.createdAt, now), updated == null ? null : formatTime(updated, now)),
            style: KranoxType.small.copyWith(color: palette.inkSoft),
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
              if (onAnother != null) PillButton(label: Copy.payAnother, tone: PillTone.quiet, onPressed: onAnother),
              if (onClose != null) PillButton(label: Copy.bridgeClose, tone: PillTone.solid, onPressed: onClose),
            ],
          ),
        ],
      ),
    );
  }

  List<SwapStep> _steps() {
    final asset = swap.asset;
    final amount = formatDecimal(swap.amount, decimals: 8);
    final xmr = swap.xmrAmount;
    final xmrText = xmr == null ? '…' : formatDecimal(xmr, decimals: 8);
    final recipient = shortText(swap.payoutAddress);
    final moneroHash = swap.depositHash;
    final chainHash = swap.payoutHash;

    // Each step of the way, with its facts once done and while it runs. The XMR left the wallet before the first step,
    // so its facts show from the start.
    SwapStep step(SwapStage of, SwapMark mark) => switch (of) {
      SwapStage.waiting => SwapStep(mark, mark == SwapMark.done ? Copy.payStepDeposited : Copy.payStepWaiting, [
        SwapFact(Copy.payStepSentNote(xmrText)),
        if (moneroHash != null) SwapCopyLine(label: Copy.payMoneroHash, value: moneroHash),
      ]),
      SwapStage.confirming => SwapStep(mark, Copy.payStepConfirming, [
        if (mark == SwapMark.active) const SwapFact(Copy.payStepConfirmingNote),
      ]),
      SwapStage.exchanging => SwapStep(mark, Copy.payStepExchanging(asset)),
      SwapStage.sending => SwapStep(mark, Copy.payStepSendingOut(asset, recipient), [
        if (mark != SwapMark.pending && chainHash != null) SwapCopyLine(label: Copy.payChainHash, value: chainHash),
      ]),
      _ => SwapStep(mark, Copy.payStepDone, [
        if (mark == SwapMark.done) SwapFact(Copy.payStepDoneNote(amount, asset, recipient)),
      ]),
    };

    final refundHash = swap.refundHash;
    return swapSteps(
      swap,
      step: step,
      refunded: SwapStep(SwapMark.refunded, Copy.bridgeStepRefunded, [
        SwapFact(Copy.payRefunded(formatDecimal(swap.refundAmount ?? xmr ?? 0, decimals: 8), swap.subaddressIndex)),
        if (refundHash != null) SwapCopyLine(label: Copy.payMoneroHash, value: refundHash),
      ]),
      failed: SwapStep(SwapMark.failed, Copy.bridgeStepFailed, [SwapFact(Copy.payFailed(swap.subaddressIndex))]),
    );
  }
}
