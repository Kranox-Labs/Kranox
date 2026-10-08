import 'package:flutter/material.dart';

import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';

/// A page of the open wallet: a title, a short line below it, chips at the right, and the content below. A [centered]
/// page puts all of it in one column of [width] in the middle, with the chips under the line, after the home of Vizor;
/// the owner asked for it on the send page on 5 Oct 2026.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.lead,
    required this.children,
    this.chips = const [],
    this.centered = false,
    this.width = Metrics.centerColumnWidth,
  });

  final String title;
  final String lead;
  final List<Widget> chips;
  final List<Widget> children;
  final bool centered;

  /// The width of the column of a [centered] page.
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (centered) {
      return SingleChildScrollView(
        padding: Metrics.centeredPagePadding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: KranoxType.pageTitle.copyWith(color: palette.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  lead,
                  textAlign: TextAlign.center,
                  style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: Metrics.gapSmall),
                  Wrap(alignment: WrapAlignment.center, spacing: 8, children: chips),
                ],
                const SizedBox(height: Metrics.gap + 10),
                ...children,
              ],
            ),
          ),
        ),
      );
    }
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
