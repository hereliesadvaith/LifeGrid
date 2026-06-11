import 'field_def.dart';

/// A model = a collection of records sharing a schema (its fields).
class AppModel {
  const AppModel({
    required this.id,
    required this.name,
    required this.position,
    required this.fields,
    required this.recordCount,
  });

  final int id;
  final String name;
  final int position;
  final List<FieldDef> fields;
  final int recordCount;

  /// The schema is editable only while the model holds no records (plan §7.2).
  bool get schemaLocked => recordCount > 0;

  /// Distinct field type codes, used for the chips on the Schema list.
  List<String> get typeCodes {
    final seen = <String>{};
    for (final f in fields) {
      seen.add(f.type.code);
    }
    return seen.toList();
  }
}
