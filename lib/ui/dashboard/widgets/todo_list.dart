import 'package:flutter/material.dart';

import '../../../models/field_def.dart';
import '../../../models/record_entry.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

/// The body of a to-do chart: the model's records as a checklist. Each row is a
/// record — a checkbox (the [doneField] BOOL), the [labelField] text, and an
/// optional [tagField] pill. Tapping a row calls [onToggle] to flip done.
///
/// Undone rows sort above done ones (stable within each group); the list scrolls
/// inside a capped height so the dashboard card stays compact.
class TodoList extends StatelessWidget {
  const TodoList({
    super.key,
    required this.records,
    required this.labelField,
    required this.doneField,
    required this.tagField,
    required this.onToggle,
  });

  final List<RecordEntry> records;
  final FieldDef labelField;
  final FieldDef doneField;
  final FieldDef? tagField;
  final ValueChanged<RecordEntry> onToggle;

  bool _isDone(RecordEntry r) => r.values[doneField.id] == true;

  @override
  Widget build(BuildContext context) {
    // Undone first, then done — preserving record order within each group.
    final sorted = [...records]
      ..sort((a, b) {
        final da = _isDone(a), db = _isDone(b);
        if (da == db) return 0;
        return da ? 1 : -1;
      });
    final doneCount = records.where(_isDone).length;
    final leftCount = records.length - doneCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 264),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: sorted.length,
            itemBuilder: (_, i) {
              final r = sorted[i];
              return _TodoRow(
                label: _text(r, labelField),
                tag: tagField == null ? null : _text(r, tagField!),
                done: _isDone(r),
                onTap: () => onToggle(r),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        const _DottedRule(),
        const SizedBox(height: 12),
        _Footer(left: leftCount, done: doneCount),
      ],
    );
  }

  /// The display text of [field] on [r], or empty when unset.
  String _text(RecordEntry r, FieldDef field) {
    final v = r.values[field.id];
    if (v == null) return '';
    return v.toString();
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.label,
    required this.tag,
    required this.done,
    required this.onTap,
  });

  final String label;
  final String? tag;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            _Checkbox(done: done),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label.isEmpty ? '—' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.ui(
                  size: 14,
                  color: done ? T.textDim : T.text,
                ).copyWith(
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: T.textDim,
                  decorationThickness: 1.5,
                ),
              ),
            ),
            if (tag != null && tag!.isNotEmpty) ...[
              const SizedBox(width: 12),
              _TagPill(text: tag!, dim: done),
            ],
          ],
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: done ? T.text : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: done ? T.text : T.textMid, width: 1.5),
      ),
      child: done
          ? const Icon(Icons.check, size: 13, color: T.surface)
          : null,
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.text, required this.dim});
  final String text;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.4 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: T.line),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.mono(size: 10, color: T.textDim, letterSpacing: 1),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.left, required this.done});
  final int left;
  final int done;

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            style: AppText.mono(size: 11, color: T.textDim, letterSpacing: 2),
            children: [
              TextSpan(
                  text: _pad(left),
                  style: AppText.mono(
                      size: 11,
                      weight: FontWeight.w800,
                      color: T.text,
                      letterSpacing: 2)),
              const TextSpan(text: ' LEFT · '),
              TextSpan(
                  text: _pad(done),
                  style: AppText.mono(
                      size: 11,
                      weight: FontWeight.w800,
                      color: T.accent,
                      letterSpacing: 2)),
              const TextSpan(text: ' DONE'),
            ],
          ),
        ),
      ],
    );
  }
}

/// The dotted divider from the mockup, between the list and the count footer.
class _DottedRule extends StatelessWidget {
  const _DottedRule();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 4.0, gap = 4.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: dash, height: 1, color: T.line),
          ),
        );
      },
    );
  }
}
