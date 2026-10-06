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
enum SwapMark { done, active, pending, failed, held, refunded }

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
/// failure, a check, and a refund.
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
        SwapMark.pending => ring(palette.line),
      },
    );
  }
}

/// The head of the card of a swap: its title, with a button to check it now while it runs; when it started and last
/// changed; while it runs, when the app last checked it with the exchanger, and [notes] that tell the user what to
/// expect. The owner asked on 6 Oct 2026 for a card that keeps a user calm through a long wait.
class SwapCardHeader extends StatelessWidget {
  const SwapCardHeader({
    super.key,
    required this.title,
    required this.swap,
    required this.checkedAt,
    required this.onRefresh,
    this.notes = const [],
  });

  final String title;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardTitle(
          title,
          trailing: running ? PillButton(label: Copy.bridgeRefresh, tone: PillTone.quiet, onPressed: onRefresh) : null,
        ),
        const SizedBox(height: 4),
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
/// of the way, or the check, the failure, or the refund in place of the step where it stopped. [step] gives a step of
/// the way with its mark, and [refunded] and [failed] the step that ends a swap that went wrong.
List<SwapStep> swapSteps(
  BridgeSwap swap, {
  required SwapStep Function(SwapStage stage, SwapMark mark) step,
  required SwapStep refunded,
  required SwapStep failed,
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
    _ => [...before, failed],
  };
}

/// The swaps of one way on this device, the newest first, with their state: [line] names each one, and [trailing]
/// gives its amount, or null when it has none to show.
class SwapHistory extends StatelessWidget {
  const SwapHistory({super.key, required this.title, required this.swaps, required this.line, required this.trailing});

  final String title;
  final List<BridgeSwap> swaps;
  final String Function(BridgeSwap swap) line;
  final String? Function(BridgeSwap swap) trailing;

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
            Padding(
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
                ],
              ),
            ),
        ],
      ),
    );
  }
}
