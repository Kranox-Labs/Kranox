import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/copy.dart';
import 'ui/screens/onboarding.dart';
import 'ui/screens/wallet_shell.dart';
import 'ui/theme/kranox_theme.dart';
import 'ui/theme/palette.dart';
import 'ui/widgets/backdrop.dart';
import 'ui/widgets/recovery_notice.dart';
import 'bridge/controller.dart';
import 'wallet/controller.dart';
import 'wallet/idle_lock.dart';

/// The app: one window that shows the screen of the stage of the wallet.
class KranoxApp extends StatefulWidget {
  const KranoxApp({super.key, required this.controller, required this.bridge});

  final WalletController controller;
  final BridgeController bridge;

  @override
  State<KranoxApp> createState() => _KranoxAppState();
}

class _KranoxAppState extends State<KranoxApp> {
  // The notice of a damaged file that the app moved aside stays until the user closes it, also across locks. The start
  // reads the settings; the swaps open with the wallet, so their notice can come later.
  late bool _noticeOpen = widget.controller.settingsRecoveredFrom != null;
  String? _swapsNoticed;
  late final AppLifecycleListener _lifecycle;
  late final IdleLock _idle = IdleLock(
    isOpen: () => widget.controller.phase == WalletPhase.open,
    lock: widget.controller.lock,
  );

  @override
  void initState() {
    super.initState();
    // wallet2 writes the state of the wallet to its file when the wallet closes, so the app closes it first. A window
    // that comes back, as after a sleep of the Mac, checks the time without use at once.
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await widget.controller.shutdown();
        return AppExitResponse.exit;
      },
      onResume: () => unawaited(_idle.check()),
      onShow: () => unawaited(_idle.check()),
    );
    // Each key counts as use; the handler lets every key through.
    HardwareKeyboard.instance.addHandler(_onKey);
    widget.controller.addListener(_onPhase);
    widget.bridge.addListener(_onBridge);
    _idle.start();
  }

  bool _onKey(KeyEvent event) {
    _idle.touch();
    return false;
  }

  void _onBridge() {
    final recovered = widget.bridge.recoveredFrom;
    if (recovered == null || recovered == _swapsNoticed) return;
    setState(() {
      _swapsNoticed = recovered;
      _noticeOpen = true;
    });
  }

  // The time without use starts again when the wallet opens, so that a wallet never locks right after its unlock.
  void _onPhase() {
    if (widget.controller.phase == WalletPhase.open) _idle.touch();
  }

  @override
  void dispose() {
    _idle.stop();
    widget.controller.removeListener(_onPhase);
    widget.bridge.removeListener(_onBridge);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: Copy.appName,
    debugShowCheckedModeBanner: false,
    theme: KranoxTheme.build(Palette.of(activeLook)),
    // Each click, scroll, or move of the pointer counts as use.
    home: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _idle.touch(),
      onPointerHover: (_) => _idle.touch(),
      onPointerSignal: (_) => _idle.touch(),
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => switch (widget.controller.phase) {
          WalletPhase.starting => const Backdrop(child: Center(child: CircularProgressIndicator())),
          WalletPhase.noWallet => OnboardingFlow(controller: widget.controller),
          WalletPhase.locked => UnlockScreen(controller: widget.controller),
          WalletPhase.open => WalletShell(
            controller: widget.controller,
            bridge: widget.bridge,
            notice: _noticeOpen
                ? RecoveryNotice(
                    settingsFile: widget.controller.settingsRecoveredFrom,
                    swapsFile: widget.bridge.recoveredFrom,
                    onDismiss: () => setState(() => _noticeOpen = false),
                  )
                : null,
          ),
        },
      ),
    ),
  );
}
