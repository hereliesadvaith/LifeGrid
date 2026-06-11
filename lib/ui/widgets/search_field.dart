import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Pill-shaped search bar (`.searchbar`) shown above the Home / Schema model
/// lists. Filters the in-memory list by name; UI-only, no persistence.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search models',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppText.ui(size: 14, weight: FontWeight.w400),
        cursorColor: T.accent,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: AppText.ui(size: 14, weight: FontWeight.w400, color: T.textDim),
          prefixIcon: const Icon(Icons.search, size: 18, color: T.textDim),
          prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          filled: true,
          fillColor: T.surface,
          contentPadding: const EdgeInsets.fromLTRB(0, 13, 16, 13),
          enabledBorder: _border(T.line),
          focusedBorder: _border(T.textMid),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.rChip),
        borderSide: BorderSide(color: c),
      );
}

/// Centered mono "no models match …" line shown when a search filters
/// everything out (`.noresult`).
class NoResult extends StatelessWidget {
  const NoResult(this.query, {super.key});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Text(
        'No models match “$query”',
        textAlign: TextAlign.center,
        style: AppText.mono(size: 12, color: T.textDim, letterSpacing: 1),
      ),
    );
  }
}
