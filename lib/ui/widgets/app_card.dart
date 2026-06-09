import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The tappable surface card from the prototype (`.card` / `.field` / `.record`).
/// Scales slightly on press to match `:active{transform:scale(.985)}`.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.radius = T.rCard,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: T.surface,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: _down ? const Color(0xFF3A3A3A) : T.line),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
