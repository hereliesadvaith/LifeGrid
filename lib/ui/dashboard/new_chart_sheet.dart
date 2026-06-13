import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _canNext => _model != null && _type != null;
  bool get _canCreate =>
      _type == ChartType.pie && _model != null && _groupBy != null;

  void _next() {
    if (!_canNext) return;
    if (_title.text.trim().isEmpty) _title.text = _model!.name;
    setState(() => _step = 2);
  }

  Future<void> _create() async {
    if (!_canCreate) return;
    final title = _title.text.trim();
    await widget.store.createChart(
      modelId: _model!.id,
      type: _type!,
      groupFieldId: _groupBy!.id,
      style: _style,
      title: title.isEmpty ? _model!.name : title,
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
                  _groupBy = null; // reset field when model changes
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
      if (_type == ChartType.pie) ..._pieConfig(),
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
      const SheetLabel('Title'),
      SheetInput(controller: _title, hint: 'e.g. workouts by exercise'),
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
