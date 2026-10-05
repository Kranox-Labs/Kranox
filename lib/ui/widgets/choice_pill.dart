import 'package:flutter/material.dart';

import '../theme/kranox_theme.dart';
import '../theme/typography.dart';

/// A pill for one of a few options, such as a network or a way to receive. The active pill has the accent color.
/// Without [onTap], the pill takes no tap.
class ChoicePill extends StatelessWidget {
  const ChoicePill({super.key, required this.label, required this.active, required this.onTap});

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
