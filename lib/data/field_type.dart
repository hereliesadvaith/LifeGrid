import 'package:flutter/material.dart';

/// The five field types from the prototype's `TYPES` array.
enum FieldType {
  str('STR', 'Text'),
  int_('INT', 'Integer'),
  date('DATE', 'Date'),
  float('FLOAT', 'Decimal'),
  bool_('BOOL', 'Boolean');

  const FieldType(this.code, this.label);

  /// Stored in the DB and shown as the type chip (e.g. "STR").
  final String code;

  /// Human label shown in the type picker (e.g. "Text").
  final String label;

  static FieldType fromCode(String code) =>
      FieldType.values.firstWhere((t) => t.code == code);

  /// Encode a typed Dart value into the canonical TEXT form stored in `values`.
  /// Returns null for empty/unset (stored as SQL NULL).
  String? encode(Object? value) {
    if (value == null) return null;
    switch (this) {
      case FieldType.bool_:
        return (value as bool) ? '1' : '0';
      case FieldType.str:
        final s = value.toString();
        return s.isEmpty ? null : s;
      case FieldType.int_:
      case FieldType.float:
      case FieldType.date:
        final s = value.toString();
        return s.isEmpty ? null : s;
    }
  }

  /// Decode the canonical TEXT form back into a typed Dart value.
  Object? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    switch (this) {
      case FieldType.bool_:
        return raw == '1';
      case FieldType.int_:
        return int.tryParse(raw);
      case FieldType.float:
        return double.tryParse(raw);
      case FieldType.str:
      case FieldType.date:
        return raw;
    }
  }

  /// Display string for a record value (used in lists/cards). "—" when empty.
  String format(Object? value) {
    if (value == null) return '—';
    switch (this) {
      case FieldType.bool_:
        return value == true ? 'true' : 'false';
      default:
        return value.toString();
    }
  }

  /// Validate raw text input from the form. Returns an error string, or null if ok.
  /// Empty is allowed (treated as unset). Not applicable to BOOL (toggle/date picker).
  String? validate(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    switch (this) {
      case FieldType.int_:
        return int.tryParse(v) == null ? 'Must be a whole number' : null;
      case FieldType.float:
        return double.tryParse(v) == null ? 'Must be a number' : null;
      case FieldType.date:
        return DateTime.tryParse(v) == null ? 'Must be a valid date' : null;
      case FieldType.str:
      case FieldType.bool_:
        return null;
    }
  }

  TextInputType get keyboardType {
    switch (this) {
      case FieldType.int_:
        return TextInputType.number;
      case FieldType.float:
        return const TextInputType.numberWithOptions(decimal: true);
      default:
        return TextInputType.text;
    }
  }
}
