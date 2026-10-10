import 'package:flutter/material.dart';

import '../../bridge/controller.dart';
import '../../bridge/models.dart';
import '../../config/app_config.dart';
import '../../privacy/chain_scans.dart';
import '../../privacy/receive_check.dart';
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
import '../widgets/page_frame.dart';
import '../widgets/privacy_check.dart';
import '../widgets/qr_card.dart';
import '../widgets/surfaces.dart';
import 'receive_from_chain.dart';

/// The ways to receive: XMR to a subaddress, or a coin on Robinhood Chain that ChangeNOW turns into XMR.
enum _ReceiveWay { monero, robinhood }

/// The receive page: the newest subaddress as a code to scan and as text, with its privacy check from 10 Oct 2026 and a
/// button for a new subaddress, or the receive from Robinhood Chain. Its content stands in a column in the middle, as
/// on the send page; the owner asked for that on 6 Oct 2026 ("receive belum simple dan di tengah"). The page of a swap
/// from Robinhood Chain shows in its place until the user goes back.
class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key, required this.controller, required this.bridge, this.scans, this.reselect = 0});

  final WalletController controller;
  final BridgeController bridge;

  /// The addresses that the user scanned in the menu Privacy, for the check of the refund address of a receive.
  final ChainScans? scans;

  /// Counts the clicks on Receive in the sidebar while this page shows, so that a click leaves the page of a swap.
  final int reselect;

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  // A swap on its way brings the user back to its deposit address.
  late _ReceiveWay _way = widget.bridge.activeSwapOf(SwapDirection.receive) == null
      ? _ReceiveWay.monero
      : _ReceiveWay.robinhood;
  bool _busy = false;
  String? _error;

  // The swap whose page shows in place of this page, or null.
  String? _swapId;

  @override
  void didUpdateWidget(ReceivePage old) {
    super.didUpdateWidget(old);
    if (widget.reselect != old.reselect) _swapId = null;
  }

  Future<void> _newAddress() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.newReceiveAddress();
    } on WalletException catch (error) {
      setState(() => _error = failureText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_swapId case final id?) {
      return ReceiveSwapPage(bridge: widget.bridge, swapId: id, onBack: () => setState(() => _swapId = null));
    }
    final fromChain = _way == _ReceiveWay.robinhood;
    return PageFrame(
      title: Copy.receiveTitle,
      lead: fromChain ? Copy.receiveChainLead : Copy.receiveLead,
      chips: [
        StatusChip(label: widget.controller.network.label),
        if (fromChain) const StatusChip(label: Copy.exchanger),
      ],
      centered: true,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Metrics.gapTiny,
          runSpacing: Metrics.gapTiny,
          children: [
            ChoicePill(
              label: Copy.receiveMoneroTab,
              active: !fromChain,
              onTap: fromChain ? () => setState(() => _way = _ReceiveWay.monero) : null,
            ),
            ChoicePill(
              label: Copy.receiveChainTab,
              active: fromChain,
              onTap: fromChain ? null : () => setState(() => _way = _ReceiveWay.robinhood),
            ),
          ],
        ),
        const SizedBox(height: Metrics.gap),
        if (fromChain)
          ReceiveFromChain(
            bridge: widget.bridge,
            scans: widget.scans,
            onOpenSwap: (swap) => setState(() => _swapId = swap.id),
          )
        else
          _subaddress(context),
      ],
    );
  }

  Widget _subaddress(BuildContext context) {
    final palette = context.palette;
    final address = widget.controller.receiveAddress;
    return Surface(
      padding: const EdgeInsets.all(Metrics.heroPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: QrCard(data: address?.address, size: Metrics.qrSize, padding: Metrics.qrPadding),
          ),
          const SizedBox(height: Metrics.gap + 4),
          Text(
            address == null ? '' : Copy.subaddress(address.index).toUpperCase(),
            textAlign: TextAlign.center,
            style: KranoxType.label.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Metrics.gapSmall),
          // The whole subaddress, so that the payer can check it character by character.
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.field,
              borderRadius: BorderRadius.circular(Metrics.radiusField),
              border: Border.all(color: palette.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Metrics.addressBoxPadding),
              child: SelectableText(
                address?.address ?? '…',
                textAlign: TextAlign.center,
                style: KranoxType.mono.copyWith(color: palette.ink),
              ),
            ),
          ),
          // The privacy check of the subaddress, before the user hands it out.
          if (address != null) ...[
            const SizedBox(height: Metrics.gap),
            PrivacyRulesCard(
              note: Copy.privacyLocalNote,
              rules: _subaddressRules(
                address.index,
                widget.controller.transfers,
                synchronized: widget.controller.status.synchronized,
              ),
            ),
          ],
          ErrorLine(_error),
          const SizedBox(height: Metrics.gap),
          PillButton(
            label: Copy.copyAddress,
            icon: Icons.copy_rounded,
            expand: true,
            onPressed: address == null ? null : () => copyToClipboard(context, address.address),
          ),
          const SizedBox(height: Metrics.gapSmall),
          PillButton(label: Copy.newAddress, tone: PillTone.quiet, busy: _busy, expand: true, onPressed: _newAddress),
        ],
      ),
    );
  }
}

/// The rules of the privacy check of the subaddress [index] that the page gives out: the payments that it already took,
/// and what to do once the XMR comes in. One payment is a tip, since the same payer may pay again; more payments warn,
/// as the check "Subaddresses" of the menu Privacy does. Until the wallet has [synchronized], no payment yet says
/// nothing for sure, such as right after a restore, when an older install may have handed the subaddress out.
List<PrivacyRule> _subaddressRules(int index, List<WalletTransfer> transfers, {required bool synchronized}) {
  final payments = paymentsTo(index, transfers);
  return [
    PrivacyRule(
      label: Copy.privacySubaddressLabel,
      state: switch (payments) {
        0 when !synchronized => RuleState.unchecked,
        0 => RuleState.passed,
        1 => RuleState.tip,
        _ => RuleState.warning,
      },
      text: switch (payments) {
        0 when !synchronized => Copy.privacySubaddressUnchecked(index),
        0 => Copy.privacySubaddressUnused(index),
        1 => Copy.privacySubaddressOnce(index),
        _ => Copy.privacySubaddressShared(index, payments),
      },
    ),
    PrivacyRule(
      label: Copy.privacyAfterItComesIn,
      state: RuleState.tip,
      text: Copy.privacyAfterXmr(AppConfig.privacyFreshWindow.inHours),
    ),
  ];
}
