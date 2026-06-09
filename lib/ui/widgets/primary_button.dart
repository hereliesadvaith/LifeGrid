import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// The white pill CTA from the prototype (`.primary`), with a danger variant
/// (transparent + red text, used for "Delete model").
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.plus = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool plus;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? Colors.transparent : T.text;
    final fg = danger ? T.accent : Colors.black;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(T.rChip),
      shape: danger
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(T.rChip),
              side: const BorderSide(color: T.line),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(T.rChip),
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (plus)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text('+',
                      style: AppText.mono(
                          size: 16, weight: FontWeight.w700, color: fg)),
                ),
              Text(label,
                  style: AppText.ui(
                      size: 16, weight: FontWeight.w700, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
