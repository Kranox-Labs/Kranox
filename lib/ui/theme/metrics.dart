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

  /// The column in the middle of a page with its content in the center, after the home of Vizor.
  static const double centerColumnWidth = 540;

  /// A page in the center starts below the strip of the window buttons, with room above its title. The owner found
  /// the title of the send page too close to the top on 5 Oct 2026.
  static const EdgeInsets centeredPagePadding = EdgeInsets.fromLTRB(pagePaddingX, 64, pagePaddingX, pagePaddingY);

  /// The board of the menu Privacy, a dashboard in the middle of the page that the owner chose on 8 Oct 2026: its
  /// column, the least width for its two columns of tiles, and the room inside a tile.
  static const double boardWidth = 760;
  static const double boardTwoColumns = 560;
  static const double tilePadding = 18;

  /// The ring at the head of a board, with one part for each check: its size, its stroke, and the room between two
  /// parts.
  static const double ringSize = 84;
  static const double ringStroke = 7;
  static const double ringGap = 5;
  static const double transferIcon = 40;
  static const double roundButton = 46;
  static const double smallRound = 30;

  /// The code of the receive page, its white margin, and the room around the whole subaddress below it.
  static const double qrSize = 220;
  static const double qrPadding = 14;
  static const double addressBoxPadding = 14;

  /// The code of the deposit address of a swap of the bridge, beside its text, and its white margin.
  static const double bridgeQrSize = 132;
  static const double bridgeQrPadding = 10;

  /// The two sides of pay: the room inside each box, and the round arrow between them.
  static const double swapBoxPadding = 16;
  static const double swapArrow = 38;

  /// The edge of a chosen card of a choice, such as the rate of pay.
  static const double choiceBorder = 1.6;

  /// The menu of the coin of a swap: its least width and the turn of its arrow.
  static const double coinMenuWidth = 220;
  static const Duration menuTurn = Duration(milliseconds: 160);

  /// The shadow of a part that lies over other parts, such as the menu of a coin or a toast.
  static const double raisedElevation = 12;

  /// A toast, the short note at the foot of a page such as "Copied": how far above the foot it floats, the share of
  /// its height by which it rises as it shows, how long it stays, how long it fades in and out, and the room inside
  /// it. The owner found the bar of Material, from edge to edge of the window, too long on 6 Oct 2026.
  static const double toastBottom = 28;
  static const double toastLift = 0.4;
  static const Duration toastStay = Duration(milliseconds: 1500);
  static const Duration toastFade = Duration(milliseconds: 180);
  static const EdgeInsets toastPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);

  /// The mark of a step of a swap: a check, a spinner, or a ring.
  static const double stepMark = 24;
  static const double stepLine = 2;
  static const double avatar = 34;

  /// The helmet alone at the top of the sidebar, in its middle. The owner asked on 5 Oct 2026 for the logo without the
  /// name, larger, with more room around it.
  static const double sidebarLogoHeight = 40;

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

  /// The bar of the balance card that splits the unlocked part from the locked part: its height, the room between
  /// the two parts, and the least width of a part, so that a small part still shows.
  static const double splitBarHeight = 6;
  static const double splitBarGap = 3;
  static const double splitBarMinPart = 8;

  /// The dots of the card of a locked balance, one for each confirmation of the wait.
  static const double unlockDot = 10;
  static const double unlockDotGap = 6;

  /// The ring around the icon of a transaction whose coins still unlock: its stroke, and its room from the icon.
  static const double unlockRing = 2.5;
  static const double unlockRingGap = 3;

  /// The share of the window over which the balance card and the side cards share one row.
  static const int heroFlex = 155;
  static const int sideFlex = 100;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: pagePaddingX, vertical: pagePaddingY);

  /// The opacity of the grain over the balance card.
  static const double grainOpacity = 0.18;

  static const Duration fade = Duration(milliseconds: 220);
}
