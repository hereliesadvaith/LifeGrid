import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_store.dart';
import '../../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/empty_state.dart';
import '../widgets/rise_in.dart';
import 'widgets/chart_card.dart';

/// Dashboard — the app's home page: a list of user-created charts over their
/// models, with a floating "+ New chart" bar (wired in home_shell).
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final charts = store.charts;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: T.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitleHeader(title: 'Dashboard', count: charts.length),
          Expanded(
            child: store.loading
                ? const SizedBox.shrink()
                : charts.isEmpty
                    ? const EmptyState(
                        glyph: '◔',
                        title: 'No charts yet',
                        message:
                            'Create a chart from one of your models to see your data at a glance.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 4, bottom: 130),
                        itemCount: charts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, i) {
                          final chart = charts[i];
                          final model = store.modelById(chart.modelId);
                          // CASCADE removes charts when a model is deleted, so a
                          // missing model is transient; skip rather than crash.
                          if (model == null) return const SizedBox.shrink();
                          return RiseIn(
                            index: i,
                            child: ChartCard(chart: chart, model: model),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
