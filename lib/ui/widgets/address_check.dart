import 'package:flutter/material.dart';

import '../../bridge/chain_scan.dart' show LabelSource;
import '../../privacy/chain_privacy.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import 'bits.dart';
import 'buttons.dart';
import 'privacy_board.dart';

/// The check of an address on Robinhood Chain on a review: the scan of the address, which starts as the review opens,
/// then what its public history shows. Pay checks its recipient from 8 Oct 2026, and a receive its refund address from
/// 10 Oct 2026. It advises; the user can still go on.
class AddressCheck extends StatelessWidget {
  const AddressCheck({
    super.key,
    required this.report,
    required this.error,
    required this.onRetry,
    required this.now,
    required this.freshNote,
    required this.apartNote,
  });

  /// What the scan of the address found; null while it runs.
  final ChainPrivacyReport? report;

  /// Why the scan failed, with [onRetry] to scan again.
  final String? error;
  final VoidCallback? onRetry;

  /// The moment that the days of the lines count from.
  final DateTime now;

  /// Under an address without a public history.
  final String freshNote;

  /// Under an address whose history ties it to the user.
  final String apartNote;

  @override
  Widget build(BuildContext context) => switch ((report, error)) {
    (final found?, _) => _found(context, found),
    (null, final failure?) => _failed(context, failure),
    (null, null) => _checking(context),
  };

  Widget _checking(BuildContext context) {
    final color = context.palette.inkSoft;
    return Row(
      children: [
        SizedBox.square(
          dimension: _Line._mark,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
        const SizedBox(width: Metrics.gapTiny),
        Expanded(
          child: Text(Copy.addressChecking, style: KranoxType.small.copyWith(color: color)),
        ),
      ],
    );
  }

  Widget _failed(BuildContext context, String failure) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ErrorLine(failure),
      const SizedBox(height: Metrics.gapTiny),
      SmallPillButton(label: Copy.addressCheckAgain, onPressed: onRetry),
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
/// An address without a transaction, a token transfer, or a first funding, as the relay read for sure, has no public
/// history: ETH that a contract sent counts in none of the counts.
bool _isFresh(ChainPrivacyReport report) =>
    report.exposure.transactions == 0 &&
    report.exposure.tokenTransfers == 0 &&
    report.funding == null &&
    report.scan.fundingSure;

/// What the history of the address shows, one line each: no history, or its first funding or that it is not sure, its
/// direct transfers with other addresses of the user, look-alike senders, and how much it did. A look-alike sender is
/// a trap for whoever copies an address from a history, not a link to the user, so it warns without a count in the
/// privacy check; the owner asked for it on 10 Oct 2026.
List<(CheckState, String)> _lines(ChainPrivacyReport report, DateTime now) {
  if (_isFresh(report)) return const [(CheckState.good, Copy.payRecipientFresh)];
  final own = report.own;
  final since = report.exposure.firstSeen;
  return [
    if (report.funding case final funding?)
      _fundingLine(funding, now)
    else if (!report.scan.fundingSure)
      (CheckState.note, Copy.payRecipientFundingUnsure),
    if (own.isNotEmpty)
      (
        CheckState.warning,
        own.length == 1 ? Copy.payRecipientOwn(shortText(own.first.other)) : Copy.payRecipientOwnMany(own.length),
      ),
    if (report.lookAlikes.isNotEmpty) (CheckState.warning, Copy.payRecipientLookAlike(report.lookAlikes.length)),
    (
      CheckState.note,
      Copy.payRecipientHistory(report.exposure.transactions, since == null ? null : formatTime(since, now)),
    ),
  ];
}

/// The first funding of the address: from another address of the user or from a sender with a public name ties it to
/// them; from a sender without a name, or from a payment of the user from XMR, it does not, once the relay is sure that
/// no older transfer came in.
(CheckState, String) _fundingLine(FirstFunding funding, DateTime now) {
  final day = formatTime(funding.transfer.time, now);
  return switch (funding) {
    FirstFunding(links: true, fromOwn: true, :final transfer) => (
      CheckState.warning,
      Copy.payRecipientFundedOwn(shortText(transfer.from.address), day),
    ),
    FirstFunding(links: true, :final label?, :final labelSource) => (
      CheckState.warning,
      switch (labelSource) {
        LabelSource.tag => Copy.payRecipientFundedNamed(label, day),
        LabelSource.contract => Copy.payRecipientFundedContract(label, day),
        LabelSource.domain => Copy.payRecipientFundedDomain(label, day),
      },
    ),
    FirstFunding(sure: false) => (CheckState.note, Copy.payRecipientFundedUnsure(day)),
    FirstFunding(fromPay: _?) => (CheckState.good, Copy.payRecipientFundedByPay(day)),
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
