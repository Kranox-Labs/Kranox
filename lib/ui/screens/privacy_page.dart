import 'package:flutter/material.dart';

import '../../bridge/controller.dart';
import '../../config/app_config.dart';
import '../../privacy/wallet_privacy.dart';
import '../../wallet/controller.dart';
import '../../wallet/failure.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/page_frame.dart';
import '../widgets/sidebar.dart';
import '../widgets/surfaces.dart';

/// The menu Privacy: what the whole wallet shows, worked out on this Mac from its history, with one card for each
/// check and a way to improve it where the app has one.
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key, required this.controller, required this.bridge, required this.onNavigate});

  final WalletController controller;
  final BridgeController bridge;
  final ValueChanged<WalletPage> onNavigate;

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _makingSubaddress = false;
  String? _subaddressError;

  /// Makes a new subaddress for the receive page and opens it, so that the user can give it to the next payer.
  Future<void> _newSubaddress() async {
    setState(() {
      _makingSubaddress = true;
      _subaddressError = null;
    });
    try {
      await widget.controller.newReceiveAddress();
      if (mounted) widget.onNavigate(WalletPage.receive);
    } on WalletException catch (error) {
      if (mounted) setState(() => _subaddressError = failureText(error));
    } finally {
      if (mounted) setState(() => _makingSubaddress = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.controller, widget.bridge]),
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final palette = context.palette;
    final controller = widget.controller;
    final now = DateTime.now();
    final report = checkWallet(
      node: controller.node,
      transfers: controller.transfers,
      swaps: widget.bridge.swaps,
      balance: controller.status.balance,
      now: now,
    );
    final reused = report.reused;
    final pairs = report.pairs;
    final links = report.links;
    final newCoins = report.newCoins;
    final hours = AppConfig.privacyFreshWindow.inHours;
    return PageFrame(
      title: Copy.privacyPageTitle,
      lead: Copy.privacyPageLead,
      chips: [StatusChip(label: controller.network.label)],
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Metrics.formWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Summary(toImprove: report.toImprove),
                const SizedBox(height: Metrics.gap),
                _CheckCard(
                  title: Copy.privacyNodeTitle,
                  state: report.ownNode ? _CheckState.good : _CheckState.warning,
                  text: report.ownNode ? Copy.privacyNodeOwn(report.node) : Copy.privacyNodePublic(report.node),
                  action: report.ownNode
                      ? null
                      : PillButton(
                          label: Copy.privacyChangeNode,
                          tone: PillTone.quiet,
                          onPressed: () => widget.onNavigate(WalletPage.settings),
                        ),
                ),
                const SizedBox(height: Metrics.gap),
                _CheckCard(
                  title: Copy.privacySubaddressTitle,
                  state: reused.isEmpty ? _CheckState.good : _CheckState.warning,
                  text: switch (reused) {
                    [] => Copy.privacySubaddressClear,
                    [final only] => Copy.privacySubaddressOne(only.index, only.payments),
                    [final most, ...] => Copy.privacySubaddressMany(reused.length, most.index, most.payments),
                  },
                  action: reused.isEmpty
                      ? null
                      : PillButton(
                          label: Copy.privacyNewSubaddress,
                          tone: PillTone.quiet,
                          busy: _makingSubaddress,
                          onPressed: _newSubaddress,
                        ),
                  error: _subaddressError,
                ),
                const SizedBox(height: Metrics.gap),
                _CheckCard(
                  title: Copy.privacySwapsTitle,
                  state: pairs.isEmpty ? _CheckState.good : _CheckState.warning,
                  text: switch (pairs) {
                    [] => Copy.privacySwapsClear,
                    [final newest, ...] => [
                      Copy.privacySwapsPair(
                        '${formatDecimal(newest.receive.amount)} ${newest.receive.asset.label}',
                        '${formatDecimal(newest.pay.amount)} ${newest.pay.asset.label}',
                        formatTime(newest.receive.createdAt, now),
                        formatTime(newest.pay.createdAt, now),
                        switch ((newest.closeInTime, newest.closeInAmount)) {
                          (true, true) => Copy.privacyCloseInBoth,
                          (true, false) => Copy.privacyCloseInTime,
                          _ => Copy.privacyCloseInAmount,
                        },
                      ),
                      if (pairs.length > 1) Copy.privacySwapsMore(pairs.length - 1),
                      Copy.privacySwapsTip,
                    ].join(' '),
                  },
                ),
                const SizedBox(height: Metrics.gap),
                _CheckCard(
                  title: Copy.privacyRefundTitle,
                  state: links.isEmpty ? _CheckState.good : _CheckState.warning,
                  text: switch (links) {
                    [] => Copy.privacyRefundClear,
                    [final newest, ...] => [
                      Copy.privacyRefundLinked(
                        shortText(newest.address),
                        formatTime(newest.paidAt, now),
                        formatTime(newest.receivedAt, now),
                      ),
                      if (links.length > 1) Copy.privacyRefundMore(links.length - 1),
                    ].join(' '),
                  },
                ),
                const SizedBox(height: Metrics.gap),
                _CheckCard(
                  title: Copy.privacyNewCoinsTitle,
                  state: newCoins == null ? _CheckState.good : _CheckState.note,
                  text: newCoins == null
                      ? Copy.privacyNewCoinsClear(hours)
                      : Copy.privacyNewCoins(
                          formatAmount(newCoins.amount),
                          hours,
                          formatMoment(newCoins.allOlderAt, now),
                        ),
                ),
                const SizedBox(height: Metrics.gap),
                _CheckCard(
                  title: Copy.privacyLockTitle,
                  state: _CheckState.good,
                  text: Copy.privacyLock(AppConfig.idleLockAfter.inMinutes),
                ),
                const SizedBox(height: Metrics.gapSmall),
                Text(Copy.privacyPageNote, style: KranoxType.small.copyWith(color: palette.inkFaint)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// What a check found: nothing to improve, something to improve, or a note that time alone settles.
enum _CheckState { good, warning, note }

/// The count of things to improve, at the top of the page.
class _Summary extends StatelessWidget {
  const _Summary({required this.toImprove});

  final int toImprove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final clear = toImprove == 0;
    return Surface(
      child: Row(
        children: [
          Icon(
            clear ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 30,
            color: clear ? palette.accent : palette.danger,
          ),
          const SizedBox(width: Metrics.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clear ? Copy.privacyClear : Copy.privacyToImprove(toImprove),
                  style: KranoxType.cardTitle.copyWith(color: palette.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  clear ? Copy.privacyAllClearLead : Copy.privacyToImproveLead,
                  style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One check of the page: its title with its state, what it found, and a way to improve it.
class _CheckCard extends StatelessWidget {
  const _CheckCard({required this.title, required this.state, required this.text, this.action, this.error});

  final String title;
  final _CheckState state;
  final String text;
  final Widget? action;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            title,
            trailing: Icon(
              switch (state) {
                _CheckState.good => Icons.check_circle_rounded,
                _CheckState.warning => Icons.error_rounded,
                _CheckState.note => Icons.schedule_rounded,
              },
              size: 18,
              color: switch (state) {
                _CheckState.good => palette.accent,
                _CheckState.warning => palette.danger,
                _CheckState.note => palette.inkSoft,
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(text, style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft)),
          if (action case final action?) ...[const SizedBox(height: Metrics.gap), action],
          ErrorLine(error),
        ],
      ),
    );
  }
}
