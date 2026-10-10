import 'package:flutter/material.dart';

import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';

/// One line of a review or a receipt: its label at the left, and its value, as text or as a widget, beside it.
class ReviewLine extends StatelessWidget {
  const ReviewLine({super.key, required this.label, this.value, this.child, this.strong = false});

  final String label;
  final String? value;
  final Widget? child;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: KranoxType.small.copyWith(color: palette.inkSoft)),
          ),
          Expanded(
            child:
                child ??
                Text(
                  value ?? '',
                  style: (strong ? KranoxType.cardTitle : KranoxType.body).copyWith(color: palette.ink),
                ),
          ),
        ],
      ),
    );
  }
}

/// The whole address of a review in a box, so that the user can check it character by character, and a check of it
/// under a hairline.
class ReviewAddress extends StatelessWidget {
  const ReviewAddress({super.key, required this.label, required this.address, this.check});

  final String label;
  final String address;
  final Widget? check;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.field,
        borderRadius: BorderRadius.circular(Metrics.radiusField),
        border: Border.all(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Metrics.addressBoxPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: KranoxType.label.copyWith(color: palette.inkSoft)),
            const SizedBox(height: Metrics.gapTiny),
            SelectableText(address, style: KranoxType.mono.copyWith(color: palette.ink)),
            if (check case final check?) ...[
              const SizedBox(height: Metrics.gapSmall),
              Divider(height: 1, color: palette.line),
              const SizedBox(height: Metrics.gapSmall),
              check,
            ],
          ],
        ),
      ),
    );
  }
}
