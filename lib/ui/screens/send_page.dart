import 'package:flutter/material.dart';

import '../../core/address.dart';
import '../../core/amount.dart';
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
import '../widgets/surfaces.dart';

/// The send page in three steps: the form, the review with the fee, and the receipt.
class SendPage extends StatefulWidget {
  const SendPage({super.key, required this.controller});

  final WalletController controller;

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final _address = TextEditingController();
  final _amount = TextEditingController();
  String? _addressError;
  String? _amountError;
  String? _error;
  bool _busy = false;
  PreparedSend? _prepared;
  SentPayment? _sent;

  @override
  void dispose() {
    _address.dispose();
    _amount.dispose();
    super.dispose();
  }

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
      setState(() => _prepared = prepared);
    });
  }

  Future<void> _confirm() => _run(() async {
    final sent = await widget.controller.confirmSend();
    setState(() {
      _sent = sent;
      _prepared = null;
    });
  });

  Future<void> _cancel() => _run(() async {
    await widget.controller.cancelSend();
    setState(() => _prepared = null);
  });

  void _restart() {
    _address.clear();
    _amount.clear();
    setState(() => _sent = null);
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = switch ((_prepared, _sent)) {
      (_, final SentPayment sent) => _Receipt(sent: sent, onDone: _restart),
      (final PreparedSend prepared, _) => _Review(
        prepared: prepared,
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
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Metrics.formWidth),
            child: step,
          ),
        ),
      ],
    );
  }

  Widget _form(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledField(
          label: Copy.recipient,
          controller: _address,
          hint: Copy.recipientHint(widget.controller.network),
          error: _addressError,
          lines: 2,
        ),
        const SizedBox(height: Metrics.gap),
        LabeledField(
          label: Copy.amount,
          controller: _amount,
          hint: '0.0',
          suffix: Copy.currency,
          error: _amountError,
          note: Copy.available(widget.controller.status.unlocked.toExact()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => _review(),
        ),
        ErrorLine(_error),
        const SizedBox(height: Metrics.gap),
        PillButton(label: Copy.review, busy: _busy, busyLabel: Copy.preparing, onPressed: _review),
      ],
    ),
  );
}

class _Review extends StatelessWidget {
  const _Review({
    required this.prepared,
    required this.busy,
    required this.error,
    required this.onConfirm,
    required this.onCancel,
  });

  final PreparedSend prepared;
  final bool busy;
  final String? error;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle(Copy.reviewTitle),
          const SizedBox(height: 4),
          Text(Copy.reviewLead, style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft)),
          const SizedBox(height: Metrics.gap),
          _Line(
            label: Copy.to,
            child: SelectableText(prepared.address, style: KranoxType.mono.copyWith(color: palette.ink)),
          ),
          _Line(label: Copy.amount, value: '${prepared.amount.toExact()} ${Copy.currency}'),
          _Line(label: Copy.fee, value: '${prepared.fee.toExact()} ${Copy.currency}'),
          _Line(label: Copy.total, value: '${prepared.total.toExact()} ${Copy.currency}', strong: true),
          ErrorLine(error),
          const SizedBox(height: Metrics.gap),
          Row(
            children: [
              PillButton(label: Copy.sendNow, busy: busy, busyLabel: Copy.sending, onPressed: onConfirm),
              const SizedBox(width: Metrics.gapSmall),
              PillButton(label: Copy.cancel, tone: PillTone.quiet, onPressed: busy ? null : onCancel),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, this.value, this.child, this.strong = false});

  final String label;
  final String? value;
  final Widget? child;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: KranoxType.small.copyWith(color: palette.inkSoft)),
          ),
          Expanded(
            child:
                child ??
                Text(
                  value ?? '',
                  style: (strong ? KranoxType.cardTitle : KranoxType.body).copyWith(color: palette.ink),
                ),
          ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
            child: SizedBox.square(
              dimension: Metrics.roundButton,
              child: Icon(Icons.check_rounded, color: palette.onAccent),
            ),
          ),
          const SizedBox(height: Metrics.gap),
          Text(Copy.sentTitle, style: KranoxType.pageTitle.copyWith(color: palette.ink)),
          const SizedBox(height: 4),
          Text(Copy.sentLead, style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft)),
          const SizedBox(height: Metrics.gap),
          _Line(label: Copy.amount, value: '${sent.amount.toExact()} ${Copy.currency}'),
          _Line(label: Copy.fee, value: '${sent.fee.toExact()} ${Copy.currency}'),
          _Line(
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
          PillButton(label: Copy.done, tone: PillTone.solid, onPressed: onDone),
        ],
      ),
    );
  }
}
