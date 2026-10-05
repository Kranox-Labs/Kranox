import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../bridge/controller.dart';
import '../../bridge/models.dart';
import '../../wallet/controller.dart';
import '../../wallet/failure.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/choice_pill.dart';
import '../widgets/page_frame.dart';
import '../widgets/surfaces.dart';
import 'receive_from_chain.dart';

/// The ways to receive: XMR to a subaddress, or a coin on Robinhood Chain that ChangeNOW turns into XMR.
enum _ReceiveWay { monero, robinhood }

/// The receive page: the newest subaddress as a code to scan and as text, with a button for a new subaddress, or the
/// receive from Robinhood Chain.
class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key, required this.controller, required this.bridge});

  final WalletController controller;
  final BridgeController bridge;

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
    final fromChain = _way == _ReceiveWay.robinhood;
    return PageFrame(
      title: Copy.receiveTitle,
      lead: fromChain ? Copy.receiveChainLead : Copy.receiveLead,
      chips: [
        StatusChip(label: widget.controller.network.label),
        if (fromChain) const StatusChip(label: Copy.exchanger),
      ],
      children: [
        Wrap(
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
        if (fromChain) ReceiveFromChain(bridge: widget.bridge) else _subaddress(context),
      ],
    );
  }

  Widget _subaddress(BuildContext context) {
    final palette = context.palette;
    final address = widget.controller.receiveAddress;
    return Surface(
      padding: const EdgeInsets.all(Metrics.heroPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A code to scan needs dark modules on a light ground in every look.
          DecoratedBox(
            decoration: BoxDecoration(
              color: BrandColors.white,
              borderRadius: BorderRadius.circular(Metrics.radiusField),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: address == null
                  ? const SizedBox.square(dimension: Metrics.qrSize)
                  : QrImageView(
                      data: address.address,
                      size: Metrics.qrSize,
                      padding: EdgeInsets.zero,
                      backgroundColor: BrandColors.white,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: BrandColors.coal),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: BrandColors.coal,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: Metrics.gap + 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address == null ? '' : Copy.subaddress(address.index).toUpperCase(),
                  style: KranoxType.label.copyWith(color: palette.inkSoft),
                ),
                const SizedBox(height: Metrics.gapSmall),
                SelectableText(address?.address ?? '…', style: KranoxType.mono.copyWith(color: palette.ink)),
                ErrorLine(_error),
                const SizedBox(height: Metrics.gap),
                Wrap(
                  spacing: Metrics.gapSmall,
                  runSpacing: Metrics.gapSmall,
                  children: [
                    PillButton(
                      label: Copy.copyAddress,
                      icon: Icons.copy_rounded,
                      onPressed: address == null ? null : () => copyToClipboard(context, address.address),
                    ),
                    PillButton(label: Copy.newAddress, tone: PillTone.quiet, busy: _busy, onPressed: _newAddress),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
