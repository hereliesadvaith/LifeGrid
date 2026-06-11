import 'package:flutter/material.dart';

import '../../data/field_type.dart';
import '../../state/app_store.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/primary_button.dart';
import '../widgets/sheet.dart';

/// Add-field sheet: name input + the 2-col type picker grid from the prototype.
Future<void> showAddFieldSheet(
  BuildContext context,
  AppStore store,
  int modelId,
) {
  return showAppSheet(
    context: context,
    title: 'Add field',
    subtitle: 'A property on this model',
    builder: (sheetCtx) => _AddFieldForm(store: store, modelId: modelId),
  );
}

class _AddFieldForm extends StatefulWidget {
  const _AddFieldForm({required this.store, required this.modelId});

  final AppStore store;
  final int modelId;

  @override
  State<_AddFieldForm> createState() => _AddFieldFormState();
}

class _AddFieldFormState extends State<_AddFieldForm> {
  final _controller = TextEditingController();
  FieldType _type = FieldType.str;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await widget.store.addField(widget.modelId, name, _type);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final types = FieldType.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetLabel('Field name'),
        SheetInput(
          controller: _controller,
          hint: 'e.g. title',
          autofocus: true,
          onSubmitted: _add,
        ),
        const SizedBox(height: 22),
        const SheetLabel('Type'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.5,
          children: [
            for (final t in types)
              _TypeCard(
                type: t,
                selected: t == _type,
                onTap: () => setState(() => _type = t),
              ),
          ],
        ),
        const SizedBox(height: 18),
        PrimaryButton(label: 'Add field', onPressed: _add),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final FieldType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                Text(type.code,
                    style: AppText.display(
                        size: 20, weight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(type.label, style: AppText.ui(size: 12, color: T.textDim)),
              ],
            ),
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
    );
  }
}
