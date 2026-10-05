import 'dart:ui';

import 'package:flutter/material.dart';

import 'ui/copy.dart';
import 'ui/screens/onboarding.dart';
import 'ui/screens/wallet_shell.dart';
import 'ui/theme/kranox_theme.dart';
import 'ui/theme/palette.dart';
import 'ui/widgets/backdrop.dart';
import 'bridge/controller.dart';
import 'wallet/controller.dart';

/// The app: one window that shows the screen of the stage of the wallet.
class KranoxApp extends StatefulWidget {
  const KranoxApp({super.key, required this.controller, required this.bridge});

  final WalletController controller;
  final BridgeController bridge;

  @override
  State<KranoxApp> createState() => _KranoxAppState();
}

class _KranoxAppState extends State<KranoxApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // wallet2 writes the state of the wallet to its file when the wallet closes, so the app closes it first.
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await widget.controller.shutdown();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: Copy.appName,
    debugShowCheckedModeBanner: false,
    theme: KranoxTheme.build(Palette.of(activeLook)),
    home: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => switch (widget.controller.phase) {
        WalletPhase.starting => const Backdrop(child: Center(child: CircularProgressIndicator())),
        WalletPhase.noWallet => OnboardingFlow(controller: widget.controller),
        WalletPhase.locked => UnlockScreen(controller: widget.controller),
        WalletPhase.open => WalletShell(controller: widget.controller, bridge: widget.bridge),
      },
    ),
  );
}
