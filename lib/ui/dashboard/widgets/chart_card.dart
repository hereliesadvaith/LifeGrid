import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/chart_data.dart';
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

  @override
  Widget build(BuildContext context) {
    final c = widget.chart;
    final gf = _groupField;
    final subtitle = gf == null
        ? '${widget.model.name} · ${c.type.label}'
        : '${widget.model.name} · ${c.type.label} · by ${gf.name}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: c.title.isEmpty ? widget.model.name : c.title,
            subtitle: subtitle,
            onDelete: () => context.read<AppStore>().deleteChart(c.id),
          ),
          _body(gf),
        ],
      ),
    );
  }

  Widget _body(FieldDef? gf) {
    if (widget.chart.type != ChartType.pie) {
      return _Note('${widget.chart.type.label} charts coming soon.');
    }
    if (gf == null) {
      return const _Note('Group-by field no longer exists.\nDelete and recreate this chart.');
    }
    return FutureBuilder<List<RecordEntry>>(
      future: _records,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 188);
        }
        final data = computePieData(snap.data!, gf);
        if (data.total == 0) {
          return _Note('No records to chart yet.\nAdd data to ${widget.model.name} in Record.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            _Donut(data: data, style: widget.chart.style),
            const SizedBox(height: 18),
            ChartLegend(data: data),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.ui(size: 18, weight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(subtitle.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.mono(size: 11, color: T.textDim, letterSpacing: 1)),
            ],
          ),
        ),
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

class _Donut extends StatelessWidget {
  const _Donut({required this.data, required this.style});

  final ChartData data;
  final PieStyle style;

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
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${data.total}',
                      style: AppText.display(size: 34, weight: FontWeight.w900)),
                  const SizedBox(height: 1),
                  Text('RECORDS',
                      style: AppText.mono(size: 9, color: T.textDim, letterSpacing: 2)),
                ],
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
