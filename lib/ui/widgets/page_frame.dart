import 'package:flutter/material.dart';

import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';

/// A page of the open wallet: a title, a short line below it, chips at the right, and the content below.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.title, required this.lead, required this.children, this.chips = const []});

  final String title;
  final String lead;
  final List<Widget> chips;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SingleChildScrollView(
      padding: Metrics.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KranoxType.pageTitle.copyWith(color: palette.ink)),
                    const SizedBox(height: 4),
                    Text(lead, style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft)),
                  ],
                ),
              ),
              Wrap(spacing: 8, children: chips),
            ],
          ),
          const SizedBox(height: Metrics.gap + 4),
          ...children,
        ],
      ),
    );
  }
}

/// The title of a card, with an optional part at its right.
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(text, style: KranoxType.cardTitle.copyWith(color: context.palette.ink)),
      ),
      ?trailing,
    ],
  );
}
