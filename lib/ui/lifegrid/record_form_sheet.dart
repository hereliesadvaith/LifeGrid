import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/field_type.dart';
import '../../models/app_model.dart';
import '../../models/field_def.dart';
import '../../models/record_entry.dart';
import '../../state/app_store.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/primary_button.dart';
import '../widgets/sheet.dart';

/// Dynamic, type-aware form for adding OR editing a record.
/// Pass [existing] to edit; omit it to add. Returns true if saved.
Future<bool?> showRecordFormSheet({
  required BuildContext context,
  required AppStore store,
  required AppModel model,
  RecordEntry? existing,
}) {
  final editing = existing != null;
  final singular = model.name.replaceAll(RegExp(r's$'), '');
  return showAppSheet<bool>(
    context: context,
    title: editing ? 'Edit record' : 'Add record',
    subtitle: editing ? 'edit $singular' : 'new $singular entry',
    builder: (ctx) => _RecordForm(store: store, model: model, existing: existing),
  );
}

class _RecordForm extends StatefulWidget {
  const _RecordForm({required this.store, required this.model, this.existing});

  final AppStore store;
  final AppModel model;
  final RecordEntry? existing;

  @override
  State<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<_RecordForm> {
  late final Map<int, TextEditingController> _text;
  late final Map<int, bool> _bools;
  final Map<int, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _text = {};
    _bools = {};
    for (final f in widget.model.fields) {
      final v = existing?.value(f.id);
      if (f.type == FieldType.bool_) {
        _bools[f.id] = v == true;
      } else {
        _text[f.id] = TextEditingController(text: v == null ? '' : v.toString());
      }
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    // validate text fields
    final errors = <int, String?>{};
    for (final f in widget.model.fields) {
      final c = _text[f.id];
      if (c != null) errors[f.id] = f.type.validate(c.text);
    }
    if (errors.values.any((e) => e != null)) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }

    final values = <int, Object?>{};
    for (final f in widget.model.fields) {
      if (f.type == FieldType.bool_) {
        values[f.id] = _bools[f.id] ?? false;
      } else {
        final raw = _text[f.id]!.text.trim();
        values[f.id] = raw.isEmpty ? null : f.type.decode(raw);
      }
    }

    if (widget.existing != null) {
      await widget.store
          .updateRecord(widget.existing!.id, widget.model.fields, values);
    } else {
      await widget.store.addRecord(widget.model.id, widget.model.fields, values);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in widget.model.fields) ...[
          _FieldHead(name: f.name, code: f.type.code),
          const SizedBox(height: 10),
          _control(f),
          const SizedBox(height: 20),
        ],
        PrimaryButton(
          label: widget.existing != null ? 'Save changes' : 'Save record',
          onPressed: _save,
        ),
      ],
    );
  }

  Widget _control(FieldDef f) {
    switch (f.type) {
      case FieldType.bool_:
        return _BoolRow(
          value: _bools[f.id] ?? false,
          onChanged: (v) => setState(() => _bools[f.id] = v),
        );
      case FieldType.date:
        return SheetInput(
          controller: _text[f.id]!,
          hint: 'YYYY-MM-DD',
          readOnly: true,
          errorText: _errors[f.id],
          onTap: () => _pickDate(f),
        );
      default:
        return SheetInput(
          controller: _text[f.id]!,
          hint: f.type == FieldType.str ? 'Enter ${f.name}' : '0',
          keyboardType: f.type.keyboardType,
          errorText: _errors[f.id],
        );
    }
  }

  Future<void> _pickDate(FieldDef f) async {
    final current = DateTime.tryParse(_text[f.id]!.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: T.accent,
            surface: T.surface,
            onSurface: T.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _text[f.id]!.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }
}

class _FieldHead extends StatelessWidget {
  const _FieldHead({required this.name, required this.code});
  final String name;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(name.toUpperCase(),
              style: AppText.mono(size: 11, color: T.textMid, letterSpacing: 1.5)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(T.rChip),
            border: Border.all(color: T.line),
          ),
          child: Text(code,
              style: AppText.mono(size: 10, weight: FontWeight.w700, color: T.textDim, letterSpacing: 1)),
        ),
      ],
    );
  }
}

class _BoolRow extends StatelessWidget {
  const _BoolRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: T.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.line),
        ),
        child: Row(
          children: [
            Text('false / true', style: AppText.mono(size: 13, color: T.textMid)),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                color: value ? T.accent : T.surface3,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: value ? T.accent : T.line),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
