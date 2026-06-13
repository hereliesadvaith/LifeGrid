import 'package:flutter/material.dart';

import '../models/field_def.dart';
import '../models/record_entry.dart';
import '../theme/tokens.dart';
import 'field_type.dart';

/// One pie slice = a distinct value of the group-by field and how many records
/// carry it. [pct]/[color] are assigned by [computePieData].
class Slice {
  Slice({required this.label, required this.count});

  final String label;
  final int count;
  late int pct;
  late Color color;
}

/// The slices of a chart plus the record total (shown in the donut hole).
class ChartData {
  const ChartData(this.slices, this.total);

  final List<Slice> slices;
  final int total;
}

/// Tally [records] by their value for [groupBy], largest slice first, with
/// palette colors and rounded percentages. Mirrors the prototype `computeSlices`.
ChartData computePieData(List<RecordEntry> records, FieldDef groupBy) {
  final counts = <String, int>{};
  for (final r in records) {
    final v = r.values[groupBy.id];
    final String key;
    if (v == null || (v is String && v.isEmpty)) {
      key = '—'; // uncategorized
    } else if (groupBy.type == FieldType.bool_) {
      key = v == true ? 'true' : 'false';
    } else {
      key = v.toString();
    }
    counts.update(key, (n) => n + 1, ifAbsent: () => 1);
  }

  final slices = counts.entries
      .map((e) => Slice(label: e.key, count: e.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));

  final total = slices.fold<int>(0, (s, x) => s + x.count);
  for (var i = 0; i < slices.length; i++) {
    slices[i].color = kChartPalette[i % kChartPalette.length];
    slices[i].pct = total == 0 ? 0 : (slices[i].count / total * 100).round();
  }
  return ChartData(slices, total);
}
