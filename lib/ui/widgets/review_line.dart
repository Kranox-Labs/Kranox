import 'package:flutter/material.dart';

import '../theme/kranox_theme.dart';
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
