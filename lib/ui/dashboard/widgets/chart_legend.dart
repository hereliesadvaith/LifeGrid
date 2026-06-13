import 'package:flutter/material.dart';

import '../../../data/chart_data.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

/// The legend under a chart: one row per slice — color dot · label · % · count,
/// with hairline dividers between rows (prototype `.legend` / `.leg-row`).
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.data});

  final ChartData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < data.slices.length; i++)
          _LegendRow(slice: data.slices[i], divider: i > 0),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.divider});

  final Slice slice;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
      decoration: BoxDecoration(
        border: divider
            ? const Border(top: BorderSide(color: T.lineSoft))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: slice.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(size: 14, weight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Text('${slice.pct}%',
              style: AppText.mono(
                  size: 13, weight: FontWeight.w700, color: T.textMid)),
          const SizedBox(width: 10),
          Text(
            formatMetric(slice.value),
            textAlign: TextAlign.right,
            style: AppText.mono(size: 11, color: T.textDim),
          ),
        ],
      ),
    );
  }
}
