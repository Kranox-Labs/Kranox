import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/amount.dart';
import '../../privacy/privacy_check.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';

/// The privacy check on the review of a payment: one line for each rule, with a check mark or a warning, and the
/// suggested amount of the rule of the amount as a button. It advises; the payment can still leave.
class PrivacyCheckCard extends StatelessWidget {
  const PrivacyCheckCard({super.key, required this.report, required this.now, this.onUseSuggestion});

  final PrivacyReport report;

  /// The moment that the times of the lines count from.
  final DateTime now;

  /// Builds the payment again with a suggested amount. Without it, the card shows no button.
  final ValueChanged<XmrAmount>? onUseSuggestion;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final warnings = report.warnings;
    final match = report.amountMatch;
    final fresh = report.fresh;
    final own = report.ownAddress;
    final suggestion = report.suggestion;
    final use = onUseSuggestion;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.field,
        borderRadius: BorderRadius.circular(Metrics.radiusField),
        border: Border.all(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Copy.privacyTitle.toUpperCase(),
                    style: KranoxType.label.copyWith(color: palette.inkSoft),
                  ),
                ),
                Text(
                  warnings == 0 ? Copy.privacyClear : Copy.privacyWarnings(warnings),
                  style: KranoxType.smallStrong.copyWith(color: warnings == 0 ? palette.accent : palette.danger),
                ),
              ],
            ),
            const SizedBox(height: Metrics.gapSmall),
            _RuleLine(
              label: Copy.privacyAmountLabel,
              passed: match == null,
              text: switch (match) {
                null => Copy.privacyAmountClear,
                XmrMatch(:final amount, :final at) => Copy.privacyAmountMatchesXmr(
                  formatAmount(amount),
                  formatAgo(now.difference(at)),
                ),
                ChainMatch(:final asset, :final sent, :final paid, :final at) => Copy.privacyAmountMatchesChain(
                  formatDecimal(paid),
                  formatDecimal(sent),
                  asset.label,
                  formatAgo(now.difference(at)),
                ),
              },
              action: match != null && suggestion != null && use != null
                  ? _SuggestionButton(amount: suggestion, onPressed: () => use(suggestion))
                  : null,
            ),
            _RuleLine(
              label: Copy.privacyTimingLabel,
              passed: fresh == null,
              text: switch (fresh) {
                null => Copy.privacyTimingClear(AppConfig.privacyFreshWindow.inHours),
                FreshCoins(:final since, :final clearsAt, fromChain: true) => Copy.privacyTimingFromChain(
                  formatAgo(now.difference(since)),
                  formatMoment(clearsAt, now),
                ),
                FreshCoins(:final since, :final clearsAt) => Copy.privacyTimingFresh(
                  formatAgo(now.difference(since)),
                  formatMoment(clearsAt, now),
                ),
              },
            ),
            if (report.checksAddress)
              _RuleLine(
                label: Copy.privacyAddressLabel,
                passed: own == null,
                text: own == null ? Copy.privacyAddressClear : Copy.privacyAddressOwn(formatTime(own.usedAt, now)),
              ),
            const SizedBox(height: Metrics.gapTiny),
            Text(Copy.privacyNote, style: KranoxType.small.copyWith(color: palette.inkFaint)),
          ],
        ),
      ),
    );
  }
}

/// One rule of the check: a check mark or a warning, the name of the rule, and what the rule found.
class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.label, required this.passed, required this.text, this.action});

  final String label;
  final bool passed;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: Metrics.gapSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              passed ? Icons.check_circle_rounded : Icons.error_rounded,
              size: 16,
              color: passed ? palette.accent : palette.danger,
            ),
          ),
          const SizedBox(width: Metrics.gapSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KranoxType.smallStrong.copyWith(color: palette.ink)),
                const SizedBox(height: 2),
                Text(text, style: KranoxType.small.copyWith(color: palette.inkSoft)),
                if (action case final action?) ...[const SizedBox(height: Metrics.gapTiny), action],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The button that builds the payment again with the suggested amount.
class _SuggestionButton extends StatelessWidget {
  const _SuggestionButton({required this.amount, required this.onPressed});

  final XmrAmount amount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: palette.ink,
        backgroundColor: palette.surface,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: KranoxType.smallStrong,
      ),
      child: Text(Copy.privacyUse(amount.toExact())),
    );
  }
}
