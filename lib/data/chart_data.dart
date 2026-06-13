import 'package:flutter/material.dart';

import '../models/chart_def.dart';
import '../models/field_def.dart';
import '../models/record_entry.dart';
import '../theme/tokens.dart';
import 'field_type.dart';

/// One pie slice = a distinct value of the group-by field and its measured
/// amount: record count, or the sum of a chosen numeric field. [pct]/[color]
/// are assigned by [computePieData].
class Slice {
  Slice({required this.label, required this.value});

  final String label;
  final num value;
  late int pct;
  late Color color;
}

/// The slices of a chart plus the measured total (shown in the donut hole).
class ChartData {
  const ChartData(this.slices, this.total);

  final List<Slice> slices;
  final num total;
}

/// Keep only records whose [dateField] value falls in the current week / month
/// / year. The DATE field stores ISO `YYYY-MM-DD`; null/unparseable values are
/// dropped while a filter is active. [now] is injectable for testing.
List<RecordEntry> filterByDateRange(
  List<RecordEntry> records,
  FieldDef dateField,
  DateFilter filter, {
  DateTime? now,
}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  bool inRange(DateTime d) {
    final day = DateUtils.dateOnly(d);
    switch (filter) {
      case DateFilter.week:
        // Week starts Sunday. weekday is Mon=1..Sun=7, so % 7 maps Sun->0.
        final start = today.subtract(Duration(days: today.weekday % 7));
        final end = start.add(const Duration(days: 7));
        return !day.isBefore(start) && day.isBefore(end);
      case DateFilter.month:
        return day.year == today.year && day.month == today.month;
      case DateFilter.year:
        return day.year == today.year;
    }
  }

  return records.where((r) {
    final v = r.values[dateField.id];
    if (v is! String || v.isEmpty) return false;
    final d = DateTime.tryParse(v);
    return d != null && inRange(d);
  }).toList();
}

/// Compact display for a measured value: whole numbers as integers, otherwise
/// trimmed to 2 decimals.
String formatMetric(num v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

/// Group [records] by their [groupBy] value and measure each group, largest
/// slice first, with palette colors and percentages. The measure — and so the
/// slice sizes, percentages and total — is the **record count** when [sumField]
/// is null, or the **sum of [sumField]** otherwise.
ChartData computePieData(
  List<RecordEntry> records,
  FieldDef groupBy, {
  FieldDef? sumField,
}) {
  final values = <String, num>{};
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
    final num contribution;
    if (sumField == null) {
      contribution = 1; // count measure
    } else {
      final sv = r.values[sumField.id];
      contribution = sv is num ? sv : 0; // sum measure (null -> 0)
    }
    values.update(key, (n) => n + contribution, ifAbsent: () => contribution);
  }

  final slices = values.entries
      .map((e) => Slice(label: e.key, value: e.value))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final total = slices.fold<num>(0, (s, x) => s + x.value);
  for (var i = 0; i < slices.length; i++) {
    slices[i].color = kChartPalette[i % kChartPalette.length];
    slices[i].pct = total == 0 ? 0 : (slices[i].value / total * 100).round();
  }
  return ChartData(slices, total);
}
