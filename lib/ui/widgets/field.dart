import 'package:flutter/material.dart';

import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';

/// A field of a form with its label above it, in the shapes of the look.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.note,
    this.obscure = false,
    this.lines = 1,
    this.suffix,
    this.onSubmitted,
    this.autofocus = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final String? note;
  final bool obscure;
  final int lines;
  final String? suffix;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Metrics.radiusField),
      borderSide: BorderSide(color: color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KranoxType.smallStrong.copyWith(color: palette.inkSoft)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          minLines: lines,
          maxLines: obscure ? 1 : lines,
          autofocus: autofocus,
          keyboardType: keyboardType,
          onSubmitted: onSubmitted,
          autocorrect: false,
          enableSuggestions: false,
          style: KranoxType.body.copyWith(color: palette.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.field,
            hintText: hint,
            hintStyle: KranoxType.body.copyWith(color: palette.inkFaint),
            suffixText: suffix,
            suffixStyle: KranoxType.smallStrong.copyWith(color: palette.inkSoft),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: border(palette.line),
            enabledBorder: border(palette.line),
            focusedBorder: border(palette.accent),
            errorBorder: border(palette.danger),
            focusedErrorBorder: border(palette.danger),
            errorText: error,
            errorStyle: KranoxType.small.copyWith(color: palette.danger),
            errorMaxLines: 3,
            helperText: error == null ? note : null,
            helperStyle: KranoxType.small.copyWith(color: palette.inkFaint),
            helperMaxLines: 3,
          ),
        ),
      ],
    );
  }
}
