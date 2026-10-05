import 'package:flutter/widgets.dart';

/// The sizes of the layout, in logical pixels: one definition for each.
abstract final class Metrics {
  /// The top strip of the window: the window has no title bar, so its buttons float over the content there, and
  /// the strip moves the window instead of taking clicks. CHECKED 4 Oct 2026 on macOS 26 with the unified toolbar
  /// of MainFlutterWindow.swift: 66 points high, the close button 19 points from the top and the left edge.
  static const double windowBarHeight = 66;

  /// The foot of the window buttons, from the top of the window: 19 points down and 14 points high.
  static const double windowButtonsBottom = 33;

  /// The sidebar floats this far from the top, the left, and the bottom edge of the window, after System Settings.
  static const double sidebarInset = 8;
  static const double sidebarWidth = 232;

  /// A link of the sidebar: its icon in a rounded tile, the glyph in the tile, and the row around them.
  static const double navTile = 24;
  static const double navGlyph = 15;
  static const double navRowHeight = 36;
  static const double pagePaddingX = 30;
  static const double pagePaddingY = 26;
  static const double gap = 18;
  static const double gapSmall = 10;
  static const double gapTiny = 6;
  static const double cardPadding = 22;
  static const double heroPadding = 28;
  static const double heroMinHeight = 252;
  static const double onboardingWidth = 520;

  /// The welcome card in the middle of the window, its logo (also on the other screens before the wallet opens), and
  /// the blur of the picture behind it.
  static const double welcomeCardWidth = 460;
  static const EdgeInsets welcomeCardPadding = EdgeInsets.fromLTRB(36, 40, 36, 32);
  static const double welcomeLogoHeight = 84;
  static const double glassBlur = 24;

  /// The seed needs room for five words in a row.
  static const double onboardingWideWidth = 700;
  static const double formWidth = 640;
  static const double transferIcon = 40;
  static const double roundButton = 46;
  static const double smallRound = 30;
  static const double qrSize = 220;

  /// The code of the deposit address of a swap of the bridge, beside its text.
  static const double bridgeQrSize = 132;

  /// The mark of a step of a swap: a check, a spinner, or a ring.
  static const double stepMark = 24;
  static const double stepLine = 2;
  static const double avatar = 34;
  static const double logoHeight = 22;

  static const double radiusHero = 30;

  /// The window of macOS 26 rounds its corners by about 26 points; the sidebar keeps the same curve inside it.
  static const double radiusSidebar = 18;
  static const double radiusNavRow = 9;
  static const double radiusNavTile = 7;
  static const double radiusGlass = 30;
  static const double radiusCard = 26;
  static const double radiusField = 16;
  static const double radiusWallet = 18;
  static const double radiusPill = 999;

  /// The sync bar: dots in rows, and the room between them.
  static const int syncDots = 48;
  static const int syncDotsPerRow = 24;
  static const double syncDotGap = 3;

  /// The share of the window over which the balance card and the side cards share one row.
  static const int heroFlex = 155;
  static const int sideFlex = 100;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: pagePaddingX, vertical: pagePaddingY);

  /// The opacity of the grain over the balance card.
  static const double grainOpacity = 0.18;

  static const Duration fade = Duration(milliseconds: 220);
}
