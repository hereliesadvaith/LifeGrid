/// Chart types. [pie] and [todo] are implemented; [bar]/[line] are declared now
/// (and shown as "soon" in the picker) so adding them later is a localized
/// change.
enum ChartType {
  todo('todo', 'To-do list', 'TODO', soon: false),
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

/// Date range a chart is filtered to, available only when its model has a DATE
/// field. Defaults to the current week (a null stored value resolves to [week]).
enum DateFilter {
  week('week', 'Week'),
  month('month', 'Month'),
  year('year', 'Year');

  const DateFilter(this.code, this.label);

  final String code;
  final String label;

  static DateFilter fromCode(String? code) =>
      DateFilter.values.firstWhere((d) => d.code == code, orElse: () => week);
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
    required this.dateFieldId,
    required this.dateFilter,
    required this.sumFieldId,
    required this.labelFieldId,
    required this.doneFieldId,
    required this.tagFieldId,
  });

  final int id;
  final int modelId;
  final ChartType type;

  /// FK -> fields.id. Null if the field was deleted after the chart was made.
  final int? groupFieldId;

  final PieStyle style;
  final String title;
  final int position;

  /// Optional INT/FLOAT field summed in the donut center. Null = show the
  /// record count (the default).
  final int? sumFieldId;

  /// The DATE field this chart filters on, chosen via the wizard checkmark.
  /// Null means the date filter is off (it's optional).
  final int? dateFieldId;

  /// The saved date range, applied only when [dateFieldId] is set; resolves to
  /// [DateFilter.week] when never explicitly chosen.
  final DateFilter dateFilter;

  // --- todo-chart fields (null on non-todo charts) ---

  /// FK -> fields.id (a STR field). The task text shown on each row. Null if
  /// the field was deleted after the chart was made.
  final int? labelFieldId;

  /// FK -> fields.id (a BOOL field). Drives each row's checkbox and the
  /// LEFT/DONE counts. Null if the field was deleted.
  final int? doneFieldId;

  /// FK -> fields.id (a STR field). Optional pill shown on the right of a row.
  final int? tagFieldId;

  factory ChartDef.fromMap(Map<String, Object?> m) => ChartDef(
        id: m['id'] as int,
        modelId: m['model_id'] as int,
        type: ChartType.fromCode(m['type'] as String),
        groupFieldId: m['group_field'] as int?,
        style: PieStyle.fromCode(m['style'] as String?),
        title: m['title'] as String,
        position: m['position'] as int,
        dateFieldId: m['date_field'] as int?,
        dateFilter: DateFilter.fromCode(m['date_filter'] as String?),
        sumFieldId: m['sum_field'] as int?,
        labelFieldId: m['label_field'] as int?,
        doneFieldId: m['done_field'] as int?,
        tagFieldId: m['tag_field'] as int?,
      );
}
