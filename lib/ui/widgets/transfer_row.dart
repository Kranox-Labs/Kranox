import 'package:flutter/material.dart';

import '../../wallet/models.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';

/// One transaction in a list: a round arrow, what happened and when, and the amount.
class TransferRow extends StatelessWidget {
  const TransferRow({super.key, required this.transfer, this.trailing});

  final WalletTransfer transfer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final outgoing = transfer.direction == TransferDirection.outgoing;
    final sign = outgoing ? '−' : '+';
    final details = <String>[
      formatTime(transfer.time, DateTime.now()),
      ?_stateText(),
      if (!outgoing && transfer.subaddressIndex != null && transfer.subaddressIndex! > 0)
        Copy.subaddress(transfer.subaddressIndex!),
      // A fee is a few hundred-thousandths of an XMR, so it shows in full, as on the send page.
      if (outgoing && transfer.fee.units > 0) Copy.feeOf(transfer.fee.toExact()),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: outgoing ? palette.outgoing : palette.incoming, shape: BoxShape.circle),
            child: SizedBox.square(
              dimension: Metrics.transferIcon,
              child: Icon(
                outgoing ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 18,
                color: outgoing ? palette.outgoingInk : palette.incomingInk,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(outgoing ? Copy.sent : Copy.received, style: KranoxType.body.copyWith(color: palette.ink)),
                const SizedBox(height: 2),
                Text(details.join(' · '), style: KranoxType.small.copyWith(color: palette.inkSoft)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$sign${formatAmount(transfer.amount)}', style: KranoxType.rowFigure.copyWith(color: palette.ink)),
              Text(Copy.currency, style: KranoxType.unitLabel.copyWith(color: palette.inkSoft)),
            ],
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }

  String? _stateText() {
    if (transfer.isFailed) return Copy.failed;
    if (transfer.isPending) return Copy.pending;
    return Copy.confirmations(transfer.confirmations);
  }
}
