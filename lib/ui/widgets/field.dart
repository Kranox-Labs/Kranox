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
    this.action,
    this.onChanged,
    this.good = false,
    this.mono = false,
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

  /// A small button inside the field at its right, such as "Paste".
  final Widget? action;
  final ValueChanged<String>? onChanged;

  /// Whether [note] confirms the value, such as a checked address: it shows with a check in the accent color.
  final bool good;

  /// Whether the value shows in the font for addresses and ids.
  final bool mono;

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
          onChanged: onChanged,
          autocorrect: false,
          enableSuggestions: false,
          style: (mono ? KranoxType.mono : KranoxType.body).copyWith(color: palette.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.field,
            hintText: hint,
            hintStyle: KranoxType.body.copyWith(color: palette.inkFaint),
            suffixText: action == null ? suffix : null,
            suffixStyle: KranoxType.smallStrong.copyWith(color: palette.inkSoft),
            suffixIcon: action == null ? null : Padding(padding: const EdgeInsets.only(right: 8), child: action),
            suffixIconConstraints: const BoxConstraints(minHeight: 32),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: border(palette.line),
            enabledBorder: border(palette.line),
            focusedBorder: border(palette.accent),
            errorBorder: border(palette.danger),
            focusedErrorBorder: border(palette.danger),
            errorText: error,
            errorStyle: KranoxType.small.copyWith(color: palette.danger),
            errorMaxLines: 3,
            helperText: error == null && !good ? note : null,
            helper: error == null && good && note != null
                ? Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: palette.accent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(note!, style: KranoxType.small.copyWith(color: palette.accent)),
                      ),
                    ],
                  )
                : null,
            helperStyle: KranoxType.small.copyWith(color: palette.inkFaint),
            helperMaxLines: 3,
          ),
        ),
      ],
    );
  }
}
