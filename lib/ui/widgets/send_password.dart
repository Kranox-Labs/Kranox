import 'package:flutter/material.dart';

import '../copy.dart';
import '../theme/metrics.dart';
import 'buttons.dart';
import 'field.dart';

/// The password of the wallet and the button that sends a payment with it. The button waits for a password, as the
/// desktop wallet of Monero asks for one before each payment, so that nobody at an open wallet can send its coins.
class SendWithPassword extends StatelessWidget {
  const SendWithPassword({
    super.key,
    required this.password,
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onConfirm,
  });

  final TextEditingController password;
  final String label;
  final String busyLabel;
  final bool busy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: password,
    builder: (context, _) {
      final ready = password.text.isNotEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: Copy.sendPassword,
            controller: password,
            obscure: true,
            onSubmitted: (_) => ready && !busy ? onConfirm() : null,
          ),
          const SizedBox(height: Metrics.gap),
          PillButton(label: label, busy: busy, busyLabel: busyLabel, expand: true, onPressed: ready ? onConfirm : null),
        ],
      );
    },
  );
}
