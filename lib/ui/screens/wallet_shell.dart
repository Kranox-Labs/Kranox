import 'package:flutter/material.dart';

import '../../bridge/controller.dart';
import '../../privacy/chain_scans.dart';
import '../../wallet/controller.dart';
import '../theme/metrics.dart';
import '../widgets/backdrop.dart';
import '../widgets/sidebar.dart';
import '../widgets/toast.dart';
import 'activity_page.dart';
import 'home_page.dart';
import 'privacy_page.dart';
import 'receive_page.dart';
import 'send_page.dart';
import 'settings_page.dart';

/// The open wallet: the sidebar at the left and the chosen page at the right.
class WalletShell extends StatefulWidget {
  const WalletShell({super.key, required this.controller, required this.bridge, this.notice});

  final WalletController controller;
  final BridgeController bridge;

  /// A notice that floats at the foot of every page until the user closes it, such as a damaged file moved aside.
  final Widget? notice;

  @override
  State<WalletShell> createState() => _WalletShellState();
}

class _WalletShellState extends State<WalletShell> {
  WalletPage _page = WalletPage.home;

  // The scans of addresses on Robinhood Chain live while the wallet is open, and go when it locks.
  late final ChainScans? _scans = switch (widget.bridge.scanner) {
    final scanner? => ChainScans(scanner),
    null => null,
  };

  @override
  void dispose() {
    _scans?.dispose();
    super.dispose();
  }

  // The send page opens on pay once, after the way to a clean start of the menu Privacy.
  bool _startOnPay = false;

  void _go(WalletPage page) => setState(() {
    _page = page;
    _startOnPay = false;
  });

  void _payNewAddress() => setState(() {
    _page = WalletPage.send;
    _startOnPay = true;
  });

  Future<void> _lock() => widget.controller.lock();

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Backdrop(
        showArt: true,
        child: Row(
          // Each page fills the height of the window and starts at its top.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Sidebar(
              page: _page,
              onSelect: _go,
              onLock: _lock,
              status: controller.status,
              network: controller.network,
              node: controller.node,
            ),
            Expanded(
              // A toast such as "Copied" floats at the foot of the page, in the middle beside the sidebar.
              child: ToastHost(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: switch (_page) {
                        WalletPage.home => HomePage(controller: controller, onNavigate: _go),
                        WalletPage.send => SendPage(
                          controller: controller,
                          bridge: widget.bridge,
                          scans: _scans,
                          startOnPay: _startOnPay,
                        ),
                        WalletPage.receive => ReceivePage(controller: controller, bridge: widget.bridge),
                        WalletPage.activity => ActivityPage(controller: controller),
                        WalletPage.privacy => PrivacyPage(
                          controller: controller,
                          bridge: widget.bridge,
                          onNavigate: _go,
                          onPayNewAddress: _payNewAddress,
                          scans: _scans,
                        ),
                        WalletPage.settings => SettingsPage(
                          controller: controller,
                          bridge: widget.bridge,
                          onLock: _lock,
                        ),
                      },
                    ),
                    if (widget.notice case final notice?)
                      Positioned(
                        left: Metrics.pagePaddingX,
                        right: Metrics.pagePaddingX,
                        bottom: Metrics.toastBottom,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: Metrics.formWidth),
                            child: notice,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
