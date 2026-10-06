import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/amount.dart';
import '../../core/unlock.dart';
import '../../wallet/controller.dart';
import '../../wallet/models.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/page_frame.dart';
import '../widgets/sidebar.dart';
import '../widgets/surfaces.dart';
import '../widgets/transfer_row.dart';

/// The width below which the side cards move under the balance card.
const double _twoColumnWidth = 760;

/// The home of the open wallet: the balance card, the card of the unlocked or the locked part, the receive address,
/// and the latest transactions.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller, required this.onNavigate});

  final WalletController controller;
  final ValueChanged<WalletPage> onNavigate;

  @override
  Widget build(BuildContext context) {
    final status = controller.status;
    final hero = _BalanceCard(status: status, onNavigate: onNavigate);
    final side = Column(
      children: [
        if (status.isLoading || status.locked.units <= 0)
          _UnlockedCard(status: status)
        else
          _UnlockingCard(locked: status.locked, wait: controller.unlockWait),
        const SizedBox(height: Metrics.gap),
        _ReceiveCard(address: controller.receiveAddress),
      ],
    );
    return PageFrame(
      title: Copy.greeting(DateTime.now()),
      lead: Copy.homeLead,
      chips: [
        StatusChip(label: controller.network.label),
        _NodeChip(connection: status.connection),
      ],
      children: [
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= _twoColumnWidth
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: Metrics.heroFlex, child: hero),
                      const SizedBox(width: Metrics.gap),
                      Expanded(flex: Metrics.sideFlex, child: side),
                    ],
                  ),
                )
              : Column(
                  children: [
                    hero,
                    const SizedBox(height: Metrics.gap),
                    side,
                  ],
                ),
        ),
        const SizedBox(height: Metrics.gap),
        _RecentActivity(
          transfers: controller.transfers,
          synchronized: status.synchronized,
          loading: status.isLoading,
          onShowAll: () => onNavigate(WalletPage.activity),
        ),
      ],
    );
  }
}

class _NodeChip extends StatelessWidget {
  const _NodeChip({required this.connection});

  final NodeConnection connection;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return switch (connection) {
      NodeConnection.connected => StatusChip(label: Copy.nodeOnline, dot: palette.accent),
      NodeConnection.disconnected => StatusChip(label: Copy.nodeOffline, dot: palette.danger),
      NodeConnection.wrongVersion => StatusChip(label: Copy.nodeWrongVersion, dot: palette.danger),
    };
  }
}

/// The quieter text of the balance card.
Color _heroSoft(Palette palette) => palette.heroInk.withValues(alpha: 0.75);

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.status, required this.onNavigate});

  final WalletStatus status;
  final ValueChanged<WalletPage> onNavigate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final soft = _heroSoft(palette);
    return HeroSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Copy.balance.toUpperCase(), style: KranoxType.label.copyWith(color: soft)),
          const SizedBox(height: Metrics.gap),
          if (status.isLoading)
            LoadingFigure(style: KranoxType.figure, color: palette.heroInk)
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AmountFigure(
                value: formatAmount(status.balance),
                style: KranoxType.figure,
                unitStyle: KranoxType.figureUnit,
                color: palette.heroInk,
              ),
            ),
          if (!status.isLoading && status.locked.units > 0) ...[
            const SizedBox(height: Metrics.gap),
            _BalanceSplit(unlocked: status.unlocked, locked: status.locked),
          ] else ...[
            const SizedBox(height: Metrics.gapSmall),
            Text(
              status.isLoading ? Copy.balanceUpdating : Copy.allUnlocked,
              style: KranoxType.bodyRegular.copyWith(color: soft),
            ),
          ],
          const Spacer(),
          const SizedBox(height: Metrics.gap + 4),
          Row(
            children: [
              PillButton(label: Copy.navSend, tone: PillTone.heroMain, onPressed: () => onNavigate(WalletPage.send)),
              const SizedBox(width: Metrics.gapSmall),
              PillButton(
                label: Copy.navReceive,
                tone: PillTone.heroAlt,
                onPressed: () => onNavigate(WalletPage.receive),
              ),
              const Spacer(),
              RoundButton(
                icon: Icons.north_east_rounded,
                tooltip: Copy.allActivity,
                background: palette.heroAlt,
                foreground: palette.heroAltInk,
                onPressed: () => onNavigate(WalletPage.activity),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A balance with a locked part, split in two below the total: a bar with a part for the coins that the wallet can
/// spend now and a part for the coins that wait for confirmations, and the two amounts under it.
class _BalanceSplit extends StatelessWidget {
  const _BalanceSplit({required this.unlocked, required this.locked});

  final XmrAmount unlocked;
  final XmrAmount locked;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SplitBar(unlockedShare: unlocked.units / (unlocked.units + locked.units)),
        const SizedBox(height: Metrics.gapSmall + 2),
        Wrap(
          spacing: Metrics.gap * 2,
          runSpacing: Metrics.gapSmall,
          children: [
            _SplitPart(label: Copy.unlocked, amount: unlocked, color: palette.heroInk),
            _SplitPart(label: Copy.locked, amount: locked, color: palette.heroTrack),
          ],
        ),
      ],
    );
  }
}

/// A thin bar in two parts: the unlocked share in the ink of the balance card, the locked share in a fainter tone.
/// The unlocked part grows as coins unlock.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.unlockedShare});

  final double unlockedShare;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // A painter learns the width of the bar when it paints: the balance card sits in a row of intrinsic height, which
    // a LayoutBuilder does not support.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: unlockedShare),
      duration: Metrics.fade,
      builder: (context, share, _) => SizedBox(
        height: Metrics.splitBarHeight,
        child: CustomPaint(
          painter: _SplitBarPainter(unlockedShare: share, unlocked: palette.heroInk, locked: palette.heroTrack),
        ),
      ),
    );
  }
}

class _SplitBarPainter extends CustomPainter {
  const _SplitBarPainter({required this.unlockedShare, required this.unlocked, required this.locked});

  final double unlockedShare;
  final Color unlocked;
  final Color locked;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final unlockedWidth = _unlockedWidth(size.width);
    if (unlockedWidth > 0) {
      canvas.drawRRect(RRect.fromLTRBR(0, 0, unlockedWidth, size.height, radius), Paint()..color = unlocked);
    }
    final lockedLeft = unlockedWidth > 0 ? unlockedWidth + Metrics.splitBarGap : 0.0;
    canvas.drawRRect(RRect.fromLTRBR(lockedLeft, 0, size.width, size.height, radius), Paint()..color = locked);
  }

  /// The width of the unlocked part: its share of the bar, but never so thin or so wide that a part disappears.
  double _unlockedWidth(double width) {
    if (unlockedShare <= 0) return 0;
    final room = width - Metrics.splitBarGap;
    return (room * unlockedShare).clamp(Metrics.splitBarMinPart, room - Metrics.splitBarMinPart).toDouble();
  }

  @override
  bool shouldRepaint(_SplitBarPainter old) =>
      old.unlockedShare != unlockedShare || old.unlocked != unlocked || old.locked != locked;
}

/// One part of the balance below the bar: a dot in the color of its part of the bar, its name, and its amount.
class _SplitPart extends StatelessWidget {
  const _SplitPart({required this.label, required this.amount, required this.color});

  final String label;
  final XmrAmount amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: 7),
            ),
            const SizedBox(width: 7),
            Text(label.toUpperCase(), style: KranoxType.label.copyWith(color: _heroSoft(palette))),
          ],
        ),
        const SizedBox(height: 4),
        AmountFigure(
          value: formatAmount(amount),
          style: KranoxType.rowFigure,
          unitStyle: KranoxType.smallStrong,
          color: palette.heroInk,
        ),
      ],
    );
  }
}

/// The round mark at the corner of a side card: a check, or a lock with a clock.
class _CardMark extends StatelessWidget {
  const _CardMark(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(color: palette.solid, shape: BoxShape.circle),
      child: SizedBox.square(
        dimension: Metrics.smallRound,
        child: Icon(icon, size: 15, color: palette.solidInk),
      ),
    );
  }
}

/// The side card while a part of the balance is locked: a dot for each confirmation of the transfer that unlocks
/// last, the time left, and why Monero locks new coins.
class _UnlockingCard extends StatelessWidget {
  const _UnlockingCard({required this.locked, required this.wait});

  final XmrAmount locked;

  /// Null when no transfer in the history explains the locked part yet: the card then states the rule alone.
  final UnlockProgress? wait;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final amount = formatAmount(locked);
    final progress = wait;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle(Copy.unlocking, trailing: _CardMark(Icons.lock_clock_rounded)),
          const SizedBox(height: 14),
          if (progress == null)
            Text(Copy.lockedNote(amount), style: KranoxType.body.copyWith(color: palette.ink))
          else ...[
            Row(
              children: [
                ConfirmationDots(confirmations: progress.confirmations, target: progress.target),
                const Spacer(),
                Text(
                  Copy.confirmationCount(progress.confirmations),
                  style: KranoxType.smallStrong.copyWith(color: palette.inkSoft),
                ),
              ],
            ),
            const SizedBox(height: Metrics.gapSmall + 2),
            Text(Copy.lockedReadyIn(amount, progress.timeLeft), style: KranoxType.body.copyWith(color: palette.ink)),
            const SizedBox(height: Metrics.gapTiny),
            Text(Copy.unlockReason, style: KranoxType.small.copyWith(color: palette.inkSoft)),
          ],
        ],
      ),
    );
  }
}

class _UnlockedCard extends StatelessWidget {
  const _UnlockedCard({required this.status});

  final WalletStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle(Copy.unlocked, trailing: _CardMark(Icons.check_rounded)),
          const SizedBox(height: 12),
          if (status.isLoading)
            LoadingFigure(style: KranoxType.cardFigure)
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AmountFigure(
                value: formatAmount(status.unlocked),
                style: KranoxType.cardFigure,
                unitStyle: KranoxType.smallStrong,
              ),
            ),
          const SizedBox(height: Metrics.gapTiny),
          Text(Copy.unlockedNote, style: KranoxType.small.copyWith(color: palette.inkSoft)),
        ],
      ),
    );
  }
}

class _ReceiveCard extends StatelessWidget {
  const _ReceiveCard({required this.address});

  final ReceiveAddress? address;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final current = address;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            Copy.receiveAddress,
            trailing: RoundButton(
              icon: Icons.copy_rounded,
              tooltip: Copy.copyAddress,
              size: Metrics.smallRound,
              onPressed: current == null ? null : () => copyToClipboard(context, current.address),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            current == null ? '…' : shortText(current.address),
            style: KranoxType.rowFigure.copyWith(color: palette.ink),
          ),
          const SizedBox(height: Metrics.gapTiny),
          Text(
            current == null ? '' : Copy.subaddress(current.index),
            style: KranoxType.small.copyWith(color: palette.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.transfers,
    required this.synchronized,
    required this.loading,
    required this.onShowAll,
  });

  final List<WalletTransfer> transfers;
  final bool synchronized;

  /// Whether the wallet catches up with the chain, so that the list may still change.
  final bool loading;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final latest = transfers.take(AppConfig.recentActivityCount).toList();
    return Surface(
      padding: const EdgeInsets.fromLTRB(Metrics.cardPadding, 18, Metrics.cardPadding, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitle(
            Copy.recentActivity,
            trailing: TextButton(
              onPressed: onShowAll,
              style: TextButton.styleFrom(foregroundColor: palette.inkSoft, textStyle: KranoxType.body),
              child: const Text(Copy.allActivity),
            ),
          ),
          if (loading) ...[
            const SizedBox(height: Metrics.gapTiny),
            LoadingLine(latest.isEmpty ? Copy.activityAfterSync : Copy.activityUpdating),
            const SizedBox(height: Metrics.gapTiny),
          ],
          if (latest.isEmpty && !loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                synchronized ? Copy.noActivity : Copy.activityAfterSync,
                style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft),
              ),
            )
          else
            for (final (index, transfer) in latest.indexed) ...[
              if (index > 0) Divider(height: 1, color: palette.line),
              TransferRow(transfer: transfer, loading: loading),
            ],
        ],
      ),
    );
  }
}
