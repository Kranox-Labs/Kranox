import 'package:flutter/material.dart';

import '../../config/network.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';

/// A row of pills, one for each Monero network. The pill of the active network has the accent color. Without
/// [onSelect], the pills take no tap, such as while the app moves to another network.
class NetworkChoice extends StatelessWidget {
  const NetworkChoice({super.key, required this.network, required this.onSelect, this.alignment = WrapAlignment.start});

  final MoneroNetwork network;
  final ValueChanged<MoneroNetwork>? onSelect;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: alignment,
    spacing: Metrics.gapTiny,
    runSpacing: Metrics.gapTiny,
    children: [
      for (final candidate in MoneroNetwork.values)
        _NetworkPill(
          label: candidate.label,
          active: candidate == network,
          onTap: onSelect == null || candidate == network ? null : () => onSelect!(candidate),
        ),
    ],
  );
}

class _NetworkPill extends StatelessWidget {
  const _NetworkPill({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = StadiumBorder(side: BorderSide(color: active ? palette.accent : palette.line));
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? palette.accent : palette.surface,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          mouseCursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label.toUpperCase(),
              style: KranoxType.label.copyWith(color: active ? palette.onAccent : palette.inkSoft),
            ),
          ),
        ),
      ),
    );
  }
}
