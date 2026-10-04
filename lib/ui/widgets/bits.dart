import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../copy.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';

/// A small pill with a label in capitals, and a dot for a state, such as the network and the node.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.dot});

  final String label;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Metrics.radiusPill),
        border: Border.all(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              DecoratedBox(
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: 7),
              ),
              const SizedBox(width: 8),
            ],
            Text(label.toUpperCase(), style: KranoxType.label.copyWith(color: palette.ink)),
          ],
        ),
      ),
    );
  }
}

/// A large thin figure with its unit, such as a balance.
class AmountFigure extends StatelessWidget {
  const AmountFigure({super.key, required this.value, required this.style, required this.unitStyle, this.color});

  final String value;
  final TextStyle style;
  final TextStyle unitStyle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? context.palette.ink;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: style.copyWith(color: ink),
          ),
          TextSpan(
            text: ' ${Copy.currency}',
            style: unitStyle.copyWith(color: ink),
          ),
        ],
      ),
    );
  }
}

/// The progress of the scan of the chain as a bar of dots. A reached dot has the accent color.
class SyncDots extends StatelessWidget {
  const SyncDots({super.key, required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reached = (share * Metrics.syncDots).floor();
    return LayoutBuilder(
      builder: (context, constraints) {
        final dot = (constraints.maxWidth - Metrics.syncDotGap * (Metrics.syncDotsPerRow - 1)) / Metrics.syncDotsPerRow;
        return Wrap(
          spacing: Metrics.syncDotGap,
          runSpacing: Metrics.syncDotGap,
          children: [
            for (var index = 0; index < Metrics.syncDots; index++)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: index < reached ? palette.accent : palette.dotOff,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: dot),
              ),
          ],
        );
      },
    );
  }
}

/// A line of text in the color of a failure.
class ErrorLine extends StatelessWidget {
  const ErrorLine(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Metrics.gapSmall),
      child: Text(text, style: KranoxType.small.copyWith(color: context.palette.danger)),
    );
  }
}

/// Puts a text on the clipboard and says so.
Future<void> copyToClipboard(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: text));
  messenger.showSnackBar(const SnackBar(content: Text(Copy.copied), duration: Duration(seconds: 2)));
}
