import 'dart:async';

import 'package:flutter/material.dart';

import '../../bridge/chain_scan.dart' show LabelSource;
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
import '../widgets/choice_pill.dart';
import '../widgets/field.dart';
import '../widgets/page_frame.dart';
import '../widgets/privacy_board.dart';
import '../widgets/sidebar.dart';
import '../widgets/surfaces.dart';

/// The two boards of the menu Privacy: the wallet, and the scan of an address on Robinhood Chain.
enum _PrivacyTab { monero, robinhood }

/// The menu Privacy, a board in the middle of the page, which the owner chose on 8 Oct 2026: what the whole wallet
/// shows, worked out on this Mac from its history, with a ring of the checks at the head and a row for each check, the
/// things to improve first, with a way to improve it where the app has one; and on mainnet, with [scans], a second tab
/// for the scan of an address of the user on Robinhood Chain.
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({
    super.key,
    required this.controller,
    required this.bridge,
    required this.onNavigate,
    required this.onPayNewAddress,
    this.scans,
  });

  final WalletController controller;
  final BridgeController bridge;
  final ValueChanged<WalletPage> onNavigate;

  /// Opens pay on the send page, for a clean start on a new address of the user.
  final VoidCallback onPayNewAddress;
  final ChainScans? scans;

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  _PrivacyTab _tab = _PrivacyTab.monero;
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

  /// Opens the tab of Robinhood Chain on the scan of [address], an address of the user that a note of the wallet names.
  /// The scan works on mainnet only, where the relay of the bridge answers.
  void _scanFromNote(String address) {
    final scans = widget.bridge.available ? widget.scans : null;
    if (scans == null) return;
    setState(() {
      _tab = _PrivacyTab.robinhood;
      _chainAddress.text = address;
      _chainAddressError = null;
    });
    unawaited(scans.scan(address));
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
    // The scan reads Robinhood Chain through the relay of the bridge, which works on mainnet only.
    final scans = widget.bridge.available ? widget.scans : null;
    final tab = scans == null ? _PrivacyTab.monero : _tab;
    return PageFrame(
      title: Copy.privacyPageTitle,
      lead: Copy.privacyPageLead,
      chips: [StatusChip(label: widget.controller.network.label)],
      centered: true,
      width: Metrics.boardWidth,
      children: [
        if (scans != null) ...[_tabs(tab), const SizedBox(height: Metrics.gap)],
        ...(tab == _PrivacyTab.robinhood && scans != null ? _chainBoard(scans) : _walletBoard()),
      ],
    );
  }

  Widget _tabs(_PrivacyTab tab) => Wrap(
    alignment: WrapAlignment.center,
    spacing: Metrics.gapTiny,
    runSpacing: Metrics.gapTiny,
    children: [
      for (final (option, label) in const [
        (_PrivacyTab.monero, Copy.privacyMoneroTab),
        (_PrivacyTab.robinhood, Copy.privacyChainTab),
      ])
        ChoicePill(
          label: label,
          active: tab == option,
          onTap: tab == option ? null : () => setState(() => _tab = option),
        ),
    ],
  );

  /// The board of the wallet: the ring, the six checks, and where the page gets its answers.
  List<Widget> _walletBoard() {
    final controller = widget.controller;
    final now = DateTime.now();
    final report = checkWallet(
      node: controller.node,
      proxy: controller.proxy,
      transfers: controller.transfers,
      receiveIndex: controller.receiveAddress?.index,
      swaps: widget.bridge.swaps,
      balance: controller.status.balance,
      now: now,
    );
    final checks = warningsFirst([
      _nodeCheck(report),
      _subaddressCheck(report),
      _swapsCheck(report.pairs, now),
      _refundCheck(report.links, now, onScan: _scanFromNote),
      _newCoinsCheck(report.newCoins, now),
      _lockCheck(),
    ]);
    final toImprove = report.toImprove;
    final notes = checks.where((check) => check.state == CheckState.note).length;
    return [
      PrivacySummary(
        checks: checks,
        headline: switch ((toImprove, notes)) {
          (0, 0) => Copy.privacyClear,
          (0, _) => Copy.privacyNothingLeft,
          _ => Copy.privacyToImprove(toImprove),
        },
        lead: switch ((toImprove, notes)) {
          (0, 0) => Copy.privacyAllClearLead,
          (0, _) => Copy.privacyNotesLead(notes),
          _ => Copy.privacyToImproveLead,
        },
      ),
      const SizedBox(height: Metrics.gap),
      CheckList(checks: checks),
      const SizedBox(height: Metrics.gap),
      Text(
        Copy.privacyPageNote,
        textAlign: TextAlign.center,
        style: KranoxType.small.copyWith(color: context.palette.inkFaint),
      ),
    ];
  }

  PrivacyCheck _nodeCheck(WalletPrivacyReport report) => switch (report) {
    WalletPrivacyReport(ownNode: true) => PrivacyCheck(
      title: Copy.privacyNodeTitle,
      state: CheckState.good,
      line: Copy.privacyNodeOwnLine,
      detail: Copy.privacyNodeOwn(report.node),
    ),
    WalletPrivacyReport(:final proxy?) => PrivacyCheck(
      title: Copy.privacyNodeTitle,
      state: CheckState.good,
      line: Copy.privacyNodeProxyLine,
      detail: Copy.privacyNodeProxy(report.node, proxy),
    ),
    _ => PrivacyCheck(
      title: Copy.privacyNodeTitle,
      state: CheckState.warning,
      line: Copy.privacyNodePublicLine,
      detail: Copy.privacyNodePublic(report.node),
      action: SmallPillButton(label: Copy.privacyChangeNode, onPressed: () => widget.onNavigate(WalletPage.settings)),
    ),
  };

  /// A reused subaddress that the receive page still gives out is something to improve, with a new subaddress as the
  /// way; once the page gives out another one, the reuse is a note on the history.
  PrivacyCheck _subaddressCheck(WalletPrivacyReport report) {
    final reused = report.reused;
    final inUse = report.reuseInUse;
    return PrivacyCheck(
      title: Copy.privacySubaddressTitle,
      state: switch (reused) {
        [] => CheckState.good,
        _ when inUse => CheckState.warning,
        _ => CheckState.note,
      },
      line: switch (reused) {
        [] => Copy.privacySubaddressClearLine,
        [final only] when inUse => Copy.privacySubaddressLine(only.index, only.payments),
        [final only] => Copy.privacySubaddressPastLine(only.index, only.payments),
        _ when inUse => Copy.privacySubaddressManyLine(reused.length),
        _ => Copy.privacySubaddressPastManyLine(reused.length),
      },
      detail: switch (reused) {
        [] => Copy.privacySubaddressClear,
        [final only] when inUse => Copy.privacySubaddressOne(only.index, only.payments),
        [final only] => Copy.privacySubaddressPast(only.index, only.payments),
        [final most, ...] when inUse => Copy.privacySubaddressMany(reused.length, most.index, most.payments),
        [final most, ...] => Copy.privacySubaddressPastMany(reused.length, most.index, most.payments),
      },
      action: inUse
          ? SmallPillButton(label: Copy.privacyNewSubaddress, busy: _makingSubaddress, onPressed: _newSubaddress)
          : null,
      error: _subaddressError,
      tag: reused.isNotEmpty && !inUse ? Copy.privacyFromHistory : null,
    );
  }

  /// The board of an address on Robinhood Chain: the form at the top, then what each check reads before the first
  /// scan, or the ring and the checks of the newest scan.
  List<Widget> _chainBoard(ChainScans scans) {
    final scan = scans.current;
    if (scan == null) {
      return [_scanForm(scans), const SizedBox(height: Metrics.gap), const CheckList(checks: _pendingChainChecks)];
    }
    final report = analyzeChain(scan, swaps: widget.bridge.swaps, ownAddresses: scans.scanned);
    final checks = warningsFirst(_chainChecks(report, DateTime.now()));
    // From 10 Oct 2026 an address that ties swaps of the user together counts as something to improve, so that "All
    // clear" means no trace that Kranox can find; the owner asked for privacy kept at its most.
    final toImprove = report.toImprove;
    return [
      _scanForm(scans),
      const SizedBox(height: Metrics.gap),
      PrivacySummary(
        checks: checks,
        subject: Copy.privacyChainResult(shortText(scan.address)),
        // A first funding that the relay could not read for sure leaves nothing to call clear.
        headline: switch ((toImprove, scan.fundingSure)) {
          (0, true) => Copy.privacyClear,
          (0, false) => Copy.privacyNothingFound,
          _ => Copy.privacyToImprove(toImprove),
        },
        lead: switch ((toImprove, scan.fundingSure)) {
          (0, true) => Copy.privacyChainClearLead,
          (0, false) => Copy.privacyChainUnsureLead,
          _ => Copy.privacyCleanStart,
        },
        action: toImprove == 0
            ? null
            : SmallPillButton(
                label: Copy.privacyPayNewAddress,
                tone: PillTone.accent,
                onPressed: widget.onPayNewAddress,
              ),
      ),
      const SizedBox(height: Metrics.gap),
      CheckList(checks: checks),
    ];
  }

  /// The field of the address with its button inside, which stays at the top of the board for the next address.
  Widget _scanForm(ChainScans scans) {
    final error = scans.error;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle(Copy.privacyChainTitle),
          const SizedBox(height: 4),
          Text(Copy.privacyChainLead, style: KranoxType.bodyRegular.copyWith(color: context.palette.inkSoft)),
          const SizedBox(height: Metrics.gap),
          LabeledField(
            label: Copy.privacyChainField,
            controller: _chainAddress,
            hint: Copy.payRecipientHint,
            error: _chainAddressError,
            note: Copy.privacyChainNote,
            mono: true,
            onSubmitted: (_) => scans.scanning ? null : _scan(scans),
            action: SmallPillButton(
              label: Copy.privacyChainScan,
              tone: PillTone.accent,
              busy: scans.scanning,
              busyLabel: Copy.privacyChainScanning,
              onPressed: () => _scan(scans),
            ),
          ),
          if (error != null) ErrorLine(bridgeFailureText(error)),
        ],
      ),
    );
  }
}

/// A swap pair is already on the chain, so it is a note; the privacy check of a payment warns before the next one.
PrivacyCheck _swapsCheck(List<SwapPair> pairs, DateTime now) => PrivacyCheck(
  title: Copy.privacySwapsTitle,
  state: pairs.isEmpty ? CheckState.good : CheckState.note,
  tag: pairs.isEmpty ? null : Copy.privacyFromHistory,
  line: pairs.isEmpty ? Copy.privacySwapsClearLine : Copy.privacySwapsLine(pairs.length),
  detail: switch (pairs) {
    [] => Copy.privacySwapsClear,
    [final newest, ...] => [
      Copy.privacySwapsPair(
        '${formatDecimal(newest.receive.amount)} ${newest.receive.asset.label}',
        '${formatDecimal(newest.pay.amount)} ${newest.pay.asset.label}',
        shortText(newest.pay.payoutAddress),
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
);

/// A refund address paid from XMR is already on both sides, so it is a note, like a swap pair. The address is the
/// user's own, so the note offers its scan through [onScan], where the scan of Robinhood Chain works.
PrivacyCheck _refundCheck(List<LinkedRefund> links, DateTime now, {ValueChanged<String>? onScan}) => PrivacyCheck(
  title: Copy.privacyRefundTitle,
  state: links.isEmpty ? CheckState.good : CheckState.note,
  tag: links.isEmpty ? null : Copy.privacyFromHistory,
  line: links.isEmpty ? Copy.privacyRefundClearLine : Copy.privacyRefundLine(links.length),
  detail: switch (links) {
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
  action: switch ((links, onScan)) {
    ([final newest, ...], final scan?) => SmallPillButton(
      label: Copy.privacyScanIt,
      onPressed: () => scan(newest.address),
    ),
    _ => null,
  },
);

/// New XMR is a note: time alone settles it.
PrivacyCheck _newCoinsCheck(NewCoins? newCoins, DateTime now) {
  final hours = AppConfig.privacyFreshWindow.inHours;
  return switch (newCoins) {
    null => PrivacyCheck(
      title: Copy.privacyNewCoinsTitle,
      state: CheckState.good,
      line: Copy.privacyNewCoinsClearLine(hours),
      detail: Copy.privacyNewCoinsClear(hours),
    ),
    NewCoins(:final amount, :final allOlderAt) => PrivacyCheck(
      title: Copy.privacyNewCoinsTitle,
      state: CheckState.note,
      line: Copy.privacyNewCoinsLine(formatAmount(amount), hours),
      detail: Copy.privacyNewCoins(formatAmount(amount), hours, formatMoment(allOlderAt, now)),
    ),
  };
}

PrivacyCheck _lockCheck() {
  final minutes = AppConfig.idleLockAfter.inMinutes;
  return PrivacyCheck(
    title: Copy.privacyLockTitle,
    state: CheckState.good,
    line: Copy.privacyLockLine(minutes),
    detail: Copy.privacyLock(minutes),
  );
}

/// The checks of an address before its first scan, each with what it reads.
const List<PrivacyCheck> _pendingChainChecks = [
  PrivacyCheck(title: Copy.privacyFundingTitle, state: CheckState.pending, line: Copy.privacyFundingPending),
  PrivacyCheck(title: Copy.privacyOwnTitle, state: CheckState.pending, line: Copy.privacyOwnPending),
  PrivacyCheck(title: Copy.privacyLookAlikeTitle, state: CheckState.pending, line: Copy.privacyLookAlikePending),
  PrivacyCheck(title: Copy.privacyKranoxTitle, state: CheckState.pending, line: Copy.privacyKranoxPending),
  PrivacyCheck(title: Copy.privacyExposureTitle, state: CheckState.pending, line: Copy.privacyExposurePending),
];

/// The checks of a scanned address in their order: four that can find a link, then what everyone sees.
List<PrivacyCheck> _chainChecks(ChainPrivacyReport report, DateTime now) => [
  _fundingCheck(report.funding, sure: report.scan.fundingSure, now: now),
  _ownCheck(report.own, now),
  _lookAlikeCheck(report.lookAlikes, now),
  _kranoxCheck(report.kranox, now),
  _exposureCheck(report.exposure, now),
];

/// The first funding of the address. One that links warns; one that the relay could not read for sure, or none found
/// without being [sure], is a note and never clean, from 10 Oct 2026; a clean one says that the explorer still misses
/// some transfers that contracts made.
PrivacyCheck _fundingCheck(FirstFunding? funding, {required bool sure, required DateTime now}) => PrivacyCheck(
  title: Copy.privacyFundingTitle,
  state: switch (funding) {
    null => CheckState.note,
    FirstFunding(links: true) => CheckState.warning,
    FirstFunding(sure: false) => CheckState.note,
    FirstFunding() => CheckState.good,
  },
  line: switch (funding) {
    null when !sure => Copy.privacyFundingUnsureLine,
    null => Copy.privacyFundingNoneLine,
    FirstFunding(links: true, fromOwn: true) => Copy.privacyFundingOwnLine,
    FirstFunding(links: true, :final label?, :final labelSource) => switch (labelSource) {
      LabelSource.tag => Copy.privacyFundingNamedLine(label),
      LabelSource.contract => Copy.privacyFundingContractLine(label),
      LabelSource.domain => Copy.privacyFundingDomainLine(label),
    },
    FirstFunding(sure: false) => Copy.privacyFundingUnsureLine,
    FirstFunding(fromPay: _?) => Copy.privacyFundingPayLine,
    FirstFunding() => Copy.privacyFundingPlainLine,
  },
  detail: switch (funding) {
    null when !sure => Copy.privacyFundingUnsureNone,
    null => Copy.privacyFundingNone,
    FirstFunding(links: true, fromOwn: true, :final transfer) => Copy.privacyFundingOwn(
      shortText(transfer.from.address),
      formatTime(transfer.time, now),
    ),
    FirstFunding(links: true, :final label?, :final labelSource, :final transfer) => switch (labelSource) {
      LabelSource.tag => Copy.privacyFundingNamed(label, formatTime(transfer.time, now)),
      LabelSource.contract => Copy.privacyFundingContract(label, formatTime(transfer.time, now)),
      LabelSource.domain => Copy.privacyFundingDomain(label, formatTime(transfer.time, now)),
    },
    FirstFunding(sure: false, :final transfer) => Copy.privacyFundingUnsure(
      shortText(transfer.from.address),
      formatTime(transfer.time, now),
    ),
    FirstFunding(fromPay: final pay?) => [
      Copy.privacyFundingPay(
        '${formatDecimal(pay.amountOut ?? pay.amount)} ${pay.asset.label}',
        formatTime(pay.createdAt, now),
      ),
      Copy.privacyFundingExplorerGap,
    ].join(' '),
    FirstFunding(:final transfer) => [
      Copy.privacyFundingPlain(shortText(transfer.from.address), formatTime(transfer.time, now)),
      Copy.privacyFundingExplorerGap,
    ].join(' '),
  },
);

PrivacyCheck _ownCheck(List<OwnLink> own, DateTime now) => PrivacyCheck(
  title: Copy.privacyOwnTitle,
  state: own.isEmpty ? CheckState.good : CheckState.warning,
  line: own.isEmpty ? Copy.privacyOwnClearLine : Copy.privacyOwnLine(own.length),
  detail: switch (own) {
    [] => Copy.privacyOwnClear,
    [final newest, ...] => [
      Copy.privacyOwnLinked(shortText(newest.other), formatTime(newest.at, now)),
      if (own.length > 1) Copy.privacyMoreAddresses(own.length - 1),
    ].join(' '),
  },
);

PrivacyCheck _lookAlikeCheck(List<LookAlike> lookAlikes, DateTime now) => PrivacyCheck(
  title: Copy.privacyLookAlikeTitle,
  state: lookAlikes.isEmpty ? CheckState.good : CheckState.warning,
  line: lookAlikes.isEmpty ? Copy.privacyLookAlikeClearLine : Copy.privacyLookAlikeLine(lookAlikes.length),
  detail: switch (lookAlikes) {
    [] => Copy.privacyLookAlikeClear,
    [final newest, ...] => [
      Copy.privacyLookAlike(newest.sender, newest.resembles, formatTime(newest.at, now)),
      if (lookAlikes.length > 1) Copy.privacyMoreAddresses(lookAlikes.length - 1),
    ].join(' '),
  },
);

/// The swaps of Kranox of the address: one is how a swap goes, and only the records of the exchanger tie the address to
/// it; more tie those swaps together there, so the address counts as something to improve, with a new address as the
/// way.
PrivacyCheck _kranoxCheck(List<KranoxLink> kranox, DateTime now) {
  String amount(BridgeSwap swap) => '${formatDecimal(swap.amount)} ${swap.asset.label}';
  String linkText(KranoxLink link) => switch (link) {
    FundedReceive(:final swap) => Copy.privacyKranoxFunded(amount(swap), formatTime(swap.createdAt, now)),
    GotPay(:final swap) => Copy.privacyKranoxPaid(amount(swap), formatTime(swap.createdAt, now)),
    RefundOf(:final swap) => Copy.privacyKranoxRefund(formatTime(swap.createdAt, now)),
  };
  return PrivacyCheck(
    title: Copy.privacyKranoxTitle,
    state: kranox.length > 1 ? CheckState.warning : CheckState.good,
    line: kranox.isEmpty ? Copy.privacyKranoxClearLine : Copy.privacyKranoxLine(kranox.length),
    detail: switch (kranox) {
      [] => Copy.privacyKranoxClear,
      [final only] => [linkText(only), Copy.privacyKranoxOne].join(' '),
      [final newest, ...] => [
        linkText(newest),
        Copy.privacyMoreSwaps(kranox.length - 1),
        onBothSides(kranox) ? Copy.privacyKranoxBothSides : Copy.privacyKranoxTied(kranox.length),
      ].join(' '),
    },
  );
}

/// What everyone sees is a note with its figures. The tokens that the address holds stand in its line, so that the
/// figures fit on one row.
PrivacyCheck _exposureCheck(Exposure exposure, DateTime now) {
  final empty = exposure.transactions == 0 && exposure.tokenTransfers == 0;
  final hours = exposure.activeHours;
  final tokens = exposure.tokens.join(', ');
  return PrivacyCheck(
    title: Copy.privacyExposureTitle,
    state: CheckState.note,
    line: switch ((empty, tokens)) {
      (true, _) => Copy.privacyExposureEmptyLine,
      (false, '') => Copy.privacyExposureLine,
      _ => Copy.privacyExposureHoldsLine(tokens),
    },
    detail: empty
        ? Copy.privacyExposureEmpty
        : [
            Copy.privacyExposure(exposure.transactions, exposure.tokenTransfers),
            if (exposure.firstSeen case final first?) Copy.privacyExposureSince(formatTime(first, now)),
            if (tokens.isNotEmpty) Copy.privacyExposureTokens(tokens),
            if (hours case (final from, final to)) Copy.privacyExposureHours(_hour(from), _hour(to)),
          ].join(' '),
    stats: empty
        ? const []
        : [
            CheckStat(value: Copy.privacyStatCount(exposure.transactions), label: Copy.privacyStatTransactions),
            CheckStat(value: Copy.privacyStatCount(exposure.tokenTransfers), label: Copy.privacyStatTokenTransfers),
            if (exposure.firstSeen case final first?)
              CheckStat(value: formatTime(first, now), label: Copy.privacyStatFirstSeen),
            if (hours case (final from, final to))
              CheckStat(value: Copy.privacyStatHourRange(_hour(from), _hour(to)), label: Copy.privacyStatHours),
          ],
  );
}

/// An hour of the day in two digits, such as 08.
String _hour(int value) => value.toString().padLeft(2, '0');
