import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/chart_data.dart';
import '../../../data/field_type.dart';
import '../../../models/app_model.dart';
import '../../../models/chart_def.dart';
import '../../../models/field_def.dart';
import '../../../models/record_entry.dart';
import '../../../state/app_store.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../widgets/app_card.dart';
import 'chart_legend.dart';
import 'donut_painter.dart';
import 'todo_list.dart';

/// A dashboard chart card: header (title / "model · type · by field" / delete)
/// and a body that renders per chart type. Loads the model's records itself so
/// the dashboard stays lazy.
class ChartCard extends StatefulWidget {
  const ChartCard({super.key, required this.chart, required this.model});

  final ChartDef chart;
  final AppModel model;

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  late Future<List<RecordEntry>> _records;

  @override
  void initState() {
    super.initState();
    _records = context.read<AppStore>().loadRecords(widget.model.id);
  }

  @override
  void didUpdateWidget(ChartCard old) {
    super.didUpdateWidget(old);
    // Re-fetch when the underlying model or its record count changes.
    if (old.model.id != widget.model.id ||
        old.model.recordCount != widget.model.recordCount) {
      _records = context.read<AppStore>().loadRecords(widget.model.id);
    }
  }

  FieldDef? get _groupField {
    for (final f in widget.model.fields) {
      if (f.id == widget.chart.groupFieldId) return f;
    }
    return null;
  }

  /// The DATE field this chart was configured to filter on (via the wizard
  /// checkmark), if it still exists. Null disables the week/month/year filter.
  FieldDef? get _dateField {
    final id = widget.chart.dateFieldId;
    if (id == null) return null;
    for (final f in widget.model.fields) {
      if (f.id == id && f.type == FieldType.date) return f;
    }
    return null;
  }

  /// The INT/FLOAT field summed in the donut center, if still present. Null
  /// falls back to the record count.
  FieldDef? get _centerSumField {
    final id = widget.chart.sumFieldId;
    if (id == null) return null;
    for (final f in widget.model.fields) {
      if (f.id == id &&
          (f.type == FieldType.int_ || f.type == FieldType.float)) {
        return f;
      }
    }
    return null;
  }

  /// A configured field of [type] that still exists on the model, by id.
  FieldDef? _fieldOf(int? id, FieldType type) {
    if (id == null) return null;
    for (final f in widget.model.fields) {
      if (f.id == id && f.type == type) return f;
    }
    return null;
  }

  /// Flip a to-do row's done state: mutate the in-memory record (so the list
  /// updates without a refetch) then persist the whole record in the background.
  void _toggleDone(RecordEntry r, FieldDef doneField) {
    final next = r.values[doneField.id] != true;
    setState(() => r.values[doneField.id] = next);
    context.read<AppStore>().updateRecord(r.id, widget.model.fields, r.values);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chart;
    final gf = _groupField;
    final df = _dateField;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: c.title.isEmpty ? widget.model.name : c.title,
            filter: df == null
                ? null
                : _DateFilterControl(
                    value: c.dateFilter,
                    onChanged: (f) => context
                        .read<AppStore>()
                        .updateChartDateFilter(c.id, f),
                  ),
            onDelete: () => context.read<AppStore>().deleteChart(c.id),
          ),
          _body(gf, df),
        ],
      ),
    );
  }

  Widget _body(FieldDef? gf, FieldDef? df) {
    switch (widget.chart.type) {
      case ChartType.pie:
        return _pieBody(gf, df);
      case ChartType.todo:
        return _todoBody(df);
      default:
        return _Note('${widget.chart.type.label} charts coming soon.');
    }
  }

  Widget _pieBody(FieldDef? gf, FieldDef? df) {
    if (gf == null) {
      return const _Note('Group-by field no longer exists.\nDelete and recreate this chart.');
    }
    return FutureBuilder<List<RecordEntry>>(
      future: _records,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 188);
        }
        var records = snap.data!;
        if (df != null) {
          records = filterByDateRange(records, df, widget.chart.dateFilter);
        }
        if (records.isEmpty) {
          return _Note(df != null
              ? 'No ${widget.model.name} records in the current ${widget.chart.dateFilter.label.toLowerCase()}.'
              : 'No records to chart yet.\nAdd data to ${widget.model.name} in Record.');
        }
        final sf = _centerSumField;
        // Measure (slice sizes, %, total) is record count, or sum of [sf].
        final data = computePieData(records, gf, sumField: sf);
        if (data.total == 0) {
          return _Note('No ${sf!.name} values to chart in this selection.');
        }
        final centerValue = formatMetric(data.total);
        final centerLabel = sf != null ? sf.name.toUpperCase() : 'RECORDS';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            _Donut(
              data: data,
              style: widget.chart.style,
              centerValue: centerValue,
              centerLabel: centerLabel,
            ),
            const SizedBox(height: 18),
            ChartLegend(data: data),
          ],
        );
      },
    );
  }

  Widget _todoBody(FieldDef? df) {
    final labelField = _fieldOf(widget.chart.labelFieldId, FieldType.str);
    final doneField = _fieldOf(widget.chart.doneFieldId, FieldType.bool_);
    if (labelField == null || doneField == null) {
      return const _Note(
          'A field this list needs no longer exists.\nDelete and recreate this chart.');
    }
    final tagField = _fieldOf(widget.chart.tagFieldId, FieldType.str);
    return FutureBuilder<List<RecordEntry>>(
      future: _records,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 188);
        }
        var records = snap.data!;
        if (df != null) {
          records = filterByDateRange(records, df, widget.chart.dateFilter);
        }
        if (records.isEmpty) {
          return _Note(df != null
              ? 'No ${widget.model.name} records in the current ${widget.chart.dateFilter.label.toLowerCase()}.'
              : 'No records yet.\nAdd data to ${widget.model.name} in Record.');
        }
        return TodoList(
          records: records,
          labelField: labelField,
          doneField: doneField,
          tagField: tagField,
          onToggle: (r) => _toggleDone(r, doneField),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onDelete,
    this.filter,
  });

  final String title;
  final VoidCallback onDelete;
  final Widget? filter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(size: 18, weight: FontWeight.w600)),
        ),
        if (filter != null) ...[
          const SizedBox(width: 8),
          filter!,
        ],
        const SizedBox(width: 4),
        InkWell(
          onTap: onDelete,
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.close, size: 18, color: T.textDim),
          ),
        ),
      ],
    );
  }
}

/// Compact Week/Month/Year pill (right of the chart title) that opens a menu;
/// the selection is persisted via [onChanged]. Shown only when the model has a
/// DATE field.
class _DateFilterControl extends StatelessWidget {
  const _DateFilterControl({required this.value, required this.onChanged});

  final DateFilter value;
  final ValueChanged<DateFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DateFilter>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: 'Date range',
      color: T.surface2,
      elevation: 0,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: T.line),
      ),
      itemBuilder: (_) => [
        for (final f in DateFilter.values)
          PopupMenuItem<DateFilter>(
            value: f,
            height: 42,
            child: Text(f.label,
                style: AppText.ui(
                    size: 14,
                    weight: f == value ? FontWeight.w600 : FontWeight.w400,
                    color: f == value ? T.accent : T.text)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 6, 6, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(T.rChip),
          border: Border.all(color: T.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value.label.toUpperCase(),
                style: AppText.mono(
                    size: 11,
                    weight: FontWeight.w700,
                    color: T.textMid,
                    letterSpacing: 1)),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: T.textDim),
          ],
        ),
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({
    required this.data,
    required this.style,
    required this.centerValue,
    required this.centerLabel,
  });

  final ChartData data;
  final PieStyle style;
  final String centerValue;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final donut = style == PieStyle.donut;
    return Center(
      child: SizedBox(
        width: 188,
        height: 188,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(188),
              painter: DonutPainter(data: data, donut: donut),
            ),
            if (donut)
              SizedBox(
                width: 150, // keep the metric inside the ring
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(centerValue,
                          maxLines: 1,
                          style: AppText.display(size: 34, weight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 1),
                    Text(centerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppText.mono(size: 9, color: T.textDim, letterSpacing: 2)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 26, 0, 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.mono(size: 12, color: T.textDim, letterSpacing: 0),
      ),
    );
  }
}
