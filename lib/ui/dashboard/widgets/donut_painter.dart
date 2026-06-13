import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/chart_data.dart';

/// Paints a [ChartData] as a donut ring or a solid pie, starting at 12 o'clock
/// with a small angular gap between slices. Matches the prototype's SVG donut.
class DonutPainter extends CustomPainter {
  DonutPainter({required this.data, required this.donut});

  final ChartData data;
  final bool donut;

  static const _start = -math.pi / 2; // 12 o'clock
  static const _gap = 0.045; // radians between slices

  @override
  void paint(Canvas canvas, Size size) {
    if (data.total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2;
    final multi = data.slices.length > 1;
    var angle = _start;

    if (donut) {
      final stroke = outer * 0.34;
      final rect = Rect.fromCircle(center: center, radius: outer - stroke / 2 - 1);
      for (final s in data.slices) {
        final sweep = s.value / data.total * 2 * math.pi;
        final g = multi ? _gap : 0.0;
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = s.color;
        canvas.drawArc(rect, angle + g / 2, sweep - g, false, paint);
        angle += sweep;
      }
    } else {
      final rect = Rect.fromCircle(center: center, radius: outer - 1);
      for (final s in data.slices) {
        final sweep = s.value / data.total * 2 * math.pi;
        final g = multi ? _gap : 0.0;
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = s.color;
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..arcTo(rect, angle + g / 2, sweep - g, false)
          ..close();
        canvas.drawPath(path, paint);
        angle += sweep;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter old) =>
      old.donut != donut ||
      old.data.total != data.total ||
      old.data.slices.length != data.slices.length;
}
