/// Chart types. Only [pie] is implemented; [bar]/[line] are declared now (and
/// shown as "soon" in the picker) so adding them later is a localized change.
enum ChartType {
  pie('pie', 'Pie / donut', 'PIE', soon: false),
  bar('bar', 'Bar', 'BAR', soon: true),
  line('line', 'Line', 'LINE', soon: true);

  const ChartType(this.code, this.label, this.short, {required this.soon});

  /// Stored in the DB.
  final String code;

  /// Human label in the picker (e.g. "Pie / donut").
  final String label;

  /// Short code shown on the type card (e.g. "PIE").
  final String short;

  /// Not yet implemented — disabled in the picker.
  final bool soon;

  static ChartType fromCode(String code) =>
      ChartType.values.firstWhere((t) => t.code == code, orElse: () => pie);
}

/// Pie-specific render style: a donut ring (with the total in the hole) or a
/// solid pie. Ignored by non-pie chart types.
enum PieStyle {
  donut('donut', 'Donut'),
  pie('pie', 'Pie');

  const PieStyle(this.code, this.label);

  final String code;
  final String label;

  static PieStyle fromCode(String? code) =>
      PieStyle.values.firstWhere((s) => s.code == code, orElse: () => donut);
}

/// A saved chart on the Dashboard — a descriptor over an existing model. It does
/// not copy data; the slices are recomputed from the model's records on render.
///
/// References by row id ([modelId]/[groupFieldId]) so a chart survives a renamed
/// field and degrades gracefully if its model/field is deleted (see plan §2).
class ChartDef {
  const ChartDef({
    required this.id,
    required this.modelId,
    required this.type,
    required this.groupFieldId,
    required this.style,
    required this.title,
    required this.position,
  });

  final int id;
  final int modelId;
  final ChartType type;

  /// FK -> fields.id. Null if the field was deleted after the chart was made.
  final int? groupFieldId;

  final PieStyle style;
  final String title;
  final int position;

  factory ChartDef.fromMap(Map<String, Object?> m) => ChartDef(
        id: m['id'] as int,
        modelId: m['model_id'] as int,
        type: ChartType.fromCode(m['type'] as String),
        groupFieldId: m['group_field'] as int?,
        style: PieStyle.fromCode(m['style'] as String?),
        title: m['title'] as String,
        position: m['position'] as int,
      );
}
