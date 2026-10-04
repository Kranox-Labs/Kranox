import 'package:flutter/material.dart';

/// The two takes of the look after Ron Design Lab, which the owner chose as the model on 4 Oct 2026. Ember is
/// dark, after the project Airofit; Paper is light, after CreditPros and DisputeFox. The app uses [activeLook].
enum Look { ember, paper }

/// The look of the app. The owner has not chosen yet: Ember is the recommendation of the assistant.
const Look activeLook = Look.ember;

/// The colors of the brand, from `brand/palette.json`.
abstract final class BrandColors {
  static const Color orange = Color(0xFFF26822);
  static const Color coal = Color(0xFF211D1A);
  static const Color cream = Color(0xFFF6F3EC);
  static const Color white = Color(0xFFFFFFFF);
}

/// A soft round glow behind the content: its color, its diameter, and the place of its center as a share of the
/// window.
final class Glow {
  const Glow({required this.color, required this.diameter, required this.center});

  final Color color;
  final double diameter;
  final Alignment center;
}

/// The colors of one look. Each color of the screens has one definition here.
final class Palette {
  const Palette({
    required this.ground,
    required this.glows,
    required this.sidebar,
    required this.line,
    required this.surface,
    required this.field,
    required this.glass,
    required this.glassLine,
    required this.art,
    required this.artOpacity,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.accent,
    required this.onAccent,
    required this.navActive,
    required this.navActiveInk,
    required this.navTile,
    required this.navTileInk,
    required this.navActiveTile,
    required this.heroGradient,
    required this.heroInk,
    required this.heroMain,
    required this.heroMainInk,
    required this.heroAlt,
    required this.heroAltInk,
    required this.solid,
    required this.solidInk,
    required this.outgoing,
    required this.outgoingInk,
    required this.incoming,
    required this.incomingInk,
    required this.danger,
    required this.dotOff,
    required this.brightness,
  });

  /// The ground of the window and the soft glows over it.
  final Color ground;
  final List<Glow> glows;

  /// The sidebar, and the hairlines between parts.
  final Color sidebar;
  final Color line;

  /// The cards, and the fields of a form.
  final Color surface;
  final Color field;

  /// A card of frosted glass over the picture of the ground, and its edge.
  final Color glass;
  final Color glassLine;

  /// The picture on the ground of the welcome screen, as an asset path, and how strongly it shows. A look
  /// without a picture shows its plain ground.
  final String? art;
  final double artOpacity;

  /// The text, in three strengths.
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;

  final Color accent;
  final Color onAccent;

  /// The active link of the sidebar.
  final Color navActive;
  final Color navActiveInk;

  /// The tile behind the icon of a link, its glyph, and the tile of the active link.
  final Color navTile;
  final Color navTileInk;
  final Color navActiveTile;

  /// The balance card: its gradient, its text, and its two buttons.
  final List<Color> heroGradient;
  final Color heroInk;
  final Color heroMain;
  final Color heroMainInk;
  final Color heroAlt;
  final Color heroAltInk;

  /// A solid button or a round icon on a card.
  final Color solid;
  final Color solidInk;

  /// The round icons of the transactions.
  final Color outgoing;
  final Color outgoingInk;
  final Color incoming;
  final Color incomingInk;

  final Color danger;

  /// A dot of the sync bar that the wallet has not reached yet. A reached dot has the accent color.
  final Color dotOff;

  final Brightness brightness;

  static Palette of(Look look) => switch (look) {
    Look.ember => ember,
    Look.paper => paper,
  };

  /// Dark: a ground of coal, cards of tinted glass, and a balance card in an ember gradient.
  static const Palette ember = Palette(
    ground: Color(0xFF0F0D0C),
    glows: [
      Glow(color: Color(0x52F26822), diameter: 760, center: Alignment(1.05, -1.35)),
      Glow(color: Color(0x386E48BE), diameter: 620, center: Alignment(-0.55, 1.6)),
    ],
    // The sidebar and the cards are frosted glass over the drawing on the ground: dense enough to keep the text
    // clear, and in the tone that a thin cream tint over the coal ground had before the drawing.
    sidebar: Color(0xBF1D1B1A),
    line: Color(0x14F6F3EC),
    surface: Color(0xB81B1817),
    field: Color(0x0FF6F3EC),
    glass: Color(0x8C15120F),
    glassLine: Color(0x1FF6F3EC),
    art: 'assets/images/welcome-art.webp',
    artOpacity: 0.24,
    ink: BrandColors.cream,
    inkSoft: Color(0x99F6F3EC),
    inkFaint: Color(0x59F6F3EC),
    accent: BrandColors.orange,
    onAccent: Color(0xFF0F0D0C),
    navActive: BrandColors.orange,
    navActiveInk: Color(0xFF0F0D0C),
    navTile: Color(0xFF3A3532),
    navTileInk: BrandColors.cream,
    navActiveTile: Color(0x29000000),
    heroGradient: [Color(0xFFFF8A3D), Color(0xFFE2541C), Color(0xFF7A1F2E), Color(0xFF2A1238)],
    heroInk: BrandColors.white,
    heroMain: Color(0xFF0F0D0C),
    heroMainInk: BrandColors.cream,
    heroAlt: Color(0x29FFFFFF),
    heroAltInk: BrandColors.white,
    solid: Color(0x1AF6F3EC),
    solidInk: BrandColors.cream,
    outgoing: BrandColors.orange,
    outgoingInk: Color(0xFF0F0D0C),
    incoming: Color(0x1AF6F3EC),
    incomingInk: BrandColors.cream,
    danger: Color(0xFFFF8A7A),
    dotOff: Color(0x26F6F3EC),
    brightness: Brightness.dark,
  );

  /// Light: a warm gray ground, white cards, black pill buttons, and a balance card from peach into orange.
  static const Palette paper = Palette(
    ground: Color(0xFFEBE8E2),
    glows: [],
    sidebar: Color(0xFFF4F2EE),
    line: Color(0x14211D1A),
    surface: BrandColors.white,
    field: Color(0xFFF4F2EE),
    glass: Color(0xE6FFFFFF),
    glassLine: Color(0x14211D1A),
    art: null,
    artOpacity: 0,
    ink: BrandColors.coal,
    inkSoft: Color(0x99211D1A),
    inkFaint: Color(0x59211D1A),
    accent: BrandColors.orange,
    onAccent: BrandColors.coal,
    navActive: BrandColors.coal,
    navActiveInk: BrandColors.cream,
    navTile: Color(0xFFE2DED7),
    navTileInk: BrandColors.coal,
    navActiveTile: Color(0x33FFFFFF),
    heroGradient: [Color(0xFFFFD9B8), Color(0xFFFFB27A), BrandColors.orange, Color(0xFFC8492A)],
    heroInk: BrandColors.coal,
    heroMain: BrandColors.coal,
    heroMainInk: BrandColors.cream,
    heroAlt: Color(0x8CFFFFFF),
    heroAltInk: BrandColors.coal,
    solid: BrandColors.coal,
    solidInk: BrandColors.cream,
    outgoing: BrandColors.coal,
    outgoingInk: BrandColors.cream,
    incoming: Color(0xFFFFE2CC),
    incomingInk: Color(0xFFC8492A),
    danger: Color(0xFFC8372D),
    dotOff: Color(0x1F211D1A),
    brightness: Brightness.light,
  );
}
