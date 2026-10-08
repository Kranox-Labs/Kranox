import 'package:flutter/material.dart';

import '../copy.dart';
import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import 'buttons.dart';
import 'surfaces.dart';

/// The notice after the start of the app moved a file that it could not read aside: which file, what the app did
/// about it, and that the wallets did not change. It stays until the user closes it. It closes K-09 of the security
/// review of 0.2.0, whose fix moved such a file without a word on the screen.
class RecoveryNotice extends StatelessWidget {
  const RecoveryNotice({super.key, required this.settingsFile, required this.swapsFile, required this.onDismiss});

  /// Where the settings and the swaps went, each null when its file read well.
  final String? settingsFile;
  final String? swapsFile;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = KranoxType.small.copyWith(color: palette.inkSoft);
    return GlassCard(
      padding: const EdgeInsets.all(Metrics.tilePadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_rounded, size: 20, color: palette.danger),
          const SizedBox(width: Metrics.gapSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Copy.recoveryTitle, style: KranoxType.cardTitle.copyWith(color: palette.ink)),
                for (final line in [
                  if (settingsFile case final file?) Copy.recoverySettings(_name(file)),
                  if (swapsFile case final file?) Copy.recoverySwaps(_name(file)),
                  Copy.recoveryWalletsSafe,
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(line, style: style),
                  ),
                const SizedBox(height: Metrics.gapSmall),
                SmallPillButton(label: Copy.recoveryDismiss, onPressed: onDismiss),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The name of a file without its folders: the support folder of the app sits deep in the sandbox.
String _name(String path) => path.substring(path.lastIndexOf('/') + 1);
