import '../data/field_type.dart';

/// A single field (column) on a model.
class FieldDef {
  const FieldDef({
    required this.id,
    required this.modelId,
    required this.name,
    required this.type,
    required this.position,
  });

  final int id;
  final int modelId;
  final String name;
  final FieldType type;
  final int position;

  factory FieldDef.fromMap(Map<String, Object?> m) => FieldDef(
        id: m['id'] as int,
        modelId: m['model_id'] as int,
        name: m['name'] as String,
        type: FieldType.fromCode(m['type'] as String),
        position: m['position'] as int,
      );
}
