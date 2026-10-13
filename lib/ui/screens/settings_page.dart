import 'package:flutter/material.dart';

import '../../bridge/controller.dart';
import '../../config/app_config.dart';
import '../../config/network.dart';
import '../../core/node_address.dart';
import '../../wallet/controller.dart';
import '../../wallet/failure.dart';
import '../../wallet/tor_service.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/field.dart';
import '../widgets/network_choice.dart';
import '../widgets/page_frame.dart';
import '../widgets/seed_grid.dart';
import '../widgets/surfaces.dart';

/// The settings of the wallet: the node, the relay of the bridge, the network, the seed behind the password, the file,
/// and the lock.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller, required this.bridge, required this.onLock});

  final WalletController controller;
  final BridgeController bridge;
  final VoidCallback onLock;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _node = TextEditingController(text: widget.controller.node);
  // The field shows the proxy of the user, never the proxy of Tor built into the app (W-01).
  late final _proxy = TextEditingController(text: widget.controller.userProxy ?? '');
  final _password = TextEditingController();
  String? _nodeError;
  // A proxy that wallet2 refused at the unlock keeps the wallet offline, so the field says why from the start.
  late String? _proxyError = widget.controller.proxyRefused ? Copy.proxyRefused : null;
  String? _nodeNote;
  bool _savingNode = false;
  bool _switchingNetwork = false;
  String? _seedError;
  bool _readingSeed = false;
  List<String>? _seed;

  @override
  void initState() {
    super.initState();
    widget.bridge.checkRelay();
  }

  @override
  void dispose() {
    _node.dispose();
    _proxy.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Saves the proxy first, so that the new node never sees a request without it, then the node.
  Future<void> _saveNode() async {
    setState(() {
      _nodeError = null;
      _proxyError = null;
      _nodeNote = null;
      _savingNode = true;
    });
    try {
      // While Tor built into the app is on, the field is out of sight and the proxy of the user stays as it is.
      if (!widget.controller.torBuiltIn) {
        try {
          await widget.controller.changeProxy(_proxy.text);
        } on NodeAddressException {
          setState(() => _proxyError = Copy.proxyInvalid);
          return;
        } on WalletException catch (error) {
          setState(() => _proxyError = failureText(error));
          return;
        }
      }
      await widget.controller.changeNode(_node.text);
      setState(() => _nodeNote = Copy.nodeSaved);
    } on NodeAddressException {
      setState(() => _nodeError = Copy.nodeInvalid(widget.controller.network));
    } on WalletException catch (error) {
      setState(() => _nodeError = failureText(error));
    } finally {
      if (mounted) setState(() => _savingNode = false);
    }
  }

  /// Locks this wallet and moves the app to the wallet of another network. The settings page closes with it.
  Future<void> _switchNetwork(MoneroNetwork network) async {
    setState(() => _switchingNetwork = true);
    try {
      await widget.controller.switchNetwork(network);
    } finally {
      if (mounted) setState(() => _switchingNetwork = false);
    }
  }

  Future<void> _showSeed() async {
    setState(() {
      _seedError = null;
      _readingSeed = true;
    });
    try {
      final seed = await widget.controller.readSeed(_password.text);
      _password.clear();
      setState(() => _seed = seed);
    } on WalletException catch (error) {
      setState(() => _seedError = failureText(error));
    } finally {
      if (mounted) setState(() => _readingSeed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final soft = KranoxType.bodyRegular.copyWith(color: palette.inkSoft);
    final seed = _seed;
    return PageFrame(
      title: Copy.settingsTitle,
      lead: Copy.settingsLead,
      chips: [StatusChip(label: widget.controller.network.label)],
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Metrics.formWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CardTitle(Copy.nodeTitle),
                      const SizedBox(height: 4),
                      Text(Copy.nodeLead, style: soft),
                      const SizedBox(height: Metrics.gap),
                      LabeledField(
                        label: Copy.nodeField,
                        controller: _node,
                        hint: Copy.nodeHint,
                        error: _nodeError,
                        note: _nodeNote,
                        onSubmitted: (_) => _saveNode(),
                      ),
                      const SizedBox(height: Metrics.gap),
                      _TorSwitch(controller: widget.controller),
                      const SizedBox(height: Metrics.gap),
                      if (widget.controller.torBuiltIn)
                        Text(Copy.torProxyOff, style: soft)
                      else
                        LabeledField(
                          label: Copy.proxyField,
                          controller: _proxy,
                          hint: Copy.proxyHint,
                          error: _proxyError,
                          note: Copy.proxyNote,
                          onSubmitted: (_) => _saveNode(),
                        ),
                      const SizedBox(height: Metrics.gap),
                      PillButton(label: Copy.saveNode, busy: _savingNode, onPressed: _saveNode),
                    ],
                  ),
                ),
                const SizedBox(height: Metrics.gap),
                _RelayCard(bridge: widget.bridge, proxy: widget.controller.proxy, tor: widget.controller.torBuiltIn),
                const SizedBox(height: Metrics.gap),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CardTitle(Copy.networkTitle),
                      const SizedBox(height: 4),
                      Text(Copy.networkLead, style: soft),
                      const SizedBox(height: Metrics.gap),
                      NetworkChoice(
                        network: widget.controller.network,
                        onSelect: _switchingNetwork ? null : _switchNetwork,
                      ),
                      const SizedBox(height: Metrics.gapSmall),
                      Text(
                        Copy.networkNote(widget.controller.network),
                        style: KranoxType.small.copyWith(color: palette.inkFaint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Metrics.gap),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CardTitle(Copy.seed),
                      const SizedBox(height: 4),
                      Text(seed == null ? Copy.seedSettingsLead : Copy.seedLead, style: soft),
                      const SizedBox(height: Metrics.gap),
                      if (seed != null) ...[
                        SeedGrid(words: seed),
                        const SizedBox(height: Metrics.gap),
                        PillButton(
                          label: Copy.hideSeed,
                          tone: PillTone.quiet,
                          onPressed: () => setState(() => _seed = null),
                        ),
                      ] else ...[
                        LabeledField(
                          label: Copy.password,
                          controller: _password,
                          obscure: true,
                          error: _seedError,
                          onSubmitted: (_) => _showSeed(),
                        ),
                        const SizedBox(height: Metrics.gap),
                        PillButton(
                          label: Copy.showSeed,
                          tone: PillTone.solid,
                          busy: _readingSeed,
                          onPressed: _showSeed,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Metrics.gap),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CardTitle(Copy.walletFileTitle),
                      const SizedBox(height: Metrics.gapSmall),
                      SelectableText(
                        widget.controller.walletFolder,
                        style: KranoxType.mono.copyWith(color: palette.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Metrics.gap),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CardTitle(Copy.navLock),
                      const SizedBox(height: 4),
                      Text(Copy.lockLead, style: soft),
                      const SizedBox(height: Metrics.gap),
                      PillButton(
                        label: Copy.lockNow,
                        tone: PillTone.solid,
                        icon: Icons.lock_rounded,
                        onPressed: widget.onLock,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The relay of the bridge: its address and whether it answers. The app does not let the user change it: another
/// relay would need its own key of ChangeNOW. The address is fixed in [AppConfig.bridgeRelay].
class _RelayCard extends StatelessWidget {
  const _RelayCard({required this.bridge, required this.proxy, required this.tor});

  final BridgeController bridge;

  /// The proxy of the settings, which the words about the trouble name, unless it is Tor built into the app ([tor]).
  final String? proxy;
  final bool tor;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: bridge,
    builder: (context, _) {
      final palette = context.palette;
      final online = bridge.relayOnline;
      final chip = bridge.checkingRelay || online == null
          ? StatusChip(label: Copy.relayChecking, dot: palette.dotOff)
          : online
          ? StatusChip(label: Copy.relayOnline, dot: palette.accent)
          : StatusChip(label: Copy.relayOffline, dot: palette.danger);
      return Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardTitle(Copy.relayTitle, trailing: chip),
            const SizedBox(height: 4),
            Text(Copy.relayLead, style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft)),
            const SizedBox(height: Metrics.gap),
            Row(
              children: [
                Expanded(
                  child: SelectableText(AppConfig.bridgeRelay, style: KranoxType.mono.copyWith(color: palette.ink)),
                ),
                PillButton(
                  label: Copy.relayCheck,
                  tone: PillTone.quiet,
                  busy: bridge.checkingRelay,
                  onPressed: bridge.checkRelay,
                ),
              ],
            ),
            if (bridge.lookingForRelay)
              Padding(
                padding: const EdgeInsets.only(top: Metrics.gapSmall),
                child: Text(Copy.relayLooking, style: KranoxType.small.copyWith(color: palette.inkSoft)),
              )
            else if (bridge.relayOnline == false)
              Padding(
                padding: const EdgeInsets.only(top: Metrics.gapSmall),
                child: Text(switch (bridge.relayTrouble) {
                  final trouble? => relayTroubleText(trouble, proxy: proxy, tor: tor),
                  null => Copy.relayTroubleSilent,
                }, style: KranoxType.small.copyWith(color: palette.danger)),
              ),
          ],
        ),
      );
    },
  );
}

/// The switch of Tor built into the app, from 13 Oct 2026, with where Tor stands: off, connecting, on, or failed with
/// a way to try again. The controller starts and stops Tor and connects the wallet accordingly.
class _TorSwitch extends StatelessWidget {
  const _TorSwitch({required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final soft = KranoxType.bodyRegular.copyWith(color: palette.inkSoft);
    final tor = controller.tor;
    final on = controller.torBuiltIn;
    final state = on ? tor?.state : null;
    final (chip, line) = switch (state) {
      null => (StatusChip(label: Copy.torStatusOff, dot: palette.dotOff), Copy.torLineOff),
      TorState.on => (StatusChip(label: Copy.torStatusOn, dot: palette.accent), Copy.torLineOn),
      TorState.failed => (StatusChip(label: Copy.torStatusFailed, dot: palette.danger), Copy.torLineFailed),
      TorState.off ||
      TorState.starting => (StatusChip(label: Copy.torStatusStarting, dot: palette.dotOff), Copy.torLineStarting),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(Copy.torSwitch, style: KranoxType.cardTitle.copyWith(color: palette.ink)),
            ),
            Switch.adaptive(
              value: on,
              activeTrackColor: palette.accent,
              onChanged: tor == null || controller.torSwitching ? null : (value) => controller.changeTorBuiltIn(value),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(Copy.torSwitchNote, style: soft),
        const SizedBox(height: Metrics.gapSmall),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Metrics.gapSmall,
          runSpacing: Metrics.gapSmall,
          children: [
            chip,
            if (state == TorState.failed)
              PillButton(label: Copy.torTryAgain, tone: PillTone.quiet, onPressed: controller.retryTor),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          line,
          style: KranoxType.small.copyWith(color: state == TorState.failed ? palette.danger : palette.inkSoft),
        ),
        if (state == TorState.failed && tor?.failure != null) ...[
          const SizedBox(height: 4),
          Text(
            Copy.torFailureReason(torFailureText(tor!.failure!)),
            style: KranoxType.small.copyWith(color: soft.color),
          ),
        ],
      ],
    );
  }
}
