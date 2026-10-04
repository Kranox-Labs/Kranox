import 'package:flutter/material.dart';

import 'palette.dart';
import 'typography.dart';

/// The palette of the active look, carried by the theme so that every widget reads it.
final class KranoxTheme extends ThemeExtension<KranoxTheme> {
  const KranoxTheme(this.palette);

  final Palette palette;

  @override
  KranoxTheme copyWith({Palette? palette}) => KranoxTheme(palette ?? this.palette);

  @override
  KranoxTheme lerp(KranoxTheme? other, double t) => t < 0.5 || other == null ? this : other;

  static ThemeData build(Palette palette) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: palette.brightness,
      surface: palette.ground,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      error: palette.danger,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.ground,
      fontFamily: KranoxType.family,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.accent,
        selectionColor: palette.accent.withValues(alpha: 0.35),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        contentTextStyle: KranoxType.body.copyWith(color: palette.ground),
        behavior: SnackBarBehavior.floating,
      ),
      extensions: [KranoxTheme(palette)],
    );
  }
}

extension KranoxContext on BuildContext {
  /// The colors of the active look.
  Palette get palette => Theme.of(this).extension<KranoxTheme>()!.palette;
}
