import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/amount.dart';
import '../../privacy/chain_privacy.dart';
import '../../privacy/privacy_check.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';

/// What one line of a privacy check says: its rule passed, its rule warns, a tip that asks for nothing now, or its rule
/// could not read what it needs yet, which keeps the check from "All clear".
enum RuleState { passed, warning, tip, unchecked }

/// One line of a privacy check: the name of its rule, what it found, and a way to act on it.
final class PrivacyRule {
  const PrivacyRule({required this.label, required this.state, required this.text, this.action});

  final String label;
  final RuleState state;
  final String text;
  final Widget? action;
}

/// A privacy check before the user acts, such as on the review of a payment or of a receive: one line for each rule,
/// the count of its warnings at the head, and [note] at the foot. It advises; the user can still go on.
class PrivacyRulesCard extends StatelessWidget {
  const PrivacyRulesCard({super.key, required this.rules, required this.note});

  final List<PrivacyRule> rules;
  final String note;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final warnings = rules.where((rule) => rule.state == RuleState.warning).length;
    final unchecked = rules.where((rule) => rule.state == RuleState.unchecked).length;
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
                  switch ((warnings, unchecked)) {
                    (0, 0) => Copy.privacyClear,
                    (0, _) => Copy.privacyNotChecked(unchecked),
                    _ => Copy.privacyWarnings(warnings),
                  },
                  style: KranoxType.smallStrong.copyWith(
                    color: switch ((warnings, unchecked)) {
                      (0, 0) => palette.accent,
                      (0, _) => palette.inkSoft,
                      _ => palette.danger,
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: Metrics.gapSmall),
            for (final rule in rules) _RuleLine(rule),
            const SizedBox(height: Metrics.gapTiny),
            Text(note, style: KranoxType.small.copyWith(color: palette.inkFaint)),
          ],
        ),
      ),
    );
  }
}

/// The privacy check on the review of a payment: the rules of the amount, the timing, and, for pay, the address, with
/// the suggested amount of the rule of the amount as a button.
class PrivacyCheckCard extends StatelessWidget {
  const PrivacyCheckCard({super.key, required this.report, required this.now, this.onUseSuggestion});

  final PrivacyReport report;

  /// The moment that the times of the lines count from.
  final DateTime now;

  /// Builds the payment again with a suggested amount. Without it, the card shows no button.
  final ValueChanged<XmrAmount>? onUseSuggestion;

  @override
  Widget build(BuildContext context) {
    final match = report.amountMatch;
    final fresh = report.fresh;
    final own = report.ownAddress;
    final suggestion = report.suggestion;
    final use = onUseSuggestion;
    return PrivacyRulesCard(
      note: Copy.privacyNote,
      rules: [
        PrivacyRule(
          label: Copy.privacyAmountLabel,
          state: match == null ? RuleState.passed : RuleState.warning,
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
        PrivacyRule(
          label: Copy.privacyTimingLabel,
          state: fresh == null ? RuleState.passed : RuleState.warning,
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
          PrivacyRule(
            label: Copy.privacyAddressLabel,
            state: switch (own) {
              null when !report.addressChecked => RuleState.unchecked,
              null => RuleState.passed,
              _ => RuleState.warning,
            },
            text: switch (own) {
              null when !report.addressChecked => Copy.privacyAddressUnchecked,
              null => Copy.privacyAddressClear,
              OwnAddress(link: RefundOf(), :final usedAt) => Copy.privacyAddressRefund(formatTime(usedAt, now)),
              OwnAddress(link: FundedReceive(), :final usedAt) => Copy.privacyAddressFunded(formatTime(usedAt, now)),
              OwnAddress(link: GotPay(), :final usedAt) => Copy.privacyAddressPaid(formatTime(usedAt, now)),
            },
          ),
      ],
    );
  }
}

/// One rule of a check: a mark of its state, the name of the rule, what the rule found, and its action.
class _RuleLine extends StatelessWidget {
  const _RuleLine(this.rule);

  final PrivacyRule rule;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (icon, color) = switch (rule.state) {
      RuleState.passed => (Icons.check_circle_rounded, palette.accent),
      RuleState.warning => (Icons.error_rounded, palette.danger),
      RuleState.tip => (Icons.info_outline_rounded, palette.inkSoft),
      RuleState.unchecked => (Icons.help_outline_rounded, palette.inkSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Metrics.gapSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: Metrics.gapSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.label, style: KranoxType.smallStrong.copyWith(color: palette.ink)),
                const SizedBox(height: 2),
                Text(rule.text, style: KranoxType.small.copyWith(color: palette.inkSoft)),
                if (rule.action case final action?) ...[const SizedBox(height: Metrics.gapTiny), action],
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
