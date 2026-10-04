import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../wallet/controller.dart';
import '../../wallet/models.dart';
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
import '../widgets/transfer_row.dart';

/// The width below which the side cards move under the balance card.
const double _twoColumnWidth = 760;

/// The home of the open wallet: the balance card, the unlocked part, the receive address, and the latest
/// transactions.
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
        _UnlockedCard(status: status),
        const SizedBox(height: Metrics.gap),
        _ReceiveCard(address: controller.receiveAddress),
      ],
    );
    return PageFrame(
      title: Copy.greeting(DateTime.now()),
      lead: Copy.homeLead,
      chips: [
        StatusChip(label: AppConfig.network.label),
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

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.status, required this.onNavigate});

  final WalletStatus status;
  final ValueChanged<WalletPage> onNavigate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final soft = palette.heroInk.withValues(alpha: 0.75);
    return HeroSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Copy.balance.toUpperCase(), style: KranoxType.label.copyWith(color: soft)),
          const SizedBox(height: Metrics.gap),
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
          const SizedBox(height: Metrics.gapSmall),
          Text(
            status.locked.units > 0 ? Copy.lockedNote(formatAmount(status.locked)) : Copy.allUnlocked,
            style: KranoxType.bodyRegular.copyWith(color: soft),
          ),
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
          CardTitle(
            Copy.unlocked,
            trailing: DecoratedBox(
              decoration: BoxDecoration(color: palette.solid, shape: BoxShape.circle),
              child: SizedBox.square(
                dimension: Metrics.smallRound,
                child: Icon(Icons.check_rounded, size: 15, color: palette.solidInk),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
  const _RecentActivity({required this.transfers, required this.synchronized, required this.onShowAll});

  final List<WalletTransfer> transfers;
  final bool synchronized;
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
          if (latest.isEmpty)
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
              TransferRow(transfer: transfer),
            ],
        ],
      ),
    );
  }
}
