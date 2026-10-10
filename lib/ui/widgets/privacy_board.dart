import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../copy.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import 'bits.dart';
import 'surfaces.dart';

/// What a check found: nothing to improve, something to improve, a note that asks for nothing, or nothing yet, such as
/// a check of an address before its scan.
enum CheckState { good, warning, note, pending }

/// A figure of a check, such as the count of transactions of an address: the value large, its name below.
final class CheckStat {
  const CheckStat({required this.value, required this.label});

  final String value;
  final String label;
}

/// One check of a board in the menu Privacy: what its row shows, and the whole text that shows when the user opens
/// the row.
final class PrivacyCheck {
  const PrivacyCheck({
    required this.title,
    required this.state,
    required this.line,
    this.detail,
    this.action,
    this.error,
    this.stats = const [],
    this.tag,
  });

  final String title;
  final CheckState state;

  /// What the check found, in one short line.
  final String line;

  /// What shows and what to do about it, in full.
  final String? detail;

  /// The way to improve it that the app offers, such as a button to the settings of the node.
  final Widget? action;
  final String? error;
  final List<CheckStat> stats;

  /// A few words beside the title, such as where a note comes from.
  final String? tag;

  bool get clear => state != CheckState.warning;

  /// Whether the row has more to show when the user opens it.
  bool get opens => detail != null || stats.isNotEmpty || action != null;
}

/// The head of a board: a ring with one part for each check, lit in the accent color when the check finds nothing to
/// improve, like a reached dot of the sync bar; the share of those checks in the ring; a headline beside it, a line
/// under the headline, and a way forward under the line.
class PrivacySummary extends StatelessWidget {
  const PrivacySummary({
    super.key,
    required this.checks,
    required this.headline,
    required this.lead,
    this.subject,
    this.action,
  });

  final List<PrivacyCheck> checks;
  final String headline;
  final String lead;

  /// What the board is about, above the headline, such as a scanned address.
  final String? subject;

  /// A way forward that the app offers, such as a payment to a new address.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final clear = checks.where((check) => check.clear).length;
    return Surface(
      child: Row(
        children: [
          _Ring(lit: [for (final check in checks) check.clear], clear: clear),
          const SizedBox(width: Metrics.gap + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subject case final subject?) ...[
                  Text(subject, style: KranoxType.smallStrong.copyWith(color: palette.inkSoft)),
                  const SizedBox(height: Metrics.gapTiny),
                ],
                Text(headline, style: KranoxType.boardTitle.copyWith(color: palette.ink)),
                const SizedBox(height: 4),
                Text(lead, style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft)),
                if (action case final action?) ...[const SizedBox(height: Metrics.gapSmall + 2), action],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The color of the mark of a check of [state].
Color _stateColor(Palette palette, CheckState state) => switch (state) {
  CheckState.good => palette.accent,
  CheckState.warning => palette.danger,
  CheckState.note => palette.inkSoft,
  CheckState.pending => palette.inkFaint,
};

class _Ring extends StatelessWidget {
  const _Ring({required this.lit, required this.clear});

  /// Whether each part is lit, in the order of the checks.
  final List<bool> lit;
  final int clear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox.square(
      dimension: Metrics.ringSize,
      child: CustomPaint(
        painter: _RingPainter(colors: [for (final part in lit) part ? palette.accent : palette.dotOff]),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Copy.privacyRingCount(clear, lit.length), style: KranoxType.rowFigure.copyWith(color: palette.ink)),
              const SizedBox(height: 2),
              Text(Copy.privacyRingLabel.toUpperCase(), style: KranoxType.unitLabel.copyWith(color: palette.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A ring in parts of the same length, from the top and clockwise, with room between them.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.colors});

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    final radius = (size.shortestSide - Metrics.ringStroke) / 2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    final step = 2 * math.pi / colors.length;
    // A round end reaches half the stroke past its arc, so the room between two arcs counts the stroke too.
    final room = colors.length == 1 ? 0.0 : (Metrics.ringGap + Metrics.ringStroke) / radius;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = Metrics.ringStroke
      ..strokeCap = StrokeCap.round;
    for (final (index, color) in colors.indexed) {
      final start = -math.pi / 2 + step * index + room / 2;
      canvas.drawArc(rect, start, step - room, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => !listEquals(old.colors, colors);
}

/// The checks that find something to improve first, then the others, each part in its order, so that the ring and the
/// list read the same way.
List<PrivacyCheck> warningsFirst(List<PrivacyCheck> checks) => [
  ...checks.where((check) => check.state == CheckState.warning),
  ...checks.where((check) => check.state != CheckState.warning),
];

/// The checks of a board as one list as wide as the board, which the owner chose on 10 Oct 2026 over a grid of tiles,
/// so that the whole text of a check reads without a narrow column: a hairline between two rows.
class CheckList extends StatelessWidget {
  const CheckList({super.key, required this.checks});

  final List<PrivacyCheck> checks;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Surface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, check) in checks.indexed) ...[
            if (index > 0) Divider(height: 1, color: palette.line),
            CheckRow(key: ValueKey(check.title), check: check),
          ],
        ],
      ),
    );
  }
}

/// One row of a board: the mark of its state, its title, and what it found in one line. A click opens the whole text
/// under the line, with the figures of the check and its way to improve it, and a second click closes it.
class CheckRow extends StatefulWidget {
  const CheckRow({super.key, required this.check});

  final PrivacyCheck check;

  @override
  State<CheckRow> createState() => _CheckRowState();
}

class _CheckRowState extends State<CheckRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final check = widget.check;
    if (!check.opens) return _head(context, open: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = !_open),
              child: _head(context, open: _open),
            ),
          ),
        ),
        AnimatedSize(
          duration: Metrics.fade,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open ? _body(context) : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _head(BuildContext context, {required bool open}) {
    final palette = context.palette;
    final check = widget.check;
    final pending = check.state == CheckState.pending;
    return Padding(
      padding: const EdgeInsets.all(Metrics.tilePadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StateMark(check.state),
          const SizedBox(width: Metrics.checkMarkGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Wrap(
                  spacing: Metrics.gapSmall,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      check.title,
                      style: KranoxType.cardTitle.copyWith(color: pending ? palette.inkSoft : palette.ink),
                    ),
                    if (check.tag case final tag?) _Tag(tag),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  check.line,
                  style: KranoxType.bodyRegular.copyWith(color: pending ? palette.inkFaint : palette.inkSoft),
                ),
              ],
            ),
          ),
          if (check.opens) ...[
            const SizedBox(width: Metrics.gapTiny),
            Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: palette.inkFaint),
          ],
        ],
      ),
    );
  }

  /// The whole text, under the title and as wide as the row, then the figures and the way to improve it.
  Widget _body(BuildContext context) {
    final palette = context.palette;
    final check = widget.check;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Metrics.tilePadding + Metrics.smallRound + Metrics.checkMarkGap,
        0,
        Metrics.tilePadding,
        Metrics.tilePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (check.detail case final detail?) Text(detail, style: KranoxType.bodyRegular.copyWith(color: palette.ink)),
          if (check.stats.isNotEmpty) ...[const SizedBox(height: Metrics.gap - 4), _Stats(check.stats)],
          if (check.action case final action?) ...[const SizedBox(height: Metrics.gapSmall + 2), action],
          ErrorLine(check.error),
        ],
      ),
    );
  }
}

/// A small pill beside the title of a check, in capitals, such as "From your history" on a note.
class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(color: palette.solid, borderRadius: BorderRadius.circular(Metrics.radiusPill)),
      child: Padding(
        padding: Metrics.tagPadding,
        child: Text(text.toUpperCase(), style: KranoxType.unitLabel.copyWith(color: palette.inkSoft)),
      ),
    );
  }
}

/// The round mark of the state of a check: a check, a warning, a dash for a note, or dots before the check runs.
class _StateMark extends StatelessWidget {
  const _StateMark(this.state);

  final CheckState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (ground, icon) = switch (state) {
      CheckState.good => (palette.accentTint, Icons.check_rounded),
      CheckState.warning => (palette.dangerTint, Icons.priority_high_rounded),
      CheckState.note => (palette.solid, Icons.remove_rounded),
      CheckState.pending => (palette.field, Icons.more_horiz_rounded),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: ground, shape: BoxShape.circle),
      child: SizedBox.square(
        dimension: Metrics.smallRound,
        child: Icon(icon, size: 16, color: _stateColor(palette, state)),
      ),
    );
  }
}

/// The figures of a check side by side, and on more rows when they do not fit.
class _Stats extends StatelessWidget {
  const _Stats(this.stats);

  final List<CheckStat> stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      spacing: Metrics.gap * 2,
      runSpacing: Metrics.gapSmall,
      children: [
        for (final stat in stats)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(stat.value, style: KranoxType.rowFigure.copyWith(color: palette.ink)),
              const SizedBox(height: 4),
              Text(stat.label.toUpperCase(), style: KranoxType.unitLabel.copyWith(color: palette.inkSoft)),
            ],
          ),
      ],
    );
  }
}
