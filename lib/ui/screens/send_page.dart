import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bridge/controller.dart';
import '../../config/app_config.dart';
import '../../bridge/models.dart';
import '../../core/address.dart';
import '../../core/amount.dart';
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
import '../widgets/choice_pill.dart';
import '../widgets/field.dart';
import '../widgets/page_frame.dart';
import '../widgets/privacy_check.dart';
import '../widgets/review_line.dart';
import '../widgets/send_password.dart';
import '../widgets/surfaces.dart';
import 'send_to_chain.dart';

/// The ways to send: XMR to a Monero address, or pay, XMR that ChangeNOW turns into a coin for an address on Robinhood
/// Chain.
enum _SendWay { monero, robinhood }

/// The send page: a payment in XMR in three steps, the form, the review with the fee, and the receipt; or pay to
/// Robinhood Chain.
class SendPage extends StatefulWidget {
  const SendPage({super.key, required this.controller, required this.bridge, this.scans, this.startOnPay = false});

  final WalletController controller;
  final BridgeController bridge;

  /// The addresses on Robinhood Chain that the user scanned in the menu Privacy, which the check of the recipient of
  /// pay counts as the user's own.
  final ChainScans? scans;

  /// Whether the page opens on pay, such as from the way to a clean start of the menu Privacy.
  final bool startOnPay;

  @override
  State<SendPage> createState() => _SendPageState();
}

/// The live check of the address waits until the text is as long as the shortest address: 95 characters.
const int _shortestAddress = 95;

class _SendPageState extends State<SendPage> {
  // A payment on its way, under review, or in preparation brings the user back to pay.
  late _SendWay _way =
      !widget.startOnPay &&
          widget.bridge.activeSwapOf(SwapDirection.pay) == null &&
          widget.bridge.pay.review == null &&
          !widget.bridge.pay.preparing
      ? _SendWay.monero
      : _SendWay.robinhood;
  final _address = TextEditingController();
  final _amount = TextEditingController();
  final _password = TextEditingController();
  String? _addressError;
  String? _amountError;

  // What the live check found: the kind of a complete, valid address, and an amount that the wallet can send.
  AddressKind? _addressKind;
  XmrAmount? _validAmount;
  String? _error;
  bool _busy = false;
  PreparedSend? _prepared;
  SentPayment? _sent;

  // The privacy check of the payment under review, made once for each review, so that its suggestion stays put.
  PrivacyReport? _privacy;
  final Random _random = Random.secure();

  @override
  void dispose() {
    // A review that the user leaves goes: the wallet drops its payment unless it built another one since.
    final prepared = _prepared;
    if (prepared != null) unawaited(widget.controller.cancelSend(prepared));
    _address.dispose();
    _amount.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Checks the address while the user types. A partial address shows no error yet; a complete one shows its kind
  /// or what is wrong with it.
  void _onAddressChanged(String text) {
    final network = widget.controller.network;
    final value = text.trim();
    AddressKind? kind;
    String? error;
    if (value.length >= _shortestAddress) {
      try {
        kind = checkAddress(value, network);
      } on AddressException catch (problem) {
        error = addressProblemText(problem, network);
      }
    }
    setState(() {
      _addressKind = kind;
      _addressError = error;
    });
  }

  /// Checks the amount while the user types: its form, and the unlocked balance once the wallet has caught up.
  void _onAmountChanged(String text) {
    XmrAmount? amount;
    String? error;
    if (text.trim().isNotEmpty) {
      try {
        amount = XmrAmount.parse(text);
        final status = widget.controller.status;
        // The fee comes out of the unlocked balance too, so the amount must stay below it.
        if (!status.isLoading && amount > status.unlocked) {
          error = Copy.amountAboveUnlocked;
          amount = null;
        } else if (!status.isLoading && amount == status.unlocked) {
          error = Copy.amountLeavesNoFee;
          amount = null;
        }
      } on AmountFormatException catch (problem) {
        error = amountProblemText(problem.problem);
      }
    }
    setState(() {
      _validAmount = amount;
      _amountError = error;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _address.text = text;
    _onAddressChanged(text);
  }

  bool get _canReview => _addressKind != null && _validAmount != null && !_busy;

  Future<void> _review() async {
    setState(() {
      _addressError = null;
      _amountError = null;
      _error = null;
    });
    try {
      checkAddress(_address.text, widget.controller.network);
    } on AddressException catch (error) {
      setState(() => _addressError = addressProblemText(error, widget.controller.network));
    }
    XmrAmount? amount;
    try {
      amount = XmrAmount.parse(_amount.text);
      if (amount > widget.controller.status.unlocked) {
        setState(() => _amountError = Copy.amountAboveUnlocked);
      }
    } on AmountFormatException catch (error) {
      setState(() => _amountError = amountProblemText(error.problem));
    }
    if (_addressError != null || _amountError != null || amount == null) return;
    await _run(() async {
      final prepared = await widget.controller.prepareSend(address: _address.text, amount: amount!);
      setState(() {
        _prepared = prepared;
        _privacy = _checkPrivacy(prepared);
      });
    });
  }

  Future<void> _confirm() => _run(() async {
    final prepared = _prepared;
    if (prepared == null) return;
    try {
      final sent = await widget.controller.confirmSend(prepared, password: _password.text);
      _password.clear();
      setState(() {
        _sent = sent;
        _prepared = null;
      });
    } on WalletException catch (error) {
      // The wallet holds another payment or none, so this review cannot leave: the form shows again.
      if (error.failure == WalletFailure.paymentChanged || error.failure == WalletFailure.walletClosed) {
        setState(() => _prepared = null);
      }
      rethrow;
    }
  });

  Future<void> _cancel() => _run(() async {
    final prepared = _prepared;
    if (prepared != null) await widget.controller.cancelSend(prepared);
    _password.clear();
    setState(() {
      _prepared = null;
      _privacy = null;
    });
  });

  PrivacyReport _checkPrivacy(PreparedSend prepared) {
    final status = widget.controller.status;
    return checkPrivacy(
      amount: prepared.amount,
      fee: prepared.fee,
      transfers: widget.controller.transfers,
      swaps: widget.bridge.swaps,
      balance: status.balance,
      spendable: status.unlocked,
      now: DateTime.now(),
      random: _random,
    );
  }

  /// Leaves the review, puts the suggested amount of the privacy check into the form, and reviews the payment again.
  Future<void> _useSuggestion(XmrAmount amount) async {
    await _cancel();
    final text = amount.toExact();
    _amount.text = text;
    _onAmountChanged(text);
    if (_canReview) await _review();
  }

  void _restart() {
    _address.clear();
    _amount.clear();
    setState(() {
      _sent = null;
      _addressKind = null;
      _validAmount = null;
    });
  }

  /// Runs a call to the wallet while the buttons show that it works, and shows a failure under the buttons.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
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

  // The choice of the way follows pay, which prepares a review on its own page.
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: widget.bridge.pay, builder: (context, _) => _page(context));

  Widget _page(BuildContext context) {
    final toChain = _way == _SendWay.robinhood;
    final pay = widget.bridge.pay;
    // The choice waits while a payment is under review or in preparation, so that a review never stays open behind
    // the other way and no plain payment is built while pay builds one.
    final choosing = _prepared == null && pay.review == null && !pay.preparing && !_busy;
    final ways = Wrap(
      alignment: WrapAlignment.center,
      spacing: Metrics.gapTiny,
      runSpacing: Metrics.gapTiny,
      children: [
        ChoicePill(
          label: Copy.sendMoneroTab,
          active: !toChain,
          onTap: toChain && choosing ? () => setState(() => _way = _SendWay.monero) : null,
        ),
        ChoicePill(
          label: Copy.sendChainTab,
          active: toChain,
          onTap: !toChain && choosing ? () => setState(() => _way = _SendWay.robinhood) : null,
        ),
      ],
    );
    if (toChain) {
      return PageFrame(
        title: Copy.sendTitle,
        lead: Copy.payLead,
        chips: [
          StatusChip(label: widget.controller.network.label),
          const StatusChip(label: Copy.exchanger),
        ],
        centered: true,
        children: [
          ways,
          const SizedBox(height: Metrics.gap),
          SendToChain(bridge: widget.bridge, wallet: widget.controller, scans: widget.scans),
        ],
      );
    }
    final step = switch ((_prepared, _sent)) {
      (_, final SentPayment sent) => _Receipt(sent: sent, onDone: _restart),
      (final PreparedSend prepared, _) => _Review(
        prepared: prepared,
        privacy: _privacy,
        onUseSuggestion: _useSuggestion,
        password: _password,
        busy: _busy,
        error: _error,
        onConfirm: _confirm,
        onCancel: _cancel,
      ),
      _ => _form(context),
    };
    return PageFrame(
      title: Copy.sendTitle,
      lead: Copy.sendLead,
      chips: [StatusChip(label: widget.controller.network.label)],
      centered: true,
      children: [
        ways,
        const SizedBox(height: Metrics.gap),
        step,
      ],
    );
  }

  Widget _form(BuildContext context) {
    final palette = context.palette;
    final network = widget.controller.network;
    final status = widget.controller.status;
    final kind = _addressKind;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: Copy.recipient,
            controller: _address,
            hint: Copy.recipientHint(network),
            error: _addressError,
            note: kind == null ? null : Copy.addressValid(kind, network),
            good: kind != null,
            lines: 2,
            mono: true,
            onChanged: _onAddressChanged,
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
            Copy.amount.toUpperCase(),
            textAlign: TextAlign.center,
            style: KranoxType.label.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Metrics.gapTiny),
          // The amount stands large in the middle, like a balance, with its unit below it.
          TextField(
            controller: _amount,
            onChanged: _onAmountChanged,
            onSubmitted: (_) => _canReview ? _review() : null,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // The form says itself when an amount has too many decimals.
            inputFormatters: [LengthLimitingTextInputFormatter(AppConfig.amountFieldMaxLength), AmountInputFormatter()],
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
            Copy.currency,
            textAlign: TextAlign.center,
            style: KranoxType.smallStrong.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Metrics.gapSmall),
          if (_amountError case final error?)
            Text(
              error,
              textAlign: TextAlign.center,
              style: KranoxType.small.copyWith(color: palette.danger),
            )
          else if (status.isLoading)
            const Center(child: IntrinsicWidth(child: LoadingLine(Copy.availableUpdating)))
          else ...[
            Text(
              Copy.available(status.unlocked.toExact()),
              textAlign: TextAlign.center,
              style: KranoxType.small.copyWith(color: palette.inkSoft),
            ),
            // Coins that arrived or came back as change a few blocks ago are in the balance but not yet spendable.
            if (status.locked.units > 0) ...[
              const SizedBox(height: 2),
              Text(
                switch (widget.controller.unlockWait) {
                  final wait? => Copy.lockedPartReadyIn(status.locked.toExact(), wait.timeLeft),
                  null => Copy.lockedPart(status.locked.toExact()),
                },
                textAlign: TextAlign.center,
                style: KranoxType.small.copyWith(color: palette.inkFaint),
              ),
            ],
          ],
          ErrorLine(_error),
          const SizedBox(height: Metrics.gap + 4),
          PillButton(
            label: Copy.review,
            busy: _busy,
            busyLabel: Copy.preparing,
            expand: true,
            onPressed: _canReview ? _review : null,
          ),
        ],
      ),
    );
  }
}

class _Review extends StatelessWidget {
  const _Review({
    required this.prepared,
    required this.privacy,
    required this.onUseSuggestion,
    required this.password,
    required this.busy,
    required this.error,
    required this.onConfirm,
    required this.onCancel,
  });

  final PreparedSend prepared;
  final PrivacyReport? privacy;
  final ValueChanged<XmrAmount> onUseSuggestion;
  final TextEditingController password;
  final bool busy;
  final String? error;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
            Copy.youSend.toUpperCase(),
            textAlign: TextAlign.center,
            style: KranoxType.label.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Metrics.gapTiny),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AmountFigure(
                value: prepared.amount.toExact(),
                style: KranoxType.sendFigure,
                unitStyle: KranoxType.smallStrong,
              ),
            ),
          ),
          const SizedBox(height: Metrics.gap),
          // The whole address, so that the user can check it character by character before the payment leaves.
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
                  Text(Copy.to.toUpperCase(), style: KranoxType.label.copyWith(color: palette.inkSoft)),
                  const SizedBox(height: Metrics.gapTiny),
                  SelectableText(prepared.address, style: KranoxType.mono.copyWith(color: palette.ink)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Metrics.gapSmall),
          ReviewLine(label: Copy.fee, value: '${prepared.fee.toExact()} ${Copy.currency}'),
          Divider(height: 1, color: palette.line),
          ReviewLine(label: Copy.total, value: '${prepared.total.toExact()} ${Copy.currency}', strong: true),
          if (privacy case final report?) ...[
            const SizedBox(height: Metrics.gapSmall),
            PrivacyCheckCard(report: report, now: DateTime.now(), onUseSuggestion: busy ? null : onUseSuggestion),
          ],
          const SizedBox(height: Metrics.gap),
          SendWithPassword(
            password: password,
            label: Copy.sendNow,
            busyLabel: Copy.sending,
            busy: busy,
            onConfirm: onConfirm,
          ),
          ErrorLine(error),
          const SizedBox(height: Metrics.gapSmall),
          PillButton(label: Copy.cancel, tone: PillTone.quiet, expand: true, onPressed: busy ? null : onCancel),
        ],
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.sent, required this.onDone});

  final SentPayment sent;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
              child: SizedBox.square(
                dimension: Metrics.roundButton,
                child: Icon(Icons.check_rounded, color: palette.onAccent),
              ),
            ),
          ),
          const SizedBox(height: Metrics.gap),
          Text(
            Copy.sentTitle,
            textAlign: TextAlign.center,
            style: KranoxType.pageTitle.copyWith(color: palette.ink),
          ),
          const SizedBox(height: 4),
          Text(
            Copy.sentLead,
            textAlign: TextAlign.center,
            style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Metrics.gap),
          ReviewLine(label: Copy.amount, value: '${sent.amount.toExact()} ${Copy.currency}'),
          ReviewLine(label: Copy.fee, value: '${sent.fee.toExact()} ${Copy.currency}'),
          ReviewLine(
            label: Copy.transactionId,
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(sent.transactionId, style: KranoxType.mono.copyWith(color: palette.ink)),
                ),
                RoundButton(
                  icon: Icons.copy_rounded,
                  tooltip: Copy.copyId,
                  size: Metrics.smallRound,
                  onPressed: () => copyToClipboard(context, sent.transactionId),
                ),
              ],
            ),
          ),
          const SizedBox(height: Metrics.gap),
          PillButton(label: Copy.done, tone: PillTone.solid, expand: true, onPressed: onDone),
        ],
      ),
    );
  }
}
