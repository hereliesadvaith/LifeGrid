import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// The dashed-glyph empty state from the prototype (`.empty`).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.glyph,
    required this.title,
    required this.message,
    this.action,
  });

  final String glyph;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: T.line),
              ),
              alignment: Alignment.center,
              child: Text(glyph,
                  style: AppText.display(size: 30, color: T.textMid)),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: AppText.ui(size: 18, weight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.ui(size: 14, color: T.textDim, height: 1.55),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Small pill "ghost" button used inside empty states.
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: T.surface2,
      borderRadius: BorderRadius.circular(T.rChip),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.rChip),
        side: const BorderSide(color: T.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(T.rChip),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(label,
              style: AppText.ui(size: 14, weight: FontWeight.w600)),
        ),
      ),
    );
  }
}
