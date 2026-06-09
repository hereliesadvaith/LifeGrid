import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Shows the prototype's rounded-top bottom sheet (grabber, title, subtitle).
/// The [builder] receives a scroll-aware content area; pad for the keyboard.
Future<R?> showAppSheet<R>({
  required BuildContext context,
  required String title,
  required String subtitle,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: T.surface,
            border: Border(top: BorderSide(color: T.line)),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                T.pad, 10, T.pad, 24 + MediaQuery.of(ctx).padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(top: 6, bottom: 18),
                    decoration: BoxDecoration(
                      color: T.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(title,
                    style: AppText.display(
                        size: 24, weight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(subtitle.toUpperCase(),
                    style: AppText.mono(size: 11, color: T.textDim, letterSpacing: 1)),
                const SizedBox(height: 22),
                builder(ctx),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The uppercase mono field label used inside sheets (`.flabel`).
class SheetLabel extends StatelessWidget {
  const SheetLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(),
          style: AppText.mono(size: 11, color: T.textMid, letterSpacing: 1.5)),
    );
  }
}

/// Mono text input styled like the prototype's `.input` / `.dinput`.
class SheetInput extends StatelessWidget {
  const SheetInput({
    super.key,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.autofocus = false,
    this.errorText,
    this.onSubmitted,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool autofocus;
  final String? errorText;
  final VoidCallback? onSubmitted;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autofocus: autofocus,
      readOnly: readOnly,
      onTap: onTap,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: AppText.mono(size: 15, color: T.text),
      cursorColor: T.accent,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: AppText.mono(size: 15, color: T.textDim),
        errorText: errorText,
        errorStyle: AppText.mono(size: 11, color: T.accent),
        filled: true,
        fillColor: T.surface2,
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: _border(T.line),
        focusedBorder: _border(T.textMid),
        errorBorder: _border(T.accent),
        focusedErrorBorder: _border(T.accent),
      ),
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.rField),
        borderSide: BorderSide(color: c),
      );
}
