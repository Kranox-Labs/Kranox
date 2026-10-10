import 'package:flutter/material.dart';

import '../../bridge/models.dart';

import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import 'bits.dart';
import 'buttons.dart';
import 'page_frame.dart';
import 'surfaces.dart';

// The steps of a swap of the bridge, from its deposit to its payout, as the receive and the send pages show them.

/// How a step of a swap stands, for its mark.
enum SwapMark { done, active, pending, failed, held, refunded, expired }

/// One step of a swap: its mark, its title, and its facts.
final class SwapStep {
  const SwapStep(this.mark, this.title, [this.facts = const []]);

  final SwapMark mark;
  final String title;
  final List<Widget> facts;
}

/// A step: its mark on a line that joins the marks, beside its title and its facts.
class SwapStepRow extends StatelessWidget {
  const SwapStepRow({super.key, required this.step, required this.last, required this.nextMark});

  final SwapStep step;
  final bool last;
  final SwapMark? nextMark;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reachedNext = nextMark == SwapMark.done || nextMark == SwapMark.active;
    final titleColor = switch (step.mark) {
      SwapMark.pending => palette.inkFaint,
      SwapMark.failed => palette.danger,
      _ => palette.ink,
    };
    // The line to the next mark hangs beside the row, so that it reaches as far down as the facts of the step go.
    return Stack(
      children: [
        if (!last)
          Positioned(
            left: (Metrics.stepMark - Metrics.stepLine) / 2,
            top: Metrics.stepMark,
            bottom: 0,
            child: Container(width: Metrics.stepLine, color: reachedNext ? palette.accent : palette.line),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: last ? 0 : Metrics.gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepMark(mark: step.mark),
              const SizedBox(width: Metrics.gapSmall + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: Metrics.stepMark,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(step.title, style: KranoxType.body.copyWith(color: titleColor)),
                      ),
                    ),
                    for (final fact in step.facts) ...[const SizedBox(height: Metrics.gapTiny), fact],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The mark of a step: a check when done, a spinner while it runs, an empty ring before it, and a sign for a
/// failure, a check, a refund, and a deposit that did not come in time.
class _StepMark extends StatelessWidget {
  const _StepMark({required this.mark});

  final SwapMark mark;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget filled(Color color, IconData icon, Color ink) => DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(child: Icon(icon, size: 15, color: ink)),
    );
    Widget ring(Color color, {Widget? child}) => DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: child == null ? null : Center(child: child),
    );
    return SizedBox.square(
      dimension: Metrics.stepMark,
      child: switch (mark) {
        SwapMark.done => filled(palette.accent, Icons.check_rounded, palette.onAccent),
        SwapMark.failed => filled(palette.danger, Icons.close_rounded, palette.onAccent),
        SwapMark.active => Padding(
          padding: const EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2.4, color: palette.accent, backgroundColor: palette.line),
        ),
        SwapMark.held => ring(palette.accent, child: Icon(Icons.pause_rounded, size: 14, color: palette.accent)),
        SwapMark.refunded => ring(palette.accent, child: Icon(Icons.undo_rounded, size: 14, color: palette.accent)),
        SwapMark.expired => ring(
          palette.inkSoft,
          child: Icon(Icons.schedule_rounded, size: 14, color: palette.inkSoft),
        ),
        SwapMark.pending => ring(palette.line),
      },
    );
  }
}

/// The head of the card of a swap, under the title of its page: when it started and last changed; while it runs, when
/// the app last checked it with the exchanger, with a button to check it now, and [notes] that tell the user what to
/// expect. The owner asked on 6 Oct 2026 for a card that keeps a user calm through a long wait.
class SwapCardHeader extends StatelessWidget {
  const SwapCardHeader({
    super.key,
    required this.swap,
    required this.checkedAt,
    required this.onRefresh,
    this.notes = const [],
  });

  final BridgeSwap swap;
  final DateTime? checkedAt;
  final Future<void> Function() onRefresh;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    final updated = swap.updatedAt;
    final checked = checkedAt;
    final running = !swap.stage.isFinal;
    final soft = KranoxType.small.copyWith(color: palette.inkSoft);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Copy.bridgeSwapTimes(
                  formatTime(swap.createdAt, now),
                  updated == null ? null : formatTime(updated, now),
                  checked: running && checked != null ? formatClock(checked) : null,
                ),
                style: soft,
              ),
              if (running)
                for (final note in notes) ...[const SizedBox(height: 2), Text(note, style: soft)],
            ],
          ),
        ),
        if (running) ...[
          const SizedBox(width: Metrics.gapSmall),
          PillButton(label: Copy.bridgeRefresh, tone: PillTone.quiet, onPressed: onRefresh),
        ],
      ],
    );
  }
}

/// A sentence about a step.
class SwapFact extends StatelessWidget {
  const SwapFact(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: KranoxType.small.copyWith(color: context.palette.inkSoft, height: 1.45));
}

/// A value of a step that the user may need elsewhere, such as a transaction hash, with a button that copies it.
class SwapCopyLine extends StatelessWidget {
  const SwapCopyLine({super.key, required this.label, required this.value, this.shorten = true});

  final String label;
  final String value;
  final bool shorten;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${label.toUpperCase()}  ', style: KranoxType.label.copyWith(color: palette.inkSoft)),
        Text(shorten ? shortText(value) : value, style: KranoxType.mono.copyWith(color: palette.ink)),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => copyToClipboard(context, value),
          tooltip: Copy.copy,
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          icon: Icon(Icons.copy_rounded, color: palette.inkSoft),
        ),
      ],
    );
  }
}

/// The steps of a swap as it stands: the steps of a good swap up to the furthest one it reached, then either the rest
/// of the way, or the check, the failure, the refund, or the end of the wait in place of the step where it stopped.
/// [step] gives a step of the way with its mark, and [refunded], [failed], and [expired] the step that ends a swap that
/// went wrong.
List<SwapStep> swapSteps(
  BridgeSwap swap, {
  required SwapStep Function(SwapStage stage, SwapMark mark) step,
  required SwapStep refunded,
  required SwapStep failed,
  required SwapStep expired,
}) {
  final stage = swap.stage;
  final path = SwapStage.path;
  final reached = path.indexOf(swap.reached);
  if (!stage.isOffPath) {
    final current = path.indexOf(stage);
    return [
      for (var index = 0; index < path.length; index++)
        step(
          path[index],
          index < current || stage == SwapStage.finished
              ? SwapMark.done
              : index == current
              ? SwapMark.active
              : SwapMark.pending,
        ),
    ];
  }
  final before = [for (var index = 0; index < reached; index++) step(path[index], SwapMark.done)];
  return switch (stage) {
    // ChangeNOW checks a swap after the deposit, so the steps up to the furthest one show as done.
    SwapStage.verifying => [
      ...before,
      step(path[reached], SwapMark.done),
      const SwapStep(SwapMark.held, Copy.bridgeStepHeld, [SwapFact(Copy.bridgeHeld)]),
      for (var index = reached + 1; index < path.length; index++) step(path[index], SwapMark.pending),
    ],
    SwapStage.refunded => [...before, refunded],
    SwapStage.expired => [...before, expired],
    _ => [...before, failed],
  };
}

/// The mark of a swap as it stands, for its card in a list: a spinner while it runs, and the mark of the step where it
/// ended.
SwapMark swapMarkOf(SwapStage stage) => switch (stage) {
  SwapStage.finished => SwapMark.done,
  SwapStage.failed => SwapMark.failed,
  SwapStage.refunded => SwapMark.refunded,
  SwapStage.expired => SwapMark.expired,
  SwapStage.verifying => SwapMark.held,
  SwapStage.waiting || SwapStage.confirming || SwapStage.exchanging || SwapStage.sending => SwapMark.active,
};

/// The swaps of one way that a page keeps in view under its form, the newest first: every one that runs, and every one
/// that ended until the user closes it. The owner asked on 10 Oct 2026 for each in a simple card of its own, so that a
/// user can start another swap while one runs, and for its steps on a page of its own, which a click on the card
/// opens through [onOpen]. Without swaps it shows nothing; with swaps, it keeps the room of a gap above them.
class SwapCards extends StatelessWidget {
  const SwapCards({super.key, required this.title, required this.swaps, required this.headline, required this.onOpen});

  final String title;
  final List<BridgeSwap> swaps;

  /// The title of a swap, as its page names it.
  final String Function(BridgeSwap swap) headline;
  final ValueChanged<BridgeSwap> onOpen;

  @override
  Widget build(BuildContext context) {
    if (swaps.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Metrics.gapTiny, top: Metrics.gap, bottom: Metrics.gapSmall),
          child: Text(title.toUpperCase(), style: KranoxType.label.copyWith(color: palette.inkSoft)),
        ),
        for (final (index, swap) in swaps.indexed) ...[
          if (index > 0) const SizedBox(height: Metrics.gapSmall),
          _Opens(
            onTap: () => onOpen(swap),
            child: Surface(
              padding: const EdgeInsets.symmetric(horizontal: Metrics.heroPadding, vertical: Metrics.tilePadding),
              child: Row(
                children: [
                  _StepMark(mark: swapMarkOf(swap.stage)),
                  const SizedBox(width: Metrics.checkMarkGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(headline(swap), style: KranoxType.cardTitle.copyWith(color: palette.ink)),
                        const SizedBox(height: 4),
                        Text(
                          '${Copy.swapStage(swap.direction, swap.stage)} · '
                          '${Copy.bridgeSwapTimes(formatTime(swap.createdAt, now), null)}',
                          style: KranoxType.small.copyWith(
                            color: swap.stage == SwapStage.failed ? palette.danger : palette.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Metrics.gapSmall),
                  Icon(Icons.chevron_right_rounded, color: palette.inkFaint),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A part that opens something with a click, with the hand of a link over it.
class _Opens extends StatelessWidget {
  const _Opens({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
    ),
  );
}

/// The swaps of one way on this device, the newest first, with their state: [line] names each one, and [trailing]
/// gives its amount, or null when it has none to show. A click on a line opens the page of its swap through [onOpen],
/// so that the transactions of an older swap stay at hand.
class SwapHistory extends StatelessWidget {
  const SwapHistory({
    super.key,
    required this.title,
    required this.swaps,
    required this.line,
    required this.trailing,
    required this.onOpen,
  });

  final String title;
  final List<BridgeSwap> swaps;
  final String Function(BridgeSwap swap) line;
  final String? Function(BridgeSwap swap) trailing;
  final ValueChanged<BridgeSwap> onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitle(title),
          const SizedBox(height: Metrics.gapSmall),
          for (final swap in swaps)
            _Opens(
              onTap: () => onOpen(swap),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line(swap), style: KranoxType.body.copyWith(color: palette.ink)),
                          Text(
                            '${formatTime(swap.createdAt, now)} · ${Copy.swapStage(swap.direction, swap.stage)}',
                            style: KranoxType.small.copyWith(
                              color: swap.stage == SwapStage.failed ? palette.danger : palette.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trailing(swap) case final amount?)
                      Text(amount, style: KranoxType.body.copyWith(color: palette.ink)),
                    const SizedBox(width: Metrics.gapTiny),
                    Icon(Icons.chevron_right_rounded, size: 20, color: palette.inkFaint),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
