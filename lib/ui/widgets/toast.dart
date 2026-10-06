import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/kranox_theme.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';

/// The pages of the open wallet with room for a toast at their foot: a short note such as "Copied", in a small pill
/// in the middle below the page, beside the sidebar. It rises and fades in, stays a moment, and fades out; a new note
/// takes the place of the one in view, so that notes never queue. The owner found the bar of Material, which ran
/// under the sidebar from edge to edge of the window, too long on 6 Oct 2026.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  /// The host of the page that holds [context]. Every page of the open wallet has one.
  static ToastHostState of(BuildContext context) {
    final host = context.findAncestorStateOfType<ToastHostState>();
    if (host == null) throw StateError('A toast needs a ToastHost above the widget that shows it.');
    return host;
  }

  @override
  State<ToastHost> createState() => ToastHostState();
}

class ToastHostState extends State<ToastHost> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this, duration: Metrics.toastFade);
  late final Animation<double> _shown = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _lift = Tween<Offset>(
    begin: const Offset(0, Metrics.toastLift),
    end: Offset.zero,
  ).animate(_shown);
  String _message = '';
  Timer? _hide;

  /// Shows [message] for a moment, in place of a note that may be in view.
  void show(String message) {
    _hide?.cancel();
    setState(() => _message = message);
    _motion.forward();
    _hide = Timer(Metrics.toastStay, () {
      if (mounted) _motion.reverse();
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      Positioned(
        left: 0,
        right: 0,
        bottom: Metrics.toastBottom,
        child: IgnorePointer(
          child: FadeTransition(
            opacity: _shown,
            child: SlideTransition(
              position: _lift,
              child: Center(child: _Toast(_message)),
            ),
          ),
        ),
      ),
    ],
  );
}

/// The pill of a toast: a check in the accent beside the note, in the colors of the text and the ground turned around,
/// with a shadow. A pill in the colors of a card looked like a part of the button below it.
class _Toast extends StatelessWidget {
  const _Toast(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: palette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: Metrics.raisedElevation,
        shape: const StadiumBorder(),
        child: Padding(
          padding: Metrics.toastPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 18, color: palette.accent),
              const SizedBox(width: Metrics.gapTiny + 2),
              Text(message, style: KranoxType.body.copyWith(color: palette.ground)),
            ],
          ),
        ),
      ),
    );
  }
}
