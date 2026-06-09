import 'package:flutter/material.dart';

import '../../state/app_store.dart';
import '../widgets/primary_button.dart';
import '../widgets/sheet.dart';

Future<void> showNewModelSheet(BuildContext context, AppStore store) {
  final controller = TextEditingController();

  Future<void> create(BuildContext sheetCtx) async {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    await store.createModel(name);
    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
  }

  return showAppSheet(
    context: context,
    title: 'New model',
    subtitle: 'A collection of records',
    builder: (sheetCtx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetLabel('Model name'),
        SheetInput(
          controller: controller,
          hint: 'e.g. workouts',
          autofocus: true,
          onSubmitted: () => create(sheetCtx),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Create model',
          onPressed: () => create(sheetCtx),
        ),
      ],
    ),
  );
}
