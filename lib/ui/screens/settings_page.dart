import 'package:flutter/material.dart';

import '../../bridge/controller.dart';
import '../../config/app_config.dart';
import '../../config/network.dart';
import '../../core/node_address.dart';
import '../../wallet/controller.dart';
import '../../wallet/failure.dart';
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
  final _password = TextEditingController();
  String? _nodeError;
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
    _password.dispose();
    super.dispose();
  }

  Future<void> _saveNode() async {
    setState(() {
      _nodeError = null;
      _nodeNote = null;
      _savingNode = true;
    });
    try {
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
                      PillButton(label: Copy.saveNode, busy: _savingNode, onPressed: _saveNode),
                    ],
                  ),
                ),
                const SizedBox(height: Metrics.gap),
                _RelayCard(bridge: widget.bridge),
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
  const _RelayCard({required this.bridge});

  final BridgeController bridge;

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
          ],
        ),
      );
    },
  );
}
