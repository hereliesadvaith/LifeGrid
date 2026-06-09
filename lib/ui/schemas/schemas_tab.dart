import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_model.dart';
import '../../state/app_store.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/app_card.dart';
import '../widgets/chips.dart';
import '../widgets/common.dart';
import '../widgets/empty_state.dart';
import '../widgets/rise_in.dart';
import 'fields_page.dart';

/// Tab 2 — the list of models, each showing its field count and type chips.
class SchemasTab extends StatelessWidget {
  const SchemasTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final models = store.models;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: T.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            eyebrow: 'Data structure',
            subtitle: 'Define models and fields',
            count: models.length,
          ),
          Expanded(
            child: store.loading
                ? const SizedBox.shrink()
                : models.isEmpty
                    ? const EmptyState(
                        glyph: '+',
                        title: 'No models yet',
                        message:
                            'Create your first model to start defining the shape of your data.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 4, bottom: 130),
                        itemCount: models.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => RiseIn(
                          index: i,
                          child: _ModelCard(model: models[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final codes = model.typeCodes;
    final shown = codes.take(4).toList();
    final extra = codes.length - shown.length;

    return AppCard(
      onTap: () => Navigator.of(context).push(
        slideRoute(FieldsPage(modelId: model.id)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(model.name,
                    style: AppText.ui(size: 19, weight: FontWeight.w600)),
              ),
              Text('›', style: AppText.mono(size: 18, color: T.textDim)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(plural(model.fields.length, 'field'),
                  style: AppText.mono(size: 12, color: T.textMid)),
              const Spacer(),
              Wrap(
                spacing: 5,
                children: [
                  for (final c in shown) TypeChip(c),
                  if (extra > 0) TypeChip('+$extra', dashed: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
