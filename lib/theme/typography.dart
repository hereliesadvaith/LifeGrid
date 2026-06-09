import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// The three font families from the prototype:
///   --display : "Doto"          (big numeric/title display)
///   --ui      : "Space Grotesk" (general UI text)
///   --mono    : "Space Mono"    (labels, meta, codes)
class AppText {
  AppText._();

  static TextStyle display({
    double size = 26,
    FontWeight weight = FontWeight.w900,
    Color color = T.text,
    double letterSpacing = 1.5,
  }) =>
      GoogleFonts.doto(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle ui({
    double size = 16,
    FontWeight weight = FontWeight.w500,
    Color color = T.text,
    double height = 1.2,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color color = T.textMid,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.spaceMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// Uppercase mono "eyebrow" label used above lists and on sheets.
  static TextStyle eyebrow({Color color = T.textDim}) => mono(
        size: 11,
        weight: FontWeight.w400,
        color: color,
        letterSpacing: 2,
      );
}
