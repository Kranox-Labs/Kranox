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
import '../widgets/field.dart';
import '../widgets/page_frame.dart';
import '../widgets/review_line.dart';
import '../widgets/surfaces.dart';
import '../widgets/swap_steps.dart';

/// The length of an address on Robinhood Chain: 0x and 40 hex digits. The live check of the recipient waits for it.
const int _evmAddressLength = 42;

/// Pay to Robinhood Chain: the user types the XMR to pay and sees the coin that it buys at a fixed rate, then enters
/// the recipient there, and ChangeNOW turns the XMR of this wallet into exactly that amount. The part of the send page
/// under the choice "To Robinhood Chain", in the form of a swap, as the owner showed on 6 Oct 2026.
class SendToChain extends StatefulWidget {
  const SendToChain({super.key, required this.bridge, required this.wallet});

  final BridgeController bridge;
  final WalletController wallet;

  @override
  State<SendToChain> createState() => _SendToChainState();
}

class _SendToChainState extends State<SendToChain> {
  late final _recipient = TextEditingController(text: _pay.recipientText);
  late final _xmr = TextEditingController(text: _pay.xmrText);
  String? _error;
  bool _busy = false;

  // While a payment is on its way, the page shows that payment alone, until the user asks for the form of another one.
  bool _another = false;

  PayController get _pay => widget.bridge.pay;

  @override
  void initState() {
    super.initState();
    _recipient.addListener(() => _pay.setRecipient(_recipient.text));
    _xmr.addListener(() => _pay.setXmr(_xmr.text));
    widget.bridge.refresh();
    _pay.loadRange();
  }

  @override
  void dispose() {
    _recipient.dispose();
    _xmr.dispose();
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
    _xmr.clear();
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
              line: (swap) => Copy.paySwapTitle(_paidAmount(swap), swap.asset, shortText(swap.payoutAddress)),
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
          _AmountBox(
            label: Copy.payYouSend,
            amount: TextField(
              controller: _xmr,
              onSubmitted: (_) => pay.canReview ? _startReview() : null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            coin: const _Coin(label: Copy.currency, network: Copy.payOnMonero),
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LimitLine(pay: pay),
                if (pay.suggestsFloating) _FloatingHint(pay: pay),
                _FundsLine(pay: pay, wallet: widget.wallet),
              ],
            ),
          ),
          // The arrow between the two sides sits over the upper edge of the second one, so that they read as one swap.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: Metrics.gapSmall),
                child: _AmountBox(
                  label: pay.rate == PayRate.floating ? Copy.payTheyReceiveAbout : Copy.payTheyReceive,
                  amount: _ReceivedFigure(pay: pay),
                  coin: _CoinMenu(asset: pay.asset, enabled: !_busy, onSelect: pay.selectAsset),
                  footer: _FeesLine(pay: pay),
                ),
              ),
              const Positioned(
                top: (Metrics.gapSmall - Metrics.swapArrow) / 2,
                left: 0,
                right: 0,
                child: Center(child: _Arrow()),
              ),
            ],
          ),
          _QuoteNote(pay: pay),
          const SizedBox(height: Metrics.gap),
          Text(Copy.payRateTitle.toUpperCase(), style: KranoxType.label.copyWith(color: palette.inkSoft)),
          const SizedBox(height: Metrics.gapTiny),
          Row(
            children: [
              for (final (index, rate) in PayRate.values.indexed) ...[
                if (index > 0) const SizedBox(width: Metrics.gapSmall),
                Expanded(
                  child: _RateCard(rate: rate, pay: pay, onSelect: _busy ? null : () => pay.selectRate(rate)),
                ),
              ],
            ],
          ),
          const SizedBox(height: Metrics.gap),
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
          ErrorLine(_error),
          const SizedBox(height: Metrics.gap + 4),
          PillButton(
            label: pay.recipient == null ? Copy.payEnterRecipient : Copy.review,
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

/// One side of the swap: its label, the amount at the left, and its coin at the right, with a line below it.
class _AmountBox extends StatelessWidget {
  const _AmountBox({required this.label, required this.amount, required this.coin, this.footer});

  final String label;
  final Widget amount;
  final Widget coin;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.field,
        borderRadius: BorderRadius.circular(Metrics.radiusField),
        border: Border.all(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Metrics.swapBoxPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label.toUpperCase(), style: KranoxType.label.copyWith(color: palette.inkSoft)),
            const SizedBox(height: Metrics.gapTiny),
            Row(
              children: [
                Expanded(child: amount),
                const SizedBox(width: Metrics.gapSmall),
                coin,
              ],
            ),
            if (footer case final footer?) ...[const SizedBox(height: Metrics.gapTiny), footer],
          ],
        ),
      ),
    );
  }
}

/// A coin of the swap with its network below it, and a sign at its right when it opens a choice.
class _Coin extends StatelessWidget {
  const _Coin({required this.label, required this.network, this.trailing});

  final String label;
  final String network;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Metrics.radiusField),
        border: Border.all(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: KranoxType.cardTitle.copyWith(color: palette.ink)),
                Text(network, style: KranoxType.small.copyWith(color: palette.inkSoft)),
              ],
            ),
            if (trailing case final trailing?) ...[const SizedBox(width: Metrics.gapTiny), trailing],
          ],
        ),
      ),
    );
  }
}

/// The coin that the recipient gets, as a menu of the coins of Robinhood Chain that the bridge pays out. The menu opens
/// below the coin on the solid ground of a card, each coin with its network, and the chosen one with a check. The
/// owner turned down the plain menu of Material on 6 Oct 2026 ("ui dropdownya jangan gini").
class _CoinMenu extends StatelessWidget {
  const _CoinMenu({required this.asset, required this.enabled, required this.onSelect});

  final BridgeAsset asset;
  final bool enabled;
  final ValueChanged<BridgeAsset> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(Metrics.radiusField);
    // A menu lies over other parts, so it takes the color of a card on the ground, without the see-through.
    final ground = Color.alphaBlend(palette.surface, palette.ground);
    // The menu hangs from the lower right corner of the coin, so that its right edge meets the edge of the coin and it
    // stays inside the form.
    return MenuAnchor(
      alignmentOffset: const Offset(-Metrics.coinMenuWidth, Metrics.gapTiny),
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        backgroundColor: WidgetStatePropertyAll(ground),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(Metrics.menuElevation),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(Metrics.gapTiny)),
        minimumSize: const WidgetStatePropertyAll(Size(Metrics.coinMenuWidth, 0)),
        maximumSize: const WidgetStatePropertyAll(Size(Metrics.coinMenuWidth, double.infinity)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: palette.line),
          ),
        ),
      ),
      menuChildren: [
        for (final choice in BridgeAsset.values)
          MenuItemButton(
            onPressed: () => onSelect(choice),
            trailingIcon: choice == asset
                ? Icon(Icons.check_rounded, size: 18, color: palette.accent)
                : const SizedBox(width: 18),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(Metrics.coinMenuWidth - 2 * Metrics.gapTiny, 0)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: Metrics.gapSmall + 2, vertical: Metrics.gapSmall),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(Metrics.radiusField - Metrics.gapTiny)),
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                    ? palette.field
                    : Colors.transparent,
              ),
              overlayColor: WidgetStatePropertyAll(palette.field),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  choice.label,
                  style: KranoxType.cardTitle.copyWith(color: choice == asset ? palette.accent : palette.ink),
                ),
                Text(Copy.payOnChain, style: KranoxType.small.copyWith(color: palette.inkSoft)),
              ],
            ),
          ),
      ],
      builder: (context, controller, _) => InkWell(
        onTap: enabled ? () => controller.isOpen ? controller.close() : controller.open() : null,
        borderRadius: radius,
        child: _Coin(
          label: asset.label,
          network: Copy.payOnChain,
          trailing: AnimatedRotation(
            turns: controller.isOpen ? 0.5 : 0,
            duration: Metrics.menuTurn,
            child: Icon(Icons.expand_more_rounded, size: 18, color: palette.inkSoft),
          ),
        ),
      ),
    );
  }
}

/// The round arrow between the two sides of the swap: the XMR above turns into the coin below.
class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.field,
        shape: BoxShape.circle,
        border: Border.all(color: palette.line),
      ),
      child: SizedBox.square(
        dimension: Metrics.swapArrow,
        child: Icon(Icons.arrow_downward_rounded, size: 18, color: palette.ink),
      ),
    );
  }
}

/// The amount that the recipient gets: a spinner while the quote is on its way, then the amount at the fixed rate.
class _ReceivedFigure extends StatelessWidget {
  const _ReceivedFigure({required this.pay});

  final PayController pay;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = KranoxType.swapFigure;
    if (pay.quoting) return LoadingFigure(style: style);
    final amount = pay.quotedAmount;
    final text = amount == null ? Copy.amountHint : formatDecimal(amount, decimals: 8);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        amount != null && pay.rate == PayRate.floating ? Copy.about(text) : text,
        style: style.copyWith(color: amount == null ? palette.inkFaint : palette.ink),
      ),
    );
  }
}

/// The amount of a payment in its list and on its card: what arrived once the exchanger reports it, else the quoted
/// amount, which is an estimate at a floating rate.
String _paidAmount(BridgeSwap swap) {
  final text = formatDecimal(swap.amountOut ?? swap.amount, decimals: 8);
  return swap.fixedRate || swap.amountOut != null ? text : Copy.about(text);
}

/// One choice of the rate: its name, what it means, and its minimum for the coin of the form. The chosen one has the
/// accent on its edge and a check.
class _RateCard extends StatelessWidget {
  const _RateCard({required this.rate, required this.pay, required this.onSelect});

  final PayRate rate;
  final PayController pay;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chosen = pay.rate == rate;
    final (icon, title, note) = switch (rate) {
      PayRate.fixed => (Icons.lock_rounded, Copy.payRateFixed, Copy.payRateFixedNote),
      PayRate.floating => (Icons.show_chart_rounded, Copy.payRateFloating, Copy.payRateFloatingNote),
    };
    final range = pay.rangeOf(rate);
    final minimum = range == null ? '…' : formatLimit(range.minXmr, up: true);
    final radius = BorderRadius.circular(Metrics.radiusField);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: chosen ? null : onSelect,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.field,
            borderRadius: radius,
            border: Border.all(color: chosen ? palette.accent : palette.line, width: chosen ? Metrics.choiceBorder : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Metrics.swapBoxPadding - 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: chosen ? palette.accent : palette.inkSoft),
                    const SizedBox(width: Metrics.gapTiny),
                    Expanded(
                      child: Text(title, style: KranoxType.cardTitle.copyWith(color: palette.ink)),
                    ),
                    if (chosen) Icon(Icons.check_circle_rounded, size: 16, color: palette.accent),
                  ],
                ),
                const SizedBox(height: 4),
                Text(note, style: KranoxType.small.copyWith(color: palette.inkSoft)),
                Text(Copy.payRateMinimum(minimum), style: KranoxType.smallStrong.copyWith(color: palette.inkSoft)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The way out of an amount below the minimum of a fixed rate: a floating rate, whose minimum is lower.
class _FloatingHint extends StatelessWidget {
  const _FloatingHint({required this.pay});

  final PayController pay;

  @override
  Widget build(BuildContext context) {
    final range = pay.rangeOf(PayRate.floating);
    if (range == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => pay.selectRate(PayRate.floating),
        child: Text(
          Copy.paySwitchToFloating(formatLimit(range.minXmr, up: true)),
          style: KranoxType.smallStrong.copyWith(
            color: context.palette.accent,
            decoration: TextDecoration.underline,
            decorationColor: context.palette.accent,
          ),
        ),
      ),
    );
  }
}

/// The fees of the exchanger that the quote holds, so that a small payment explains what it loses.
class _FeesLine extends StatelessWidget {
  const _FeesLine({required this.pay});

  final PayController pay;

  @override
  Widget build(BuildContext context) {
    final quote = pay.quotedAmount == null ? null : pay.quote;
    final deposit = quote?.depositFee;
    final withdrawal = quote?.withdrawalFee;
    if (quote == null || deposit == null || withdrawal == null) return const SizedBox.shrink();
    return Text(
      Copy.payFees(formatDecimal(deposit, decimals: 8), formatDecimal(withdrawal, decimals: 8), quote.asset),
      style: KranoxType.small.copyWith(color: context.palette.inkSoft),
    );
  }
}

/// The minimum payment of the coin of the form, from the start, so that nobody has to guess it; in the color of a
/// failure when the XMR to pay stands below it, or above the maximum.
class _LimitLine extends StatelessWidget {
  const _LimitLine({required this.pay});

  final PayController pay;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final range = pay.range;
    if (range == null) return const SizedBox.shrink();
    final minimum = formatLimit(range.minXmr, up: true);
    final max = range.maxXmr;
    final (text, color) = switch (pay.limit) {
      PayLimit.below => (Copy.payBelowMinimum(minimum), palette.danger),
      PayLimit.above when max != null => (Copy.payAboveMaximum(formatLimit(max, up: false)), palette.danger),
      _ => (Copy.payMinimum(minimum), palette.inkSoft),
    };
    return Text(text, style: KranoxType.smallStrong.copyWith(color: color));
  }
}

/// The unlocked balance below the XMR to pay, or why the wallet cannot pay that much.
class _FundsLine extends StatelessWidget {
  const _FundsLine({required this.pay, required this.wallet});

  final PayController pay;
  final WalletController wallet;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = wallet.status;
    if (status.isLoading) return const LoadingLine(Copy.availableUpdating);
    final xmr = pay.xmr;
    if (xmr != null && !pay.coversFee) {
      return Text(
        xmr == status.unlocked ? Copy.amountLeavesNoFee : Copy.amountAboveUnlocked,
        style: KranoxType.small.copyWith(color: palette.danger),
      );
    }
    return Text(Copy.available(status.unlocked.toExact()), style: KranoxType.small.copyWith(color: palette.inkSoft));
  }
}

/// What the quote says beside a good estimate: why there is none, or a warning of the exchanger. The box of the XMR
/// shows the range of the fixed rate.
class _QuoteNote extends StatelessWidget {
  const _QuoteNote({required this.pay});

  final PayController pay;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final quote = pay.quote;
    final (String, Color)? note = switch ((pay.quoteError, quote)) {
      _ when pay.quoting => null,
      (final error?, _) => (bridgeFailureText(error), palette.danger),
      (null, PayQuote(:final warning?)) => (warning, palette.inkSoft),
      _ => null,
    };
    if (note == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Metrics.gapSmall),
      child: Text(
        note.$1,
        textAlign: TextAlign.center,
        style: KranoxType.small.copyWith(color: note.$2),
      ),
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
            (review.rate == PayRate.floating ? Copy.payTheyReceiveAbout : Copy.payTheyReceive).toUpperCase(),
            textAlign: TextAlign.center,
            style: KranoxType.label.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Metrics.gapTiny),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AmountFigure(
                value: review.rate == PayRate.floating
                    ? Copy.about(formatDecimal(created.amount, decimals: 8))
                    : formatDecimal(created.amount, decimals: 8),
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
          ReviewLine(
            label: Copy.payRateTitle,
            value: review.rate == PayRate.fixed ? Copy.payRateFixedReview : Copy.payRateFloatingReview,
          ),
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
            Copy.paySwapTitle(_paidAmount(swap), swap.asset, shortText(swap.payoutAddress)),
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
    final amount = _paidAmount(swap);
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
