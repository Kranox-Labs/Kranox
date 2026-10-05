import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../bridge/client.dart';
import '../../bridge/controller.dart';
import '../../bridge/models.dart';
import '../../wallet/failure.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/field.dart';
import '../widgets/choice_pill.dart';
import '../widgets/page_frame.dart';
import '../widgets/surfaces.dart';

/// An address on Robinhood Chain, an EVM chain: 0x and 40 hex digits.
final RegExp _evmAddress = RegExp(r'^0x[0-9a-fA-F]{40}$');

/// Receive from Robinhood Chain: the user sends ETH or USDG there, and ChangeNOW turns it into XMR for a new
/// subaddress of this wallet. The part of the receive page under the choice "From Robinhood Chain".
class ReceiveFromChain extends StatefulWidget {
  const ReceiveFromChain({super.key, required this.bridge});

  final BridgeController bridge;

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

  Future<void> _create() async {
    final refund = _refund.text.trim();
    if (refund.isNotEmpty && !_evmAddress.hasMatch(refund)) {
      setState(() => _refundError = Copy.bridgeRefundInvalid);
      return;
    }
    setState(() {
      _refundError = null;
      _error = null;
      _creating = true;
    });
    try {
      await widget.bridge.createSwap(refundAddress: refund.isEmpty ? null : refund);
      _amount.clear();
      _another = false;
    } on BridgeException catch (error) {
      setState(() => _error = bridgeFailureText(error));
    } on WalletException catch (error) {
      setState(() => _error = failureText(error));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.bridge,
    builder: (context, _) {
      final bridge = widget.bridge;
      final shown = bridge.shownSwap;
      return Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Metrics.formWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!bridge.available)
                Surface(
                  child: Text(
                    Copy.bridgeMainnetOnly,
                    style: KranoxType.bodyRegular.copyWith(color: context.palette.inkSoft),
                  ),
                )
              else ...[
                if (shown != null) ...[
                  _SwapCard(
                    swap: shown,
                    onRefresh: bridge.refresh,
                    onAnother: shown.stage.isFinal || _another ? null : () => setState(() => _another = true),
                    onClose: shown.stage.isFinal ? () => bridge.closeSwap(shown.id) : null,
                  ),
                  if (_another && !shown.stage.isFinal) ...[
                    const SizedBox(height: Metrics.gap),
                    _form(context, bridge),
                  ],
                ] else
                  _form(context, bridge),
              ],
              if (bridge.swaps.isNotEmpty) ...[const SizedBox(height: Metrics.gap), _History(swaps: bridge.swaps)],
            ],
          ),
        ),
      );
    },
  );

  Widget _form(BuildContext context, BridgeController bridge) {
    final palette = context.palette;
    final soft = KranoxType.bodyRegular.copyWith(color: palette.inkSoft);
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle(Copy.bridgeFormTitle),
          const SizedBox(height: 4),
          Text(Copy.bridgeFormLead, style: soft),
          const SizedBox(height: Metrics.gap),
          Text(Copy.bridgeAssetLabel.toUpperCase(), style: KranoxType.label.copyWith(color: palette.inkSoft)),
          const SizedBox(height: Metrics.gapSmall),
          Wrap(
            spacing: Metrics.gapTiny,
            children: [
              for (final asset in BridgeAsset.values)
                ChoicePill(
                  label: asset.label,
                  active: asset == bridge.asset,
                  onTap: _creating ? null : () => bridge.selectAsset(asset),
                ),
            ],
          ),
          const SizedBox(height: Metrics.gap),
          LabeledField(
            label: Copy.amount,
            controller: _amount,
            hint: Copy.bridgeAmountHint(bridge.asset),
            suffix: bridge.asset.label,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: Metrics.gapSmall),
          _QuoteLine(bridge: bridge),
          const SizedBox(height: Metrics.gap),
          LabeledField(
            label: Copy.bridgeRefundField,
            controller: _refund,
            hint: Copy.bridgeRefundHint,
            note: Copy.bridgeRefundNote,
            error: _refundError,
          ),
          ErrorLine(_error),
          const SizedBox(height: Metrics.gap),
          PillButton(
            label: Copy.bridgeCreate,
            busy: _creating,
            busyLabel: Copy.bridgeCreating,
            onPressed: bridge.canSwap ? _create : null,
          ),
          const SizedBox(height: Metrics.gapSmall),
          Text(Copy.bridgeSeenBy, style: KranoxType.small.copyWith(color: palette.inkFaint)),
        ],
      ),
    );
  }
}

/// The quote under the amount: the XMR that the amount buys, or the least amount, or why there is no quote.
class _QuoteLine extends StatelessWidget {
  const _QuoteLine({required this.bridge});

  final BridgeController bridge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final quote = bridge.quote;
    final error = bridge.quoteError;
    if (bridge.quoting) return const LoadingLine(Copy.bridgeQuoting);
    if (error != null) return ErrorLine(bridgeFailureText(error));
    if (quote == null) return const SizedBox.shrink();
    final estimate = quote.estimatedXmr;
    final minimum = Copy.bridgeMinimum(formatDecimal(quote.minAmount, decimals: 8), quote.asset);
    if (estimate == null) return ErrorLine(minimum);
    final speed = quote.speedMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Copy.bridgeEstimate(formatDecimal(estimate)), style: KranoxType.cardTitle.copyWith(color: palette.ink)),
        const SizedBox(height: 2),
        Text(
          [minimum, if (speed != null) Copy.bridgeSpeed(speed), ?quote.warning].join(' '),
          style: KranoxType.small.copyWith(color: palette.inkSoft),
        ),
      ],
    );
  }
}

/// How a step of a swap stands, for its mark.
enum _Mark { done, active, pending, failed, held, refunded }

/// One step of a swap: its mark, its title, and its facts.
final class _Step {
  const _Step(this.mark, this.title, [this.facts = const []]);

  final _Mark mark;
  final String title;
  final List<Widget> facts;
}

/// The swap that the page follows: its steps from the deposit to the XMR in this wallet, each with what ChangeNOW
/// reports about it. A failure, a check, or a refund says what happened and what to do, and the card stays until the
/// user closes it.
class _SwapCard extends StatelessWidget {
  const _SwapCard({required this.swap, required this.onRefresh, required this.onAnother, required this.onClose});

  final BridgeSwap swap;
  final Future<void> Function() onRefresh;

  /// Shows the form for another swap; null when the form shows or the swap has ended.
  final VoidCallback? onAnother;

  /// Closes the card of an ended swap; null while the swap runs.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    final updated = swap.updatedAt;
    final steps = _steps(context);
    return Surface(
      padding: const EdgeInsets.all(Metrics.heroPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            Copy.bridgeSwapTitle(formatDecimal(swap.amount, decimals: 8), swap.asset),
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
            _StepRow(
              step: steps[index],
              last: index == steps.length - 1,
              nextMark: index + 1 < steps.length ? steps[index + 1].mark : null,
            ),
          const SizedBox(height: Metrics.gapSmall),
          Row(
            children: [
              Expanded(
                child: _CopyLine(label: Copy.bridgeSwapId, value: swap.id, shorten: false),
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
  List<_Step> _steps(BuildContext context) {
    final asset = swap.asset;
    final amount = formatDecimal(swap.amount, decimals: 8);
    final estimate = swap.estimatedXmr;
    final xmr = swap.amountOut ?? estimate;
    final xmrText = xmr == null ? '…' : formatDecimal(xmr);
    final depositHash = swap.depositHash;
    final payoutHash = swap.payoutHash;
    final stage = swap.stage;

    // Each step of the way, with its facts once done and while it runs.
    _Step step(SwapStage of, _Mark mark) => switch (of) {
      SwapStage.waiting => _Step(mark, mark == _Mark.done ? Copy.bridgeStepDeposited : Copy.bridgeStepWaiting, [
        if (mark == _Mark.active) _Deposit(swap: swap),
        if (mark == _Mark.done) _Fact(Copy.bridgeStepReceived(amount, asset)),
        if (mark == _Mark.done && depositHash != null) _CopyLine(label: Copy.bridgeDepositHash, value: depositHash),
      ]),
      SwapStage.confirming => _Step(mark, Copy.bridgeStepConfirming, [
        if (mark == _Mark.active) const _Fact(Copy.bridgeStepConfirmingNote),
      ]),
      SwapStage.exchanging => _Step(mark, Copy.bridgeStepExchanging(asset), [
        if (mark == _Mark.active && estimate != null) _Fact(Copy.bridgeStepRate(formatDecimal(estimate))),
        if (mark == _Mark.done) _Fact(Copy.bridgeStepExchanged(xmrText)),
      ]),
      SwapStage.sending => _Step(mark, Copy.bridgeStepSending(swap.subaddressIndex), [
        if (mark == _Mark.active) _Fact(Copy.bridgeStepSendingNote(xmrText)),
        if (mark != _Mark.pending && payoutHash != null) _CopyLine(label: Copy.bridgePayoutHash, value: payoutHash),
      ]),
      _ => _Step(mark, Copy.bridgeStepDone, [if (mark == _Mark.done) _Fact(Copy.bridgeStepDoneNote(xmrText))]),
    };

    final path = SwapStage.path;
    final reached = path.indexOf(swap.reached);
    if (!stage.isOffPath) {
      final current = path.indexOf(stage);
      return [
        for (var index = 0; index < path.length; index++)
          step(
            path[index],
            index < current || stage == SwapStage.finished
                ? _Mark.done
                : index == current
                ? _Mark.active
                : _Mark.pending,
          ),
      ];
    }
    final before = [for (var index = 0; index < reached; index++) step(path[index], _Mark.done)];
    final refundAddress = swap.refundAddress;
    final refundHash = swap.refundHash;
    return switch (stage) {
      // ChangeNOW checks a swap after the deposit, so the steps up to the furthest one show as done.
      SwapStage.verifying => [
        ...before,
        step(path[reached], _Mark.done),
        const _Step(_Mark.held, Copy.bridgeStepHeld, [_Fact(Copy.bridgeHeld)]),
        for (var index = reached + 1; index < path.length; index++) step(path[index], _Mark.pending),
      ],
      SwapStage.refunded => [
        ...before,
        _Step(_Mark.refunded, Copy.bridgeStepRefunded, [
          _Fact(
            refundAddress == null
                ? Copy.bridgeRefundedNoAddress(formatDecimal(swap.refundAmount ?? swap.amount, decimals: 8), asset)
                : Copy.bridgeRefundedTo(
                    formatDecimal(swap.refundAmount ?? swap.amount, decimals: 8),
                    asset,
                    shortText(refundAddress),
                  ),
          ),
          if (refundHash != null) _CopyLine(label: Copy.bridgeRefundHash, value: refundHash),
        ]),
      ],
      _ => [
        ...before,
        _Step(_Mark.failed, Copy.bridgeStepFailed, [
          _Fact(
            depositHash == null && swap.reached == SwapStage.waiting
                ? Copy.bridgeFailedNoDeposit(asset)
                : refundAddress == null
                ? Copy.bridgeFailedNoRefundAddress(amount, asset)
                : Copy.bridgeFailedRefunding(amount, asset, shortText(refundAddress)),
          ),
          // The step of the deposit shows its hash once it is done; before that, the failure shows it.
          if (depositHash != null && reached == 0) _CopyLine(label: Copy.bridgeDepositHash, value: depositHash),
        ]),
      ],
    };
  }
}

/// A step: its mark on a line that joins the marks, beside its title and its facts.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.last, required this.nextMark});

  final _Step step;
  final bool last;
  final _Mark? nextMark;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reachedNext = nextMark == _Mark.done || nextMark == _Mark.active;
    final titleColor = switch (step.mark) {
      _Mark.pending => palette.inkFaint,
      _Mark.failed => palette.danger,
      _ => palette.ink,
    };
    // The line to the next mark hangs beside the row, so that it reaches as far down as the facts of the step go.
    return Stack(
      children: [
        if (!last)
          Positioned(
            left: (Metrics.stepMark - Metrics.stepLine) / 2,
            top: Metrics.stepMark,
            bottom: 0,
            child: Container(width: Metrics.stepLine, color: reachedNext ? palette.accent : palette.line),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: last ? 0 : Metrics.gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepMark(mark: step.mark),
              const SizedBox(width: Metrics.gapSmall + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: Metrics.stepMark,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(step.title, style: KranoxType.body.copyWith(color: titleColor)),
                      ),
                    ),
                    for (final fact in step.facts) ...[const SizedBox(height: Metrics.gapTiny), fact],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The mark of a step: a check when done, a spinner while it runs, an empty ring before it, and a sign for a
/// failure, a check, and a refund.
class _StepMark extends StatelessWidget {
  const _StepMark({required this.mark});

  final _Mark mark;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget filled(Color color, IconData icon, Color ink) => DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(child: Icon(icon, size: 15, color: ink)),
    );
    Widget ring(Color color, {Widget? child}) => DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: child == null ? null : Center(child: child),
    );
    return SizedBox.square(
      dimension: Metrics.stepMark,
      child: switch (mark) {
        _Mark.done => filled(palette.accent, Icons.check_rounded, palette.onAccent),
        _Mark.failed => filled(palette.danger, Icons.close_rounded, palette.onAccent),
        _Mark.active => Padding(
          padding: const EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2.4, color: palette.accent, backgroundColor: palette.line),
        ),
        _Mark.held => ring(palette.accent, child: Icon(Icons.pause_rounded, size: 14, color: palette.accent)),
        _Mark.refunded => ring(palette.accent, child: Icon(Icons.undo_rounded, size: 14, color: palette.accent)),
        _Mark.pending => ring(palette.line),
      },
    );
  }
}

/// A sentence about a step.
class _Fact extends StatelessWidget {
  const _Fact(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: KranoxType.small.copyWith(color: context.palette.inkSoft, height: 1.45));
}

/// A value of a step that the user may need elsewhere, such as a transaction hash, with a button that copies it.
class _CopyLine extends StatelessWidget {
  const _CopyLine({required this.label, required this.value, this.shorten = true});

  final String label;
  final String value;
  final bool shorten;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${label.toUpperCase()}  ', style: KranoxType.label.copyWith(color: palette.inkSoft)),
        Text(shorten ? shortText(value) : value, style: KranoxType.mono.copyWith(color: palette.ink)),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => copyToClipboard(context, value),
          tooltip: Copy.copied,
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          icon: Icon(Icons.copy_rounded, color: palette.inkSoft),
        ),
      ],
    );
  }
}

/// The deposit while the swap waits for it: the address on Robinhood Chain as a code to scan and as text.
class _Deposit extends StatelessWidget {
  const _Deposit({required this.swap});

  final BridgeSwap swap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Copy.bridgeDepositLead(formatDecimal(swap.amount, decimals: 8), swap.asset),
          style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft),
        ),
        const SizedBox(height: Metrics.gapSmall),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A code to scan needs dark modules on a light ground in every look.
            DecoratedBox(
              decoration: BoxDecoration(
                color: BrandColors.white,
                borderRadius: BorderRadius.circular(Metrics.radiusField),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: QrImageView(
                  data: swap.depositAddress,
                  size: Metrics.bridgeQrSize,
                  padding: EdgeInsets.zero,
                  backgroundColor: BrandColors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: BrandColors.coal),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: BrandColors.coal,
                  ),
                ),
              ),
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

/// Every swap of this device, the newest first, with its state.
class _History extends StatelessWidget {
  const _History({required this.swaps});

  final List<BridgeSwap> swaps;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle(Copy.bridgeSwapsTitle),
          const SizedBox(height: Metrics.gapSmall),
          for (final swap in swaps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Copy.bridgeSwapLine(formatDecimal(swap.amount, decimals: 8), swap.asset),
                          style: KranoxType.body.copyWith(color: palette.ink),
                        ),
                        Text(
                          '${formatTime(swap.createdAt, now)} · ${Copy.bridgeStage(swap.stage)}',
                          style: KranoxType.small.copyWith(
                            color: swap.stage == SwapStage.failed ? palette.danger : palette.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // A failed or refunded swap brought no XMR, so it shows no amount of XMR.
                  if (swap.stage != SwapStage.failed && swap.stage != SwapStage.refunded)
                    if ((swap.amountOut ?? swap.estimatedXmr) case final xmr?)
                      Text(Copy.bridgeOut(formatDecimal(xmr)), style: KranoxType.body.copyWith(color: palette.ink)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
