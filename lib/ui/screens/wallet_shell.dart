import 'package:flutter/material.dart';

import '../../wallet/controller.dart';
import '../widgets/backdrop.dart';
import '../widgets/sidebar.dart';
import 'activity_page.dart';
import 'home_page.dart';
import 'receive_page.dart';
import 'send_page.dart';
import 'settings_page.dart';

/// The open wallet: the sidebar at the left and the chosen page at the right.
class WalletShell extends StatefulWidget {
  const WalletShell({super.key, required this.controller});

  final WalletController controller;

  @override
  State<WalletShell> createState() => _WalletShellState();
}

class _WalletShellState extends State<WalletShell> {
  WalletPage _page = WalletPage.home;

  void _go(WalletPage page) => setState(() => _page = page);

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
              child: switch (_page) {
                WalletPage.home => HomePage(controller: controller, onNavigate: _go),
                WalletPage.send => SendPage(controller: controller),
                WalletPage.receive => ReceivePage(controller: controller),
                WalletPage.activity => ActivityPage(controller: controller),
                WalletPage.settings => SettingsPage(controller: controller, onLock: _lock),
              },
            ),
          ],
        ),
      ),
    );
  }
}
