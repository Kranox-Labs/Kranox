import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';

/// A card of the look: frosted glass over the drawing of the dark ground, white on the light ground.
class Surface extends StatelessWidget {
  const Surface({super.key, required this.child, this.padding = const EdgeInsets.all(Metrics.cardPadding)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(Metrics.radiusCard);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: Metrics.glassBlur, sigmaY: Metrics.glassBlur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: radius,
            border: Border.all(color: palette.line),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A card of frosted glass that floats over the picture of the ground: it blurs the picture behind it.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  static const BoxShadow _shadow = BoxShadow(
    color: Color(0x66000000),
    blurRadius: 60,
    spreadRadius: -12,
    offset: Offset(0, 28),
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(Metrics.radiusGlass);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: const [_shadow]),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: Metrics.glassBlur, sigmaY: Metrics.glassBlur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.glass,
              borderRadius: radius,
              border: Border.all(color: palette.glassLine),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// The balance card: a gradient with a fine grain, after the large cards of Ron Design Lab.
class HeroSurface extends StatelessWidget {
  const HeroSurface({super.key, required this.child});

  final Widget child;

  /// Where the colors of the gradient sit along the card.
  static const List<double> _stops = [0, 0.32, 0.7, 1];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(Metrics.radiusHero);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.heroGradient,
          stops: _stops,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.heroGradient[1].withValues(alpha: 0.4),
            blurRadius: 60,
            spreadRadius: -20,
            offset: const Offset(0, 30),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: Metrics.grainOpacity,
                  child: Image.asset('assets/images/grain.png', repeat: ImageRepeat.repeat, fit: BoxFit.none),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Metrics.heroMinHeight),
              child: Padding(padding: const EdgeInsets.all(Metrics.heroPadding), child: child),
            ),
          ],
        ),
      ),
    );
  }
}
