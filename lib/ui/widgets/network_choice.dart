import 'package:flutter/material.dart';

import '../../config/network.dart';
import '../theme/metrics.dart';
import 'choice_pill.dart';

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
        ChoicePill(
          label: candidate.label,
          active: candidate == network,
          onTap: onSelect == null || candidate == network ? null : () => onSelect!(candidate),
        ),
    ],
  );
}
