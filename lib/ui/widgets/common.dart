import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

/// Slide-in-from-right route matching the prototype's `translateX(100%)` overlay.
Route<R> slideRoute<R>(Widget page) {
  return PageRouteBuilder<R>(
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      return SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: animation, curve: const Cubic(.22, 1, .36, 1))),
        child: child,
      );
    },
  );
}

/// The bordered count badge shown in tab/page headers (`.count`).
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(T.rChip),
        border: Border.all(color: T.line),
      ),
      child: Text(count.toString().padLeft(2, '0'),
          style: AppText.mono(size: 13, weight: FontWeight.w700, color: T.textMid)),
    );
  }
}

/// Eyebrow + subtitle + count header used at the top of each tab.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.subtitle,
    required this.count,
  });

  final String eyebrow;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('●  ',
                  style: AppText.mono(size: 11, color: T.accent, weight: FontWeight.w700)),
              Text(eyebrow.toUpperCase(), style: AppText.eyebrow()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(subtitle.toUpperCase(),
                    style: AppText.mono(size: 13, color: T.textDim, letterSpacing: 2)),
              ),
              CountBadge(count),
            ],
          ),
        ],
      ),
    );
  }
}

/// Back-arrow + breadcrumb + big title header for drill-down pages.
class OverlayHeader extends StatelessWidget {
  const OverlayHeader({
    super.key,
    required this.breadcrumb,
    required this.title,
    required this.subtitle,
  });

  final String breadcrumb;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _BackButton(onTap: () => Navigator.of(context).maybePop()),
            const SizedBox(width: 14),
            Text(breadcrumb.toUpperCase(),
                style: AppText.mono(size: 11, color: T.textDim, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 14),
        Text(title, style: AppText.display(size: 32, weight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(subtitle.toUpperCase(),
            style: AppText.mono(size: 11, color: T.textDim, letterSpacing: 1)),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: T.surface,
      shape: const CircleBorder(side: BorderSide(color: T.line)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.chevron_left, color: T.text, size: 22),
        ),
      ),
    );
  }
}
