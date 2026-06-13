import 'package:flutter_test/flutter_test.dart';

import 'package:lifegrid/data/chart_data.dart';
import 'package:lifegrid/data/field_type.dart';
import 'package:lifegrid/models/chart_def.dart';
import 'package:lifegrid/models/field_def.dart';
import 'package:lifegrid/models/record_entry.dart';

RecordEntry _rec(int id, int fieldId, String? date) => RecordEntry(
      id: id,
      modelId: 1,
      values: {fieldId: date},
      createdAt: 0,
      updatedAt: 0,
    );

void main() {
  group('FieldType encode/decode', () {
    test('BOOL round-trips through canonical form', () {
      expect(FieldType.bool_.encode(true), '1');
      expect(FieldType.bool_.encode(false), '0');
      expect(FieldType.bool_.decode('1'), true);
      expect(FieldType.bool_.decode('0'), false);
    });

    test('empty values encode to null', () {
      expect(FieldType.str.encode(''), isNull);
      expect(FieldType.int_.encode(''), isNull);
      expect(FieldType.str.decode(null), isNull);
    });

    test('numbers decode to typed values', () {
      expect(FieldType.int_.decode('42'), 42);
      expect(FieldType.float.decode('4.5'), 4.5);
    });
  });

  group('FieldType validation', () {
    test('rejects non-numeric INT/FLOAT and bad dates', () {
      expect(FieldType.int_.validate('abc'), isNotNull);
      expect(FieldType.float.validate('1.2.3'), isNotNull);
      expect(FieldType.date.validate('not-a-date'), isNotNull);
    });

    test('accepts valid input and empty', () {
      expect(FieldType.int_.validate('10'), isNull);
      expect(FieldType.float.validate('10.5'), isNull);
      expect(FieldType.date.validate('2026-06-10'), isNull);
      expect(FieldType.str.validate(''), isNull);
    });
  });

  group('filterByDateRange', () {
    const dateField = FieldDef(
      id: 7,
      modelId: 1,
      name: 'day',
      type: FieldType.date,
      position: 0,
    );
    // Wednesday 2026-06-10; Sunday-based week is Sun 06-07 .. Sat 06-13.
    final now = DateTime(2026, 6, 10);
    final records = [
      _rec(1, 7, '2026-06-07'), // Sunday — week start
      _rec(2, 7, '2026-06-13'), // Saturday — week end
      _rec(3, 7, '2026-06-14'), // next Sunday — out of week, in month
      _rec(4, 7, '2026-06-06'), // prev Saturday — out of week, in month
      _rec(5, 7, '2026-05-31'), // last month — in year only
      _rec(6, 7, '2025-12-31'), // last year — out of all
      _rec(7, 7, null), // no date — always excluded
      _rec(8, 7, 'oops'), // unparseable — excluded
    ];

    List<int> ids(DateFilter f) =>
        filterByDateRange(records, dateField, f, now: now)
            .map((r) => r.id)
            .toList();

    test('week keeps Sun..Sat of the current week', () {
      expect(ids(DateFilter.week), [1, 2]);
    });

    test('month keeps the current calendar month', () {
      expect(ids(DateFilter.month), [1, 2, 3, 4]);
    });

    test('year keeps the current calendar year', () {
      expect(ids(DateFilter.year), [1, 2, 3, 4, 5]);
    });
  });

  group('computePieData', () {
    const cat = FieldDef(
      id: 2,
      modelId: 1,
      name: 'category',
      type: FieldType.str,
      position: 0,
    );

    test('count measure tallies, sorts desc, and computes percentages', () {
      final records = [
        _rec(1, 2, 'food'),
        _rec(2, 2, 'food'),
        _rec(3, 2, 'food'),
        _rec(4, 2, 'rent'),
      ];
      final data = computePieData(records, cat);
      expect(data.total, 4);
      expect(data.slices.first.label, 'food');
      expect(data.slices.first.value, 3);
      expect(data.slices.first.pct, 75);
    });

    test('sum measure aggregates a numeric field per category', () {
      const amount = FieldDef(
        id: 3,
        modelId: 1,
        name: 'amount',
        type: FieldType.float,
        position: 1,
      );
      RecordEntry rec(int id, String c, num a) => RecordEntry(
            id: id,
            modelId: 1,
            values: {2: c, 3: a},
            createdAt: 0,
            updatedAt: 0,
          );
      final data = computePieData(
        [rec(1, 'food', 10.5), rec(2, 'food', 9.5), rec(3, 'rent', 30)],
        cat,
        sumField: amount,
      );
      expect(data.total, 50); // 10.5 + 9.5 + 30
      expect(data.slices.first.label, 'rent'); // 30 is the largest
      expect(data.slices.first.value, 30);
      expect(data.slices.first.pct, 60);
    });

    test('null/empty values fall into the "—" bucket', () {
      final data = computePieData([_rec(1, 2, null)], cat);
      expect(data.slices.single.label, '—');
    });
  });
}
