import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../config/network.dart';
import '../../wallet/models.dart';
import '../copy.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import 'bits.dart';

/// The pages of the open wallet.
enum WalletPage { home, send, receive, activity, privacy, settings }

/// The sidebar of the open wallet, after the sidebar of System Settings in macOS: a panel that floats inside the
/// window, with the window buttons at its top and the brand below them, then the wallet, the pages with their
/// icons, the lock, and the progress of the scan at the foot.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.page,
    required this.onSelect,
    required this.onLock,
    required this.status,
    required this.network,
    required this.node,
  });

  final WalletPage page;
  final ValueChanged<WalletPage> onSelect;
  final VoidCallback onLock;
  final WalletStatus status;
  final MoneroNetwork network;
  final String node;

  /// The pages of the upper group, with their icons.
  static const List<(WalletPage, IconData)> _pages = [
    (WalletPage.home, Icons.home_rounded),
    (WalletPage.send, Icons.arrow_outward_rounded),
    (WalletPage.receive, Icons.call_received_rounded),
    (WalletPage.activity, Icons.history_rounded),
    (WalletPage.privacy, Icons.visibility_off_rounded),
  ];

  /// The brand sits this far below the top of the panel, just below the window buttons. It shows no control, so it
  /// may lie in the strip of the window that takes no clicks.
  static const double _top = Metrics.windowButtonsBottom - Metrics.sidebarInset + 11;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(Metrics.radiusSidebar);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Metrics.sidebarInset, Metrics.sidebarInset, 0, Metrics.sidebarInset),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: Metrics.glassBlur, sigmaY: Metrics.glassBlur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.sidebar,
              borderRadius: radius,
              border: Border.all(color: palette.line),
            ),
            child: SizedBox(
              width: Metrics.sidebarWidth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, _top, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Brand(),
                    const SizedBox(height: Metrics.gap + 8),
                    _WalletRow(network: network),
                    const SizedBox(height: Metrics.gap),
                    for (final (item, icon) in _pages)
                      _NavItem(label: _labelOf(item), icon: icon, active: page == item, onTap: () => onSelect(item)),
                    const Spacer(),
                    _NavItem(
                      label: Copy.navSettings,
                      icon: Icons.settings_rounded,
                      active: page == WalletPage.settings,
                      onTap: () => onSelect(WalletPage.settings),
                    ),
                    _NavItem(label: Copy.navLock, icon: Icons.lock_rounded, active: false, onTap: onLock),
                    const SizedBox(height: Metrics.gapSmall),
                    _SyncCard(status: status, node: node),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _labelOf(WalletPage page) => switch (page) {
    WalletPage.home => Copy.navHome,
    WalletPage.send => Copy.navSend,
    WalletPage.receive => Copy.navReceive,
    WalletPage.activity => Copy.navActivity,
    WalletPage.privacy => Copy.navPrivacy,
    WalletPage.settings => Copy.navSettings,
  };
}

/// The helmet of Kranox alone, in the middle of the sidebar. Its alternative text names the app.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Metrics.gapSmall),
    child: Center(
      child: Image.asset('assets/images/logo.png', height: Metrics.sidebarLogoHeight, semanticLabel: Copy.appName),
    ),
  );
}

/// The wallet at the top of the sidebar, like the account in System Settings: a round mark, the name, and the
/// network.
class _WalletRow extends StatelessWidget {
  const _WalletRow({required this.network});

  final MoneroNetwork network;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
            child: SizedBox.square(
              dimension: Metrics.avatar,
              child: Center(
                child: Text(
                  Copy.walletName.characters.first,
                  style: KranoxType.button.copyWith(color: palette.onAccent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Copy.walletName, style: KranoxType.body.copyWith(color: palette.ink)),
              Text(network.label, style: KranoxType.small.copyWith(color: palette.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A link of the sidebar: an icon in a rounded tile and the name of the page. The active link fills its row with
/// the accent, as System Settings fills it with blue.
class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.icon, required this.active, required this.onTap});

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ink = active ? palette.navActiveInk : palette.ink;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Metrics.radiusNavRow));
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? palette.navActive : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: Metrics.navRowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: active ? palette.navActiveTile : palette.navTile,
                      borderRadius: BorderRadius.circular(Metrics.radiusNavTile),
                    ),
                    child: SizedBox.square(
                      dimension: Metrics.navTile,
                      child: Icon(icon, size: Metrics.navGlyph, color: active ? ink : palette.navTileInk),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(label, style: KranoxType.body.copyWith(color: ink)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.status, required this.node});

  final WalletStatus status;
  final String node;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = switch (status) {
      WalletStatus(synchronized: true) => Copy.synced,
      WalletStatus(nodeHeight: > 0) => Copy.syncing,
      _ => Copy.connecting,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // The spinner of Apple while the wallet connects or catches up, as beside every amount.
                if (!status.synchronized) ...[
                  CupertinoActivityIndicator(radius: 6, color: palette.inkSoft),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(label, style: KranoxType.smallStrong.copyWith(color: palette.ink)),
                ),
                Text(groupDigits(status.walletHeight), style: KranoxType.smallStrong.copyWith(color: palette.ink)),
              ],
            ),
            const SizedBox(height: 10),
            SyncDots(share: status.syncShare),
            const SizedBox(height: 10),
            Text(
              node,
              style: KranoxType.small.copyWith(color: palette.inkFaint),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Writes a whole number with commas between groups of three digits, such as a block height.
String groupDigits(int value) =>
    value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match.group(1)},');
