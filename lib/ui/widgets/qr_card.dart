import 'package:flutter/widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/metrics.dart';
import '../theme/palette.dart';

/// An address as a code to scan, on white with round corners: a code needs dark modules on a light ground in every
/// look. While [data] is null, the card keeps its size without a code.
class QrCard extends StatelessWidget {
  const QrCard({super.key, required this.data, required this.size, required this.padding});

  final String? data;
  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final code = data;
    return DecoratedBox(
      decoration: BoxDecoration(color: BrandColors.white, borderRadius: BorderRadius.circular(Metrics.radiusField)),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: code == null
            ? SizedBox.square(dimension: size)
            : QrImageView(
                data: code,
                size: size,
                padding: EdgeInsets.zero,
                backgroundColor: BrandColors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: BrandColors.coal),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: BrandColors.coal,
                ),
              ),
      ),
    );
  }
}
