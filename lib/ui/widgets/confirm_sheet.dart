import 'package:flutter/material.dart';

import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import 'buttons.dart';
import 'page_frame.dart';
import 'surfaces.dart';

/// Asks the user a question over the page, on a card of the look, and answers whether the user confirmed. A click
/// outside the card or an escape answers no.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String text,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final palette = context.palette;
  final answer = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Metrics.formWidth),
        child: Surface(
          padding: const EdgeInsets.all(Metrics.heroPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardTitle(title),
              const SizedBox(height: Metrics.gapSmall),
              Text(text, style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft)),
              const SizedBox(height: Metrics.gap),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PillButton(
                    label: cancelLabel,
                    tone: PillTone.quiet,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: Metrics.gapSmall),
                  PillButton(
                    label: confirmLabel,
                    tone: PillTone.solid,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return answer ?? false;
}
