import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/app_config.dart';
import '../../wallet/controller.dart';
import '../../wallet/failure.dart';
import '../copy.dart';
import '../format.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/page_frame.dart';
import '../widgets/surfaces.dart';

/// The receive page: the newest subaddress as a code to scan and as text, and a button for a new subaddress.
class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key, required this.controller});

  final WalletController controller;

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  bool _busy = false;
  String? _error;

  Future<void> _newAddress() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.newReceiveAddress();
    } on WalletException catch (error) {
      setState(() => _error = failureText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final address = widget.controller.receiveAddress;
    return PageFrame(
      title: Copy.receiveTitle,
      lead: Copy.receiveLead,
      chips: [StatusChip(label: AppConfig.network.label)],
      children: [
        Surface(
          padding: const EdgeInsets.all(Metrics.heroPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A code to scan needs dark modules on a light ground in every look.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: BrandColors.white,
                  borderRadius: BorderRadius.circular(Metrics.radiusField),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: address == null
                      ? const SizedBox.square(dimension: Metrics.qrSize)
                      : QrImageView(
                          data: address.address,
                          size: Metrics.qrSize,
                          padding: EdgeInsets.zero,
                          backgroundColor: BrandColors.white,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: BrandColors.coal),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: BrandColors.coal,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: Metrics.gap + 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address == null ? '' : Copy.subaddress(address.index).toUpperCase(),
                      style: KranoxType.label.copyWith(color: palette.inkSoft),
                    ),
                    const SizedBox(height: Metrics.gapSmall),
                    SelectableText(address?.address ?? '…', style: KranoxType.mono.copyWith(color: palette.ink)),
                    ErrorLine(_error),
                    const SizedBox(height: Metrics.gap),
                    Wrap(
                      spacing: Metrics.gapSmall,
                      runSpacing: Metrics.gapSmall,
                      children: [
                        PillButton(
                          label: Copy.copyAddress,
                          icon: Icons.copy_rounded,
                          onPressed: address == null ? null : () => copyToClipboard(context, address.address),
                        ),
                        PillButton(label: Copy.newAddress, tone: PillTone.quiet, busy: _busy, onPressed: _newAddress),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
