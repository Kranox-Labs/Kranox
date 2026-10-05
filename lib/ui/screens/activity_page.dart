import 'package:flutter/material.dart';

import '../../wallet/controller.dart';
import '../copy.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/page_frame.dart';
import '../widgets/surfaces.dart';
import '../widgets/transfer_row.dart';

/// Every transaction of the wallet, the newest first, each with a button that copies its id.
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key, required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final transfers = controller.transfers;
    final loading = controller.status.isLoading;
    return PageFrame(
      title: Copy.activityTitle,
      lead: Copy.activityLead,
      chips: [StatusChip(label: controller.network.label)],
      children: [
        Surface(
          padding: const EdgeInsets.fromLTRB(Metrics.cardPadding, 8, Metrics.cardPadding, 8),
          child: transfers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: loading
                      ? const LoadingLine(Copy.activityAfterSync)
                      : Text(
                          controller.status.synchronized ? Copy.noActivity : Copy.activityAfterSync,
                          style: KranoxType.bodyRegular.copyWith(color: palette.inkSoft),
                        ),
                )
              : Column(
                  children: [
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LoadingLine(Copy.activityUpdating),
                      ),
                    for (final (index, transfer) in transfers.indexed) ...[
                      if (index > 0 || loading) Divider(height: 1, color: palette.line),
                      TransferRow(
                        loading: loading,
                        transfer: transfer,
                        trailing: RoundButton(
                          icon: Icons.copy_rounded,
                          tooltip: Copy.copyId,
                          size: Metrics.smallRound,
                          onPressed: () => copyToClipboard(context, transfer.hash),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
