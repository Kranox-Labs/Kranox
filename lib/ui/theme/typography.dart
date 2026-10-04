import 'package:flutter/widgets.dart';

/// The type of the app: Archivo, a grotesk of the brand, which the app carries in its assets. The weight of a
/// variable font comes through its axis `wght`, so each style sets the axis and the weight together.
abstract final class KranoxType {
  static const String family = 'Archivo';

  static TextStyle _style(double size, double weight, {double tracking = 0, double height = 1.25}) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: _nearestWeight(weight),
    fontVariations: [FontVariation.weight(weight)],
    letterSpacing: tracking * size,
    height: height,
  );

  static FontWeight _nearestWeight(double weight) =>
      FontWeight.values[((weight / 100).round() - 1).clamp(0, FontWeight.values.length - 1)];

  /// The balance: large and thin, the focus of the screen.
  static final TextStyle figure = _style(76, 250, tracking: -0.04, height: 1);
  static final TextStyle figureUnit = _style(22, 500);

  /// The figure of a small card, and the amount of a transaction.
  static final TextStyle cardFigure = _style(34, 300, tracking: -0.03, height: 1.1);
  static final TextStyle rowFigure = _style(20, 300, tracking: -0.02, height: 1.1);

  static final TextStyle pageTitle = _style(26, 500, tracking: -0.02, height: 1.15);
  static final TextStyle onboardingTitle = _style(34, 500, tracking: -0.025, height: 1.1);
  static final TextStyle cardTitle = _style(15, 600);
  static final TextStyle body = _style(14, 500);
  static final TextStyle bodyRegular = _style(14, 400, height: 1.45);
  static final TextStyle small = _style(12, 400, height: 1.35);
  static final TextStyle smallStrong = _style(12, 600);

  /// A label in capitals with open letter spacing, such as the label of the balance and the chips.
  static final TextStyle label = _style(12, 600, tracking: 0.08);
  static final TextStyle unitLabel = _style(11, 600, tracking: 0.06);

  static final TextStyle brand = _style(17, 600, tracking: -0.01);
  static final TextStyle button = _style(14, 600);
  static final TextStyle mono = _style(13, 500, tracking: 0.01, height: 1.5);
}
