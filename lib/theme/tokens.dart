import 'package:flutter/material.dart';

/// Design tokens ported verbatim from `schema_app.html` (the CSS `:root` vars).
class T {
  T._();

  // colors
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF0C0C0C);
  static const surface2 = Color(0xFF161616);
  static const surface3 = Color(0xFF1E1E1E);
  static const line = Color(0xFF262626);
  static const lineSoft = Color(0xFF1A1A1A);
  static const text = Color(0xFFFFFFFF);
  static const textMid = Color(0xFF9A9A9A);
  static const textDim = Color(0xFF5E5E5E);
  static const accent = Color(0xFFD71921);

  // the "selected" red-tinted surface used on the type picker
  static const accentSurface = Color(0xFF160708);

  // radii
  static const rCard = 16.0;
  static const rChip = 999.0;
  static const rField = 14.0;

  // spacing
  static const pad = 20.0;

  // app frame
  static const maxWidth = 430.0;
  static const navHeight = 66.0;
}

/// Chart slice palette ported from the prototype (`PALETTE`): accent red leads,
/// then white → greys. Cycled when a chart has more slices than colors.
const kChartPalette = [
  Color(0xFFD71921),
  Color(0xFFFFFFFF),
  Color(0xFF9A9A9A),
  Color(0xFF5E5E5E),
  Color(0xFFC98A8D),
  Color(0xFF3A3A3A),
  Color(0xFFE8E8E8),
  Color(0xFF7A7A7A),
];
