/// A single record (row) belonging to a model.
///
/// [values] maps field id -> decoded typed value (String/int/double/bool/null).
class RecordEntry {
  const RecordEntry({
    required this.id,
    required this.modelId,
    required this.values,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int modelId;
  final Map<int, Object?> values;
  final int createdAt;
  final int updatedAt;

  Object? value(int fieldId) => values[fieldId];
}
