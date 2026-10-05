import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/unlock.dart';
import '../../wallet/models.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import 'bits.dart';

/// One transaction in a list: a round arrow, what happened and when, and the amount. While the wallet catches up with
/// the chain, a spinner stands in place of the amount. While the coins of the transaction unlock, a ring around the
/// arrow fills with each confirmation.
class TransferRow extends StatelessWidget {
  const TransferRow({super.key, required this.transfer, this.trailing, this.loading = false});

  final WalletTransfer transfer;
  final Widget? trailing;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final outgoing = transfer.direction == TransferDirection.outgoing;
    final sign = outgoing ? '−' : '+';
    final unlock = transfer.unlock;
    final unlocking = !transfer.isFailed && !unlock.isUnlocked;
    final details = <String>[
      formatTime(transfer.time, DateTime.now()),
      ..._stateText(outgoing),
      if (!outgoing && transfer.subaddressIndex != null && transfer.subaddressIndex! > 0)
        Copy.subaddress(transfer.subaddressIndex!),
      // A fee is a few hundred-thousandths of an XMR, so it shows in full, as on the send page.
      if (outgoing && transfer.fee.units > 0) Copy.feeOf(transfer.fee.toExact()),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          _TransferIcon(outgoing: outgoing, unlocking: unlocking ? unlock : null),
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
          if (loading)
            SizedBox(
              width: Metrics.transferIcon,
              child: LoadingFigure(style: KranoxType.rowFigure),
            )
          else
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

  /// Where the transaction stands, until its coins unlock: failed, waiting in the pool of the node, or a count of
  /// confirmations, and for coins that came in, the time left. A transaction whose coins have unlocked needs no word.
  List<String> _stateText(bool outgoing) {
    final unlock = transfer.unlock;
    if (transfer.isFailed) return const [Copy.failed];
    if (unlock.isUnlocked) return const [];
    final count = transfer.isPending
        ? Copy.pending
        : outgoing
        ? Copy.confirmationsOf(unlock.confirmations)
        : Copy.confirmationCount(unlock.confirmations);
    return [count, if (!outgoing) Copy.readyIn(unlock.timeLeft)];
  }
}

/// The round arrow of a transaction. While its coins unlock, a thin ring around it fills with each confirmation. The
/// ring reaches into the room around the row, so a row with a ring lines up with a row without one.
class _TransferIcon extends StatelessWidget {
  const _TransferIcon({required this.outgoing, required this.unlocking});

  final bool outgoing;

  /// Null once the coins of the transaction have unlocked, or when it failed.
  final UnlockProgress? unlocking;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final progress = unlocking;
    final icon = DecoratedBox(
      decoration: BoxDecoration(color: outgoing ? palette.outgoing : palette.incoming, shape: BoxShape.circle),
      child: SizedBox.square(
        dimension: Metrics.transferIcon,
        child: Icon(
          outgoing ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 18,
          color: outgoing ? palette.outgoingInk : palette.incomingInk,
        ),
      ),
    );
    if (progress == null) return icon;
    const reach = Metrics.unlockRingGap + Metrics.unlockRing;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          left: -reach,
          top: -reach,
          right: -reach,
          bottom: -reach,
          child: CustomPaint(
            painter: _RingPainter(share: progress.share, track: palette.dotOff, fill: palette.accent),
          ),
        ),
      ],
    );
  }
}

/// A thin ring: a faint track all around, and an arc from the top, clockwise, for the share that is done.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.share, required this.track, required this.fill});

  final double share;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(Metrics.unlockRing / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = Metrics.unlockRing
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(rect, stroke..color = track);
    if (share > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * share, false, stroke..color = fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.share != share || old.track != track || old.fill != fill;
}
