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

/// One check of a board in the menu Privacy: what its tile shows, and the longer text that shows when the user opens
/// the tile.
final class PrivacyCheck {
  const PrivacyCheck({
    required this.title,
    required this.state,
    required this.line,
    this.detail,
    this.action,
    this.error,
    this.stats = const [],
    this.wide = false,
  });

  final String title;
  final CheckState state;

  /// What the check found, in one short line.
  final String line;

  /// What shows and what to do about it. A tile without it does not open.
  final String? detail;

  /// The way to improve it that the app offers, such as a button to the settings of the node.
  final Widget? action;
  final String? error;
  final List<CheckStat> stats;

  /// Whether the tile takes a whole row of the board, such as a check with figures.
  final bool wide;

  bool get clear => state != CheckState.warning;
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

/// The checks of a board in two columns, row by row, each row as high as its highest tile; a wide check takes a row of
/// its own. Narrower than [Metrics.boardTwoColumns], the board has one column.
class CheckGrid extends StatelessWidget {
  const CheckGrid({super.key, required this.checks});

  final List<PrivacyCheck> checks;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rows = constraints.maxWidth < Metrics.boardTwoColumns
          ? [
              for (final check in checks) [check],
            ]
          : _rows(checks);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, row) in rows.indexed) ...[if (index > 0) const SizedBox(height: Metrics.gap), _row(row)],
        ],
      );
    },
  );

  /// The checks two by two in their order, with a wide check alone in its row.
  static List<List<PrivacyCheck>> _rows(List<PrivacyCheck> checks) {
    final rows = <List<PrivacyCheck>>[];
    for (final check in checks) {
      final last = rows.isEmpty ? null : rows.last;
      if (!check.wide && last != null && last.length == 1 && !last.first.wide) {
        last.add(check);
      } else {
        rows.add([check]);
      }
    }
    return rows;
  }

  static Widget _row(List<PrivacyCheck> row) {
    final first = row.first;
    if (first.wide) return CheckTile(key: ValueKey(first.title), check: first);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CheckTile(key: ValueKey(first.title), check: first),
          ),
          const SizedBox(width: Metrics.gap),
          Expanded(
            child: row.length > 1 ? CheckTile(key: ValueKey(row.last.title), check: row.last) : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

/// One tile of a board: the mark of its state, its title, what it found, its figures, and its way to improve it. A
/// click puts the longer text in the place of the line, and a second click puts the line back. A tile that warns has
/// an edge in the color of a failure.
class CheckTile extends StatefulWidget {
  const CheckTile({super.key, required this.check});

  final PrivacyCheck check;

  @override
  State<CheckTile> createState() => _CheckTileState();
}

class _CheckTileState extends State<CheckTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final check = widget.check;
    final detail = check.detail;
    final pending = check.state == CheckState.pending;
    final tile = Surface(
      padding: const EdgeInsets.all(Metrics.tilePadding),
      border: check.state == CheckState.warning ? palette.dangerLine : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StateMark(check.state),
          const SizedBox(width: Metrics.gapSmall + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(check.title, style: KranoxType.cardTitle.copyWith(color: pending ? palette.inkSoft : palette.ink)),
                const SizedBox(height: 4),
                Text(
                  _open && detail != null ? detail : check.line,
                  style: KranoxType.bodyRegular.copyWith(color: pending ? palette.inkFaint : palette.inkSoft),
                ),
                if (check.stats.isNotEmpty) ...[const SizedBox(height: Metrics.gap - 4), _Stats(check.stats)],
                if (check.action case final action?) ...[const SizedBox(height: Metrics.gapSmall + 2), action],
                ErrorLine(check.error),
              ],
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: Metrics.gapTiny),
            Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: palette.inkFaint),
          ],
        ],
      ),
    );
    if (detail == null) return tile;
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: tile,
        ),
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
