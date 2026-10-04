import 'package:flutter/material.dart';

import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';

/// The colors of a pill button: the accent, the two buttons of the balance card, a solid button, and a quiet one.
enum PillTone { accent, heroMain, heroAlt, solid, quiet }

/// A rounded button with a label. While [busy], it shows a small spinner and [busyLabel], and takes no tap.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = PillTone.accent,
    this.busy = false,
    this.busyLabel,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillTone tone;
  final bool busy;
  final String? busyLabel;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _colors(context.palette);
    final button = FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: background.a * 0.5),
        disabledForegroundColor: foreground.withValues(alpha: 0.7),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: KranoxType.button,
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: foreground)),
            const SizedBox(width: Metrics.gapSmall),
          ] else if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: Metrics.gapTiny),
          ],
          Text(busy ? busyLabel ?? label : label),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  (Color, Color) _colors(Palette palette) => switch (tone) {
    PillTone.accent => (palette.accent, palette.onAccent),
    PillTone.heroMain => (palette.heroMain, palette.heroMainInk),
    PillTone.heroAlt => (palette.heroAlt, palette.heroAltInk),
    PillTone.solid => (palette.solid, palette.solidInk),
    PillTone.quiet => (palette.field, palette.ink),
  };
}

/// A round button with an icon, such as the arrow on the balance card and the copy buttons.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.background,
    this.foreground,
    this.size = Metrics.roundButton,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: size * 0.42),
      style: IconButton.styleFrom(
        backgroundColor: background ?? palette.solid,
        foregroundColor: foreground ?? palette.solidInk,
        fixedSize: Size.square(size),
        minimumSize: Size.square(size),
        shape: const CircleBorder(),
      ),
    );
  }
}
