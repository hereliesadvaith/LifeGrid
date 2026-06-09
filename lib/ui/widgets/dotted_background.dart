import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The dotted radial-grid backdrop from the prototype:
///   radial-gradient(circle, rgba(255,255,255,0.04) 1px, transparent 1.4px) 0 0/22px 22px
class DottedBackground extends StatelessWidget {
  const DottedBackground({super.key, this.child, this.opacity = 0.04});

  final Widget? child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotPainter(opacity),
      child: child,
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.opacity);

  final double opacity;
  static const _gap = 22.0;
  static const _radius = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = T.text.withValues(alpha: opacity);
    for (double y = 0; y < size.height; y += _gap) {
      for (double x = 0; x < size.width; x += _gap) {
        canvas.drawCircle(Offset(x, y), _radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) => oldDelegate.opacity != opacity;
}
