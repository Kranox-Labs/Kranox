import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bridge/chain_scan.dart';
import '../../bridge/client.dart';
import '../../bridge/controller.dart';
import '../../bridge/models.dart';
import '../../bridge/pay_controller.dart';
import '../../config/app_config.dart';
import '../../core/amount.dart';
import '../../core/evm_address.dart';
import '../../core/unlock.dart';
import '../../privacy/chain_privacy.dart';
import '../../privacy/chain_scans.dart';
import '../../privacy/privacy_check.dart';
import '../../wallet/controller.dart';
import '../../wallet/failure.dart';
import '../../wallet/models.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/field.dart';
import '../widgets/page_frame.dart';
import '../widgets/privacy_check.dart';
import '../widgets/address_check.dart';
import '../widgets/review_line.dart';
import '../widgets/send_password.dart';
import '../widgets/surfaces.dart';
import '../widgets/swap_box.dart';
import '../widgets/swap_steps.dart';

/// The length of an address on Robinhood Chain: 0x and 40 hex digits. The live check of the recipient waits for it.
const int _evmAddressLength = 42;

/// Pay to Robinhood Chain: the user types the XMR to pay and sees the coin that it buys at a fixed rate, then enters
/// the recipient there, and ChangeNOW turns the XMR of this wallet into exactly that amount. The part of the send page
/// under the choice "To Robinhood Chain", in the form of a swap, as the owner showed on 6 Oct 2026. From 10 Oct 2026
/// each payment has a page of its own, which [onOpenSwap] opens: from its card under the form, from its line in the
/// list, and at once for a new payment.
class SendToChain extends StatefulWidget {
  const SendToChain({super.key, required this.bridge, required this.wallet, required this.onOpenSwap, this.scans});

  final BridgeController bridge;
  final WalletController wallet;
  final ValueChanged<BridgeSwap> onOpenSwap;

  /// The addresses that the user scanned in the menu Privacy, which the check of the recipient counts as the user's.
  final ChainScans? scans;

  @override
  State<SendToChain> createState() => _SendToChainState();
}

class _SendToChainState extends State<SendToChain> {
  late final _recipient = TextEditingController(text: _pay.recipientText);
  late final _xmr = TextEditingController(text: _pay.xmrText);
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  // The privacy check of the review on screen, made once for each review, so that its suggestion stays put. The review
  // lives in pay, so it can outlast a visit of this page.
  PayReview? _checked;
  PrivacyReport? _privacy;
  final Random _random = Random.secure();

  // The check of the recipient, for the address that it belongs to: what the scan found, or why it failed.
  String? _checkedRecipient;
  ChainPrivacyReport? _recipientReport;
  String? _recipientError;
  bool _checkingRecipient = false;

  PayController get _pay => widget.bridge.pay;

  @override
  void initState() {
    super.initState();
    _recipient.addListener(() => _pay.setRecipient(_recipient.text));
    _xmr.addListener(() => _pay.setXmr(_xmr.text));
    widget.bridge.refresh();
    _pay.loadRange();
    // A review that outlived a visit of this page gets its check once the page shows.
    if (_pay.review case final review?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startRecipientCheck(review);
      });
    }
  }

  @override
  void dispose() {
    _recipient.dispose();
    _xmr.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _recipient.text = text;
  }

  Future<void> _startReview() => _run(() async => _startRecipientCheck(await _pay.startReview()));

  Future<void> _confirm() => _run(() async {
    final swap = await _pay.confirm(password: _password.text);
    _password.clear();
    _recipient.clear();
    _xmr.clear();
    widget.onOpenSwap(swap);
  });

  Future<void> _cancel() => _run(() async {
    await _pay.cancelReview();
    _password.clear();
  });

  PrivacyReport _privacyOf(PayReview review) {
    final known = _privacy;
    if (known != null && identical(review, _checked)) return known;
    final status = widget.wallet.status;
    final range = _pay.range;
    final report = checkPrivacy(
      amount: review.prepared.amount,
      fee: review.prepared.fee,
      transfers: widget.wallet.transfers,
      swaps: widget.bridge.swaps,
      balance: status.balance,
      spendable: status.unlocked,
      now: DateTime.now(),
      chain: ChainPayment(
        asset: review.asset,
        amount: review.created.amount,
        recipient: review.created.payoutAddress,
        minXmr: range?.minXmr,
        maxXmr: range?.maxXmr,
      ),
      ownAddresses: widget.scans?.scanned ?? const [],
      random: _random,
    );
    _checked = review;
    _privacy = report;
    return report;
  }

  /// The privacy check of [review] with the rule of the address from the scan of its recipient once it is in, which
  /// also knows the receives whose coin the recipient sent in. The rest of the check stays as it was made.
  PrivacyReport _withRecipientScan(PrivacyReport report, PayReview review) {
    final recipient = review.created.payoutAddress;
    final scanned = _checkedRecipient == recipient ? _recipientReport : null;
    if (scanned == null) return report;
    return report.withOwnAddress(
      ownAddressOf(
        recipient,
        widget.bridge.swaps,
        ownAddresses: widget.scans?.scanned ?? const [],
        links: scanned.kranox,
      ),
    );
  }

  /// Starts the check of the recipient of [review] as the review opens, since a user forgets a button, when the relay
  /// of the app offers the scan. A check of the same address that found something stays.
  void _startRecipientCheck(PayReview review) {
    final scanner = widget.bridge.scanner;
    final address = review.created.payoutAddress;
    if (scanner == null || (_checkedRecipient == address && _recipientReport != null)) return;
    unawaited(_checkRecipient(address, scanner));
  }

  /// Whether the review of [review] waits for the check of its recipient before it pays.
  bool _waitsForCheck(PayReview review) => _checkedRecipient == review.created.payoutAddress && _checkingRecipient;

  /// Scans the recipient [address] through the relay. The scan stays out of the scans of the menu Privacy, because the
  /// recipient may be someone else.
  Future<void> _checkRecipient(String address, ChainScanClient scanner) async {
    setState(() {
      _checkedRecipient = address;
      _recipientReport = null;
      _recipientError = null;
      _checkingRecipient = true;
    });
    try {
      final scan = await readScan(scanner, address);
      final report = analyzeChain(scan, swaps: widget.bridge.swaps, ownAddresses: widget.scans?.scanned ?? const []);
      if (mounted && _checkedRecipient == address) setState(() => _recipientReport = report);
    } on BridgeException catch (error) {
      if (mounted && _checkedRecipient == address) setState(() => _recipientError = bridgeFailureText(error));
    } finally {
      if (mounted && _checkedRecipient == address) setState(() => _checkingRecipient = false);
    }
  }

  /// The check of the recipient on [review], when the relay of the app offers the scan.
  Widget? _recipientCheck(PayReview review) {
    final scanner = widget.bridge.scanner;
    if (scanner == null) return null;
    final address = review.created.payoutAddress;
    final mine = _checkedRecipient == address;
    return AddressCheck(
      report: mine ? _recipientReport : null,
      error: mine ? _recipientError : null,
      onRetry: _busy || _checkingRecipient ? null : () => _checkRecipient(address, scanner),
      now: DateTime.now(),
      freshNote: Copy.payRecipientFreshNote,
      apartNote: Copy.payRecipientApart,
    );
  }

  /// Leaves the review and puts the suggested amount of the privacy check into the form. Pay quotes it again, and the
  /// user reviews the new amount.
  Future<void> _useSuggestion(XmrAmount amount) async {
    await _cancel();
    _xmr.text = amount.toExact();
  }

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
    } on Object {
      // The page says so, and the error still reaches the handler of Flutter.
      setState(() => _error = Copy.unexpectedFailure);
      rethrow;
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
      final open = widget.bridge.openSwapsOf(SwapDirection.pay);
      final review = _pay.review;
      final payments = widget.bridge.swapsOf(SwapDirection.pay);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (review != null)
            _Review(
              review: review,
              privacy: _withRecipientScan(_privacyOf(review), review),
              recipientCheck: _recipientCheck(review),
              checking: _waitsForCheck(review),
              onUseSuggestion: _useSuggestion,
              password: _password,
              busy: _busy,
              error: _error,
              onConfirm: _confirm,
              onCancel: _cancel,
            )
          else
            _form(context),
          // Each payment that runs has a simple card of its own under the form, so that the user can pay again
          // meanwhile.
          SwapCards(
            title: Copy.payOpenPayments(open.length),
            swaps: open,
            headline: _paymentTitle,
            onOpen: widget.onOpenSwap,
          ),
          if (payments.isNotEmpty) ...[
            const SizedBox(height: Metrics.gap),
            SwapHistory(
              title: Copy.paymentsTitle,
              swaps: payments,
              line: _paymentTitle,
              // A payment that failed, was refunded, or expired paid nothing, so it shows no amount that left.
              trailing: (swap) => switch (swap.xmrAmount) {
                final xmr? when !swap.stage.withoutPayout => Copy.payOut(formatDecimal(xmr, decimals: 8)),
                _ => null,
              },
              onOpen: widget.onOpenSwap,
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
          SwapPair(
            top: SwapAmountBox(
              label: Copy.payYouSend,
              amount: TextField(
                controller: _xmr,
                onSubmitted: (_) => pay.canReview ? _startReview() : null,
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
              coin: const SwapCoin(label: Copy.currency, network: Copy.payOnMonero),
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LimitLine(pay: pay),
                  if (pay.suggestsFloating) _FloatingHint(pay: pay),
                  _FundsLine(pay: pay, wallet: widget.wallet),
                ],
              ),
            ),
            bottom: SwapAmountBox(
              label: pay.rate == PayRate.floating ? Copy.payTheyReceiveAbout : Copy.payTheyReceive,
              amount: _ReceivedFigure(pay: pay),
              coin: CoinMenu(asset: pay.asset, enabled: !_busy, onSelect: pay.selectAsset),
              footer: _FeesLine(pay: pay),
            ),
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

/// The title of a payment, on its card, its line, and its page.
String _paymentTitle(BridgeSwap swap) =>
    Copy.paySwapTitle(_paidAmount(swap), swap.asset, shortText(swap.payoutAddress));

/// The transfer of this wallet that carried the XMR of [swap] to the exchanger, once the history of the wallet in
/// [transfers] holds it, for the confirmations that the card of the payment counts.
WalletTransfer? _sentTransfer(BridgeSwap swap, List<WalletTransfer> transfers) {
  final hash = swap.depositHash;
  if (hash == null) return null;
  for (final transfer in transfers) {
    if (transfer.hash == hash) return transfer;
  }
  return null;
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
  Widget build(BuildContext context) => switch ((pay.quoteError, pay.quote)) {
    _ when pay.quoting => const SwapNote(null),
    (final error?, _) => SwapNote(bridgeFailureText(error), failure: true),
    (null, PayQuote(:final warning?)) => SwapNote(warning),
    _ => const SwapNote(null),
  };
}

/// The review of a payment: what the recipient gets and where, with the check of the recipient, the XMR that leaves with
/// its fee, until when the rate holds, and where a refund goes.
class _Review extends StatelessWidget {
  const _Review({
    required this.review,
    required this.privacy,
    required this.recipientCheck,
    required this.checking,
    required this.onUseSuggestion,
    required this.password,
    required this.busy,
    required this.error,
    required this.onConfirm,
    required this.onCancel,
  });

  final PayReview review;
  final PrivacyReport privacy;
  final Widget? recipientCheck;

  /// Whether the check of the recipient runs, so that the payment waits for it.
  final bool checking;
  final ValueChanged<XmrAmount> onUseSuggestion;
  final TextEditingController password;
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
          ReviewAddress(label: Copy.payTo, address: created.payoutAddress, check: recipientCheck),
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
          const SizedBox(height: Metrics.gapSmall),
          PrivacyCheckCard(report: privacy, now: DateTime.now(), onUseSuggestion: busy ? null : onUseSuggestion),
          const SizedBox(height: Metrics.gap),
          SendWithPassword(
            password: password,
            label: Copy.payNow,
            busyLabel: busy ? Copy.paying : Copy.addressCheckWait,
            busy: busy || checking,
            onConfirm: onConfirm,
          ),
          ErrorLine(error),
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

/// The page of one payment, with the way back to the send page in [onBack]. It follows the payment as the bridge reads
/// it and the confirmations of its XMR as the wallet reads them, and goes back once the user closes the card of an
/// ended payment.
class PaymentPage extends StatelessWidget {
  const PaymentPage({
    super.key,
    required this.bridge,
    required this.wallet,
    required this.swapId,
    required this.onBack,
  });

  final BridgeController bridge;
  final WalletController wallet;
  final String swapId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([bridge, wallet]),
    builder: (context, _) {
      final swap = bridge.swaps.where((swap) => swap.id == swapId).firstOrNull;
      if (swap == null) {
        // The swaps closed with the wallet, so the page goes back to the form.
        WidgetsBinding.instance.addPostFrameCallback((_) => onBack());
        return const SizedBox.shrink();
      }
      return PageFrame(
        back: BackLink(label: Copy.navSend, onTap: onBack),
        title: _paymentTitle(swap),
        lead: Copy.swapStage(swap.direction, swap.stage),
        chips: const [StatusChip(label: Copy.exchanger)],
        centered: true,
        children: [
          _PaymentCard(
            swap: swap,
            transfer: _sentTransfer(swap, wallet.transfers),
            checkedAt: bridge.checkedAt,
            onRefresh: bridge.refresh,
            onClose: swap.stage.isFinal && !swap.closed
                ? () async {
                    await bridge.closeSwap(swap.id);
                    onBack();
                  }
                : null,
          ),
        ],
      );
    },
  );
}

/// A payment that the page follows: its steps from the XMR that left this wallet to the coin at the recipient, each
/// with what ChangeNOW reports about it. A failure, a check, a refund, or the end of the wait says what happened and
/// what to do, and the card stays under the form until the user closes it.
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.swap,
    required this.transfer,
    required this.checkedAt,
    required this.onRefresh,
    required this.onClose,
  });

  final BridgeSwap swap;

  /// The transfer of this wallet that carried the XMR, for its confirmations; null until the history holds it.
  final WalletTransfer? transfer;
  final DateTime? checkedAt;
  final Future<void> Function() onRefresh;

  /// Closes the card of an ended payment; null while the payment runs, or once the user closed it.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final steps = _steps();
    return Surface(
      padding: const EdgeInsets.all(Metrics.heroPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwapCardHeader(
            swap: swap,
            checkedAt: checkedAt,
            onRefresh: onRefresh,
            notes: [
              swap.fixedRate ? Copy.payRateFixedReview : Copy.payRateFloatingReview,
              Copy.payUsualTime,
              Copy.bridgeCanClose,
            ],
          ),
          const SizedBox(height: Metrics.gap),
          for (var index = 0; index < steps.length; index++)
            SwapStepRow(
              step: steps[index],
              last: index == steps.length - 1,
              nextMark: index + 1 < steps.length ? steps[index + 1].mark : null,
            ),
          if (!swap.stage.isFinal) ...[
            const SizedBox(height: Metrics.gapSmall),
            Text(Copy.payRefundNote(swap.subaddressIndex), style: KranoxType.small.copyWith(color: palette.inkSoft)),
          ],
          const SizedBox(height: Metrics.gapSmall),
          Row(
            children: [
              Expanded(
                child: SwapCopyLine(label: Copy.bridgeSwapId, value: swap.id, shorten: false),
              ),
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
        if (mark == SwapMark.active) _MoneroProgress(transfer: transfer),
      ]),
      SwapStage.confirming => SwapStep(mark, Copy.payStepConfirming, [
        if (mark == SwapMark.active) _MoneroProgress(transfer: transfer),
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
      expired: SwapStep(SwapMark.expired, Copy.bridgeStepExpired, [
        SwapFact(moneroHash == null ? Copy.payExpiredNothingSent : Copy.payExpired(swap.subaddressIndex)),
      ]),
    );
  }
}

/// How far the XMR of a payment is on its way to the confirmations that ChangeNOW waits for, from the history of this
/// wallet: the wait for the first block, then a dot for each confirmation with the time left. Until the history holds
/// the transfer, the step says what ChangeNOW waits for.
class _MoneroProgress extends StatelessWidget {
  const _MoneroProgress({required this.transfer});

  final WalletTransfer? transfer;

  @override
  Widget build(BuildContext context) {
    final sent = transfer;
    if (sent == null) return const SwapFact(Copy.payStepConfirmingNote);
    if (sent.isPending || sent.confirmations == 0) return SwapFact(Copy.payStepFirstBlock);
    final wait = ConfirmationWait(sent.confirmations, target: AppConfig.exchangerXmrConfirmations);
    if (wait.isDone) return const SwapFact(Copy.payStepConfirmed);
    return Row(
      children: [
        ConfirmationDots(confirmations: wait.confirmations, target: wait.target),
        const SizedBox(width: Metrics.gapSmall),
        Expanded(
          child: Text(
            Copy.payStepConfirmations(wait.confirmations, wait.target, wait.timeLeft),
            style: KranoxType.small.copyWith(color: context.palette.inkSoft),
          ),
        ),
      ],
    );
  }
}
