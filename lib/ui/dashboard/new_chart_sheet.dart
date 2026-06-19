import 'package:flutter/material.dart';

import '../../data/field_type.dart';
import '../../models/app_model.dart';
import '../../models/chart_def.dart';
import '../../models/field_def.dart';
import '../../state/app_store.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/primary_button.dart';
import '../widgets/sheet.dart';

/// The two-step "New chart" wizard.
///   Step 1 — pick a model + chart type (generic to every chart type).
///   Step 2 — type-specific config only (group-by field, style, title).
/// Model & type are fixed on step 2 (shown as context, not re-pickable).
Future<void> showNewChartSheet(BuildContext context, AppStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: T.surface,
          border: Border(top: BorderSide(color: T.line)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              T.pad, 10, T.pad, 24 + MediaQuery.of(ctx).padding.bottom),
          child: _NewChartWizard(store: store),
        ),
      ),
    ),
  );
}

class _NewChartWizard extends StatefulWidget {
  const _NewChartWizard({required this.store});
  final AppStore store;

  @override
  State<_NewChartWizard> createState() => _NewChartWizardState();
}

class _NewChartWizardState extends State<_NewChartWizard> {
  final _title = TextEditingController();
  int _step = 1;
  AppModel? _model;
  ChartType? _type;
  FieldDef? _groupBy;
  PieStyle _style = PieStyle.donut;
  bool _useSum = false; // false = count measure, true = sum a numeric field
  FieldDef? _sumField; // the field summed when _useSum (slices/%/center)
  FieldDef? _dateField; // optional DATE field to filter by (null = off)
  // To-do chart config.
  FieldDef? _todoLabel; // STR field — task text (required)
  FieldDef? _todoDone; // BOOL field — checkbox / done state (required)
  FieldDef? _todoTag; // STR field — optional right-side pill (null = off)

  /// INT/FLOAT fields on the selected model — candidates for the sum measure.
  List<FieldDef> get _numericFields {
    final m = _model;
    if (m == null) return const [];
    return m.fields
        .where((f) => f.type == FieldType.int_ || f.type == FieldType.float)
        .toList();
  }

  /// DATE fields on the selected model — candidates for the date filter.
  List<FieldDef> get _dateFields {
    final m = _model;
    if (m == null) return const [];
    return m.fields.where((f) => f.type == FieldType.date).toList();
  }

  /// STR fields — candidates for the to-do label and tag.
  List<FieldDef> get _textFields {
    final m = _model;
    if (m == null) return const [];
    return m.fields.where((f) => f.type == FieldType.str).toList();
  }

  /// BOOL fields — candidates for the to-do done state.
  List<FieldDef> get _boolFields {
    final m = _model;
    if (m == null) return const [];
    return m.fields.where((f) => f.type == FieldType.bool_).toList();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _canNext => _model != null && _type != null;
  bool get _canCreate {
    if (_model == null) return false;
    switch (_type) {
      case ChartType.pie:
        return _groupBy != null &&
            (!_useSum || _sumField != null); // sum needs a chosen field
      case ChartType.todo:
        return _todoLabel != null && _todoDone != null; // tag is optional
      default:
        return false;
    }
  }

  void _next() {
    if (!_canNext) return;
    if (_title.text.trim().isEmpty) _title.text = _model!.name;
    setState(() => _step = 2);
  }

  Future<void> _create() async {
    if (!_canCreate) return;
    final title = _title.text.trim();
    final isTodo = _type == ChartType.todo;
    await widget.store.createChart(
      modelId: _model!.id,
      type: _type!,
      groupFieldId: isTodo ? null : _groupBy!.id,
      style: _style,
      title: title.isEmpty ? _model!.name : title,
      dateFieldId: _dateField?.id,
      sumFieldId: !isTodo && _useSum ? _sumField?.id : null,
      labelFieldId: isTodo ? _todoLabel!.id : null,
      doneFieldId: isTodo ? _todoDone!.id : null,
      tagFieldId: isTodo ? _todoTag?.id : null,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(top: 6, bottom: 18),
            decoration: BoxDecoration(
              color: T.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        if (_step == 1) ..._buildStep1() else ..._buildStep2(),
      ],
    );
  }

  // ---------------------------------------------------- step 1: model + type ---
  List<Widget> _buildStep1() {
    final models = widget.store.models;
    return [
      Text('New chart',
          style: AppText.display(size: 24, weight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text('PICK A MODEL & CHART TYPE',
          style: AppText.mono(size: 11, color: T.textDim, letterSpacing: 1)),
      const SizedBox(height: 22),
      const SheetLabel('Model'),
      if (models.isEmpty)
        const _SheetNote('No models yet — create one in Schema first.')
      else
        ...models.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PickCard(
                title: m.name,
                meta: '${m.recordCount} rec · ${m.fields.length} fld',
                selected: _model?.id == m.id,
                onTap: () => setState(() {
                  _model = m;
                  // Field availability differs per model — reset all picks.
                  _groupBy = null;
                  _useSum = false;
                  _sumField = null;
                  _dateField = null;
                  _todoLabel = null;
                  _todoDone = null;
                  _todoTag = null;
                }),
              ),
            )),
      const SizedBox(height: 12),
      const SheetLabel('Chart type'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.5,
        children: [
          for (final t in ChartType.values)
            _ChartTypeCard(
              type: t,
              selected: _type == t,
              onTap: t.soon ? null : () => setState(() => _type = t),
            ),
        ],
      ),
      const SizedBox(height: 18),
      _DimmedButton(
        enabled: _canNext,
        child: PrimaryButton(label: 'Next ›', onPressed: _next),
      ),
    ];
  }

  // ----------------------------------------------- step 2: type-specific config ---
  List<Widget> _buildStep2() {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleBack(onTap: () => setState(() => _step = 1)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configure',
                    style: AppText.display(
                        size: 24, weight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('${_model!.name} · ${_type!.label}'.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mono(size: 11, color: T.textDim, letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      // Per-type config. Add a branch here when bar/line land.
      if (_type == ChartType.pie)
        ..._pieConfig()
      else if (_type == ChartType.todo)
        ..._todoConfig(),
      const SizedBox(height: 4),
      _DimmedButton(
        enabled: _canCreate,
        child: PrimaryButton(label: 'Create chart', onPressed: _create),
      ),
    ];
  }

  List<Widget> _pieConfig() {
    final fields = _model!.fields;
    return [
      const SheetLabel('Group by'),
      if (fields.isEmpty)
        const _SheetNote('This model has no fields — add some in Schema.')
      else
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final f in fields)
              _FieldChip(
                field: f,
                selected: _groupBy?.id == f.id,
                onTap: () => setState(() => _groupBy = f),
              ),
          ],
        ),
      const SizedBox(height: 22),
      // Measure: slice sizes, percentages and the center total are by record
      // count, or by the sum of a chosen numeric field. Sum needs a number
      // field, so the toggle only appears when the model has one.
      if (_numericFields.isNotEmpty) ...[
        const SheetLabel('Measure'),
        Row(
          children: [
            Expanded(
              child: _SegButton(
                label: 'Count',
                selected: !_useSum,
                onTap: () => setState(() {
                  _useSum = false;
                  _sumField = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SegButton(
                label: 'Sum',
                selected: _useSum,
                onTap: () => setState(() => _useSum = true),
              ),
            ),
          ],
        ),
        if (_useSum) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final f in _numericFields)
                _SelectChip(
                  label: f.name,
                  code: f.type.code,
                  selected: _sumField?.id == f.id,
                  onTap: () => setState(() => _sumField = f),
                ),
            ],
          ),
        ],
        const SizedBox(height: 22),
      ],
      const SheetLabel('Style'),
      Row(
        children: [
          for (final s in PieStyle.values) ...[
            Expanded(
              child: _SegButton(
                label: s.label,
                selected: _style == s,
                onTap: () => setState(() => _style = s),
              ),
            ),
            if (s != PieStyle.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
      const SizedBox(height: 22),
      // Optional — pick which DATE field to filter the chart by (or Off). The
      // week/month/year range itself is chosen later, on the chart card.
      if (_dateFields.isNotEmpty) ...[
        const SheetLabel('Date filter'),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _SelectChip(
              label: 'Off',
              selected: _dateField == null,
              onTap: () => setState(() => _dateField = null),
            ),
            for (final f in _dateFields)
              _SelectChip(
                label: f.name,
                code: f.type.code,
                selected: _dateField?.id == f.id,
                onTap: () => setState(() => _dateField = f),
              ),
          ],
        ),
        const SizedBox(height: 22),
      ],
      const SheetLabel('Title'),
      SheetInput(controller: _title, hint: 'e.g. workouts by exercise'),
      const SizedBox(height: 22),
    ];
  }

  List<Widget> _todoConfig() {
    final texts = _textFields;
    final bools = _boolFields;
    return [
      // Label — the task text on each row (required STR field).
      const SheetLabel('Task label'),
      if (texts.isEmpty)
        const _SheetNote('This model has no text field — add one in Schema.')
      else
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final f in texts)
              _FieldChip(
                field: f,
                selected: _todoLabel?.id == f.id,
                onTap: () => setState(() {
                  _todoLabel = f;
                  if (_todoTag?.id == f.id) _todoTag = null; // can't reuse label
                }),
              ),
          ],
        ),
      const SizedBox(height: 22),
      // Done — the checkbox / LEFT·DONE counts (required BOOL field).
      const SheetLabel('Done state'),
      if (bools.isEmpty)
        const _SheetNote(
            'This model has no boolean field — add one in Schema to track done.')
      else
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final f in bools)
              _FieldChip(
                field: f,
                selected: _todoDone?.id == f.id,
                onTap: () => setState(() => _todoDone = f),
              ),
          ],
        ),
      const SizedBox(height: 22),
      // Tag — optional right-side pill. Only the text fields not used as label.
      if (texts.length > 1 || (texts.isNotEmpty && _todoLabel == null)) ...[
        const SheetLabel('Tag'),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _SelectChip(
              label: 'Off',
              selected: _todoTag == null,
              onTap: () => setState(() => _todoTag = null),
            ),
            for (final f in texts.where((f) => f.id != _todoLabel?.id))
              _SelectChip(
                label: f.name,
                code: f.type.code,
                selected: _todoTag?.id == f.id,
                onTap: () => setState(() => _todoTag = f),
              ),
          ],
        ),
        const SizedBox(height: 22),
      ],
      // Optional DATE filter — same mechanism as the pie chart.
      if (_dateFields.isNotEmpty) ...[
        const SheetLabel('Date filter'),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _SelectChip(
              label: 'Off',
              selected: _dateField == null,
              onTap: () => setState(() => _dateField = null),
            ),
            for (final f in _dateFields)
              _SelectChip(
                label: f.name,
                code: f.type.code,
                selected: _dateField?.id == f.id,
                onTap: () => setState(() => _dateField = f),
              ),
          ],
        ),
        const SizedBox(height: 22),
      ],
      const SheetLabel('Title'),
      SheetInput(controller: _title, hint: 'e.g. today\'s tasks'),
      const SizedBox(height: 22),
    ];
  }
}

// --------------------------------------------------------------- sub-widgets ---

/// Selectable model row (prototype `.pickcard`).
class _PickCard extends StatelessWidget {
  const _PickCard({
    required this.title,
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String meta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? T.accentSurface : T.surface2,
          borderRadius: BorderRadius.circular(T.rField),
          border: Border.all(color: selected ? T.accent : T.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(size: 15, weight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            Text(meta, style: AppText.mono(size: 11, color: T.textDim)),
          ],
        ),
      ),
    );
  }
}

/// Chart-type card in the type grid (prototype `.typecard`, with a SOON badge
/// for unimplemented types).
class _ChartTypeCard extends StatelessWidget {
  const _ChartTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ChartType type;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final soon = onTap == null;
    return Opacity(
      opacity: soon ? 0.4 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? T.accentSurface : T.surface2,
            borderRadius: BorderRadius.circular(T.rField),
            border: Border.all(color: selected ? T.accent : T.line),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(type.short,
                      style: AppText.display(
                          size: 20, weight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(type.label, style: AppText.ui(size: 12, color: T.textDim)),
                ],
              ),
              if (soon)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(T.rChip),
                      border: Border.all(color: T.line),
                    ),
                    child: Text('SOON',
                        style: AppText.mono(
                            size: 9, weight: FontWeight.w700, color: T.textDim, letterSpacing: 1)),
                  ),
                )
              else
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? T.accent : Colors.transparent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable field pill (prototype `.fchip`).
class _FieldChip extends StatelessWidget {
  const _FieldChip({
    required this.field,
    required this.selected,
    required this.onTap,
  });

  final FieldDef field;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? T.accentSurface : T.surface2,
          borderRadius: BorderRadius.circular(T.rChip),
          border: Border.all(color: selected ? T.accent : T.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(field.name,
                style: AppText.mono(
                    size: 12,
                    weight: FontWeight.w700,
                    color: selected ? T.text : T.textMid)),
            const SizedBox(width: 7),
            Text(field.type.code,
                style: AppText.mono(
                    size: 9,
                    color: selected ? T.accent : T.textDim,
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

/// Donut/Pie segmented toggle button (prototype `.seg-toggle button`).
class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? T.accentSurface : T.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? T.accent : T.line),
        ),
        child: Text(label,
            style: AppText.ui(
                size: 13,
                weight: FontWeight.w600,
                color: selected ? T.text : T.textMid)),
      ),
    );
  }
}

/// Dims + disables its button child when [enabled] is false (PrimaryButton has
/// no built-in disabled style).
class _DimmedButton extends StatelessWidget {
  const _DimmedButton({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: IgnorePointer(ignoring: !enabled, child: child),
    );
  }
}

/// Generic selectable pill (used for the center-value choice: Count + numeric
/// fields), styled like [_FieldChip] but with an optional type code.
class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.code,
  });

  final String label;
  final String? code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? T.accentSurface : T.surface2,
          borderRadius: BorderRadius.circular(T.rChip),
          border: Border.all(color: selected ? T.accent : T.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppText.mono(
                    size: 12,
                    weight: FontWeight.w700,
                    color: selected ? T.text : T.textMid)),
            if (code != null) ...[
              const SizedBox(width: 7),
              Text(code!,
                  style: AppText.mono(
                      size: 9,
                      color: selected ? T.accent : T.textDim,
                      letterSpacing: 1)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: T.surface2,
      shape: const CircleBorder(side: BorderSide(color: T.line)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.chevron_left, color: T.text, size: 22),
        ),
      ),
    );
  }
}

class _SheetNote extends StatelessWidget {
  const _SheetNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: AppText.mono(size: 11, color: T.textDim, letterSpacing: 0)),
    );
  }
}
