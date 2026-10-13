import 'package:flutter/material.dart';

import '../../bridge/controller.dart';
import '../../bridge/models.dart';
import '../../wallet/controller.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/page_frame.dart';
import '../widgets/surfaces.dart';
import '../widgets/swap_steps.dart';
import '../widgets/transfer_row.dart';

/// Every transaction of the wallet, the newest first, each with a button that copies its id, and under them every swap
/// with Robinhood Chain of this device, so that a swap whose card the user closed stays in reach (13 Oct 2026).
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key, required this.controller, required this.bridge, required this.onOpenSwap});

  final WalletController controller;
  final BridgeController bridge;

  /// Opens the page of a swap, on the page of its way.
  final ValueChanged<BridgeSwap> onOpenSwap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final transfers = controller.transfers;
    final loading = controller.status.isLoading;
    return PageFrame(
      title: Copy.activityTitle,
      lead: Copy.activityLead,
      chips: [StatusChip(label: controller.network.label)],
      children: [
        Surface(
          padding: const EdgeInsets.fromLTRB(Metrics.cardPadding, 8, Metrics.cardPadding, 8),
          child: transfers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: loading
                      ? const LoadingLine(Copy.activityAfterSync)
                      : Text(
                          controller.status.synchronized ? Copy.noActivity : Copy.activityAfterSync,
                          style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft),
                        ),
                )
              : Column(
                  children: [
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LoadingLine(Copy.activityUpdating),
                      ),
                    for (final (index, transfer) in transfers.indexed) ...[
                      if (index > 0 || loading) Divider(height: 1, color: palette.line),
                      TransferRow(
                        loading: loading,
                        transfer: transfer,
                        trailing: RoundButton(
                          icon: Icons.copy_rounded,
                          tooltip: Copy.copyId,
                          size: Metrics.smallRound,
                          onPressed: () => copyToClipboard(context, transfer.hash),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        ListenableBuilder(
          listenable: bridge,
          builder: (context, _) {
            final swaps = bridge.swaps;
            if (swaps.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: Metrics.gap),
              child: SwapHistory(
                title: Copy.activitySwaps,
                swaps: swaps,
                line: _line,
                trailing: _trailing,
                onOpen: onOpenSwap,
              ),
            );
          },
        ),
      ],
    );
  }

  /// What a swap did: the coin that came in for XMR, or the XMR that went out for a coin.
  static String _line(BridgeSwap swap) => switch (swap.direction) {
    SwapDirection.receive => Copy.bridgeSwapLine(formatDecimal(swap.amount, decimals: 8), swap.asset),
    SwapDirection.pay => Copy.activityPayLine(switch (swap.xmrAmount) {
      final xmr? => formatDecimal(xmr, decimals: 8),
      null => '…',
    }, swap.asset),
  };

  /// What the swap gave, once it did: the XMR of a receive, or the XMR that a payment took.
  static String? _trailing(BridgeSwap swap) {
    if (swap.stage.withoutPayout) return null;
    return switch (swap.direction) {
      SwapDirection.receive => switch (swap.amountOut ?? swap.xmrAmount) {
        final xmr? => Copy.bridgeOut(formatDecimal(xmr)),
        null => null,
      },
      SwapDirection.pay => switch (swap.xmrAmount) {
        final xmr? => Copy.payOut(formatDecimal(xmr, decimals: 8)),
        null => null,
      },
    };
  }
}
