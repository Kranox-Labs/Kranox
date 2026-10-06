import 'package:flutter/material.dart';

import '../../bridge/models.dart';
import '../copy.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';

// The form of a swap of the bridge: one box for each side, the side that goes in above the side that comes out, with
// a round arrow between them. The owner showed this form for pay on 6 Oct 2026, and asked the same day for receive
// from Robinhood Chain in the same form, so that both ways look alike.

/// The two sides of a swap, [top] over [bottom], with the round arrow over the upper edge of the second one, so that
/// they read as one swap.
class SwapPair extends StatelessWidget {
  const SwapPair({super.key, required this.top, required this.bottom});

  final Widget top;
  final Widget bottom;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      top,
      Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: Metrics.gapSmall),
            child: bottom,
          ),
          const Positioned(
            top: (Metrics.gapSmall - Metrics.swapArrow) / 2,
            left: 0,
            right: 0,
            child: Center(child: _SwapArrow()),
          ),
        ],
      ),
    ],
  );
}

/// One side of a swap: its label, the amount at the left, and its coin at the right, with a line below it.
class SwapAmountBox extends StatelessWidget {
  const SwapAmountBox({super.key, required this.label, required this.amount, required this.coin, this.footer});

  final String label;
  final Widget amount;
  final Widget coin;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.field,
        borderRadius: BorderRadius.circular(Metrics.radiusField),
        border: Border.all(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Metrics.swapBoxPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label.toUpperCase(), style: KranoxType.label.copyWith(color: palette.inkSoft)),
            const SizedBox(height: Metrics.gapTiny),
            Row(
              children: [
                Expanded(child: amount),
                const SizedBox(width: Metrics.gapSmall),
                coin,
              ],
            ),
            if (footer case final footer?) ...[const SizedBox(height: Metrics.gapTiny), footer],
          ],
        ),
      ),
    );
  }
}

/// A coin of a swap with its network below it, and a sign at its right when it opens a choice.
class SwapCoin extends StatelessWidget {
  const SwapCoin({super.key, required this.label, required this.network, this.trailing});

  final String label;
  final String network;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Metrics.radiusField),
        border: Border.all(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: KranoxType.cardTitle.copyWith(color: palette.ink)),
                Text(network, style: KranoxType.small.copyWith(color: palette.inkSoft)),
              ],
            ),
            if (trailing case final trailing?) ...[const SizedBox(width: Metrics.gapTiny), trailing],
          ],
        ),
      ),
    );
  }
}

/// The coin of Robinhood Chain of a swap, as a menu of the coins that the bridge takes in and pays out. The menu opens
/// below the coin on the solid ground of a card, each coin with its network, and the chosen one with a check. The
/// owner turned down the plain menu of Material on 6 Oct 2026 ("ui dropdownya jangan gini").
class CoinMenu extends StatelessWidget {
  const CoinMenu({super.key, required this.asset, required this.enabled, required this.onSelect});

  final BridgeAsset asset;
  final bool enabled;
  final ValueChanged<BridgeAsset> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(Metrics.radiusField);
    // The menu hangs from the lower right corner of the coin, so that its right edge meets the edge of the coin and it
    // stays inside the form.
    return MenuAnchor(
      alignmentOffset: const Offset(-Metrics.coinMenuWidth, Metrics.gapTiny),
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        backgroundColor: WidgetStatePropertyAll(palette.raised),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(Metrics.raisedElevation),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(Metrics.gapTiny)),
        minimumSize: const WidgetStatePropertyAll(Size(Metrics.coinMenuWidth, 0)),
        maximumSize: const WidgetStatePropertyAll(Size(Metrics.coinMenuWidth, double.infinity)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: palette.line),
          ),
        ),
      ),
      menuChildren: [
        for (final choice in BridgeAsset.values)
          MenuItemButton(
            onPressed: () => onSelect(choice),
            trailingIcon: choice == asset
                ? Icon(Icons.check_rounded, size: 18, color: palette.accent)
                : const SizedBox(width: 18),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(Metrics.coinMenuWidth - 2 * Metrics.gapTiny, 0)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: Metrics.gapSmall + 2, vertical: Metrics.gapSmall),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(Metrics.radiusField - Metrics.gapTiny)),
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                    ? palette.field
                    : Colors.transparent,
              ),
              overlayColor: WidgetStatePropertyAll(palette.field),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  choice.label,
                  style: KranoxType.cardTitle.copyWith(color: choice == asset ? palette.accent : palette.ink),
                ),
                Text(Copy.payOnChain, style: KranoxType.small.copyWith(color: palette.inkSoft)),
              ],
            ),
          ),
      ],
      builder: (context, controller, _) => InkWell(
        onTap: enabled ? () => controller.isOpen ? controller.close() : controller.open() : null,
        borderRadius: radius,
        child: SwapCoin(
          label: asset.label,
          network: Copy.payOnChain,
          trailing: AnimatedRotation(
            turns: controller.isOpen ? 0.5 : 0,
            duration: Metrics.menuTurn,
            child: Icon(Icons.expand_more_rounded, size: 18, color: palette.inkSoft),
          ),
        ),
      ),
    );
  }
}

/// A sentence below the two sides of a swap: why the quote failed, in the color of a failure, or a warning of the
/// exchanger. Nothing when [text] is null.
class SwapNote extends StatelessWidget {
  const SwapNote(this.text, {super.key, this.failure = false});

  final String? text;
  final bool failure;

  @override
  Widget build(BuildContext context) {
    final note = text;
    if (note == null) return const SizedBox.shrink();
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: Metrics.gapSmall),
      child: Text(
        note,
        textAlign: TextAlign.center,
        style: KranoxType.small.copyWith(color: failure ? palette.danger : palette.inkSoft),
      ),
    );
  }
}

/// The round arrow between the two sides of a swap: the coin above turns into the coin below.
class _SwapArrow extends StatelessWidget {
  const _SwapArrow();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.field,
        shape: BoxShape.circle,
        border: Border.all(color: palette.line),
      ),
      child: SizedBox.square(
        dimension: Metrics.swapArrow,
        child: Icon(Icons.arrow_downward_rounded, size: 18, color: palette.ink),
      ),
    );
  }
}
