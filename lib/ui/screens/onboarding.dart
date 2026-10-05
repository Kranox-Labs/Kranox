import 'package:flutter/material.dart';

import '../../config/network.dart';
import '../../core/block_height.dart';
import '../../core/seed.dart';
import '../../wallet/controller.dart';
import '../../wallet/failure.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import '../widgets/backdrop.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/field.dart';
import '../widgets/network_choice.dart';
import '../widgets/seed_grid.dart';
import '../widgets/surfaces.dart';

/// The frame of the screens before the wallet opens: the logo, a title, a short text, and the content, in one
/// column in the middle of the window.
class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    required this.title,
    required this.lead,
    required this.children,
    this.wide = false,
  });

  final String title;
  final String lead;
  final List<Widget> children;

  /// A wide frame holds the seed: five words in a row.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Backdrop(
        showArt: true,
        child: Center(
          child: SingleChildScrollView(
            padding: Metrics.pagePadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? Metrics.onboardingWideWidth : Metrics.onboardingWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: Alignment.centerLeft, child: Image.asset('assets/images/logo.png', height: 44)),
                  const SizedBox(height: Metrics.gap + 4),
                  Text(title, style: KranoxType.onboardingTitle.copyWith(color: palette.ink)),
                  const SizedBox(height: Metrics.gapSmall),
                  Text(lead, style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft)),
                  const SizedBox(height: Metrics.gap + 8),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The screens for a device without a wallet: the welcome, the creation of a wallet, and its restore.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.controller});

  final WalletController controller;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _Step { welcome, create, restore }

class _OnboardingFlowState extends State<OnboardingFlow> {
  _Step _step = _Step.welcome;

  void _go(_Step step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) => switch (_step) {
    _Step.welcome => _Welcome(
      network: widget.controller.network,
      onNetwork: widget.controller.switchNetwork,
      onCreate: () => _go(_Step.create),
      onRestore: () => _go(_Step.restore),
    ),
    _Step.create => _Create(controller: widget.controller, onBack: () => _go(_Step.welcome)),
    _Step.restore => _Restore(controller: widget.controller, onBack: () => _go(_Step.welcome)),
  };
}

/// The first screen on a network without a wallet: one card of glass in the middle of the window, over the picture
/// of the look, with the choice of the network at its foot.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.network, required this.onNetwork, required this.onCreate, required this.onRestore});

  final MoneroNetwork network;
  final ValueChanged<MoneroNetwork> onNetwork;
  final VoidCallback onCreate;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Backdrop(
        showArt: true,
        child: Center(
          child: SingleChildScrollView(
            padding: Metrics.pagePadding,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Metrics.welcomeCardWidth),
              child: GlassCard(
                padding: Metrics.welcomeCardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/images/logo.png', height: Metrics.welcomeLogoHeight),
                    const SizedBox(height: Metrics.gap + 6),
                    Text(
                      Copy.welcomeTitle,
                      textAlign: TextAlign.center,
                      style: KranoxType.onboardingTitle.copyWith(color: palette.ink),
                    ),
                    const SizedBox(height: Metrics.gapSmall),
                    Text(
                      Copy.welcomeLead,
                      textAlign: TextAlign.center,
                      style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft),
                    ),
                    const SizedBox(height: Metrics.gap + 10),
                    PillButton(label: Copy.createWallet, expand: true, onPressed: onCreate),
                    const SizedBox(height: Metrics.gapSmall),
                    PillButton(label: Copy.restoreWallet, tone: PillTone.quiet, expand: true, onPressed: onRestore),
                    const SizedBox(height: Metrics.gap + 4),
                    NetworkChoice(network: network, onSelect: onNetwork, alignment: WrapAlignment.center),
                    const SizedBox(height: Metrics.gapSmall),
                    Text(
                      Copy.networkNote(network, lineBreak: true),
                      textAlign: TextAlign.center,
                      style: KranoxType.small.copyWith(color: palette.inkFaint),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Create extends StatefulWidget {
  const _Create({required this.controller, required this.onBack});

  final WalletController controller;
  final VoidCallback onBack;

  @override
  State<_Create> createState() => _CreateState();
}

class _CreateState extends State<_Create> {
  final _password = TextEditingController();
  final _repeated = TextEditingController();
  String? _error;
  bool _busy = false;
  List<String>? _seed;
  bool _wroteDown = false;

  @override
  void dispose() {
    _password.dispose();
    _repeated.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final problem = passwordProblem(_password.text, _repeated.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    await _run(() async {
      final seed = await widget.controller.create(_password.text);
      _password.clear();
      _repeated.clear();
      setState(() => _seed = seed);
    });
  }

  Future<void> _enter() => _run(widget.controller.enterWallet);

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on WalletException catch (error) {
      setState(() => _error = failureText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seed = _seed;
    if (seed != null) {
      return OnboardingFrame(
        title: Copy.seedTitle,
        lead: Copy.seedLead,
        wide: true,
        children: [
          SeedGrid(words: seed),
          const SizedBox(height: Metrics.gap),
          // The tile paints its ink on a Material, and the ground of the backdrop lies under it.
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              value: _wroteDown,
              onChanged: (value) => setState(() => _wroteDown = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: context.palette.accent,
              title: Text(Copy.seedConfirm, style: KranoxType.body.copyWith(color: context.palette.ink)),
            ),
          ),
          ErrorLine(_error),
          const SizedBox(height: Metrics.gap),
          PillButton(
            label: Copy.enterWallet,
            busy: _busy,
            busyLabel: Copy.opening,
            expand: true,
            onPressed: _wroteDown ? _enter : null,
          ),
        ],
      );
    }
    return OnboardingFrame(
      title: Copy.createTitle,
      lead: Copy.createLead,
      children: [
        LabeledField(label: Copy.password, controller: _password, obscure: true, autofocus: true),
        const SizedBox(height: Metrics.gap),
        LabeledField(label: Copy.confirmPassword, controller: _repeated, obscure: true, onSubmitted: (_) => _create()),
        ErrorLine(_error),
        const SizedBox(height: Metrics.gap + 4),
        PillButton(label: Copy.createAction, busy: _busy, busyLabel: Copy.creating, expand: true, onPressed: _create),
        const SizedBox(height: Metrics.gapSmall),
        PillButton(label: Copy.back, tone: PillTone.quiet, expand: true, onPressed: _busy ? null : widget.onBack),
        _NetworkLine(widget.controller.network),
      ],
    );
  }
}

class _Restore extends StatefulWidget {
  const _Restore({required this.controller, required this.onBack});

  final WalletController controller;
  final VoidCallback onBack;

  @override
  State<_Restore> createState() => _RestoreState();
}

class _RestoreState extends State<_Restore> {
  final _seed = TextEditingController();
  final _height = TextEditingController();
  final _password = TextEditingController();
  final _repeated = TextEditingController();
  String? _seedError;
  String? _heightError;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_seed, _height, _password, _repeated]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _restore() async {
    List<String>? seed;
    int? height;
    setState(() {
      _seedError = null;
      _heightError = null;
      _error = passwordProblem(_password.text, _repeated.text);
    });
    try {
      seed = parseSeed(_seed.text);
    } on SeedFormatException catch (error) {
      setState(() => _seedError = seedProblemText(error));
    }
    try {
      height = parseRestoreHeight(_height.text);
    } on BlockHeightException {
      setState(() => _heightError = Copy.restoreHeightInvalid);
    }
    if (seed == null || height == null || _error != null) return;
    setState(() => _busy = true);
    try {
      await widget.controller.restore(seed: seed, restoreHeight: height, password: _password.text);
    } on WalletException catch (error) {
      setState(() => _error = failureText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OnboardingFrame(
    title: Copy.restoreTitle,
    lead: Copy.restoreLead,
    children: [
      LabeledField(
        label: Copy.seed,
        controller: _seed,
        hint: Copy.seedHint,
        error: _seedError,
        lines: 3,
        autofocus: true,
      ),
      const SizedBox(height: Metrics.gap),
      LabeledField(
        label: Copy.restoreHeight,
        controller: _height,
        hint: Copy.restoreHeightHint,
        error: _heightError,
        note: Copy.restoreHeightNote,
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: Metrics.gap),
      LabeledField(label: Copy.password, controller: _password, obscure: true),
      const SizedBox(height: Metrics.gap),
      LabeledField(label: Copy.confirmPassword, controller: _repeated, obscure: true, onSubmitted: (_) => _restore()),
      ErrorLine(_error),
      const SizedBox(height: Metrics.gap + 4),
      PillButton(label: Copy.restoreAction, busy: _busy, busyLabel: Copy.restoring, expand: true, onPressed: _restore),
      const SizedBox(height: Metrics.gapSmall),
      PillButton(label: Copy.back, tone: PillTone.quiet, expand: true, onPressed: _busy ? null : widget.onBack),
      _NetworkLine(widget.controller.network),
    ],
  );
}

/// The screen that asks for the password of the wallet on this device.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, required this.controller});

  final WalletController controller;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  /// Moves to the wallet of another network. The password of this wallet does not belong there.
  void _switchNetwork(MoneroNetwork network) {
    _password.clear();
    setState(() => _error = null);
    widget.controller.switchNetwork(network);
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.unlock(_password.text);
    } on WalletException catch (error) {
      setState(() => _error = failureText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OnboardingFrame(
    title: Copy.unlockTitle,
    lead: Copy.unlockLead,
    children: [
      LabeledField(
        label: Copy.password,
        controller: _password,
        obscure: true,
        autofocus: true,
        error: _error,
        onSubmitted: (_) => _unlock(),
      ),
      const SizedBox(height: Metrics.gap + 4),
      PillButton(label: Copy.unlockAction, busy: _busy, busyLabel: Copy.opening, expand: true, onPressed: _unlock),
      const SizedBox(height: Metrics.gap + 8),
      NetworkChoice(network: widget.controller.network, onSelect: _busy ? null : _switchNetwork),
      _NetworkLine(widget.controller.network),
    ],
  );
}

/// The note on the network of the wallet, at the foot of a screen before the wallet opens.
class _NetworkLine extends StatelessWidget {
  const _NetworkLine(this.network);

  final MoneroNetwork network;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Metrics.gapSmall),
    child: Text(Copy.networkNote(network), style: KranoxType.small.copyWith(color: context.palette.inkFaint)),
  );
}
