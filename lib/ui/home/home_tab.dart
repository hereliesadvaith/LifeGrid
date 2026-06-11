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
import '../widgets/search_field.dart';
import 'records_page.dart';

/// Home page — pick a model to log data into. Shows record + field counts and
/// a search bar that filters the model list by name.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.onGoToSchema});

  final VoidCallback onGoToSchema;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final models = store.models;
    final filtered = _query.isEmpty
        ? models
        : models
            .where((m) => m.name.toLowerCase().contains(_query))
            .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: T.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitleHeader(title: 'Records', count: models.length),
          if (models.isNotEmpty)
            SearchField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          Expanded(
            child: store.loading
                ? const SizedBox.shrink()
                : models.isEmpty
                    ? EmptyState(
                        glyph: '▢',
                        title: 'Nothing to fill yet',
                        message:
                            'Create a model in Schema first, then come back here to start logging data into it.',
                        action: GhostButton(
                          label: 'Go to Schema ›',
                          onPressed: widget.onGoToSchema,
                        ),
                      )
                    : filtered.isEmpty
                        ? NoResult(_query)
                        : ListView.separated(
                            padding: const EdgeInsets.only(top: 4, bottom: 130),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => RiseIn(
                              index: i,
                              child: _DataCard(model: filtered[i]),
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
