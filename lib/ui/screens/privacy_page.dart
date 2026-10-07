import 'package:flutter/material.dart';

import '../../bridge/controller.dart';
import '../../bridge/models.dart';
import '../../config/app_config.dart';
import '../../core/evm_address.dart';
import '../../privacy/chain_privacy.dart';
import '../../privacy/chain_scans.dart';
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
import '../widgets/field.dart';
import '../widgets/page_frame.dart';
import '../widgets/sidebar.dart';
import '../widgets/surfaces.dart';

/// The menu Privacy: what the whole wallet shows, worked out on this Mac from its history, with one card for each
/// check and a way to improve it where the app has one; and on mainnet, with [scans], the scan of an address of the
/// user on Robinhood Chain.
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key, required this.controller, required this.bridge, required this.onNavigate, this.scans});

  final WalletController controller;
  final BridgeController bridge;
  final ValueChanged<WalletPage> onNavigate;
  final ChainScans? scans;

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _makingSubaddress = false;
  String? _subaddressError;
  final _chainAddress = TextEditingController();
  String? _chainAddressError;

  @override
  void dispose() {
    _chainAddress.dispose();
    super.dispose();
  }

  /// Scans the address in the field once it passes the check of an address on Robinhood Chain.
  Future<void> _scan(ChainScans scans) async {
    final address = _chainAddress.text.trim();
    try {
      checkEvmAddress(address);
    } on EvmAddressException catch (error) {
      setState(() => _chainAddressError = evmAddressProblemText(error.problem));
      return;
    }
    setState(() => _chainAddressError = null);
    await scans.scan(address);
  }

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
    listenable: Listenable.merge([widget.controller, widget.bridge, ?widget.scans]),
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
                if (widget.scans case final scans? when widget.bridge.available) ..._chainPart(context, scans, now),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The scan of an address on Robinhood Chain: the form, and the cards of the newest scan.
  List<Widget> _chainPart(BuildContext context, ChainScans scans, DateTime now) {
    final palette = context.palette;
    final scan = scans.current;
    final error = scans.error;
    return [
      const SizedBox(height: Metrics.gap * 2),
      Text(Copy.privacyChainHeading, style: KranoxType.pageTitle.copyWith(color: palette.ink)),
      const SizedBox(height: Metrics.gap),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CardTitle(Copy.privacyChainTitle),
            const SizedBox(height: 4),
            Text(Copy.privacyChainLead, style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft)),
            const SizedBox(height: Metrics.gap),
            LabeledField(
              label: Copy.privacyChainField,
              controller: _chainAddress,
              hint: Copy.payRecipientHint,
              error: _chainAddressError,
              mono: true,
              onSubmitted: (_) => scans.scanning ? null : _scan(scans),
            ),
            const SizedBox(height: Metrics.gap),
            Align(
              alignment: Alignment.centerLeft,
              child: PillButton(
                label: Copy.privacyChainScan,
                busy: scans.scanning,
                busyLabel: Copy.privacyChainScanning,
                onPressed: () => _scan(scans),
              ),
            ),
            if (error != null) ErrorLine(bridgeFailureText(error)),
          ],
        ),
      ),
      if (scan != null)
        ..._chainCards(context, analyzeChain(scan, swaps: widget.bridge.swaps, ownAddresses: scans.scanned), now),
    ];
  }

  List<Widget> _chainCards(BuildContext context, ChainPrivacyReport report, DateTime now) {
    final palette = context.palette;
    final funding = report.funding;
    final own = report.own;
    final lookAlikes = report.lookAlikes;
    final kranox = report.kranox;
    final exposure = report.exposure;
    final improve = report.toImprove;
    String swapAmount(BridgeSwap swap) => '${formatDecimal(swap.amount)} ${swap.asset.label}';
    String linkText(KranoxLink link) => switch (link) {
      FundedReceive(:final swap) => Copy.privacyKranoxFunded(swapAmount(swap), formatTime(swap.createdAt, now)),
      GotPay(:final swap) => Copy.privacyKranoxPaid(swapAmount(swap), formatTime(swap.createdAt, now)),
      RefundOf(:final swap) => Copy.privacyKranoxRefund(formatTime(swap.createdAt, now)),
    };
    String hour(int value) => '${value.toString().padLeft(2, '0')}:00';
    return [
      const SizedBox(height: Metrics.gap),
      Surface(
        child: Row(
          children: [
            Icon(
              improve == 0 ? Icons.check_circle_rounded : Icons.error_rounded,
              size: 30,
              color: improve == 0 ? palette.accent : palette.danger,
            ),
            const SizedBox(width: Metrics.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Copy.privacyChainResult(shortText(report.scan.address)),
                    style: KranoxType.cardTitle.copyWith(color: palette.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    improve == 0 ? Copy.privacyClear : '${Copy.privacyToImprove(improve)}. ${Copy.privacyCleanStart}',
                    style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Metrics.gap),
      _CheckCard(
        title: Copy.privacyFundingTitle,
        state: switch (funding) {
          null => _CheckState.note,
          FirstFunding(links: true) => _CheckState.warning,
          FirstFunding() => _CheckState.good,
        },
        text: switch (funding) {
          null => Copy.privacyFundingNone,
          FirstFunding(fromOwn: true, :final transfer) => Copy.privacyFundingOwn(
            shortText(transfer.from.address),
            formatTime(transfer.time, now),
          ),
          FirstFunding(:final label?, :final transfer) => Copy.privacyFundingNamed(
            label,
            formatTime(transfer.time, now),
          ),
          FirstFunding(:final transfer) => Copy.privacyFundingPlain(
            shortText(transfer.from.address),
            formatTime(transfer.time, now),
          ),
        },
      ),
      const SizedBox(height: Metrics.gap),
      _CheckCard(
        title: Copy.privacyOwnTitle,
        state: own.isEmpty ? _CheckState.good : _CheckState.warning,
        text: switch (own) {
          [] => Copy.privacyOwnClear,
          [final newest, ...] => [
            Copy.privacyOwnLinked(shortText(newest.other), formatTime(newest.at, now)),
            if (own.length > 1) Copy.privacyMoreAddresses(own.length - 1),
          ].join(' '),
        },
      ),
      const SizedBox(height: Metrics.gap),
      _CheckCard(
        title: Copy.privacyLookAlikeTitle,
        state: lookAlikes.isEmpty ? _CheckState.good : _CheckState.warning,
        text: switch (lookAlikes) {
          [] => Copy.privacyLookAlikeClear,
          [final newest, ...] => [
            Copy.privacyLookAlike(newest.sender, newest.resembles, formatTime(newest.at, now)),
            if (lookAlikes.length > 1) Copy.privacyMoreAddresses(lookAlikes.length - 1),
          ].join(' '),
        },
      ),
      const SizedBox(height: Metrics.gap),
      _CheckCard(
        title: Copy.privacyKranoxTitle,
        state: kranox.isEmpty ? _CheckState.good : _CheckState.note,
        text: switch (kranox) {
          [] => Copy.privacyKranoxClear,
          [final newest, ...] => [
            linkText(newest),
            if (kranox.length > 1) Copy.privacyMoreSwaps(kranox.length - 1),
            Copy.privacyKranoxNote,
          ].join(' '),
        },
      ),
      const SizedBox(height: Metrics.gap),
      _CheckCard(
        title: Copy.privacyExposureTitle,
        state: _CheckState.note,
        text: exposure.transactions == 0 && exposure.tokenTransfers == 0
            ? Copy.privacyExposureEmpty
            : [
                Copy.privacyExposure(exposure.transactions, exposure.tokenTransfers),
                if (exposure.firstSeen case final first?) Copy.privacyExposureSince(formatTime(first, now)),
                if (exposure.tokens.isNotEmpty) Copy.privacyExposureTokens(exposure.tokens.join(', ')),
                if (exposure.activeHours case (final from, final to)) Copy.privacyExposureHours(hour(from), hour(to)),
              ].join(' '),
      ),
    ];
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
