import 'package:flutter/material.dart';

import '../../privacy/chain_privacy.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import 'bits.dart';
import 'buttons.dart';
import 'privacy_board.dart';

/// The check of an address on Robinhood Chain on a review: a button that scans it, then what its public history shows.
/// Pay checks its recipient from 8 Oct 2026, and a receive its refund address from 10 Oct 2026. It advises; the user
/// can still go on.
class AddressCheck extends StatelessWidget {
  const AddressCheck({
    super.key,
    required this.report,
    required this.checking,
    required this.error,
    required this.onCheck,
    required this.now,
    required this.lead,
    required this.freshNote,
    required this.apartNote,
  });

  /// What the scan of the recipient found; null before the check.
  final ChainPrivacyReport? report;
  final bool checking;
  final String? error;
  final VoidCallback? onCheck;

  /// The moment that the days of the lines count from.
  final DateTime now;

  /// Beside the button: why the user may want the check.
  final String lead;

  /// Under an address without a public history.
  final String freshNote;

  /// Under an address whose history ties it to the user.
  final String apartNote;

  @override
  Widget build(BuildContext context) => switch (report) {
    null => _offer(context),
    final found => _found(context, found),
  };

  Widget _offer(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          SmallPillButton(
            label: Copy.payCheckRecipient,
            busy: checking,
            busyLabel: Copy.payCheckingRecipient,
            onPressed: onCheck,
          ),
          const SizedBox(width: Metrics.gapSmall),
          Expanded(
            child: Text(lead, style: KranoxType.small.copyWith(color: context.palette.inkSoft)),
          ),
        ],
      ),
      ErrorLine(error),
    ],
  );

  Widget _found(BuildContext context, ChainPrivacyReport found) {
    final lines = _lines(found, now);
    final fresh = _isFresh(found);
    final warns = lines.any((line) => line.$1 == CheckState.warning);
    final note = fresh ? freshNote : (warns ? apartNote : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (state, text) in lines) _Line(state: state, text: text),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(left: _Line.indent),
            child: Text(note, style: KranoxType.small.copyWith(color: context.palette.inkSoft)),
          ),
      ],
    );
  }
}

/// An address without a transaction and without a token transfer has no public history.
bool _isFresh(ChainPrivacyReport report) => report.exposure.transactions == 0 && report.exposure.tokenTransfers == 0;

/// What the history of the address shows, one line each: no history, or its first funding, its direct transfers with
/// other addresses of the user, and how much it did.
List<(CheckState, String)> _lines(ChainPrivacyReport report, DateTime now) {
  if (_isFresh(report)) return const [(CheckState.good, Copy.payRecipientFresh)];
  final own = report.own;
  final since = report.exposure.firstSeen;
  return [
    if (report.funding case final funding?) _fundingLine(funding, now),
    if (own.isNotEmpty)
      (
        CheckState.warning,
        own.length == 1 ? Copy.payRecipientOwn(shortText(own.first.other)) : Copy.payRecipientOwnMany(own.length),
      ),
    (
      CheckState.note,
      Copy.payRecipientHistory(report.exposure.transactions, since == null ? null : formatTime(since, now)),
    ),
  ];
}

/// The first funding of the address: from another address of the user or from a sender with a public name ties it to
/// them; from a sender without a name, it does not.
(CheckState, String) _fundingLine(FirstFunding funding, DateTime now) {
  final day = formatTime(funding.transfer.time, now);
  return switch (funding) {
    FirstFunding(fromOwn: true, :final transfer) => (
      CheckState.warning,
      Copy.payRecipientFundedOwn(shortText(transfer.from.address), day),
    ),
    FirstFunding(:final label?) => (CheckState.warning, Copy.payRecipientFundedNamed(label, day)),
    FirstFunding() => (CheckState.good, Copy.payRecipientFundedPlain(day)),
  };
}

/// One line of the check: a mark in the color of its state and what it found.
class _Line extends StatelessWidget {
  const _Line({required this.state, required this.text});

  final CheckState state;
  final String text;

  /// The room from the left edge to the text: the mark and the gap after it.
  static const double indent = _mark + Metrics.gapTiny;
  static const double _mark = 16;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (icon, color) = switch (state) {
      CheckState.good => (Icons.check_circle_rounded, palette.accent),
      CheckState.warning => (Icons.error_rounded, palette.danger),
      CheckState.note || CheckState.pending => (Icons.history_rounded, palette.inkSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Metrics.gapTiny),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: _mark, color: color),
          ),
          const SizedBox(width: Metrics.gapTiny),
          Expanded(
            child: Text(text, style: KranoxType.smallStrong.copyWith(color: palette.ink)),
          ),
        ],
      ),
    );
  }
}
