import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_model.dart';
import '../../state/app_store.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/app_card.dart';
import '../widgets/common.dart';
import '../widgets/empty_state.dart';
import '../widgets/rise_in.dart';
import 'records_page.dart';

/// Tab 1 — pick a model to log data into. Shows record + field counts.
class LifegridTab extends StatelessWidget {
  const LifegridTab({super.key, required this.onGoToSchemas});

  final VoidCallback onGoToSchemas;

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
            eyebrow: 'Your records',
            subtitle: 'Pick a model to log data',
            count: models.length,
          ),
          Expanded(
            child: store.loading
                ? const SizedBox.shrink()
                : models.isEmpty
                    ? EmptyState(
                        glyph: '▢',
                        title: 'Nothing to fill yet',
                        message:
                            'Create a model in Schemas first, then come back here to start logging data into it.',
                        action: GhostButton(
                          label: 'Go to Schemas ›',
                          onPressed: onGoToSchemas,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 4, bottom: 130),
                        itemCount: models.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => RiseIn(
                          index: i,
                          child: _DataCard(model: models[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        slideRoute(RecordsPage(modelId: model.id)),
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(model.recordCount.toString(),
                  style: AppText.display(size: 15, weight: FontWeight.w900)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(model.recordCount == 1 ? 'record' : 'records',
                    style: AppText.mono(size: 11, weight: FontWeight.w700, color: T.textMid)),
              ),
              const Spacer(),
              Text(plural(model.fields.length, 'field'),
                  style: AppText.mono(size: 12, color: T.textMid)),
            ],
          ),
        ],
      ),
    );
  }
}
