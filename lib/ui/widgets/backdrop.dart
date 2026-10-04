import 'package:flutter/widgets.dart';

import '../theme/kranox_theme.dart';
import '../theme/palette.dart';

/// The ground of the window, with the soft glows of the look behind the content. With [showArt], the picture of
/// the look lies on the ground under the glows, so that it melts into the ground.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child, this.showArt = false});

  final Widget child;
  final bool showArt;

  /// The ground covers the middle of the picture with this opacity and fades out toward the edges, so that the
  /// picture shows most at the edges, where its subject lives, and stays calm behind the content.
  static const double _calmOpacity = 0.6;
  static const double _calmRadius = 0.75;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final art = showArt ? palette.art : null;
    return ColoredBox(
      color: palette.ground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (art != null) ...[
            IgnorePointer(
              child: Opacity(
                opacity: palette.artOpacity,
                child: Image.asset(art, fit: BoxFit.cover),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: _calmRadius,
                  colors: [
                    palette.ground.withValues(alpha: _calmOpacity),
                    palette.ground.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
          CustomPaint(painter: _GlowPainter(palette.glows), child: child),
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.glows);

  final List<Glow> glows;

  @override
  void paint(Canvas canvas, Size size) {
    for (final glow in glows) {
      final center = glow.center.alongSize(size);
      final radius = glow.diameter / 2;
      final paint = Paint()
        ..shader = RadialGradient(colors: [glow.color, glow.color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => oldDelegate.glows != glows;
}
