import 'package:flutter/widgets.dart';

import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';

/// The words of a seed with their numbers, in five columns, so that the user can copy them by hand in order.
class SeedGrid extends StatelessWidget {
  const SeedGrid({super.key, required this.words});

  final List<String> words;

  static const int _columns = 5;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - Metrics.gapSmall * (_columns - 1)) / _columns;
        return Wrap(
          spacing: Metrics.gapSmall,
          runSpacing: Metrics.gapSmall,
          children: [
            for (final (index, word) in words.indexed)
              SizedBox(
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.field,
                    borderRadius: BorderRadius.circular(Metrics.radiusField),
                    border: Border.all(color: palette.line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text('${index + 1}', style: KranoxType.small.copyWith(color: palette.inkFaint)),
                        ),
                        // A long word grows smaller rather than break into two lines.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(word, maxLines: 1, style: KranoxType.body.copyWith(color: palette.ink)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
