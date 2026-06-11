import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_model.dart';
import '../../models/field_def.dart';
import '../../state/app_store.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/chips.dart';
import '../widgets/common.dart';
import '../widgets/dotted_background.dart';
import '../widgets/empty_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/rise_in.dart';
import '../widgets/sheet.dart';
import 'add_field_sheet.dart';

/// Drill-down from the Schema tab: the fields of one model.
/// When the model has records its schema is locked — add/remove is disabled.
class FieldsPage extends StatelessWidget {
  const FieldsPage({super.key, required this.modelId});

  final int modelId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final model = store.modelById(modelId);

    // Model was deleted (e.g. via the delete button) — pop back out.
    if (model == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final locked = model.schemaLocked;

    return Scaffold(
      body: DottedBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: T.maxWidth),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: T.pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OverlayHeader(
                          breadcrumb: 'Schema · Structure',
                          title: model.name,
                          subtitle: plural(model.fields.length, 'field'),
                        ),
                        if (locked) const _LockBanner(),
                        Expanded(
                          child: model.fields.isEmpty
                              ? const EmptyState(
                                  glyph: ':',
                                  title: 'No fields yet',
                                  message:
                                      'Add a field to define what this model stores.',
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 150),
                                  itemCount: model.fields.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (_, i) => RiseIn(
                                    index: i,
                                    child: _FieldRow(
                                      model: model,
                                      field: model.fields[i],
                                      index: i,
                                      locked: locked,
                                      store: store,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomBar(
                      children: [
                        PrimaryButton(
                          label: 'Add field',
                          plus: true,
                          onPressed: locked
                              ? null
                              : () => showAddFieldSheet(context, store, modelId),
                        ),
                        const SizedBox(height: 10),
                        PrimaryButton(
                          label: 'Delete model',
                          danger: true,
                          onPressed: () => _confirmDeleteModel(context, store, model),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmDeleteModel(
    BuildContext context, AppStore store, AppModel model) async {
  final ok = await showAppSheet<bool>(
    context: context,
    title: 'Delete model',
    subtitle: 'This removes ${plural(model.recordCount, 'record')} too',
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Delete “${model.name}” and all of its data? This cannot be undone.',
          style: AppText.ui(size: 14, color: T.textMid, height: 1.5),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Delete permanently',
          danger: true,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
        const SizedBox(height: 10),
        PrimaryButton(label: 'Cancel', onPressed: () => Navigator.of(ctx).pop(false)),
      ],
    ),
  );
  if (ok == true) {
    await store.deleteModel(model.id);
    // FieldsPage's null-guard will pop once the model is gone.
  }
}

class _LockBanner extends StatelessWidget {
  const _LockBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(T.rField),
        border: Border.all(color: T.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: T.textMid),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Schema is locked — delete all records to change fields.',
              style: AppText.mono(size: 11, color: T.textMid, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.model,
    required this.field,
    required this.index,
    required this.locked,
    required this.store,
  });

  final AppModel model;
  final FieldDef field;
  final int index;
  final bool locked;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: locked ? null : () => _rename(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.rField),
          border: Border.all(color: T.line),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text((index + 1).toString().padLeft(2, '0'),
                  style: AppText.mono(size: 11, color: T.textDim)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(field.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(size: 16, weight: FontWeight.w500)),
            ),
            TypeChip(field.type.code, strong: true),
            if (!locked) ...[
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18, color: T.textDim),
                onPressed: () => store.deleteField(model.id, field.id),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: field.name);
    await showAppSheet(
      context: context,
      title: 'Rename field',
      subtitle: field.type.label,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetLabel('Field name'),
          SheetInput(controller: controller, autofocus: true),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Save',
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await store.renameField(model.id, field.id, name);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          T.pad, 16, T.pad, 20 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [T.bg, T.bg, Colors.transparent],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
