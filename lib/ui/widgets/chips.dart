import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Small type-code pill (e.g. "STR") used on schema cards and field rows.
class TypeChip extends StatelessWidget {
  const TypeChip(this.code, {super.key, this.dashed = false, this.strong = false});

  final String code;
  final bool dashed;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: strong ? 11 : 8, vertical: strong ? 5 : 3),
      decoration: BoxDecoration(
        color: strong ? T.surface3 : T.surface2,
        borderRadius: BorderRadius.circular(T.rChip),
        border: Border.all(
          color: T.line,
          style: dashed ? BorderStyle.none : BorderStyle.solid,
        ),
      ),
      child: Text(
        code,
        style: AppText.mono(
          size: strong ? 11 : 10,
          weight: FontWeight.w700,
          color: dashed ? T.textDim : T.textMid,
          letterSpacing: strong ? 1 : 0,
        ),
      ),
    );
  }
}

/// key/value meta pill on record cards (`.kv`).
class KvChip extends StatelessWidget {
  const KvChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: T.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: T.line),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$label ', style: AppText.mono(size: 11, color: T.textDim)),
            TextSpan(text: value, style: AppText.mono(size: 11, color: T.textMid)),
          ],
        ),
      ),
    );
  }
}
